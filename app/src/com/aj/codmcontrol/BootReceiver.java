package com.aj.codmcontrol;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (!StatusService.prefsEnabled(context)) {
            return;
        }
        try {
            context.startForegroundService(new Intent(context, StatusService.class));
        } catch (Throwable t) {
            AppLog.add(context, "arranque: notificacion no permitida: " + t.getClass().getSimpleName());
        }
    }
}
