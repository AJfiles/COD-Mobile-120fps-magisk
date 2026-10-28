package com.aj.codmcontrol;

import android.content.Context;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

final class AppLog {
    private static final long MAX_BYTES = 300_000;
    private static final int KEEP_BYTES = 100_000;

    private AppLog() {
    }

    static synchronized void add(Context context, String message) {
        File f = new File(context.getFilesDir(), "app.log");
        try {
            if (f.length() > MAX_BYTES) {
                byte[] all = readAll(f);
                int keep = Math.min(all.length, KEEP_BYTES);
                FileOutputStream out = new FileOutputStream(f, false);
                out.write(all, all.length - keep, keep);
                out.close();
            }
            FileWriter w = new FileWriter(f, true);
            String ts = new SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(new Date());
            w.write(ts + " " + message + "\n");
            w.close();
        } catch (Exception ignored) {
        }
    }

    static String tail(Context context, int lines) {
        try {
            String all = new String(readAll(new File(context.getFilesDir(), "app.log")),
                    StandardCharsets.UTF_8);
            String[] ls = all.split("\n");
            int from = Math.max(0, ls.length - lines);
            StringBuilder sb = new StringBuilder();
            for (int i = from; i < ls.length; i++) {
                sb.append(ls[i]).append('\n');
            }
            return sb.toString().trim();
        } catch (Exception e) {
            return "(sin log de la app)";
        }
    }

    private static byte[] readAll(File f) throws Exception {
        FileInputStream in = new FileInputStream(f);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] b = new byte[8192];
        int n;
        while ((n = in.read(b)) > 0) {
            out.write(b, 0, n);
        }
        in.close();
        return out.toByteArray();
    }
}
