package io.carson.uibridge;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

public final class MainActivity extends Activity {
    private TextView status;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (24 * getResources().getDisplayMetrics().density);
        layout.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("CARSON UI Bridge");
        title.setTextSize(24f);
        layout.addView(title);

        TextView body = new TextView(this);
        body.setText(
            "\nLocal accessibility control plane for CARSON.\n\n" +
            "UI control stays on this Android device. Wi-Fi, Wireless debugging, " +
            "and ADB are not required once this accessibility service is enabled.\n\n" +
            "The Termux client connects only to 127.0.0.1."
        );
        body.setTextSize(16f);
        layout.addView(body);

        status = new TextView(this);
        status.setTextSize(16f);
        layout.addView(status);

        Button open = new Button(this);
        open.setText("Open Accessibility Settings");
        open.setOnClickListener(v -> {
            Intent i = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            startActivity(i);
        });
        layout.addView(open);

        Button refresh = new Button(this);
        refresh.setText("Refresh status");
        refresh.setOnClickListener(v -> refreshStatus());
        layout.addView(refresh);

        setContentView(layout);
        refreshStatus();
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshStatus();
    }

    private void refreshStatus() {
        String enabled = Settings.Secure.getString(
            getContentResolver(),
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        );
        String expected = getPackageName() + "/" +
            CarsonAccessibilityService.class.getName();
        boolean on = enabled != null &&
            containsComponent(enabled, expected);
        status.setText("\nAccessibility service: " + (on ? "ENABLED" : "DISABLED"));
    }

    private boolean containsComponent(String enabled, String expected) {
        if (enabled == null) return false;
        for (String entry : enabled.split(":")) {
            if (entry.equalsIgnoreCase(expected)) return true;
        }
        return false;
    }
}
