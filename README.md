# MultiMonEase

MultiMonEase is a macOS menu bar utility that prevents the cursor from getting blocked at monitor borders when adjacent screens have different sizes, resolutions, or DPI, making cross-screen movement feel continuous.

# Features

- Prevents “stuck at the edge” behavior on mismatched display borders
- Seam-aware cursor remapping to the nearest valid overlap when borders don’t align perfectly
- Smooth cross-screen transition instead of abrupt jumps
- Edge resistance to require extra push distance before crossing (default: 12 px)
- Optional physical-velocity preservation for natural pointer motion across mixed-DPI screens
- Per-edge enable/disable controls for specific monitor transitions
- Live topology updates when displays are connected, disconnected, or rearranged
- Automatic GitHub release checks with a manual **Check for updates…** menu action

## How to use

1. Download the app from the [latest release](https://github.com/meziantou/Meziantou.MultiMonEase/releases/latest).
1. Move the application to your Applications folder.
1. `xattr -dr com.apple.quarantine /Applications/MultiMonEase.app` to remove the quarantine attribute.
1. Open the app from the Applications folder.
1. The app appears in your macOS menu bar.
1. On first run, grant Accessibility permission when prompted.
1. Move the pointer between monitors to feel smoother transitions.
1. Open **Preferences** from the menu bar icon to adjust behavior.

## Troubleshooting: permission shows as required even when enabled

If the menu still shows **Permissions: Required** while Accessibility already lists MultiMonEase:

1. Remove existing **MultiMonEase** entries from **System Settings** > **Privacy & Security** > **Accessibility**.
1. Make sure you run a single app instance from a stable path (recommended: `/Applications/MultiMonEase.app`).
1. Open MultiMonEase again and grant Accessibility access.

macOS binds Accessibility trust to the running app identity (code signature + executable location).  
If the app binary changes identity (for example after replacing an ad-hoc-signed build or running from another path), the previous entry can become stale.
