import com.zipfast.zipfast.engine.ArchiveBridge;
import com.zipfast.zipfast.engine.BridgeException;

import java.io.File;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Host-JVM tests for ArchiveBridge. Run with run_tests.sh. */
public class BridgeTest {
    static int passed, failed;
    static File fx;
    static File tmp;

    interface Body { void run() throws Exception; }

    static void test(String name, Body b) {
        try {
            b.run();
            passed++;
            System.out.println("PASS " + name);
        } catch (Throwable t) {
            failed++;
            System.out.println("FAIL " + name + ": " + t);
            t.printStackTrace(System.out);
        }
    }

    static void check(boolean c, String msg) { if (!c) throw new AssertionError(msg); }
    static void eq(Object a, Object b, String msg) {
        if (!Objects.equals(a, b)) throw new AssertionError(msg + ": expected <" + b + "> but was <" + a + ">");
    }
    static String code(Body b) {
        try { b.run(); return "none"; }
        catch (BridgeException e) { return e.code; }
        catch (Exception e) { return "other:" + e; }
    }
    static String fx(String n) { return new File(fx, n).getPath(); }
    static File dest(String n) { return new File(tmp, n); }
    static String read(File f) throws Exception { return new String(Files.readAllBytes(f.toPath())); }

    @SuppressWarnings("unchecked")
    static Set<String> files(Map<String, Object> listing) {
        Set<String> s = new TreeSet<>();
        for (Object o : (List<Object>) listing.get("entries")) {
            Map<String, Object> e = (Map<String, Object>) o;
            if (!(Boolean) e.get("isDir")) s.add((String) e.get("path"));
        }
        return s;
    }

    public static void main(String[] args) throws Exception {
        fx = new File(args[0]);
        tmp = Files.createTempDirectory("bridge_test").toFile();
        final String HELLO = "hello from ZipFast\n";

        for (String f : new String[]{"plain.7z", "test4.rar", "test5.rar", "test.iso", "test.cab", "split.7z.001"}) {
            test("list " + f, () -> {
                Map<String, Object> l = ArchiveBridge.list(fx(f), null);
                Set<String> got = files(l);
                System.out.println("   " + l.get("format") + " " + got);
                check(!got.isEmpty(), "no entries");
                check(got.stream().anyMatch(p -> p.toLowerCase().endsWith("hello.txt") || p.endsWith("b.txt")), "known file missing");
            });
        }

        test("split 7z lists all three volumes' content", () -> {
            eq(files(ArchiveBridge.list(fx("split.7z.001"), null)),
               new TreeSet<>(Arrays.asList("a.txt", "data/big.bin", "docs/hello.txt")), "entries");
        });

        test("extract split 7z across volumes", () -> {
            File d = dest("split");
            Map<String, Object> r = ArchiveBridge.extract(fx("split.7z.001"), null, d.getPath(), null, "rename", null, null);
            eq(r.get("extracted"), 3, "count");
            eq(read(new File(d, "docs/hello.txt")), HELLO, "hello");
            eq(new File(d, "data/big.bin").length(), 30000L, "big size");
        });

        for (String f : new String[]{"test4.rar", "test5.rar"}) {
            test("extract " + f, () -> {
                File d = dest(f);
                Map<String, Object> r = ArchiveBridge.extract(fx(f), null, d.getPath(), null, "rename", null, null);
                eq(r.get("extracted"), 2, "count");
                eq(read(new File(d, "docs/hello.txt")), HELLO, "hello");
                eq(read(new File(d, "a.txt")), "x", "a");
            });
        }

        test("extract iso", () -> {
            File d = dest("iso");
            ArchiveBridge.extract(fx("test.iso"), null, d.getPath(), null, "rename", null, null);
            File found = null;
            for (File f : new File(d, "docs").listFiles()) found = f;
            eq(read(found), HELLO, "iso content");
        });

        test("extract cab", () -> {
            File d = dest("cab");
            ArchiveBridge.extract(fx("test.cab"), null, d.getPath(), null, "rename", null, null);
            eq(read(new File(d, "hello.txt")), HELLO, "cab hello");
            eq(read(new File(d, "b.txt")), "second file", "cab b");
        });

        test("Zip Slip blocked in RAR", () -> {
            File d = new File(dest("slip"), "out");
            Map<String, Object> r = ArchiveBridge.extract(fx("slip.rar"), null, d.getPath(), null, "rename", null, null);
            System.out.println("   " + r);
            check(!new File(d.getParentFile(), "evil.txt").exists(), "evil.txt escaped!");
            check((Integer) r.get("blocked") >= 1, "blocked count");
            eq(read(new File(d, "ok/fine.txt")), "fine", "good entry still extracted");
        });

        test("selective extraction", () -> {
            File d = dest("sel");
            Map<String, Object> r = ArchiveBridge.extract(fx("plain.7z"), null, d.getPath(), Arrays.asList("docs"), "rename", null, null);
            eq(r.get("extracted"), 1, "count");
            check(new File(d, "docs/hello.txt").exists(), "docs file");
            check(!new File(d, "a.txt").exists(), "a.txt must not be extracted");
        });

        test("conflict policies", () -> {
            File d = dest("conf");
            ArchiveBridge.extract(fx("test4.rar"), null, d.getPath(), Arrays.asList("a.txt"), "rename", null, null);
            ArchiveBridge.extract(fx("test4.rar"), null, d.getPath(), Arrays.asList("a.txt"), "rename", null, null);
            check(new File(d, "a (1).txt").exists(), "renamed copy");
            Map<String, Object> s = ArchiveBridge.extract(fx("test4.rar"), null, d.getPath(), Arrays.asList("a.txt"), "skip", null, null);
            eq(s.get("skipped"), 1, "skipped");
            Map<String, Object> o = ArchiveBridge.extract(fx("test4.rar"), null, d.getPath(), Arrays.asList("a.txt"), "overwrite", null, null);
            eq(o.get("extracted"), 1, "overwritten");
        });

        test("progress is reported", () -> {
            final int[] last = {-1, -1};
            ArchiveBridge.extract(fx("plain.7z"), null, dest("prog").getPath(), null, "rename",
                (done, total, cur) -> { last[0] = done; last[1] = total; }, null);
            check(last[1] > 0 && last[0] == last[1], "progress ended at " + last[0] + "/" + last[1]);
        });

        test("encrypted 7z: password flow", () -> {
            eq(code(() -> ArchiveBridge.list(fx("secret.7z"), null)), BridgeException.PASSWORD_REQUIRED, "no password");
            eq(code(() -> ArchiveBridge.list(fx("secret.7z"), "nope")), BridgeException.WRONG_PASSWORD, "wrong password");
            Map<String, Object> l = ArchiveBridge.list(fx("secret.7z"), "pw123");
            eq(files(l), new TreeSet<>(Arrays.asList("a.txt", "data/big.bin", "docs/hello.txt")), "entries");
            File d = dest("secret");
            ArchiveBridge.extract(fx("secret.7z"), "pw123", d.getPath(), null, "rename", null, null);
            eq(read(new File(d, "docs/hello.txt")), HELLO, "decrypted");
        });

        test("readEntry preview", () -> {
            byte[] b = ArchiveBridge.readEntry(fx("plain.7z"), "docs/hello.txt", null, 1 << 20);
            eq(new String(b), HELLO, "preview");
            eq(code(() -> ArchiveBridge.readEntry(fx("plain.7z"), "data/big.bin", null, 100)), BridgeException.CORRUPT, "too large");
        });

        test("create 7z round trip (levels, empty dir)", () -> {
            File src = dest("src");
            new File(src, "sub").mkdirs();
            new File(src, "empty").mkdirs();
            Files.write(new File(src, "a.txt").toPath(), "alpha".getBytes());
            Files.write(new File(src, "sub/b.txt").toPath(), "beta".repeat(500).getBytes());
            for (int level : new int[]{0, 1, 5, 9}) {
                File out = dest("out" + level + ".7z");
                ArchiveBridge.create7z(Arrays.asList(src.getPath()), out.getPath(), level, null, null, null);
                Map<String, Object> l = ArchiveBridge.list(out.getPath(), null);
                eq(files(l), new TreeSet<>(Arrays.asList("src/a.txt", "src/sub/b.txt")), "entries level " + level);
                File d = dest("outd" + level);
                ArchiveBridge.extract(out.getPath(), null, d.getPath(), null, "rename", null, null);
                eq(read(new File(d, "src/sub/b.txt")), "beta".repeat(500), "content level " + level);
                check(new File(d, "src/empty").isDirectory(), "empty dir kept");
            }
        });

        test("create encrypted 7z (AES-256, names hidden)", () -> {
            File src = dest("src");
            File out = dest("enc.7z");
            ArchiveBridge.create7z(Arrays.asList(new File(src, "a.txt").getPath()), out.getPath(), 5, "s3cret", null, null);
            eq(code(() -> ArchiveBridge.list(out.getPath(), null)), BridgeException.PASSWORD_REQUIRED, "needs password to even list");
            eq(code(() -> ArchiveBridge.list(out.getPath(), "bad")), BridgeException.WRONG_PASSWORD, "bad password");
            File d = dest("encd");
            ArchiveBridge.extract(out.getPath(), "s3cret", d.getPath(), null, "rename", null, null);
            eq(read(new File(d, "a.txt")), "alpha", "decrypted");
        });

        test("cancel stops create", () -> {
            File big = dest("bigfile.bin");
            byte[] chunk = new byte[1 << 20];
            new Random(1).nextBytes(chunk);
            try (java.io.OutputStream o = new java.io.FileOutputStream(big)) {
                for (int i = 0; i < 60; i++) o.write(chunk);
            }
            AtomicBoolean cancel = new AtomicBoolean(true);
            File out = dest("cancelled.7z");
            eq(code(() -> ArchiveBridge.create7z(Arrays.asList(big.getPath()), out.getPath(), 9, null, null, cancel)),
               BridgeException.CANCELLED, "cancel code");
            check(!out.exists(), "partial output removed");
        });

        test("cancel stops extract", () -> {
            AtomicBoolean cancel = new AtomicBoolean(true);
            eq(code(() -> ArchiveBridge.extract(fx("plain.7z"), null, dest("cx").getPath(), null, "rename", null, cancel)),
               BridgeException.CANCELLED, "cancel code");
        });

        test("garbage file is reported as corrupt", () -> {
            File junk = dest("junk.7z");
            Files.write(junk.toPath(), new byte[]{1, 2, 3, 4, 5, 6, 7, 8, 9, 10});
            eq(code(() -> ArchiveBridge.list(junk.getPath(), null)), BridgeException.CORRUPT, "junk");
        });

        System.out.println("\n" + passed + " passed, " + failed + " failed");
        System.exit(failed == 0 ? 0 : 1);
    }
}
