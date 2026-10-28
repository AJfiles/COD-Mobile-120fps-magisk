package com.aj.codmcontrol;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import java.util.Map;

public class ActionReceiver extends BroadcastReceiver {
    static final String ACTION_TOGGLE = "com.aj.codmcontrol.TOGGLE_PROFILE";

    @Override
    public void onReceive(final Context context, Intent intent) {
        if (intent == null || !ACTION_TOGGLE.equals(intent.getAction())) {
            return;
        }
        final Context app = context.getApplicationContext();
        final BroadcastReceiver.PendingResult pending = goAsync();
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Map<String, String> st = Root.status();
                    if ("1".equals(st.get("module.active"))) {
                        String on = st.get("perf.profile");
                        String target = "on".equals(on) ? "off" : "on";
                        Root.Result r = Root.ctl("toggle " + target);
                        AppLog.add(app, "notificacion: perfil " + target + " rc=" + r.code
                                + (r.summary().isEmpty() ? "" : " " + r.summary()));
                    }
                    StatusService.refreshNow(app);
                } finally {
                    try {
                        pending.finish();
                    } catch (Exception ignored) {
                    }
                }
            }
        }).start();
    }
}
