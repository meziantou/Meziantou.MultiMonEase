# Meziantou.MultiMonEase

MultiMonEase is a macOS menu bar utility that smooths cursor transitions between adjacent displays with mismatched resolutions and physical DPI.

## Requirements

- macOS 13+
- Swift 6.3 toolchain (builds in Swift language mode 5)

## Local development

```sh
swift build
swift test
swift run MultiMonEase
```

When first launched, grant Accessibility permissions in **System Settings → Privacy & Security → Accessibility**.

## Architecture

- **Input:** `EventTapController` captures mouse move/drag events.
- **Routing:** `CursorRouter` determines seam crossings and applies anti-oscillation cooldown.
- **Topology:** `ScreenTopology` tracks displays and edge overlaps live.
- **Easing:** `EasingEngine` remaps crossings using configurable smoothing and optional physical-velocity preservation.
- **UI:** `StatusBarController` + `PreferencesWindowController`.

## CI and release

- `.github/workflows/ci-build.yml` builds and tests on every PR.
- `.github/workflows/build-release.yml` builds a macOS `.app`, signs/notarizes when secrets are configured, then creates a GitHub release artifact for tagged versions (`v*`).
