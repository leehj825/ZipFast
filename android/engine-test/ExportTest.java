import com.zipfast.zipfast.engine.BridgeException;
import com.zipfast.zipfast.engine.TreeExporter;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Host tests for TreeExporter using a filesystem-backed Target. */
public class ExportTest {
    static int passed, failed;

    interface Body { void run() throws Exception; }
    static void test(String name, Body b) {
        try { b.run(); passed++; System.out.println("PASS " + name); }
        catch (Throwable t) { failed++; System.out.println("FAIL " + name + ": " + t); t.printStackTrace(System.out); }
    }
    static void check(boolean c, String m) { if (!c) throw new AssertionError(m); }
    static void eq(Object a, Object b, String m) {
        if (!Objects.equals(a, b)) throw new AssertionError(m + ": expected <" + b + "> but was <" + a + ">");
    }

    /** Mimics a SAF provider: creates entries below a directory, records MIME types. */
    static class FsTarget implements TreeExporter.Target {
        final File root;
        final Map<String, String> mimes = new HashMap<>();
        FsTarget(File root) { this.root = root; root.mkdirs(); }
        public Object root() { return root; }
        public Object createFolder(Object parent, String name) throws IOException {
            File d = new File((File) parent, name);
            if (!d.mkdirs() && !d.isDirectory()) throw new IOException("mkdir " + d);
            return d;
        }
        public OutputStream createFile(Object parent, String name, String mime) throws IOException {
            File f = new File((File) parent, name);
            mimes.put(name, mime);
            return new FileOutputStream(f);
        }
    }

    static String read(File f) throws Exception { return new String(Files.readAllBytes(f.toPath())); }
    static void write(File f, String s) throws Exception { f.getParentFile().mkdirs(); Files.write(f.toPath(), s.getBytes()); }

    public static void main(String[] args) throws Exception {
        File tmp = Files.createTempDirectory("export_test").toFile();
        File src = new File(tmp, "src");
        write(new File(src, "docs/a.txt"), "alpha");
        write(new File(src, "docs/deep/b.zip"), "beta");
        new File(src, "empty").mkdirs();
        File single = new File(tmp, "one.7z");
        write(single, "seven");

        test("copies files and folders recursively, keeping the structure", () -> {
            FsTarget t = new FsTarget(new File(tmp, "out1"));
            int n = TreeExporter.copy(Arrays.asList(src.getPath(), single.getPath()), t, null, null);
            eq(n, 3, "files copied");
            eq(read(new File(tmp, "out1/src/docs/a.txt")), "alpha", "a");
            eq(read(new File(tmp, "out1/src/docs/deep/b.zip")), "beta", "b");
            check(new File(tmp, "out1/src/empty").isDirectory(), "empty folder kept");
            eq(read(new File(tmp, "out1/one.7z")), "seven", "single file");
        });

        test("MIME types are guessed from the extension", () -> {
            FsTarget t = new FsTarget(new File(tmp, "out2"));
            TreeExporter.copy(Arrays.asList(src.getPath(), single.getPath()), t, null, null);
            eq(t.mimes.get("b.zip"), "application/zip", "zip");
            eq(t.mimes.get("one.7z"), "application/x-7z-compressed", "7z");
            eq(t.mimes.get("a.txt"), "text/plain", "txt");
        });

        test("progress counts files and ends at total", () -> {
            List<String> seen = new ArrayList<>();
            int[] last = {-1, -1};
            TreeExporter.copy(Arrays.asList(src.getPath()), new FsTarget(new File(tmp, "out3")),
                (d, tot, cur) -> { last[0] = d; last[1] = tot; if (cur != null) seen.add(cur); }, null);
            eq(last[1], 2, "total");
            eq(last[0], 2, "done");
            eq(seen.size(), 2, "named updates");
        });

        test("symbolic links are not followed or copied", () -> {
            File d = new File(tmp, "linky");
            write(new File(d, "real.txt"), "real");
            File secret = new File(tmp, "secret.txt");
            write(secret, "secret");
            Files.createSymbolicLink(new File(d, "link.txt").toPath(), secret.toPath());
            FsTarget t = new FsTarget(new File(tmp, "out4"));
            int n = TreeExporter.copy(Arrays.asList(d.getPath()), t, null, null);
            eq(n, 1, "only the real file");
            check(!new File(tmp, "out4/linky/link.txt").exists(), "link not copied");
        });

        test("hostile names are cleaned", () -> {
            File d = new File(tmp, "weird");
            write(new File(d, "x"), "x");
            // A file whose name contains a backslash (legal on Linux).
            write(new File(d, "a\\b.txt"), "bs");
            FsTarget t = new FsTarget(new File(tmp, "out5"));
            TreeExporter.copy(Arrays.asList(d.getPath()), t, null, null);
            check(new File(tmp, "out5/weird/a_b.txt").exists(), "backslash replaced");
        });

        test("cancel stops the copy", () -> {
            AtomicBoolean cancel = new AtomicBoolean(true);
            try {
                TreeExporter.copy(Arrays.asList(src.getPath()), new FsTarget(new File(tmp, "out6")), null, cancel);
                throw new AssertionError("should have been cancelled");
            } catch (BridgeException e) {
                eq(e.code, BridgeException.CANCELLED, "code");
            }
        });

        test("a missing source is reported", () -> {
            try {
                TreeExporter.copy(Arrays.asList(new File(tmp, "nope").getPath()), new FsTarget(new File(tmp, "out7")), null, null);
                throw new AssertionError("should have failed");
            } catch (BridgeException e) {
                eq(e.code, BridgeException.CORRUPT, "code");
            }
        });

        test("write failures surface as errors", () -> {
            TreeExporter.Target bad = new TreeExporter.Target() {
                public Object root() { return "r"; }
                public Object createFolder(Object p, String n) { return p; }
                public OutputStream createFile(Object p, String n, String m) throws IOException {
                    throw new IOException("disk full");
                }
            };
            try {
                TreeExporter.copy(Arrays.asList(single.getPath()), bad, null, null);
                throw new AssertionError("should have failed");
            } catch (BridgeException e) {
                eq(e.code, BridgeException.CORRUPT, "code");
                check(e.getMessage().contains("disk full"), "message");
            }
        });

        System.out.println("\n" + passed + " passed, " + failed + " failed");
        System.exit(failed == 0 ? 0 : 1);
    }
}
