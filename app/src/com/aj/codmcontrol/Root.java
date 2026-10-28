package com.aj.codmcontrol;

import java.util.LinkedHashMap;
import java.util.Map;

final class Root {
    static final String MODULE = "/data/adb/modules/codm_s23_120";
    static final String CTL = MODULE + "/tools/codmctl.sh";
    static final String CODM = "com.activision.callofduty.shooter";

    private Root() {
    }

    static final class Result {
        final int code;
        final String out;

        Result(int code, String out) {
            this.code = code;
            this.out = out == null ? "" : out;
        }

        boolean ok() {
            return code == 0;
        }

        String summary() {
            String s = out.trim();
            if (s.length() > 400) {
                s = s.substring(0, 400) + "...";
            }
            return s;
        }
    }

    static Result run(String command) {
        return run(command, 40);
    }

    static Result run(String command, int timeoutSec) {
        return RootShell.get().execute(command, timeoutSec);
    }

    static Result ctl(String args) {
        return ctl(args, 40);
    }

    static Result ctl(String args, int timeoutSec) {
        return run("sh " + CTL + " " + args, timeoutSec);
    }

    static Map<String, String> status() {
        Result r = ctl("status");
        Map<String, String> m = parse(r.out);
        if (!r.ok() && !m.containsKey("ERROR")) {
            m.put("ERROR", r.out.trim());
        }
        return m;
    }

    static Map<String, String> parse(String out) {
        Map<String, String> m = new LinkedHashMap<>();
        if (out == null) {
            return m;
        }
        for (String line : out.split("\n")) {
            int i = line.indexOf('=');
            if (i > 0) {
                m.put(line.substring(0, i), line.substring(i + 1).trim());
            }
        }
        return m;
    }

    static boolean rootOk() {
        Result r = run("id -u", 10);
        return r.ok() && "0".equals(r.out.trim());
    }
}
