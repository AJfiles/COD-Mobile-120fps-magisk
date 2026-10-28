package com.aj.codmcontrol;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

import java.util.Collections;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class StatusService extends Service {
    static final String CHANNEL = "estado_modulo";
    static final int NOTIF_ID = 120;
    static final String ACTION_REFRESH = "com.aj.codmcontrol.REFRESH";
    static final String PREFS = "codmctl";
    static final String PREF_NOTIF = "notif";

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private volatile boolean busy;
    private boolean diagLogged;

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            refresh();
            handler.postDelayed(this, 30000);
        }
    };

    static boolean prefsEnabled(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(PREF_NOTIF, true);
    }

    static void setEnabled(Context c, boolean on) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(PREF_NOTIF, on).apply();
        if (on) {
            c.startForegroundService(new Intent(c, StatusService.class));
        } else {
            c.stopService(new Intent(c, StatusService.class));
        }
    }

    static void ensureChannel(Context c) {
        NotificationManager nm = c.getSystemService(NotificationManager.class);
        if (nm == null) {
            return;
        }
        NotificationChannel ch = new NotificationChannel(CHANNEL, "Estado del modulo",
                NotificationManager.IMPORTANCE_LOW);
        ch.setDescription("Perfil, cuenta y estado de CODM 120");
        ch.setShowBadge(false);
        nm.createNotificationChannel(ch);
    }

    static void refreshNow(Context c) {
        if (!prefsEnabled(c)) {
            return;
        }
        ensureChannel(c);
        final Context app = c.getApplicationContext();
        new Thread(new Runnable() {
            @Override
            public void run() {
                Map<String, String> st = Root.status();
                post(app, st);
            }
        }).start();
    }

    private static void post(Context c, Map<String, String> st) {
        try {
            NotificationManager nm = c.getSystemService(NotificationManager.class);
            if (nm != null) {
                nm.notify(NOTIF_ID, build(c, st, false));
            }
        } catch (Exception ignored) {
        }
    }

    private void refresh() {
        if (busy) {
            return;
        }
        busy = true;
        io.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    Map<String, String> st = Root.status();
                    if (!diagLogged && (st.get("prefs.framerate") == null
                            || st.get("prefs.framerate").isEmpty())) {
                        diagLogged = true;
                        String last = "";
                        for (String k : st.keySet()) {
                            last = k;
                        }
                        AppLog.add(StatusService.this, "estado parcial: claves=" + st.size()
                                + " prefs=" + st.get("prefs.readable")
                                + " uid=" + st.get("prefs.uid")
                                + " error=" + st.get("ERROR")
                                + " ultima=" + last);
                    }
                    NotificationManager nm = getSystemService(NotificationManager.class);
                    if (nm != null) {
                        nm.notify(NOTIF_ID, build(StatusService.this, st, false));
                    }
                } catch (Exception ignored) {
                } finally {
                    busy = false;
                }
            }
        });
    }

    private static String shortUid(String uid) {
        if (uid == null || uid.isEmpty()) {
            return "sin confirmar";
        }
        return uid.length() > 8 ? "..." + uid.substring(uid.length() - 8) : uid;
    }

    static Notification build(Context c, Map<String, String> st, boolean loading) {
        String active = st.get("module.active");
        String error = st.get("ERROR");
        boolean isActive = "1".equals(active);
        boolean rootBad = error != null || (st.isEmpty() && !loading);

        String title;
        String text;
        StringBuilder big = new StringBuilder();
        if (loading) {
            title = "CODM Control";
            text = "Consultando estado del modulo...";
        } else if (rootBad) {
            title = "CODM Control - sin root";
            text = "Concede root a CODM Control para leer el modulo";
            big.append("Abre Magisk, KernelSU o APatch y autoriza la app. Luego pulsa Actualizar.");
        } else if (!isActive) {
            title = "CODM 120 - modulo inactivo";
            text = "El modulo esta desactivado en el gestor root";
            big.append("Activa codm_s23_120 y reinicia para recuperar el perfil 120.");
        } else {
            String profile = "on".equals(st.get("perf.profile")) ? "ON" : "OFF";
            String fps = st.get("prefs.framerate");
            String uid = shortUid(st.get("account.confirmed"));
            boolean game = "1".equals(st.get("game.running"));
            title = "CODM 120 - activo";
            text = "Perfil " + profile + " - " + (fps == null || fps.isEmpty() ? "fps n/d" : fps + " fps")
                    + " - cuenta " + uid + (game ? " - CODM abierto" : "");
            big.append("Perfil de fluidez: ").append(profile)
                    .append("\nFramerate: ").append(fps == null || fps.isEmpty() ? "n/d" : fps)
                    .append("\nCuenta: ").append(uid)
                    .append("\nGestor: ").append(st.get("module.manager"))
                    .append(" ").append(st.get("module.managerVersion"))
                    .append("\nGFX 3D: ").append(st.get("gfx.width")).append("x").append(st.get("gfx.height"))
                    .append(" - Unity ").append(st.get("gfx.quality"))
                    .append("\nAudio: ").append(st.get("audio.mode"))
                    .append("\nCODM: ").append(game ? "abierto" : "cerrado");
        }

        Intent open = new Intent(c, MainActivity.class);
        open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        PendingIntent content = PendingIntent.getActivity(c, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification.Builder b = new Notification.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.ic_notif)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(new Notification.BigTextStyle().bigText(big.length() == 0 ? text : big.toString()))
                .setContentIntent(content)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setCategory(Notification.CATEGORY_SERVICE)
                .setColor(0xFFFF7A18);

        if (isActive && !rootBad) {
            boolean on = "on".equals(st.get("perf.profile"));
            Intent toggle = new Intent(c, ActionReceiver.class).setAction(ActionReceiver.ACTION_TOGGLE);
            PendingIntent pi = PendingIntent.getBroadcast(c, 1, toggle,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            b.addAction(R.drawable.ic_tile, on ? "Apagar perfil" : "Encender perfil", pi);
        }
        return b.build();
    }

    @Override
    public void onCreate() {
        super.onCreate();
        ensureChannel(this);
        startForeground(NOTIF_ID, build(this, Collections.emptyMap(), true));
        handler.post(tick);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_REFRESH.equals(intent.getAction())) {
            refresh();
        }
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        io.shutdownNow();
        super.onDestroy();
    }

    @SuppressWarnings("unused")
    private static boolean isAtLeast(int sdk) {
        return Build.VERSION.SDK_INT >= sdk;
    }
}
