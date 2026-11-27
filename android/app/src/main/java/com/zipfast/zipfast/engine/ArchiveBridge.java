package com.zipfast.zipfast.engine;

import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.Closeable;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Pattern;

import net.sf.sevenzipjbinding.ExtractAskMode;
import net.sf.sevenzipjbinding.ExtractOperationResult;
import net.sf.sevenzipjbinding.IArchiveExtractCallback;
import net.sf.sevenzipjbinding.IArchiveOpenCallback;
import net.sf.sevenzipjbinding.IArchiveOpenVolumeCallback;
import net.sf.sevenzipjbinding.ICryptoGetTextPassword;
import net.sf.sevenzipjbinding.IInArchive;
import net.sf.sevenzipjbinding.IInStream;
import net.sf.sevenzipjbinding.IOutCreateArchive7z;
import net.sf.sevenzipjbinding.IOutCreateCallback;
import net.sf.sevenzipjbinding.IOutItem7z;
import net.sf.sevenzipjbinding.ISequentialInStream;
import net.sf.sevenzipjbinding.ISequentialOutStream;
import net.sf.sevenzipjbinding.PropID;
import net.sf.sevenzipjbinding.SevenZip;
import net.sf.sevenzipjbinding.SevenZipException;
import net.sf.sevenzipjbinding.SevenZipNativeInitializationException;
import net.sf.sevenzipjbinding.impl.OutItemFactory;
import net.sf.sevenzipjbinding.impl.RandomAccessFileInStream;
import net.sf.sevenzipjbinding.impl.RandomAccessFileOutStream;
import net.sf.sevenzipjbinding.impl.VolumedArchiveInStream;

/**
 * Archive engine backed by 7-Zip (through 7-Zip-JBinding): RAR/RAR5, 7Z, ISO,
 * CAB, ZIP, TAR and friends, encrypted archives and split volumes
 * ({@code .7z.001}, {@code .zip.001}, {@code .part1.rar}, {@code .r00}).
 *
 * <p>Plain Java with no Android dependencies, so it is unit-tested on the host
 * JVM (see {@code android/engine-test}). All methods are blocking: call them
 * from a worker thread.
 *
 * <p>Licensing: 7-Zip is LGPL; its RAR decoder carries the unRAR restriction
 * (decompression only, never RAR creation).
 */
public final class ArchiveBridge {
    private ArchiveBridge() {}

    /** Receives progress: files done, files total, current entry name. */
    public interface Progress {
        void update(int done, int total, String current);
    }

    private static final Progress NO_PROGRESS = (d, t, c) -> {};
    private static final Pattern VOLUME_001 = Pattern.compile(".*\\.\\d{3}$");
    private static boolean initialized;

    /** Loads the native 7-Zip library once. */
    public static synchronized void init() throws BridgeException {
        if (initialized || SevenZip.isInitializedSuccessfully()) {
            initialized = true;
            return;
        }
        try {
            // Android (7-Zip-JBinding-4Android) bundles .so files in the APK.
            try {
                System.loadLibrary("7-Zip-JBinding");
                SevenZip.initLoadedLibraries();
            } catch (UnsatisfiedLinkError | SevenZipNativeInitializationException e) {
                // Desktop JVM: use the platform jar on the classpath.
                SevenZip.initSevenZipFromPlatformJAR();
            }
            initialized = true;
        } catch (Throwable t) {
            throw new BridgeException(BridgeException.UNSUPPORTED,
                    "Native 7-Zip engine unavailable: " + t);
        }
    }

    // ------------------------------------------------------------------
    // Opening
    // ------------------------------------------------------------------

    /** Opens volumes by name; also supplies the password to 7-Zip. */
    private static final class OpenCallback
            implements IArchiveOpenCallback, IArchiveOpenVolumeCallback, ICryptoGetTextPassword {
        private final File dir;
        private final String password;
        private String currentName;
        final List<Closeable> opened = new ArrayList<>();

        OpenCallback(File first, String password) {
            this.dir = first.getAbsoluteFile().getParentFile();
            this.currentName = first.getAbsolutePath();
            this.password = password;
        }

        @Override
        public Object getProperty(PropID propID) {
            return propID == PropID.NAME ? currentName : null;
        }

        @Override
        public IInStream getStream(String filename) throws SevenZipException {
            File f = new File(filename);
            if (!f.isAbsolute()) f = new File(dir, filename);
            if (!f.isFile()) return null; // 7-Zip treats null as "no more volumes"
            try {
                RandomAccessFile raf = new RandomAccessFile(f, "r");
                opened.add(raf);
                currentName = f.getAbsolutePath();
                return new RandomAccessFileInStream(raf);
            } catch (IOException e) {
                throw new SevenZipException("Cannot open volume " + filename, e);
            }
        }

        @Override public void setTotal(Long files, Long bytes) {}
        @Override public void setCompleted(Long files, Long bytes) {}

        @Override
        public String cryptoGetTextPassword() throws SevenZipException {
            if (password == null) throw new SevenZipException("password required");
            return password;
        }
    }

    private static final class Opened implements Closeable {
        IInArchive archive;
        OpenCallback callback;
        IInStream stream;

        @Override
        public void close() {
            try { if (archive != null) archive.close(); } catch (Exception ignored) {}
            try { if (stream != null) stream.close(); } catch (Exception ignored) {}
            for (Closeable c : callback.opened) {
                try { c.close(); } catch (Exception ignored) {}
            }
        }
    }

    private static boolean hasEncryptedMagic(File file) {
        // Header-encrypted 7z/RAR archives cannot even be listed without a password.
        try (InputStream in = new FileInputStream(file)) {
            byte[] head = new byte[6];
            int n = in.read(head);
            if (n < 6) return false;
            boolean sevenZ = head[0] == '7' && head[1] == 'z' && (head[2] & 0xff) == 0xBC;
            boolean rar = head[0] == 'R' && head[1] == 'a' && head[2] == 'r' && head[3] == '!';
            return sevenZ || rar;
        } catch (IOException e) {
            return false;
        }
    }

    private static Opened open(String path, String password) throws BridgeException {
        init();
        File file = new File(path);
        if (!file.isFile()) throw new BridgeException(BridgeException.CORRUPT, "File not found");
        Opened o = new Opened();
        o.callback = new OpenCallback(file, password);
        try {
            if (VOLUME_001.matcher(file.getName().toLowerCase()).matches()) {
                // Byte-split volumes: .7z.001, .zip.001, ...
                VolumedArchiveInStream in = new VolumedArchiveInStream(file.getName(), o.callback);
                o.stream = in;
                o.archive = SevenZip.openInArchive(null, in, o.callback);
            } else {
                // Also covers RAR volume sets: 7-Zip asks the callback for the next part.
                RandomAccessFile raf = new RandomAccessFile(file, "r");
                o.callback.opened.add(raf);
                o.stream = new RandomAccessFileInStream(raf);
                o.archive = SevenZip.openInArchive(null, o.stream, o.callback);
            }
            return o;
        } catch (Exception e) {
            o.close();
            if (hasEncryptedMagic(file) || (e instanceof SevenZipException && password != null)) {
                if (hasEncryptedMagic(file)) {
                    throw new BridgeException(
                            password == null ? BridgeException.PASSWORD_REQUIRED : BridgeException.WRONG_PASSWORD,
                            "Cannot open archive (encrypted headers or corrupt)");
                }
            }
            throw new BridgeException(BridgeException.CORRUPT, String.valueOf(e.getMessage()));
        }
    }

    // ------------------------------------------------------------------
    // Listing
    // ------------------------------------------------------------------

    private static String entryPath(IInArchive a, int i) throws SevenZipException {
        String p = a.getStringProperty(i, PropID.PATH);
        return p == null ? "" : normalize(p);
    }

    static String normalize(String raw) {
        String s = raw.replace('\\', '/');
        while (s.startsWith("./")) s = s.substring(2);
        while (s.endsWith("/")) s = s.substring(0, s.length() - 1);
        return s;
    }

    private static boolean flag(IInArchive a, int i, PropID id) throws SevenZipException {
        Object v = a.getProperty(i, id);
        return v instanceof Boolean && (Boolean) v;
    }

    /** Lists entries: {format, entries: [{path,isDir,size,modified,encrypted}]}. */
    public static Map<String, Object> list(String path, String password) throws BridgeException {
        Opened o = open(path, password);
        try {
            List<Object> entries = new ArrayList<>();
            int n = o.archive.getNumberOfItems();
            for (int i = 0; i < n; i++) {
                String p = entryPath(o.archive, i);
                if (p.isEmpty() || flag(o.archive, i, PropID.IS_ANTI)) continue;
                Map<String, Object> e = new HashMap<>();
                e.put("path", p);
                e.put("isDir", flag(o.archive, i, PropID.IS_FOLDER));
                Object size = o.archive.getProperty(i, PropID.SIZE);
                e.put("size", size instanceof Number ? ((Number) size).longValue() : 0L);
                Object when = o.archive.getProperty(i, PropID.LAST_MODIFICATION_TIME);
                e.put("modified", when instanceof Date ? ((Date) when).getTime() : 0L);
                e.put("encrypted", flag(o.archive, i, PropID.ENCRYPTED));
                entries.add(e);
            }
            Map<String, Object> result = new HashMap<>();
            result.put("format", o.archive.getArchiveFormat().toString());
            result.put("entries", entries);
            return result;
        } catch (SevenZipException e) {
            throw new BridgeException(BridgeException.CORRUPT, e.getMessage());
        } finally {
            o.close();
        }
    }

    // ------------------------------------------------------------------
    // Path safety (mirrors lib/engine/safe_path.dart)
    // ------------------------------------------------------------------

    /** Resolves {@code name} below {@code root}, or null if it would escape (Zip Slip). */
    public static File resolveSafe(File root, String rawName) {
        String name = normalize(rawName);
        if (name.isEmpty() || name.indexOf('\0') >= 0) return null;
        if (name.startsWith("/") || Pattern.matches("^[A-Za-z]:.*", name)) return null;
        try {
            File rootCanon = root.getCanonicalFile();
            File target = new File(rootCanon, name).getCanonicalFile();
            String prefix = rootCanon.getPath() + File.separator;
            if (!target.getPath().startsWith(prefix)) return null;
            return target;
        } catch (IOException e) {
            return null;
        }
    }

    static File uniqueFile(File f) {
        if (!f.exists()) return f;
        String name = f.getName();
        int dot = name.lastIndexOf('.');
        String base = dot > 0 ? name.substring(0, dot) : name;
        String ext = dot > 0 ? name.substring(dot) : "";
        for (int i = 1; ; i++) {
            File c = new File(f.getParentFile(), base + " (" + i + ")" + ext);
            if (!c.exists()) return c;
        }
    }

    // ------------------------------------------------------------------
    // Extraction
    // ------------------------------------------------------------------

    private static boolean selected(String path, Set<String> sel) {
        if (sel == null) return true;
        if (sel.contains(path)) return true;
        int i = path.lastIndexOf('/');
        while (i > 0) {
            if (sel.contains(path.substring(0, i))) return true;
            i = path.lastIndexOf('/', i - 1);
        }
        return false;
    }

    /**
     * Extracts entries. {@code conflict} is "skip", "overwrite" or "rename".
     * Returns {destinationDir, extracted, skipped, blocked}.
     */
    public static Map<String, Object> extract(
            String path, String password, String destDir, List<String> selectedPaths,
            String conflict, Progress progress, AtomicBoolean cancelled) throws BridgeException {
        final Progress report = progress == null ? NO_PROGRESS : progress;
        final Set<String> sel = selectedPaths == null ? null : new HashSet<>(selectedPaths);
        Opened o = open(path, password);
        try {
            final File root = new File(destDir);
            if (!root.isDirectory() && !root.mkdirs()) {
                throw new BridgeException(BridgeException.CORRUPT, "Cannot create " + destDir);
            }
            final IInArchive a = o.archive;
            int n = a.getNumberOfItems();
            List<Integer> picked = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                String p = entryPath(a, i);
                if (!p.isEmpty() && selected(p, sel)) picked.add(i);
            }
            final int[] indices = new int[picked.size()];
            for (int i = 0; i < indices.length; i++) indices[i] = picked.get(i);
            final int total = indices.length;

            final int[] counts = new int[4]; // extracted, skipped, blocked, done
            final String[] failure = new String[1];
            final boolean[] sawEncrypted = new boolean[1];

            class Callback implements IArchiveExtractCallback, ICryptoGetTextPassword {
                OutputStream out;
                File outFile;
                String currentName;
                boolean skipCurrent;
                boolean encryptedCurrent;

                @Override
                public ISequentialOutStream getStream(int index, ExtractAskMode mode) throws SevenZipException {
                    if (cancelled != null && cancelled.get()) throw new SevenZipException("cancelled");
                    out = null;
                    outFile = null;
                    skipCurrent = true;
                    if (mode != ExtractAskMode.EXTRACT) return null;
                    currentName = entryPath(a, index);
                    encryptedCurrent = flag(a, index, PropID.ENCRYPTED);
                    sawEncrypted[0] |= encryptedCurrent;
                    File target = resolveSafe(root, currentName);
                    if (target == null) { counts[2]++; return null; }
                    // Symlinks are never materialized.
                    Object link = a.getProperty(index, PropID.SYM_LINK);
                    if (link instanceof String && !((String) link).isEmpty()) { counts[1]++; return null; }
                    if (flag(a, index, PropID.IS_FOLDER)) { target.mkdirs(); return null; }
                    if (target.exists()) {
                        if ("skip".equals(conflict)) { counts[1]++; return null; }
                        if ("rename".equals(conflict)) target = uniqueFile(target);
                    }
                    File parent = target.getParentFile();
                    if (parent != null) parent.mkdirs();
                    try {
                        out = new BufferedOutputStream(new FileOutputStream(target), 256 * 1024);
                    } catch (IOException e) {
                        throw new SevenZipException("Cannot write " + target, e);
                    }
                    outFile = target;
                    skipCurrent = false;
                    return data -> {
                        if (cancelled != null && cancelled.get()) throw new SevenZipException("cancelled");
                        try {
                            out.write(data);
                        } catch (IOException e) {
                            throw new SevenZipException("Write failed", e);
                        }
                        return data.length;
                    };
                }

                @Override public void prepareOperation(ExtractAskMode mode) {}

                @Override
                public void setOperationResult(ExtractOperationResult result) {
                    if (out != null) {
                        try { out.close(); } catch (IOException ignored) {}
                        out = null;
                    }
                    if (!skipCurrent) {
                        if (result == ExtractOperationResult.OK) {
                            counts[0]++;
                        } else {
                            if (outFile != null) outFile.delete();
                            if (failure[0] == null) {
                                boolean pw = result == ExtractOperationResult.WRONG_PASSWORD
                                        || (encryptedCurrent && (result == ExtractOperationResult.DATAERROR
                                                || result == ExtractOperationResult.CRCERROR));
                                failure[0] = pw ? "PW" : "DATA:" + result;
                            }
                        }
                    }
                    counts[3]++;
                    report.update(counts[3], total, currentName);
                }

                @Override public void setTotal(long t) {}
                @Override public void setCompleted(long c) {}

                @Override
                public String cryptoGetTextPassword() throws SevenZipException {
                    if (password == null) throw new SevenZipException("password required");
                    return password;
                }
            }

            report.update(0, total, null);
            try {
                a.extract(indices, false, new Callback());
            } catch (SevenZipException e) {
                if (cancelled != null && cancelled.get()) {
                    throw new BridgeException(BridgeException.CANCELLED, "Cancelled");
                }
                if (sawEncrypted[0]) {
                    throw new BridgeException(
                            password == null ? BridgeException.PASSWORD_REQUIRED : BridgeException.WRONG_PASSWORD,
                            e.getMessage());
                }
                throw new BridgeException(BridgeException.CORRUPT, e.getMessage());
            }
            if (failure[0] != null) {
                if (failure[0].equals("PW")) {
                    throw new BridgeException(
                            password == null ? BridgeException.PASSWORD_REQUIRED : BridgeException.WRONG_PASSWORD,
                            "Password problem");
                }
                throw new BridgeException(BridgeException.CORRUPT, failure[0]);
            }
            Map<String, Object> result = new HashMap<>();
            result.put("destinationDir", root.getAbsolutePath());
            result.put("extracted", counts[0]);
            result.put("skipped", counts[1]);
            result.put("blocked", counts[2]);
            return result;
        } catch (SevenZipException e) {
            throw new BridgeException(BridgeException.CORRUPT, e.getMessage());
        } finally {
            o.close();
        }
    }

    // ------------------------------------------------------------------
    // Preview
    // ------------------------------------------------------------------

    /** Reads one entry fully into memory (for previews). */
    public static byte[] readEntry(String path, String entryPath, String password, long maxBytes)
            throws BridgeException {
        Opened o = open(path, password);
        try {
            int n = o.archive.getNumberOfItems();
            for (int i = 0; i < n; i++) {
                if (!entryPath(o.archive, i).equals(entryPath) || flag(o.archive, i, PropID.IS_FOLDER)) continue;
                Object size = o.archive.getProperty(i, PropID.SIZE);
                if (size instanceof Number && ((Number) size).longValue() > maxBytes) {
                    throw new BridgeException(BridgeException.CORRUPT, "Entry too large to preview");
                }
                final ByteArrayOutputStream buf = new ByteArrayOutputStream();
                ExtractOperationResult r = o.archive.extractSlow(i, data -> {
                    buf.write(data, 0, data.length);
                    return data.length;
                }, password);
                if (r == ExtractOperationResult.OK) return buf.toByteArray();
                boolean pw = r == ExtractOperationResult.WRONG_PASSWORD
                        || ((r == ExtractOperationResult.DATAERROR || r == ExtractOperationResult.CRCERROR)
                                && flag(o.archive, i, PropID.ENCRYPTED));
                if (pw) {
                    throw new BridgeException(
                            password == null ? BridgeException.PASSWORD_REQUIRED : BridgeException.WRONG_PASSWORD,
                            "Password problem");
                }
                throw new BridgeException(BridgeException.CORRUPT, r.toString());
            }
            throw new BridgeException(BridgeException.CORRUPT, "Entry not found");
        } catch (SevenZipException e) {
            boolean enc = password == null && String.valueOf(e.getMessage()).toLowerCase().contains("password");
            throw new BridgeException(enc ? BridgeException.PASSWORD_REQUIRED : BridgeException.CORRUPT,
                    e.getMessage());
        } finally {
            o.close();
        }
    }

    // ------------------------------------------------------------------
    // Creating 7z
    // ------------------------------------------------------------------

    private static final class Source {
        final File file; // null for an empty directory
        final String name;
        Source(File file, String name) { this.file = file; this.name = name; }
    }

    private static void collect(File f, String name, List<Source> out) {
        if (f.isDirectory()) {
            File[] kids = f.listFiles();
            if (kids == null || kids.length == 0) {
                out.add(new Source(null, name + "/"));
                return;
            }
            Arrays.sort(kids);
            for (File k : kids) collect(k, name + "/" + k.getName(), out);
        } else if (f.isFile()) {
            out.add(new Source(f, name));
        }
    }

    /**
     * Creates a 7z archive. {@code level} 0..9; a non-empty {@code password}
     * enables AES-256 for data and file names. Returns the output path.
     */
    public static String create7z(
            List<String> sources, String outputPath, int level, String password,
            Progress progress, AtomicBoolean cancelled) throws BridgeException {
        init();
        final Progress report = progress == null ? NO_PROGRESS : progress;
        final List<Source> items = new ArrayList<>();
        for (String s : sources) {
            File f = new File(s);
            collect(f, f.getName(), items);
        }
        final int total = items.size();
        File out = new File(outputPath);
        if (out.getParentFile() != null) out.getParentFile().mkdirs();
        final boolean usePassword = password != null && !password.isEmpty();

        class Callback implements IOutCreateCallback<IOutItem7z>, ICryptoGetTextPassword {
            int done;
            RandomAccessFile current;

            @Override
            public void setOperationResult(boolean ok) throws SevenZipException {
                if (current != null) {
                    try { current.close(); } catch (IOException ignored) {}
                    current = null;
                }
                if (!ok) throw new SevenZipException("Failed to add an item");
                done++;
                report.update(Math.min(done, total), total, done > 0 && done <= total ? items.get(done - 1).name : null);
            }

            @Override
            public IOutItem7z getItemInformation(int index, OutItemFactory<IOutItem7z> factory)
                    throws SevenZipException {
                Source s = items.get(index);
                IOutItem7z item = factory.createOutItem();
                boolean isDir = s.file == null;
                item.setPropertyPath(isDir ? s.name.substring(0, s.name.length() - 1) : s.name);
                item.setPropertyIsDir(isDir);
                item.setDataSize(isDir ? 0L : s.file.length());
                if (!isDir) item.setPropertyLastModificationTime(new Date(s.file.lastModified()));
                item.setUpdateIsNewData(true);
                item.setUpdateIsNewProperties(true);
                return item;
            }

            @Override
            public ISequentialInStream getStream(int index) throws SevenZipException {
                if (cancelled != null && cancelled.get()) throw new SevenZipException("cancelled");
                Source s = items.get(index);
                if (s.file == null) return null;
                try {
                    current = new RandomAccessFile(s.file, "r");
                } catch (IOException e) {
                    throw new SevenZipException("Cannot read " + s.file, e);
                }
                final RandomAccessFile raf = current;
                return new ISequentialInStream() {
                    @Override
                    public int read(byte[] data) throws SevenZipException {
                        if (cancelled != null && cancelled.get()) throw new SevenZipException("cancelled");
                        try {
                            int n = raf.read(data);
                            return Math.max(n, 0);
                        } catch (IOException e) {
                            throw new SevenZipException("Read failed", e);
                        }
                    }

                    @Override
                    public void close() throws IOException {
                        raf.close();
                    }
                };
            }

            @Override public void setTotal(long t) {}
            @Override public void setCompleted(long c) {}

            @Override
            public String cryptoGetTextPassword() {
                return password;
            }
        }

        RandomAccessFile raf = null;
        IOutCreateArchive7z archive = null;
        try {
            raf = new RandomAccessFile(out, "rw");
            raf.setLength(0);
            archive = SevenZip.openOutArchive7z();
            archive.setLevel(level);
            archive.setSolid(level > 0);
            if (usePassword) archive.setHeaderEncryption(true);
            report.update(0, total, null);
            archive.createArchive(new RandomAccessFileOutStream(raf), total, new Callback());
            return out.getAbsolutePath();
        } catch (Exception e) {
            try { if (raf != null) raf.close(); } catch (IOException ignored) {}
            raf = null;
            out.delete();
            if (cancelled != null && cancelled.get()) {
                throw new BridgeException(BridgeException.CANCELLED, "Cancelled");
            }
            throw new BridgeException(BridgeException.CORRUPT, String.valueOf(e.getMessage()));
        } finally {
            try { if (archive != null) archive.close(); } catch (Exception ignored) {}
            try { if (raf != null) raf.close(); } catch (IOException ignored) {}
        }
    }

    /** Convenience for tests. */
    static List<String> listOf(String... s) { return new ArrayList<>(Arrays.asList(s)); }

    static { Collections.emptyList(); }
}
