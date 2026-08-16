# CARSON LTE Accessibility RC

This candidate captures the first accepted LTE-only, no-ADB, no-Wi-Fi-required CARSON↔Claude end-to-end control plane.

The `runtime/` files are exact snapshots of the accepted CARSON runtime. Any token-bearing Android text is committed with `__CARSON_UI_DEVICE_TOKEN__`. The Termux UI client is installed exactly as committed unless it itself contains that placeholder, in which case the clone bootstrap renders it automatically. `android/` is the accepted BUILD=5 companion source/build definition with generated output, machine-local SDK paths, and signing material excluded.

`bootstrap-from-clone.sh` installs the exact committed CARSON runtime and UI client, rendering a device token only when the committed client actually contains the placeholder, reloads the listener, verifies hashes, and requires the BUILD=5 accessibility service.

`acceptance/clone-fresh-e2e.sh` is the source-controlled fresh-clone acceptance run. It uses a new acceptance marker, performs the full fresh task loop, and must finish with `SINGLE_SCRIPT_FRESH_END_TO_END=PASS` and `STATUS=COMPLETE`.

The frozen `v0.1.0` tag is not modified. This RC is intentionally published on a separate branch before release promotion.
