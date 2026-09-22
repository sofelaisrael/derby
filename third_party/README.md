# Vendored third-party packages

## add_2_calendar

- **Upstream:** add_2_calendar 3.1.1 (pub.dev), MIT license (see `add_2_calendar/LICENSE`).
- **Why vendored:** fix iOS "Add to calendar" failing on scene-based apps (`UIApplication.shared.keyWindow` is nil) and document the Android `<queries>` requirement.
- **Patch:** single file `add_2_calendar/ios/add_2_calendar/Sources/add_2_calendar/Add2CalendarPlugin.swift` — scene-aware `topViewController()` + removed deprecated `statusBarStyle` lines.
- **Constraint note:** plugin requires Flutter >=3.41.0 / Dart sdk ^3.11.0; repo currently on Flutter 3.44.6.
