package io.carson.uibridge;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.Intent;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.regex.Pattern;

public final class CarsonAccessibilityService extends AccessibilityService {
    private static final int PORT = 18765;
    private static final String TOKEN = "__CARSON_UI_DEVICE_TOKEN__";

    private final Object eventLock = new Object();
    private volatile long eventGeneration = 0;
    private volatile boolean running = false;
    private ServerSocket server;

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        AccessibilityServiceInfo info = getServiceInfo();
        info.flags |= AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS;
        info.flags |= AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        info.notificationTimeout = 0;
        setServiceInfo(info);
        startServer();
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        synchronized (eventLock) {
            eventGeneration++;
            eventLock.notifyAll();
        }
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    public void onDestroy() {
        running = false;
        try {
            if (server != null) server.close();
        } catch (IOException ignored) {
        }
        super.onDestroy();
    }

    private void startServer() {
        if (running) return;
        running = true;
        Thread t = new Thread(() -> {
            try {
                server = new ServerSocket();
                server.setReuseAddress(true);
                server.bind(new InetSocketAddress(InetAddress.getByName("127.0.0.1"), PORT));
                while (running) {
                    Socket socket = server.accept();
                    socket.setSoTimeout(30000);
                    new Thread(() -> handle(socket), "carson-ui-client").start();
                }
            } catch (Throwable ignored) {
                running = false;
            }
        }, "carson-ui-loopback");
        t.setDaemon(true);
        t.start();
    }

    private void handle(Socket socket) {
        try (
            Socket s = socket;
            BufferedReader in = new BufferedReader(
                new InputStreamReader(s.getInputStream(), StandardCharsets.UTF_8));
            BufferedWriter out = new BufferedWriter(
                new OutputStreamWriter(s.getOutputStream(), StandardCharsets.UTF_8))
        ) {
            String line = in.readLine();
            if (line == null) return;
            String[] p = line.split("\t", -1);
            if (p.length < 2 || !constantEquals(p[0], TOKEN)) {
                writeLine(out, "ERR\tAUTH");
                return;
            }

            String cmd = p[1];
            switch (cmd) {
                case "PING":
                    writeLine(out, "OK\tPONG");
                    break;
                case "STATE":
                    state(out);
                    break;
                case "SNAPSHOT":
                    snapshot(out);
                    break;
                case "FIND_EXACT":
                    requireArgs(p, 3);
                    findExact(out, decode(p[2]));
                    break;
                case "WAIT_EXACT":
                    requireArgs(p, 4);
                    waitExact(out, Long.parseLong(p[2]), decode(p[3]));
                    break;
                case "WAIT_REGEX":
                    requireArgs(p, 4);
                    waitRegex(out, Long.parseLong(p[2]), decode(p[3]));
                    break;
                case "WAIT_PACKAGE":
                    requireArgs(p, 4);
                    waitPackage(out, Long.parseLong(p[2]), decode(p[3]));
                    break;
                case "CLICK_EXACT":
                    requireArgs(p, 3);
                    clickExact(out, decode(p[2]));
                    break;
                case "CLICK_EXACT_TOP":
                    requireArgs(p, 3);
                    clickExactDirectional(out, decode(p[2]), true);
                    break;
                case "CLICK_EXACT_BOTTOM":
                    requireArgs(p, 3);
                    clickExactDirectional(out, decode(p[2]), false);
                    break;
                case "LONG_CLICK_EXACT":
                    requireArgs(p, 3);
                    longClickExact(out, decode(p[2]));
                    break;
                case "SET_TEXT":
                    requireArgs(p, 3);
                    setText(out, decode(p[2]));
                    break;
                case "BACK":
                    writeLine(out, performGlobalAction(GLOBAL_ACTION_BACK)
                        ? "OK\tBACK" : "ERR\tBACK");
                    break;
                case "HOME":
                    writeLine(out, performGlobalAction(GLOBAL_ACTION_HOME)
                        ? "OK\tHOME" : "ERR\tHOME");
                    break;
                case "OPEN_PACKAGE":
                    requireArgs(p, 3);
                    openPackage(out, decode(p[2]));
                    break;
                default:
                    writeLine(out, "ERR\tUNKNOWN_COMMAND");
            }
        } catch (Throwable ignored) {
        }
    }

    private void state(BufferedWriter out) throws IOException {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            writeLine(out, "OK\tSTATE\tNO_ROOT\tGEN=" + eventGeneration);
            return;
        }
        CharSequence pkg = root.getPackageName();
        List<AccessibilityNodeInfo> nodes = flatten(root);
        int editable = 0;
        int clickable = 0;
        for (AccessibilityNodeInfo n : nodes) {
            if (n.isEditable()) editable++;
            if (n.isClickable()) clickable++;
        }
        writeLine(out, "OK\tSTATE\tPKG=" + safe(pkg) +
            "\tNODES=" + nodes.size() +
            "\tEDITABLE=" + editable +
            "\tCLICKABLE=" + clickable +
            "\tBUILD=5" +
            "\tGEN=" + eventGeneration);
    }

    private void snapshot(BufferedWriter out) throws IOException {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            writeLine(out, "OK\tSNAPSHOT_BEGIN\tNO_ROOT");
            writeLine(out, "OK\tSNAPSHOT_END");
            return;
        }

        writeLine(out, "OK\tSNAPSHOT_BEGIN");
        for (AccessibilityNodeInfo n : flatten(root)) {
            Rect r = new Rect();
            n.getBoundsInScreen(r);
            String line =
                "NODE\t" +
                enc(safe(n.getPackageName())) + "\t" +
                enc(safe(n.getClassName())) + "\t" +
                enc(safe(n.getText())) + "\t" +
                enc(safe(n.getContentDescription())) + "\t" +
                (n.isClickable() ? "1" : "0") + "\t" +
                (n.isEditable() ? "1" : "0") + "\t" +
                r.left + "," + r.top + "," + r.right + "," + r.bottom;
            writeLine(out, line);
        }
        writeLine(out, "OK\tSNAPSHOT_END");
    }

    private void findExact(BufferedWriter out, String needle) throws IOException {
        List<AccessibilityNodeInfo> matches = exactMatches(getRootInActiveWindow(), needle);
        writeLine(out, "OK\tFIND_EXACT\tCOUNT=" + matches.size());
    }

    private void waitExact(BufferedWriter out, long timeoutMs, String needle) throws IOException {
        long start = SystemClock.elapsedRealtime();
        while (true) {
            List<AccessibilityNodeInfo> matches = exactMatches(getRootInActiveWindow(), needle);
            if (!matches.isEmpty()) {
                writeLine(out, "OK\tWAIT_EXACT\tCOUNT=" + matches.size() +
                    "\tELAPSED_MS=" + (SystemClock.elapsedRealtime() - start));
                return;
            }
            if (!waitForEventUntil(start, timeoutMs)) {
                writeLine(out, "TIMEOUT\tWAIT_EXACT\tELAPSED_MS=" +
                    (SystemClock.elapsedRealtime() - start));
                return;
            }
        }
    }

    private void waitRegex(BufferedWriter out, long timeoutMs, String regex) throws IOException {
        Pattern pattern = Pattern.compile(regex, Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
        long start = SystemClock.elapsedRealtime();
        while (true) {
            AccessibilityNodeInfo root = getRootInActiveWindow();
            int count = 0;
            if (root != null) {
                for (AccessibilityNodeInfo n : flatten(root)) {
                    if (pattern.matcher(safe(n.getText())).find() ||
                        pattern.matcher(safe(n.getContentDescription())).find()) {
                        count++;
                    }
                }
            }
            if (count > 0) {
                writeLine(out, "OK\tWAIT_REGEX\tCOUNT=" + count +
                    "\tELAPSED_MS=" + (SystemClock.elapsedRealtime() - start));
                return;
            }
            if (!waitForEventUntil(start, timeoutMs)) {
                writeLine(out, "TIMEOUT\tWAIT_REGEX\tELAPSED_MS=" +
                    (SystemClock.elapsedRealtime() - start));
                return;
            }
        }
    }

    private void waitPackage(BufferedWriter out, long timeoutMs, String pkg) throws IOException {
        long start = SystemClock.elapsedRealtime();
        while (true) {
            AccessibilityNodeInfo root = getRootInActiveWindow();
            if (root != null && pkg.equals(safe(root.getPackageName()))) {
                writeLine(out, "OK\tWAIT_PACKAGE\tELAPSED_MS=" +
                    (SystemClock.elapsedRealtime() - start));
                return;
            }
            if (!waitForEventUntil(start, timeoutMs)) {
                writeLine(out, "TIMEOUT\tWAIT_PACKAGE\tELAPSED_MS=" +
                    (SystemClock.elapsedRealtime() - start));
                return;
            }
        }
    }

    private boolean waitForEventUntil(long start, long timeoutMs) {
        long elapsed = SystemClock.elapsedRealtime() - start;
        long remain = timeoutMs - elapsed;
        if (remain <= 0) return false;
        synchronized (eventLock) {
            long before = eventGeneration;
            try {
                eventLock.wait(Math.min(remain, 5000));
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return false;
            }
            if (eventGeneration == before &&
                SystemClock.elapsedRealtime() - start >= timeoutMs) {
                return false;
            }
        }
        return SystemClock.elapsedRealtime() - start < timeoutMs;
    }

    private boolean supportsClickAction(AccessibilityNodeInfo n) {
        if (n == null) return false;
        if (n.isClickable()) return true;
        for (AccessibilityNodeInfo.AccessibilityAction a : n.getActionList()) {
            if (a.getId() == AccessibilityNodeInfo.ACTION_CLICK) return true;
        }
        return false;
    }

    private AccessibilityNodeInfo nearestClickActionNode(AccessibilityNodeInfo n) {
        AccessibilityNodeInfo q = n;
        while (q != null && !supportsClickAction(q)) q = q.getParent();
        return q;
    }

    private void clickExact(BufferedWriter out, String needle) throws IOException {
        List<AccessibilityNodeInfo> matches = exactMatches(getRootInActiveWindow(), needle);
        LinkedHashMap<String, AccessibilityNodeInfo> actions = new LinkedHashMap<>();

        for (AccessibilityNodeInfo n : matches) {
            AccessibilityNodeInfo q = n;
            while (q != null && !supportsClickAction(q)) {
                q = q.getParent();
            }
            if (q != null && supportsClickAction(q)) {
                Rect r = new Rect();
                q.getBoundsInScreen(r);
                String key = safe(q.getViewIdResourceName()) + "|" + r.flattenToString();
                actions.put(key, q);
            }
        }

        if (actions.size() != 1) {
            writeLine(out, "ERR\tAMBIGUOUS_CLICK\tMATCHES=" + matches.size() +
                "\tACTIONS=" + actions.size());
            return;
        }

        AccessibilityNodeInfo target = actions.values().iterator().next();
        boolean ok = target.performAction(AccessibilityNodeInfo.ACTION_CLICK);
        writeLine(out, ok ? "OK\tCLICK_EXACT" : "ERR\tCLICK_FAILED");
    }

    private void clickExactDirectional(
        BufferedWriter out, String needle, boolean top
    ) throws IOException {
        List<AccessibilityNodeInfo> matches =
            exactMatches(getRootInActiveWindow(), needle);

        LinkedHashMap<String, AccessibilityNodeInfo> actions =
            new LinkedHashMap<>();

        for (AccessibilityNodeInfo n : matches) {
            AccessibilityNodeInfo q = nearestClickActionNode(n);
            if (q != null) {
                Rect r = new Rect();
                q.getBoundsInScreen(r);
                String key = safe(q.getViewIdResourceName()) + "|" +
                    r.flattenToString();
                actions.put(key, q);
            }
        }

        if (actions.isEmpty()) {
            writeLine(
                out,
                "ERR\tNO_CLICK_ACTION\tMATCHES=" + matches.size()
            );
            return;
        }

        AccessibilityNodeInfo target = null;
        int bestY = top ? Integer.MAX_VALUE : Integer.MIN_VALUE;

        for (AccessibilityNodeInfo q : actions.values()) {
            Rect r = new Rect();
            q.getBoundsInScreen(r);
            int y = r.centerY();
            if (target == null || (top ? y < bestY : y > bestY)) {
                target = q;
                bestY = y;
            }
        }

        boolean ok = target != null &&
            target.performAction(AccessibilityNodeInfo.ACTION_CLICK);

        writeLine(
            out,
            ok
              ? (top ? "OK\tCLICK_EXACT_TOP" : "OK\tCLICK_EXACT_BOTTOM")
              : "ERR\tCLICK_DIRECTIONAL_FAILED"
        );
    }

    private boolean supportsLongClick(AccessibilityNodeInfo n) {
        if (n == null) return false;
        if (n.isLongClickable()) return true;
        for (AccessibilityNodeInfo.AccessibilityAction a : n.getActionList()) {
            if (a.getId() == AccessibilityNodeInfo.ACTION_LONG_CLICK) return true;
        }
        return false;
    }

    private void longClickExact(BufferedWriter out, String needle) throws IOException {
        List<AccessibilityNodeInfo> matches =
            exactMatches(getRootInActiveWindow(), needle);
        LinkedHashMap<String, AccessibilityNodeInfo> actions =
            new LinkedHashMap<>();

        for (AccessibilityNodeInfo n : matches) {
            AccessibilityNodeInfo q = n;
            while (q != null && !supportsLongClick(q)) {
                q = q.getParent();
            }
            if (q != null && supportsLongClick(q)) {
                Rect r = new Rect();
                q.getBoundsInScreen(r);
                String key =
                    safe(q.getViewIdResourceName()) + "|" +
                    r.flattenToString();
                actions.put(key, q);
            }
        }

        if (actions.size() != 1) {
            writeLine(
                out,
                "ERR\tAMBIGUOUS_LONG_CLICK\tMATCHES=" + matches.size() +
                "\tACTIONS=" + actions.size()
            );
            return;
        }

        AccessibilityNodeInfo target = actions.values().iterator().next();
        boolean ok =
            target.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK);
        writeLine(
            out,
            ok ? "OK\tLONG_CLICK_EXACT" : "ERR\tLONG_CLICK_FAILED"
        );
    }

    private void setText(BufferedWriter out, String text) throws IOException {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            writeLine(out, "ERR\tNO_ROOT");
            return;
        }

        List<AccessibilityNodeInfo> editable = new ArrayList<>();
        AccessibilityNodeInfo focused = null;
        for (AccessibilityNodeInfo n : flatten(root)) {
            if (!n.isEditable()) continue;
            editable.add(n);
            if (n.isFocused()) focused = n;
        }

        AccessibilityNodeInfo target = focused;
        if (target == null && editable.size() == 1) target = editable.get(0);
        if (target == null) {
            writeLine(out, "ERR\tAMBIGUOUS_EDITABLE\tCOUNT=" + editable.size());
            return;
        }

        Bundle args = new Bundle();
        args.putCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
            text
        );
        boolean ok = target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args);
        writeLine(out, ok
            ? "OK\tSET_TEXT\tCHARS=" + text.length()
            : "ERR\tSET_TEXT_FAILED");
    }

    private void openPackage(BufferedWriter out, String pkg) throws IOException {
            android.content.pm.PackageManager pm = getPackageManager();
    
            Intent probe = new Intent(Intent.ACTION_MAIN);
            probe.addCategory(Intent.CATEGORY_LAUNCHER);
            probe.setPackage(pkg);
    
            java.util.List<android.content.pm.ResolveInfo> matches =
                pm.queryIntentActivities(
                    probe,
                    android.content.pm.PackageManager.MATCH_DEFAULT_ONLY
                );
    
            Intent launch = null;
    
            if (matches.size() == 1) {
                android.content.pm.ActivityInfo ai = matches.get(0).activityInfo;
                launch = new Intent(Intent.ACTION_MAIN);
                launch.addCategory(Intent.CATEGORY_LAUNCHER);
                launch.setComponent(
                    new android.content.ComponentName(ai.packageName, ai.name)
                );
            } else if (matches.isEmpty()) {
                launch = pm.getLaunchIntentForPackage(pkg);
            } else {
                writeLine(out, "ERR\tAMBIGUOUS_LAUNCHER\tCOUNT=" + matches.size());
                return;
            }
    
            if (launch == null) {
                writeLine(out, "ERR\tNO_LAUNCH_INTENT");
                return;
            }
    
            launch.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK |
                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            );
    
            try {
                startActivity(launch);
                writeLine(out, "OK\tOPEN_PACKAGE");
            } catch (Throwable t) {
                writeLine(
                    out,
                    "ERR\tOPEN_PACKAGE_EXCEPTION\t" +
                        t.getClass().getSimpleName()
                );
            }
        }

    private List<AccessibilityNodeInfo> exactMatches(AccessibilityNodeInfo root, String needle) {
        List<AccessibilityNodeInfo> out = new ArrayList<>();
        if (root == null) return out;
        for (AccessibilityNodeInfo n : flatten(root)) {
            if (needle.equals(safe(n.getText())) ||
                needle.equals(safe(n.getContentDescription()))) {
                out.add(n);
            }
        }
        return out;
    }

    private List<AccessibilityNodeInfo> flatten(AccessibilityNodeInfo root) {
        List<AccessibilityNodeInfo> out = new ArrayList<>();
        if (root == null) return out;
        ArrayDeque<AccessibilityNodeInfo> q = new ArrayDeque<>();
        q.add(root);
        while (!q.isEmpty()) {
            AccessibilityNodeInfo n = q.removeFirst();
            out.add(n);
            for (int i = 0; i < n.getChildCount(); i++) {
                AccessibilityNodeInfo c = n.getChild(i);
                if (c != null) q.addLast(c);
            }
        }
        return out;
    }

    private static String safe(CharSequence s) {
        return s == null ? "" : s.toString();
    }

    private static String safe(String s) {
        return s == null ? "" : s;
    }

    private static String enc(String s) {
        return android.util.Base64.encodeToString(
            s.getBytes(StandardCharsets.UTF_8),
            android.util.Base64.NO_WRAP
        );
    }

    private static String decode(String s) {
        return new String(
            android.util.Base64.decode(s, android.util.Base64.DEFAULT),
            StandardCharsets.UTF_8
        );
    }

    private static void requireArgs(String[] p, int n) {
        if (p.length < n) throw new IllegalArgumentException("missing args");
    }

    private static void writeLine(BufferedWriter out, String line) throws IOException {
        out.write(line);
        out.newLine();
        out.flush();
    }

    private static boolean constantEquals(String a, String b) {
        byte[] x = a.getBytes(StandardCharsets.UTF_8);
        byte[] y = b.getBytes(StandardCharsets.UTF_8);
        if (x.length != y.length) return false;
        int v = 0;
        for (int i = 0; i < x.length; i++) v |= x[i] ^ y[i];
        return v == 0;
    }
}
