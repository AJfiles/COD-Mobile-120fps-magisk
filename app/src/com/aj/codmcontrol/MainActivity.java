package com.aj.codmcontrol;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private static final int BG = 0xFF0A0E14;
    private static final int CARD = 0xFF141A22;
    private static final int CARD_DEEP = 0xFF0D131B;
    private static final int STROKE = 0xFF202C3A;
    private static final int ACCENT = 0xFFFF7A18;
    private static final int TEXT = 0xFFE9EEF5;
    private static final int MUTED = 0xFF93A1B0;
    private static final int RED = 0xFFFF5C5C;
    private static final int YELLOW = 0xFFFFC857;

    private static final String[] LOG_LABELS = {
            "Actividad", "App (acciones)", "watch", "prefs", "audio_fix", "service",
            "perfz", "gfx", "account", "perf_mode", "toggle", "restore", "post-fs-data", "root"
    };
    private static final String[] LOG_KEYS = {
            "all", null, "watch", "prefs", "audio_fix", "service",
            "perfz", "gfx", "account", "perf_mode", "toggle", "restore", "post-fs-data", "root"
    };
    private static final String[] PRESET_KEYS = {"bajo", "equilibrado", "alto", "nativo"};
    private static final String[] PRESET_TEXTS = {
            "Bajo\n1158×540", "Equilibrado\n1552×720", "Alto\n1930×900", "Nativo\n2316×1080"
    };
    private static final int OFF_BG = 0xFF1B2531;
    private static final int OFF_STROKE = 0xFF2A3644;
    private static final int OFF_TEXT = 0xFF7D8A99;

    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final Map<String, String> st = new LinkedHashMap<>();

    private SharedPreferences prefs;
    private TextView moduleTitle;
    private TextView moduleBody;
    private TextView accountBody;
    private TextView gfxBody;
    private TextView logView;
    private TextView busyView;
    private ScrollView logScroll;
    private Button detectBtn;
    private Button confirmBtn;
    private Button restoreGfxBtn;
    private Button closeBtn;
    private Button retryBtn;
    private Button reapplyBtn;
    private Button diagnosticBtn;
    private Button restoreAllBtn;
    private final Button[] presetButtons = new Button[4];
    private Switch profileSwitch;
    private Switch perfzSwitch;
    private Switch notifSwitch;
    private Spinner logSpinner;
    private boolean refreshInFlight;
    private boolean suppressSwitch;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences(StatusService.PREFS, MODE_PRIVATE);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        buildUi();
        AppLog.add(this, "app abierta");
        if (StatusService.prefsEnabled(this)) {
            try {
                StatusService.setEnabled(this, true);
            } catch (Throwable t) {
                AppLog.add(this, "servicio no iniciado: " + t);
            }
            if (Build.VERSION.SDK_INT >= 33
                    && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 7);
            }
        }
        refresh();
        loadLog();
    }

    private int dp(float v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }

    private String v(String key) {
        String s = st.get(key);
        return s == null ? "" : s;
    }

    private static String shortUid(String uid) {
        if (uid == null || uid.isEmpty()) {
            return "sin confirmar";
        }
        return uid.length() > 8 ? "..." + uid.substring(uid.length() - 8) : uid;
    }

    private void buildUi() {
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(BG);
        scroll.setFillViewport(true);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(16), dp(30), dp(16), dp(30));
        scroll.addView(root, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView title = new TextView(this);
        title.setText("CODM CONTROL");
        title.setTextColor(TEXT);
        title.setTextSize(26);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setLetterSpacing(0.08f);
        root.addView(title);

        TextView sub = new TextView(this);
        sub.setText("by AJ · S23 Ultra · modulo 120 · sin relojes ni thermal forzados");
        sub.setTextColor(MUTED);
        sub.setTextSize(12);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        subLp.topMargin = dp(3);
        root.addView(sub, subLp);

        View line = new View(this);
        line.setBackgroundColor(ACCENT);
        LinearLayout.LayoutParams lineLp = new LinearLayout.LayoutParams(dp(54), dp(3));
        lineLp.topMargin = dp(12);
        lineLp.bottomMargin = dp(14);
        root.addView(line, lineLp);

        busyView = new TextView(this);
        busyView.setTextColor(ACCENT);
        busyView.setTextSize(11);
        busyView.setMinHeight(dp(18));
        root.addView(busyView);

        LinearLayout moduleCard = addCard(root, "ESTADO DEL MODULO");
        moduleTitle = new TextView(this);
        moduleTitle.setTextSize(18);
        moduleTitle.setTypeface(Typeface.DEFAULT_BOLD);
        moduleTitle.setTextColor(MUTED);
        moduleTitle.setText("Consultando...");
        moduleCard.addView(moduleTitle);
        moduleBody = body(moduleCard);
        moduleBody.setText("Leyendo modulo, cuenta y props...");

        LinearLayout toggles = addCard(root, "ENCENDIDO / APAGADO");
        profileSwitch = addSwitchRow(toggles, "Perfil de fluidez",
                "GameManager performance solo mientras CODM esta abierto",
                new CompoundButton.OnCheckedChangeListener() {
                    @Override
                    public void onCheckedChanged(CompoundButton button, boolean checked) {
                        if (suppressSwitch) {
                            return;
                        }
                        runCtl("toggle " + (checked ? "on" : "off"),
                                checked ? "encender perfil" : "apagar perfil");
                    }
                });
        perfzSwitch = addSwitchRow(toggles, "Overlay Perf Z",
                "fps en pantalla mientras juegas",
                new CompoundButton.OnCheckedChangeListener() {
                    @Override
                    public void onCheckedChanged(CompoundButton button, boolean checked) {
                        if (suppressSwitch) {
                            return;
                        }
                        runCtl("perfz " + (checked ? "show" : "hide"),
                                checked ? "mostrar Perf Z" : "ocultar Perf Z");
                    }
                });
        notifSwitch = addSwitchRow(toggles, "Notificacion de estado",
                "recordatorio permanente del modulo",
                new CompoundButton.OnCheckedChangeListener() {
                    @Override
                    public void onCheckedChanged(CompoundButton button, boolean checked) {
                        if (suppressSwitch) {
                            return;
                        }
                        setNotification(checked);
                    }
                });
        small(toggles, "Naranja = encendido, gris = apagado. El perfil no fuerza relojes "
                + "ni thermal; solo usa el modo performance de GameManager.");

        LinearLayout actions = addCard(root, "ACCIONES");
        LinearLayout row1 = row(actions);
        addBtn(row1, "Abrir CODM", true, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                openCodm();
            }
        });
        closeBtn = addBtn(row1, "Cerrar CODM", false, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                runCtl("game close", "cerrar CODM");
            }
        });
        LinearLayout row2 = row(actions);
        addBtn(row2, "Actualizar", false, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                refresh();
                loadLog();
            }
        });
        diagnosticBtn = addBtn(row2, "Diagnostico 120", false, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                showDiagnostic();
            }
        });

        LinearLayout repair = addCard(root, "OPTIMIZACION Y REPARACION");
        LinearLayout row3 = row(repair);
        reapplyBtn = addBtn(row3, "Reaplicar 120", true, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                confirmReapply();
            }
        });
        retryBtn = addBtn(row3, "Reintentar 120", false, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                confirmRetry();
            }
        });
        small(repair, "Reaplicar 120 vuelve a escribir las dos preferencias de la cuenta "
                + "confirmada. Reintentar 120 cierra y reabre CODM para volver a armar la "
                + "capa Vulkan. No inyecta codigo en el juego, no fuerza relojes ni toca "
                + "ajustes de combate.");

        LinearLayout accountCard = addCard(root, "CUENTA ACTIVA");
        accountBody = body(accountCard);
        LinearLayout accountRow = row(accountCard);
        detectBtn = addBtn(accountRow, "Detectar", false, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                runCtl("account detect", "detectar cuenta");
            }
        });
        confirmBtn = addBtn(accountRow, "Confirmar cuenta", true, new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                confirmAccount();
            }
        });
        small(accountCard, "Se lee lastUserId.xml. Solo la cuenta confirmada recibe 120; "
                + "las demas cuentas del mismo telefono no se tocan.");

        LinearLayout gfxCard = addCard(root, "GFX DEL JUEGO (EXPERIMENTAL)");
        gfxBody = body(gfxCard);
        gfxBody.setText("Leyendo prefs...");
        LinearLayout presetRow = new LinearLayout(this);
        presetRow.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams presetLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        presetLp.topMargin = dp(6);
        gfxCard.addView(presetRow, presetLp);
        for (int i = 0; i < PRESET_KEYS.length; i++) {
            final String key = PRESET_KEYS[i];
            Button b = makeButton(PRESET_TEXTS[i], false);
            stylePresetButton(b, false);
            b.setTextSize(10);
            b.setSingleLine(false);
            b.setPadding(dp(2), dp(6), dp(2), dp(6));
            b.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    confirmGfx(key);
                }
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(58), 1f);
            lp.setMargins(dp(3), 0, dp(3), 0);
            presetRow.addView(b, lp);
            presetButtons[i] = b;
        }
        restoreGfxBtn = addFullBtn(gfxCard, "Restaurar valores originales de GFX", false,
                new View.OnClickListener() {
                    @Override
                    public void onClick(View view) {
                        runCtl("gfx restore", "restaurar GFX");
                    }
                });
        small(gfxCard, "Estos botones escriben solo las preferencias del juego, nunca la "
                + "resolucion del telefono. El preset en naranja es el ultimo aplicado. "
                + "Verificado: CODM reescribe estas claves al abrir, por eso puede aparecer "
                + "como reescrito y no persistir. No toca FOV, sensibilidad, MSAA ni combate. "
                + "La distancia de vision no existe en las prefs del juego: no se fuerza.");

        LinearLayout logsCard = addCard(root, "LOGS");
        LinearLayout logRow = new LinearLayout(this);
        logRow.setOrientation(LinearLayout.HORIZONTAL);
        logRow.setGravity(Gravity.CENTER_VERTICAL);
        logsCard.addView(logRow);
        logSpinner = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this,
                android.R.layout.simple_spinner_item, LOG_LABELS);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        logSpinner.setAdapter(adapter);
        logRow.addView(logSpinner, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button refreshLog = makeButton("Ver", false);
        refreshLog.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                loadLog();
            }
        });
        logRow.addView(refreshLog, new LinearLayout.LayoutParams(dp(64), dp(40)));
        Button copyLog = makeButton("Copiar", false);
        copyLog.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                copyLog();
            }
        });
        LinearLayout.LayoutParams copyLp = new LinearLayout.LayoutParams(dp(76), dp(40));
        copyLp.leftMargin = dp(4);
        logRow.addView(copyLog, copyLp);
        logSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                loadLog();
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        logScroll = new ScrollView(this);
        GradientDrawable logBg = new GradientDrawable();
        logBg.setColor(CARD_DEEP);
        logBg.setCornerRadius(dp(10));
        logBg.setStroke(dp(1), STROKE);
        logScroll.setBackground(logBg);
        logScroll.setPadding(dp(10), dp(8), dp(10), dp(8));
        logView = new TextView(this);
        logView.setTypeface(Typeface.MONOSPACE);
        logView.setTextSize(10.5f);
        logView.setTextColor(0xFFC7D3DF);
        logView.setTextIsSelectable(true);
        // El texto seleccionable pide foco y la vista exterior salta a los logs al refrescar.
        logView.setFocusable(false);
        logView.setFocusableInTouchMode(false);
        logScroll.addView(logView);
        LinearLayout.LayoutParams logLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(250));
        logLp.topMargin = dp(8);
        logsCard.addView(logScroll, logLp);
        small(logsCard, "Actividad mezcla los registros del modulo. App (acciones) guarda "
                + "cada llamada de esta app. Todo queda en el telefono.");

        LinearLayout restoreCard = addCard(root, "RESTAURACION COMPLETA");
        small(restoreCard, "Cierra CODM y restaura framerate, GFX, GameManager, Perf Z y "
                + "props. Desactivar deja el modulo instalado pero apagado; Eliminar borra "
                + "el modulo y esta app. Las dos opciones piden aceptar y reinician el telefono.");
        restoreAllBtn = addFullBtn(restoreCard, "Restaurar todo y dejar stock", false,
                new View.OnClickListener() {
                    @Override
                    public void onClick(View view) {
                        confirmRestore();
                    }
                });
        restoreAllBtn.setTextColor(RED);

        TextView footer = new TextView(this);
        footer.setText("CODM Control v1.5 · by AJ · requiere root · sin INTERNET\n"
                + "No afiliado a Activision. Los cambios del juego quedan en el modulo "
                + "codm_s23_120 y se pueden revertir.");
        footer.setTextColor(0xFF61707F);
        footer.setTextSize(10.5f);
        footer.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams footerLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        footerLp.topMargin = dp(18);
        root.addView(footer, footerLp);

        setContentView(scroll);
        suppressSwitch = true;
        profileSwitch.setChecked(true);
        perfzSwitch.setChecked(false);
        notifSwitch.setChecked(StatusService.prefsEnabled(this));
        suppressSwitch = false;
    }

    private LinearLayout addCard(LinearLayout root, String titleText) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(CARD);
        bg.setCornerRadius(dp(18));
        bg.setStroke(dp(1), STROKE);
        card.setBackground(bg);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.bottomMargin = dp(12);
        root.addView(card, lp);
        TextView t = new TextView(this);
        t.setText(titleText);
        t.setTextColor(ACCENT);
        t.setTextSize(11);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setLetterSpacing(0.10f);
        card.addView(t);
        return card;
    }

    private TextView body(LinearLayout card) {
        TextView t = new TextView(this);
        t.setTextColor(TEXT);
        t.setTextSize(13);
        t.setLineSpacing(dp(2), 1f);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(7);
        card.addView(t, lp);
        return t;
    }

    private void small(LinearLayout card, String text) {
        TextView t = new TextView(this);
        t.setText(text);
        t.setTextColor(MUTED);
        t.setTextSize(11);
        t.setLineSpacing(dp(2), 1f);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(8);
        card.addView(t, lp);
    }

    private LinearLayout row(LinearLayout card) {
        LinearLayout r = new LinearLayout(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(8);
        card.addView(r, lp);
        return r;
    }

    private Button makeButton(String text, boolean primary) {
        Button b = new Button(this);
        b.setText(text);
        b.setTextSize(12);
        b.setAllCaps(false);
        b.setTextColor(primary ? 0xFF0A0E14 : ACCENT);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(primary ? ACCENT : 0xFF1B2531);
        bg.setCornerRadius(dp(12));
        bg.setStroke(dp(1), primary ? ACCENT : STROKE);
        b.setBackground(bg);
        b.setPadding(dp(6), dp(8), dp(6), dp(8));
        b.setMinimumHeight(dp(42));
        b.setMinHeight(dp(42));
        return b;
    }

    private Button addBtn(LinearLayout row, String text, boolean primary, View.OnClickListener l) {
        Button b = makeButton(text, primary);
        b.setOnClickListener(l);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(46), 1f);
        lp.setMargins(dp(4), 0, dp(4), 0);
        row.addView(b, lp);
        return b;
    }

    private Button addFullBtn(LinearLayout card, String text, boolean primary,
                              View.OnClickListener l) {
        Button b = makeButton(text, primary);
        b.setOnClickListener(l);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(46));
        lp.topMargin = dp(10);
        card.addView(b, lp);
        return b;
    }

    private Switch addSwitchRow(LinearLayout card, String title, String hint,
                                CompoundButton.OnCheckedChangeListener listener) {
        LinearLayout r = new LinearLayout(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        r.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(10);
        card.addView(r, lp);

        LinearLayout texts = new LinearLayout(this);
        texts.setOrientation(LinearLayout.VERTICAL);
        r.addView(texts, new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView t = new TextView(this);
        t.setText(title);
        t.setTextColor(TEXT);
        t.setTextSize(14);
        texts.addView(t);
        TextView h = new TextView(this);
        h.setText(hint);
        h.setTextColor(MUTED);
        h.setTextSize(11);
        LinearLayout.LayoutParams hLp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        hLp.topMargin = dp(2);
        texts.addView(h, hLp);

        Switch sw = new Switch(this);
        tintSwitch(sw);
        sw.setOnCheckedChangeListener(listener);
        r.addView(sw);
        return sw;
    }

    private void tintSwitch(Switch sw) {
        int[][] states = new int[][]{
                new int[]{android.R.attr.state_checked},
                new int[]{}
        };
        sw.setTrackTintList(new ColorStateList(states, new int[]{ACCENT, 0xFF3A4654}));
        sw.setTrackTintMode(android.graphics.PorterDuff.Mode.SRC);
        sw.setThumbTintList(new ColorStateList(states, new int[]{0xFFFFFFFF, OFF_TEXT}));
        // One UI dibuja el track con alfa propio; sin forzarlo el naranja se ve marron.
        if (sw.getTrackDrawable() != null) {
            sw.getTrackDrawable().mutate().setAlpha(255);
        }
        if (sw.getThumbDrawable() != null) {
            sw.getThumbDrawable().mutate().setAlpha(255);
        }
    }

    private void stylePresetButton(Button b, boolean selected) {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(selected ? ACCENT : OFF_BG);
        bg.setCornerRadius(dp(12));
        bg.setStroke(dp(1), selected ? ACCENT : OFF_STROKE);
        b.setBackground(bg);
        b.setTextColor(selected ? BG : OFF_TEXT);
    }

    private void refresh() {
        if (refreshInFlight) {
            return;
        }
        refreshInFlight = true;
        if (busyView != null) {
            busyView.setText("Leyendo estado (root)...");
        }
        io.execute(new Runnable() {
            @Override
            public void run() {
                final Root.Result r = Root.ctl("status");
                final Map<String, String> parsed = Root.parse(r.out);
                if (!r.ok() && !parsed.containsKey("ERROR")) {
                    parsed.put("ERROR", r.out.trim());
                }
                ui.post(new Runnable() {
                    @Override
                    public void run() {
                        refreshInFlight = false;
                        if (busyView != null) {
                            busyView.setText("");
                        }
                        st.clear();
                        st.putAll(parsed);
                        render(r);
                    }
                });
            }
        });
    }

    private void render(Root.Result r) {
        boolean rootBad = st.containsKey("ERROR")
                || (r != null && r.out != null && r.out.contains("Sin root"))
                || st.isEmpty();
        if (rootBad) {
            moduleTitle.setText("SIN ACCESO ROOT");
            moduleTitle.setTextColor(RED);
            String detail = st.get("ERROR");
            if (r != null && r.out.contains("Sin root")) {
                detail = r.out.trim();
            }
            moduleBody.setText("La app necesita root para leer y controlar el modulo.\n"
                    + "Abre Magisk, KernelSU o APatch y autoriza CODM Control.\n\n"
                    + (detail == null ? "" : detail));
            setControlsEnabled(false);
            notifSwitch.setEnabled(true);
            return;
        }

        boolean active = "1".equals(v("module.active"));
        boolean on = "on".equals(v("perf.profile"));
        String det = v("account.detected");
        String conf = v("account.confirmed");

        moduleTitle.setText(active ? "● MODULO ACTIVO" : "● MODULO INACTIVO");
        moduleTitle.setTextColor(active ? ACCENT : MUTED);
        String manager = v("module.manager") + " " + v("module.managerVersion");
        String audio = audioLabel(v("audio.mode"));
        boolean ready = "1".equals(v("prefs.enable")) && "120".equals(v("prefs.framerate"))
                && "1".equals(v("account.match"));
        StringBuilder mb = new StringBuilder();
        mb.append("\nVersion ").append(v("module.version"))
                .append(" · by AJ · ").append(manager.trim())
                .append("\n").append(v("device.model")).append(" (").append(v("device.device"))
                .append(") · Android ").append(v("android.release"));
        if (!v("game.package").isEmpty()) {
            mb.append("\nJuego: ").append(v("game.package"));
        }
        if (!v("android.oneui").isEmpty()) {
            mb.append(" · One UI ").append(v("android.oneui"));
        }
        if ("1".equals(v("app.packaged"))) {
            mb.append("\nApp: viaja en el modulo (v").append(orDash(v("app.wanted")))
                    .append(", instalada ");
            mb.append("1".equals(v("app.installed")) ? "v" + orDash(v("app.version")) : "no");
            mb.append(")");
        }
        mb.append("\n120: ").append(ready ? "listo" : "incompleto")
                .append(" · perfil ").append(active ? (on ? "ON" : "OFF") : "sin efecto")
                .append(" · overlay ").append(active
                        ? ("0".equals(v("perfz.visibility")) ? "ON" : "OFF") : "sin efecto");
        if (!v("doctor.verdict").isEmpty()) {
            mb.append("\nDoctor: ").append(v("doctor.verdict"));
            if (!v("doctor.notes").isEmpty()) {
                mb.append(" · ").append(v("doctor.notes"));
            }
        }
        mb.append("\nAudio: ").append(audio)
                .append("\nProps: ").append("1".equals(v("spoof.propsAdjusted"))
                        ? "originales restauradas" : "sin ajuste pendiente")
                .append(" · resetprop ").append("1".equals(v("module.resetprop")) ? "si" : "no");
        if ("1".equals(v("game.running"))) {
            mb.append("\nCODM abierto · capa ").append("1".equals(v("layer.mapped")) ? "cargada" : "no mapeada");
        }
        if (!active) {
            mb.append("\n\nModulo apagado: las opciones de abajo no actuan. "
                    + "Activa codm_s23_120 en el gestor root y reinicia.");
        }
        moduleBody.setText(mb.toString());

        accountBody.setText("Activa: " + (det.isEmpty() ? "sin detectar" : det)
                + "\nConfirmada: " + (conf.isEmpty() ? "ninguna" : conf)
                + "\n" + accountState(det, conf));
        confirmBtn.setEnabled(active && !det.isEmpty() && !det.equals(conf));
        detectBtn.setEnabled(active);

        String preset = v("gfx.preset");
        String shownPreset = preset.isEmpty()
                ? inferPreset(v("gfx.width"), v("gfx.height"), v("gfx.quality")) : preset;
        gfxBody.setText("3D actual: " + orDash(v("gfx.width")) + "×" + orDash(v("gfx.height"))
                + " · Unity " + orDash(v("gfx.quality"))
                + "\nPreset: " + (preset.isEmpty()
                        ? (shownPreset.isEmpty() ? "ninguno" : shownPreset + " (valores actuales)")
                        : preset)
                + ("1".equals(v("gfx.modified")) ? " · backup listo" : "")
                + ("1".equals(v("gfx.overridden"))
                        ? "\nNo persistio: CODM reescribio la resolucion al abrir." : "")
                + "\nCODM: " + ("1".equals(v("game.running")) ? "abierto (cierralo para aplicar)" : "cerrado")
                + "\nSolo prefs del juego; la resolucion del telefono no se toca.");

        suppressSwitch = true;
        // Con el modulo apagado no se aplica nada: los interruptores se ven grises.
        profileSwitch.setChecked(active && on);
        perfzSwitch.setChecked(active && "0".equals(v("perfz.visibility")));
        notifSwitch.setChecked(StatusService.prefsEnabled(this));
        suppressSwitch = false;

        for (int i = 0; i < presetButtons.length; i++) {
            stylePresetButton(presetButtons[i], PRESET_KEYS[i].equals(shownPreset));
        }
        setControlsEnabled(active);
        restoreGfxBtn.setEnabled(active && "1".equals(v("gfx.modified")));
    }

    private static String inferPreset(String width, String height, String quality) {
        if ("1158".equals(width) && "540".equals(height) && "0".equals(quality)) {
            return "bajo";
        }
        if ("1552".equals(width) && "720".equals(height) && "1".equals(quality)) {
            return "equilibrado";
        }
        if ("1930".equals(width) && "900".equals(height) && "2".equals(quality)) {
            return "alto";
        }
        if ("2316".equals(width) && "1080".equals(height) && "3".equals(quality)) {
            return "nativo";
        }
        return "";
    }

    private String accountState(String det, String conf) {
        if (det.isEmpty()) {
            return "Abre CODM e inicia sesion; luego pulsa Detectar.";
        }
        if (conf.isEmpty()) {
            return "Sin confirmacion: no se aplicara 120 hasta que confirmes.";
        }
        if (!det.equals(conf)) {
            return "La cuenta activa cambio. Confirma para aplicar solo a esta.";
        }
        if ("1".equals(v("account.known"))) {
            return "Cuenta conocida, auto-confirmada.";
        }
        return "Cuenta confirmada por el usuario.";
    }

    private static String orDash(String s) {
        return s == null || s.isEmpty() ? "n/d" : s;
    }

    private static String audioLabel(String mode) {
        if ("dm3q-parcheado".equals(mode)) {
            return "Samsung dm3q (XML parcheado)";
        }
        if ("dm3q-stock".equals(mode)) {
            return "Samsung dm3q (XML stock)";
        }
        if ("sin-xml".equals(mode)) {
            return "sin XML de audio";
        }
        if ("no-aplica".equals(mode)) {
            return "sin cambios (equipo no dm3q)";
        }
        if (mode == null || mode.isEmpty()) {
            return "n/d";
        }
        return mode;
    }

    private void setControlsEnabled(boolean enabled) {
        profileSwitch.setEnabled(enabled);
        perfzSwitch.setEnabled(enabled);
        closeBtn.setEnabled(enabled);
        retryBtn.setEnabled(enabled);
        reapplyBtn.setEnabled(enabled);
        diagnosticBtn.setEnabled(enabled);
        restoreAllBtn.setEnabled(enabled);
        detectBtn.setEnabled(enabled);
        confirmBtn.setEnabled(enabled && !v("account.detected").equals(v("account.confirmed")));
        restoreGfxBtn.setEnabled(enabled && "1".equals(v("gfx.modified")));
        for (Button b : presetButtons) {
            b.setEnabled(enabled);
        }
    }

    private void runCtl(final String args, final String label) {
        AppLog.add(this, "CMD " + args);
        busyView.setText("Ejecutando: " + label + "...");
        io.execute(new Runnable() {
            @Override
            public void run() {
                final Root.Result r = Root.ctl(args);
                AppLog.add(MainActivity.this, label + " rc=" + r.code
                        + (r.summary().isEmpty() ? "" : " · " + r.summary().replace("\n", " | ")));
                ui.post(new Runnable() {
                    @Override
                    public void run() {
                        busyView.setText("");
                        String msg = r.summary();
                        if (msg.isEmpty()) {
                            msg = r.ok() ? label + ": hecho" : label + ": error " + r.code;
                        }
                        Toast.makeText(MainActivity.this, msg, Toast.LENGTH_LONG).show();
                        refresh();
                        loadLog();
                    }
                });
            }
        });
    }

    private void loadLog() {
        if (logView == null || logSpinner == null) {
            return;
        }
        int pos = logSpinner.getSelectedItemPosition();
        if (pos < 0 || pos >= LOG_KEYS.length) {
            pos = 0;
        }
        final String key = LOG_KEYS[pos];
        if (key == null) {
            logView.setText(AppLog.tail(this, 300));
            scrollLogDown();
            return;
        }
        logView.setText("Cargando registro...");
        io.execute(new Runnable() {
            @Override
            public void run() {
                final Root.Result r = Root.ctl("logs " + key + " 250");
                ui.post(new Runnable() {
                    @Override
                    public void run() {
                        String text = r.out == null ? "" : r.out.trim();
                        if (text.isEmpty()) {
                            text = "(sin registros)";
                        }
                        logView.setText(text);
                        scrollLogDown();
                    }
                });
            }
        });
    }

    private void scrollLogDown() {
        if (logScroll != null) {
            logScroll.post(new Runnable() {
                @Override
                public void run() {
                    logScroll.fullScroll(View.FOCUS_DOWN);
                }
            });
        }
    }

    private void copyLog() {
        CharSequence text = logView == null ? "" : logView.getText();
        ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (cm != null) {
            cm.setPrimaryClip(ClipData.newPlainText("CODM Control log", text));
            Toast.makeText(this, "Log copiado", Toast.LENGTH_SHORT).show();
        }
    }

    private void openCodm() {
        // El modulo resuelve el paquete real (global/Garena/Tencent/VNG); asi la
        // app no depende de un ID regional fijo.
        Toast.makeText(this, "Abriendo CODM...", Toast.LENGTH_SHORT).show();
        io.execute(new Runnable() {
            @Override
            public void run() {
                Root.Result r = Root.ctl("game launch", 30);
                boolean ok = r.ok() && !r.out.trim().startsWith("ERROR");
                if (!ok) {
                    // Respaldo sin modulo: ID global.
                    r = Root.run("monkey -p " + Root.CODM
                            + " -c android.intent.category.LAUNCHER 1", 25);
                    ok = r.ok() && !r.out.contains("No activities found");
                }
                final boolean done = ok;
                final Root.Result res = r;
                ui.post(new Runnable() {
                    @Override
                    public void run() {
                        if (!done) {
                            Toast.makeText(MainActivity.this,
                                    "No pude abrir CODM: " + res.summary(), Toast.LENGTH_LONG).show();
                        }
                        refresh();
                    }
                });
            }
        });
    }

    private void confirmAccount() {
        final String det = v("account.detected");
        if (!det.matches("[0-9]{10,25}")) {
            Toast.makeText(this, "No hay una cuenta valida detectada", Toast.LENGTH_SHORT).show();
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Confirmar cuenta")
                .setMessage("Se aplicara el framerate 120 solo a la cuenta:\n\n" + det
                        + "\n\nLas demas cuentas del telefono no se modifican. "
                        + "Si cambias de cuenta, detecta y confirma de nuevo.")
                .setPositiveButton("Confirmar", new android.content.DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(android.content.DialogInterface dialog, int which) {
                        runCtl("account confirm " + det, "confirmar cuenta");
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void confirmGfx(final String preset) {
        if ("1".equals(v("game.running"))) {
            new AlertDialog.Builder(this)
                    .setTitle("CODM esta abierto")
                    .setMessage("Cierra CODM por completo antes de cambiar la resolucion de render. "
                            + "El juego reescribe sus prefs al salir.")
                    .setPositiveButton("Entendido", null)
                    .show();
            return;
        }
        String info;
        if ("bajo".equals(preset)) {
            info = "1158×540, calidad Unity 0. Maximo rendimiento, imagen mas suave.";
        } else if ("equilibrado".equals(preset)) {
            info = "1552×720, calidad Unity 1. Valores actuales verificados.";
        } else if ("alto".equals(preset)) {
            info = "1930×900, calidad Unity 2. Mas nitidez, mas carga.";
        } else {
            info = "2316×1080, calidad Unity 3. Resolucion nativa, solo para pruebas.";
        }
        new AlertDialog.Builder(this)
                .setTitle("Aplicar GFX " + preset)
                .setMessage(info + "\n\nSolo aspecto visual: no toca FOV, sensibilidad, "
                        + "MSAA por cuenta ni ajustes de combate. El juego puede ignorar o "
                        + "reescribir el valor. Se guarda un backup para restaurar.")
                .setPositiveButton("Aplicar", new android.content.DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(android.content.DialogInterface dialog, int which) {
                        runCtl("gfx apply " + preset, "GFX " + preset);
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void confirmReapply() {
        if ("1".equals(v("game.running"))) {
            new AlertDialog.Builder(this)
                    .setTitle("CODM esta abierto")
                    .setMessage("Cierra CODM por completo antes de reaplicar las prefs 120.")
                    .setPositiveButton("Entendido", null)
                    .show();
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Reaplicar 120")
                .setMessage("Se escriben EnableFramerateCustomize=1 y FramerateCustomizeValue=120 "
                        + "solo para la cuenta confirmada. Si ya estan en 120, no cambia nada.\n\n"
                        + "No toca GFX, combate, relojes ni thermal.")
                .setPositiveButton("Reaplicar", new android.content.DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(android.content.DialogInterface dialog, int which) {
                        runCtl("prefs apply", "reaplicar 120");
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void confirmRetry() {
        new AlertDialog.Builder(this)
                .setTitle("Reintentar 120")
                .setMessage("Se cierra CODM si esta abierto y se abre de nuevo para que el "
                        + "modulo vuelva a armar la capa Vulkan al detectar la interfaz.\n\n"
                        + "Usalo solo si el juego no alcanza 120. No inyecta codigo en el juego.")
                .setPositiveButton("Reintentar", new android.content.DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(android.content.DialogInterface dialog, int which) {
                        runCtl("game retry", "reintentar 120");
                    }
                })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void showDiagnostic() {
        boolean active = "1".equals(v("module.active"));
        boolean game = "1".equals(v("game.running"));
        boolean mapped = "1".equals(v("layer.mapped"));
        boolean match = "1".equals(v("account.match"));
        boolean prefsOk = "1".equals(v("prefs.enable")) && "120".equals(v("prefs.framerate"));
        boolean overlay = "0".equals(v("perfz.visibility"));
        StringBuilder d = new StringBuilder();
        d.append("Modulo: ").append(active ? "activo" : "inactivo").append('\n');
        d.append("Cuenta: ").append(match ? "confirmada" : "sin confirmar").append('\n');
        d.append("Prefs 120: ").append(prefsOk ? "si (1/120)"
                : "no (" + orDash(v("prefs.enable")) + "/" + orDash(v("prefs.framerate")) + ")")
                .append('\n');
        d.append("Capa Vulkan: ").append(game ? (mapped ? "cargada" : "NO mapeada")
                : "en espera (CODM cerrado)").append('\n');
        d.append("Perfil: ").append("on".equals(v("perf.profile")) ? "encendido" : "apagado")
                .append('\n');
        d.append("Perf Z: ").append(overlay ? "visible" : "oculto").append('\n');
        d.append("GFX: ").append(orDash(v("gfx.width"))).append("×").append(orDash(v("gfx.height")))
                .append(" · Unity ").append(orDash(v("gfx.quality")))
                .append(" · ").append(v("gfx.preset").isEmpty() ? "sin preset" : v("gfx.preset"))
                .append('\n');
        d.append("Audio: ").append(audioLabel(v("audio.mode"))).append('\n');
        d.append('\n');
        if (!active) {
            d.append("Activa el modulo y reinicia.");
        } else if (!match) {
            d.append("Confirma la cuenta activa.");
        } else if (!prefsOk) {
            d.append("Pulsa Reaplicar 120 con CODM cerrado.");
        } else if (game && !mapped) {
            d.append("La capa no se mapeo: pulsa Reintentar 120.");
        } else {
            d.append("Todo listo. Si el overlay muestra menos de 120 en partida, "
                    + "pulsa Reintentar 120.");
        }
        final String text = d.toString();
        new AlertDialog.Builder(this)
                .setTitle("Diagnostico 120")
                .setMessage(text)
                .setPositiveButton("Cerrar", null)
                .setNeutralButton("Copiar", new android.content.DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(android.content.DialogInterface dialog, int which) {
                        ClipboardManager cm = (ClipboardManager) getSystemService(
                                Context.CLIPBOARD_SERVICE);
                        if (cm != null) {
                            cm.setPrimaryClip(ClipData.newPlainText("Diagnostico CODM", text));
                            Toast.makeText(MainActivity.this, "Diagnostico copiado",
                                    Toast.LENGTH_SHORT).show();
                        }
                    }
                })
                .show();
    }

    private void confirmRestore() {
        if (!"1".equals(v("module.active"))) {
            Toast.makeText(this, "El modulo ya esta apagado", Toast.LENGTH_SHORT).show();
            return;
        }
        final AlertDialog[] chooser = new AlertDialog[1];
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(20), dp(4), dp(20), dp(4));

        TextView intro = new TextView(this);
        intro.setText("Cierra CODM y restaura framerate, GFX, GameManager, Perf Z y props. "
                + "Las dos opciones reinician el telefono para quitar el XML y la capa.");
        intro.setTextColor(MUTED);
        intro.setTextSize(12);
        intro.setLineSpacing(dp(2), 1f);
        box.addView(intro);

        addRestoreOption(box, "Desactivar modulo",
                "Deja el telefono como stock. El modulo sigue instalado y se puede reactivar.",
                ACCENT, new Runnable() {
                    @Override
                    public void run() {
                        chooser[0].dismiss();
                        confirmDisable();
                    }
                });
        addRestoreOption(box, "Eliminar modulo y esta app",
                "Borra el modulo /data/adb/modules/codm_s23_120 y esta app. No se puede deshacer.",
                RED, new Runnable() {
                    @Override
                    public void run() {
                        chooser[0].dismiss();
                        confirmRemove();
                    }
                });

        ScrollView wrap = new ScrollView(this);
        wrap.addView(box);
        chooser[0] = new AlertDialog.Builder(this)
                .setTitle("Restaurar todo y dejar stock")
                .setView(wrap)
                .setNegativeButton("Cancelar", null)
                .create();
        chooser[0].show();
    }

    private void addRestoreOption(LinearLayout parent, String title, String detail, int titleColor,
                                  final Runnable action) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(OFF_BG);
        bg.setCornerRadius(dp(12));
        bg.setStroke(dp(1), OFF_STROKE);
        box.setBackground(bg);
        box.setPadding(dp(14), dp(12), dp(14), dp(12));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(12);
        parent.addView(box, lp);

        TextView t = new TextView(this);
        t.setText(title);
        t.setTextColor(titleColor);
        t.setTextSize(14);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        box.addView(t);
        TextView d = new TextView(this);
        d.setText(detail);
        d.setTextColor(MUTED);
        d.setTextSize(11);
        d.setLineSpacing(dp(2), 1f);
        LinearLayout.LayoutParams dlp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        dlp.topMargin = dp(3);
        box.addView(d, dlp);
        box.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                action.run();
            }
        });
    }

    private void confirmDisable() {
        new AlertDialog.Builder(this)
                .setTitle("Desactivar modulo")
                .setMessage("Se restaura todo lo que el modulo cambio y queda instalado pero "
                        + "apagado; podras reactivarlo en Magisk/KernelSU/APatch.\n\n"
                        + "El telefono se reiniciara ahora. Acepta para continuar.")
                .setPositiveButton("Aceptar y reiniciar",
                        new android.content.DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(android.content.DialogInterface dialog, int which) {
                                runDestructive("module disable",
                                        "Restaurando y desactivando",
                                        "Restaurando datos y apagando el modulo.\n"
                                                + "El telefono se reiniciara.", true);
                            }
                        })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void confirmRemove() {
        new AlertDialog.Builder(this)
                .setTitle("Eliminar definitivamente")
                .setMessage("Se restaura todo y despues se borran el modulo "
                        + "/data/adb/modules/codm_s23_120 y esta app. No se puede deshacer.\n\n"
                        + "El telefono se reiniciara ahora. Acepta para eliminar.")
                .setPositiveButton("Aceptar y eliminar",
                        new android.content.DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(android.content.DialogInterface dialog, int which) {
                                runDestructive("module remove",
                                        "Eliminando modulo y app",
                                        "Restaurando datos y borrando el modulo y la app.\n"
                                                + "El telefono se reiniciara.", false);
                            }
                        })
                .setNegativeButton("Cancelar", null)
                .show();
    }

    private void runDestructive(final String cmd, final String title, final String message,
                                final boolean rebootAfter) {
        final AlertDialog progress = new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setCancelable(false)
                .create();
        progress.show();
        io.execute(new Runnable() {
            @Override
            public void run() {
                final Root.Result r = Root.ctl(cmd, 240);
                if (!r.ok()) {
                    ui.post(new Runnable() {
                        @Override
                        public void run() {
                            progress.dismiss();
                            Toast.makeText(MainActivity.this,
                                    "No se pudo completar: " + r.summary(), Toast.LENGTH_LONG).show();
                            refresh();
                        }
                    });
                    return;
                }
                if (rebootAfter) {
                    Root.Result rb = Root.run("svc power reboot", 20);
                    if (!rb.ok()) {
                        Root.run("reboot", 20);
                    }
                }
            }
        });
    }

    private void setNotification(boolean enabled) {
        AppLog.add(this, "notificacion: " + enabled);
        if (enabled && Build.VERSION.SDK_INT >= 33
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 7);
        }
        try {
            StatusService.setEnabled(this, enabled);
        } catch (Throwable t) {
            Toast.makeText(this, "No se pudo iniciar la notificacion: " + t.getClass().getSimpleName(),
                    Toast.LENGTH_LONG).show();
            AppLog.add(this, "notificacion fallo: " + t);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 7) {
            boolean granted = grantResults.length > 0
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            if (!granted) {
                Toast.makeText(this, "Sin permiso de notificaciones; el servicio puede quedar oculto",
                        Toast.LENGTH_LONG).show();
            }
            try {
                StatusService.setEnabled(this, StatusService.prefsEnabled(this));
            } catch (Throwable ignored) {
            }
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (!refreshInFlight) {
            refresh();
        }
    }

    @Override
    protected void onDestroy() {
        ui.removeCallbacksAndMessages(null);
        io.shutdownNow();
        super.onDestroy();
    }
}
