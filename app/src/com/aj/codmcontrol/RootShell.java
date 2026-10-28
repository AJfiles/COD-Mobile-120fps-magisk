package com.aj.codmcontrol;

import android.util.Log;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.ReentrantLock;

// Un unico `su` por proceso de la app: Magisk avisa en pantalla de cada
// peticion nueva y el servicio de estado consulta cada 30 s.
final class RootShell {
    private static final String TAG = "CODMCTL";
    private static final int MAX_CHARS = 2 * 1024 * 1024;
    private static final int HANDSHAKE_SEC = 15;

    private static RootShell instance;

    static synchronized RootShell get() {
        if (instance == null) {
            instance = new RootShell();
        }
        return instance;
    }

    private final ReentrantLock lock = new ReentrantLock(true);
    private final Object sync = new Object();
    private final StringBuilder buf = new StringBuilder();
    private final String nonce;

    private Process proc;
    private OutputStream stdin;
    private boolean dead;
    private boolean handshaking;
    private int seq;
    private int state; // 0 libre, 1 esperando fin, 2 fin recibido
    private int exit = -1;
    private int readyUid = -1;
    private int gen;

    private RootShell() {
        byte[] b = new byte[4];
        new SecureRandom().nextBytes(b);
        StringBuilder n = new StringBuilder("AJ");
        for (int i = 0; i < b.length; i++) {
            n.append(Integer.toHexString((b[i] & 0xff) | 0x100).substring(1));
        }
        nonce = n.toString();
    }

    Root.Result execute(String command, int timeoutSec) {
        if (timeoutSec < 1) {
            timeoutSec = 1;
        }
        boolean locked;
        try {
            locked = lock.tryLock(timeoutSec + 10L, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return new Root.Result(-1, "(interrumpido)");
        }
        if (!locked) {
            return new Root.Result(-1, "(shell ocupado)");
        }
        try {
            for (int intento = 0; intento < 2; intento++) {
                if (!ensure()) {
                    return new Root.Result(-1, "Sin root");
                }
                int id;
                synchronized (sync) {
                    if (dead) {
                        return new Root.Result(-1, "Sin root (sesion terminada)");
                    }
                    id = ++seq;
                    buf.setLength(0);
                    state = 1;
                    exit = -1;
                }
                String script = "printf '\n" + nonce + "_B" + id + "\n'\n"
                        + "(" + command + ") </dev/null\n"
                        + "printf '\n" + nonce + "_E" + id + " %s\n' \"$?\"\n";
                try {
                    stdin.write(script.getBytes(StandardCharsets.UTF_8));
                    stdin.flush();
                } catch (IOException e) {
                    // La escritura del pipe es atomica (< 4 KB): si falla, el
                    // comando no se ejecuto y reintentar con otra sesion es seguro.
                    Log.w(TAG, "escritura fallida: " + e.getMessage() + " intento=" + intento);
                    kill();
                    if (intento == 0) {
                        continue;
                    }
                    return new Root.Result(-1, "Sin root: " + e.getMessage());
                }
                long deadline = System.currentTimeMillis() + timeoutSec * 1000L;
                boolean timedOut = false;
                synchronized (sync) {
                    while (state == 1 && !dead) {
                        long rem = deadline - System.currentTimeMillis();
                        if (rem <= 0) {
                            timedOut = true;
                            break;
                        }
                        try {
                            sync.wait(Math.min(rem, 500));
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                            break;
                        }
                    }
                }
                String all;
                synchronized (sync) {
                    all = buf.toString();
                }
                String beginMarker = nonce + "_B" + id + "\n";
                String endMarker = nonce + "_E" + id + " ";
                int bi = all.indexOf(beginMarker);
                int ei = all.indexOf(endMarker);
                String out;
                if (bi >= 0) {
                    int from = bi + beginMarker.length();
                    int to = ei >= from ? ei : all.length();
                    if (to > from && all.charAt(to - 1) == '\n') {
                        to--;
                    }
                    out = all.substring(from, to);
                } else {
                    out = all;
                }
                int code = exit;
                if (ei >= 0) {
                    int j = ei + endMarker.length();
                    int k = j;
                    while (k < all.length() && all.charAt(k) >= '0' && all.charAt(k) <= '9') {
                        k++;
                    }
                    if (k > j) {
                        try {
                            code = Integer.parseInt(all.substring(j, k));
                        } catch (NumberFormatException ignored) {
                        }
                    }
                }
                if (timedOut) {
                    Log.w(TAG, "sin respuesta en " + timeoutSec + "s; se reinicia la sesion");
                    kill();
                    return new Root.Result(-1, out + "\n(tiempo agotado)");
                }
                if (dead && ei < 0) {
                    return new Root.Result(-1, out + "\n(sesion root terminada)");
                }
                return new Root.Result(code, out);
            }
            return new Root.Result(-1, "Sin root");
        } finally {
            lock.unlock();
        }
    }

    private boolean ensure() {
        synchronized (sync) {
            if (proc != null && !dead && proc.isAlive()) {
                return true;
            }
        }
        kill();
        // Rutas absolutas antes que PATH: en Samsung `su` de PATH es el stub OEM
        // y responde uid 2000; Magisk vive en /debug_ramdisk, KSU/APatch en /data/adb.
        String[][] variants = {
                {"/debug_ramdisk/su", "-M"},
                {"/debug_ramdisk/su"},
                {"/data/adb/ksu/bin/su"},
                {"/data/adb/ap/bin/su"},
                {"/data/adb/magisk/magisk", "su"},
                {"/system/bin/su", "-M"},
                {"/system/bin/su"},
                {"/system/xbin/su"},
                {"/sbin/su"},
                {"su", "-M"},
                {"su"}
        };
        for (int i = 0; i < variants.length; i++) {
            if (start(variants[i])) {
                return true;
            }
        }
        return false;
    }

    private boolean start(String[] argv) {
        Process p = null;
        try {
            if (argv[0].startsWith("/") && !new java.io.File(argv[0]).canExecute()) {
                return false;
            }
            p = new ProcessBuilder(argv).redirectErrorStream(true).start();
            final InputStream in = p.getInputStream();
            final OutputStream os = p.getOutputStream();
            final int myGen;
            synchronized (sync) {
                proc = p;
                stdin = os;
                dead = false;
                handshaking = true;
                readyUid = -1;
                seq = 0;
                state = 0;
                exit = -1;
                buf.setLength(0);
                myGen = ++gen;
            }
            final Reader r = new InputStreamReader(in, StandardCharsets.UTF_8);
            Thread t = new Thread(new Runnable() {
                @Override
                public void run() {
                    readLoop(r, myGen);
                }
            }, "root-reader");
            t.setDaemon(true);
            t.start();
            os.write(("printf '\n" + nonce + "_R0 %s\n' \"$(id -u)\"\n")
                    .getBytes(StandardCharsets.UTF_8));
            os.flush();
            long deadline = System.currentTimeMillis() + HANDSHAKE_SEC * 1000L;
            synchronized (sync) {
                while (handshaking && !dead && System.currentTimeMillis() < deadline) {
                    try {
                        sync.wait(200);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        break;
                    }
                }
            }
            boolean ok;
            synchronized (sync) {
                ok = gen == myGen && !handshaking && !dead && readyUid == 0;
                Log.i(TAG, "sesion " + (ok ? "lista" : "fallida")
                        + " variante=" + argv.length + " uid=" + readyUid);
            }
            if (ok) {
                return true;
            }
        } catch (Exception ignored) {
        }
        kill();
        if (p != null) {
            try {
                p.destroyForcibly();
            } catch (Exception ignored) {
            }
        }
        return false;
    }

    private void readLoop(Reader r, int myGen) {
        char[] c = new char[4096];
        try {
            int n;
            while ((n = r.read(c)) > 0) {
                synchronized (sync) {
                    if (gen != myGen) {
                        return;
                    }
                    if (buf.length() < MAX_CHARS) {
                        buf.append(c, 0, n);
                    }
                    scanLocked();
                    sync.notifyAll();
                }
            }
        } catch (IOException ignored) {
        } catch (RuntimeException ignored) {
        }
        synchronized (sync) {
            if (gen != myGen) {
                return;
            }
            dead = true;
            handshaking = false;
            Log.w(TAG, "sesion root terminada");
            if (state == 1) {
                state = 2;
            }
            scanLocked();
            sync.notifyAll();
        }
    }

    private void scanLocked() {
        String s = buf.toString();
        if (handshaking) {
            String m = nonce + "_R0 ";
            int i = s.indexOf(m);
            if (i >= 0) {
                int j = i + m.length();
                int k = j;
                while (k < s.length() && Character.isDigit(s.charAt(k))) {
                    k++;
                }
                if (k > j) {
                    try {
                        readyUid = Integer.parseInt(s.substring(j, k));
                    } catch (NumberFormatException ignored) {
                        readyUid = -1;
                    }
                    handshaking = false;
                    buf.setLength(0);
                }
            }
            return;
        }
        if (state == 1) {
            String em = nonce + "_E" + seq + " ";
            int i = s.indexOf(em);
            if (i >= 0) {
                int j = i + em.length();
                int k = j;
                while (k < s.length() && Character.isDigit(s.charAt(k))) {
                    k++;
                }
                if (k > j) {
                    try {
                        exit = Integer.parseInt(s.substring(j, k));
                    } catch (NumberFormatException ignored) {
                        exit = -1;
                    }
                    state = 2;
                }
            }
        }
    }

    private void kill() {
        Process p;
        OutputStream os;
        synchronized (sync) {
            gen++;
            dead = true;
            handshaking = false;
            if (state == 1) {
                state = 2;
            }
            p = proc;
            os = stdin;
            proc = null;
            stdin = null;
        }
        if (os != null) {
            try {
                os.close();
            } catch (Exception ignored) {
            }
        }
        if (p != null) {
            try {
                p.destroyForcibly();
            } catch (Exception ignored) {
            }
            try {
                p.waitFor(2, TimeUnit.SECONDS);
            } catch (Exception ignored) {
            }
        }
    }
}
