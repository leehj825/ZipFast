package com.zipfast.zipfast.engine;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Copies files and folders into a destination tree through a small
 * {@link Target} interface.
 *
 * <p>On Android the target is a Storage Access Framework folder (a
 * {@code content://} tree the user picked: no storage permission needed). The
 * traversal, progress, cancel and name handling live here, in plain Java, so
 * they are unit-tested on the host with a filesystem-backed target.
 */
public final class TreeExporter {
    private TreeExporter() {}

    /** A place that can receive folders and files. Handles are opaque to this class. */
    public interface Target {
        /** The folder everything is copied into. */
        Object root();

        /** Creates a sub-folder and returns its handle. */
        Object createFolder(Object parent, String name) throws IOException;

        /** Creates a file and returns a stream to write its content. */
        OutputStream createFile(Object parent, String name, String mimeType) throws IOException;
    }

    /** Progress: files copied, files total, current name. */
    public interface Progress {
        void update(int done, int total, String current);
    }

    /** Characters that are not allowed in a document name. */
    static String cleanName(String name) {
        String n = name.replace('/', '_').replace('\\', '_').replace("\0", "").trim();
        return n.isEmpty() || n.equals(".") || n.equals("..") ? "file" : n;
    }

    static String mimeFor(String name) {
        int dot = name.lastIndexOf('.');
        String ext = dot < 0 ? "" : name.substring(dot + 1).toLowerCase(Locale.ROOT);
        switch (ext) {
            case "zip": return "application/zip";
            case "7z": return "application/x-7z-compressed";
            case "rar": return "application/vnd.rar";
            case "gz": case "tgz": return "application/gzip";
            case "tar": return "application/x-tar";
            case "txt": case "log": case "md": return "text/plain";
            case "json": return "application/json";
            case "xml": return "text/xml";
            case "html": return "text/html";
            case "csv": return "text/csv";
            case "pdf": return "application/pdf";
            case "png": return "image/png";
            case "jpg": case "jpeg": return "image/jpeg";
            case "gif": return "image/gif";
            case "webp": return "image/webp";
            case "mp3": return "audio/mpeg";
            case "mp4": return "video/mp4";
            default: return "application/octet-stream";
        }
    }

    private static boolean isLink(File f) {
        return java.nio.file.Files.isSymbolicLink(f.toPath());
    }

    private static int countFiles(File f) {
        if (isLink(f)) return 0;
        if (f.isFile()) return 1;
        File[] kids = f.listFiles();
        if (kids == null) return 0;
        int n = 0;
        for (File k : kids) n += countFiles(k);
        return n;
    }

    /**
     * Copies each of {@code paths} (files or folders, recursively) into the
     * target's root. Symbolic links are skipped. Returns the number of files
     * copied.
     */
    public static int copy(List<String> paths, Target target, Progress progress, AtomicBoolean cancelled)
            throws BridgeException {
        final Progress report = progress == null ? (d, t, c) -> {} : progress;
        int total = 0;
        for (String p : paths) total += countFiles(new File(p));
        final int[] done = {0};
        report.update(0, total, null);
        try {
            for (String p : paths) {
                File f = new File(p);
                if (!f.exists()) throw new BridgeException(BridgeException.CORRUPT, "Missing: " + p);
                copyInto(f, target.root(), target, total, done, report, cancelled);
            }
        } catch (IOException e) {
            if (cancelled != null && cancelled.get()) {
                throw new BridgeException(BridgeException.CANCELLED, "Cancelled");
            }
            throw new BridgeException(BridgeException.CORRUPT, String.valueOf(e.getMessage()));
        }
        return done[0];
    }

    private static void copyInto(File src, Object parent, Target target, int total, int[] done,
                                 Progress report, AtomicBoolean cancelled)
            throws IOException, BridgeException {
        if (cancelled != null && cancelled.get()) {
            throw new BridgeException(BridgeException.CANCELLED, "Cancelled");
        }
        if (isLink(src)) return;
        String name = cleanName(src.getName());
        if (src.isDirectory()) {
            Object folder = target.createFolder(parent, name);
            File[] kids = src.listFiles();
            if (kids == null) return;
            Arrays.sort(kids);
            for (File k : kids) copyInto(k, folder, target, total, done, report, cancelled);
            return;
        }
        try (InputStream in = new FileInputStream(src);
             OutputStream out = target.createFile(parent, name, mimeFor(name))) {
            byte[] buf = new byte[256 * 1024];
            int n;
            while ((n = in.read(buf)) > 0) {
                if (cancelled != null && cancelled.get()) {
                    throw new BridgeException(BridgeException.CANCELLED, "Cancelled");
                }
                out.write(buf, 0, n);
            }
        }
        done[0]++;
        report.update(done[0], total, name);
    }

    /** For tests. */
    static List<String> names(String... n) { return new ArrayList<>(Arrays.asList(n)); }
}
