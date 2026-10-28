package com.aj.codmcontrol;

import android.app.PendingIntent;
import android.content.Intent;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class CodmTileService extends TileService {
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private volatile boolean busy;

    @Override
    public void onStartListening() {
        super.onStartListening();
        refreshTile();
    }

    @Override
    public void onClick() {
        super.onClick();
        io.execute(new Runnable() {
            @Override
            public void run() {
                Map<String, String> st = Root.status();
                if (!"1".equals(st.get("module.active"))) {
                    openApp();
                    return;
                }
                String target = "on".equals(st.get("perf.profile")) ? "off" : "on";
                Root.Result r = Root.ctl("toggle " + target);
                AppLog.add(CodmTileService.this, "baldosa: perfil " + target + " rc=" + r.code);
                StatusService.refreshNow(CodmTileService.this);
                refreshTile();
            }
        });
    }

    private void refreshTile() {
        if (busy) {
            return;
        }
        busy = true;
        io.execute(new Runnable() {
            @Override
            public void run() {
                final Map<String, String> st = Root.status();
                ui.post(new Runnable() {
                    @Override
                    public void run() {
                        busy = false;
                        Tile t = getQsTile();
                        if (t == null) {
                            return;
                        }
                        boolean active = "1".equals(st.get("module.active"));
                        boolean on = "on".equals(st.get("perf.profile"));
                        t.setLabel("CODM 120");
                        if (!active) {
                            t.setState(Tile.STATE_UNAVAILABLE);
                        } else if (st.containsKey("ERROR")) {
                            t.setState(Tile.STATE_UNAVAILABLE);
                        } else {
                            t.setState(on ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
                        }
                        if (Build.VERSION.SDK_INT >= 29) {
                            String sub;
                            if (st.containsKey("ERROR")) {
                                sub = "Sin root";
                            } else if (!active) {
                                sub = "Modulo inactivo";
                            } else {
                                sub = on ? "Perfil ON" : "Perfil OFF";
                            }
                            t.setSubtitle(sub);
                        }
                        t.updateTile();
                    }
                });
            }
        });
    }

    private void openApp() {
        ui.post(new Runnable() {
            @Override
            public void run() {
                Intent i = new Intent(CodmTileService.this, MainActivity.class);
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                if (Build.VERSION.SDK_INT >= 34) {
                    PendingIntent pi = PendingIntent.getActivity(CodmTileService.this, 0, i,
                            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                    startActivityAndCollapse(pi);
                } else {
                    startActivityAndCollapse(i);
                }
            }
        });
    }

    @Override
    public void onDestroy() {
        io.shutdownNow();
        super.onDestroy();
    }
}
