# Project Notes

## Overview
V-Sync — a minimal, monochrome-first academic companion app for VIT-AP students.
Flutter UI over an embedded Rust VTOP scraper, bridged with `flutter_rust_bridge`.
Android-first; published on the Play Store (closed testing). Version lives in `pubspec.yaml`.

## Scope rules
- UI/layout changes must NOT touch the embedded Rust scraper (`rust/`, `rust_builder/`, `lib/src/rust/`) or its generated Dart bindings unless explicitly requested or absolutely necessary. Treat the scraper as a stable backend. Note: `flutter analyze` on the whole workspace reports pre-existing errors inside `rust_builder/cargokit/build_tool` (unfetched deps of a vendored tool) and warnings in generated `frb_generated.dart` — ignore them; analyze `lib` and `test` only.

## Architecture quick map
- Entry: `lib/main.dart` (global OTP / auth-failure bottom sheets, theme, font scaling) + `lib/init_dependencies.dart` (get_it, ObjectBox, RustLib, dotenv, timezone, portrait lock).
- Navigation: no router package. 4-tab shell in `lib/core/common/widget/bottom_navigation_bar.dart` — Home ("For You"), Timetable, Academics hub, Account. Riverpod `bottomNavIndexProvider` + fade `AnimatedSwitcher`.
- Backend seam: `lib/core/services/vtop_service.dart` — singleton `VtopClientService` wraps the Rust client: 15-min session expiry (proactive refresh at 14 min), `executeWithRetry`, and a Completer-based OTP flow that pauses any in-flight call while the global OTP sheet resolves it. All repositories go through `executeWithRetry` and map `VtopError` to `Failure` (fpdart `Either`).
- State: Riverpod codegen (`@riverpod` viewmodels returning `AsyncValue?` with explicit `fetchX()`/`refreshX()` methods) + a few manual `Notifier`s. get_it for singletons.
- Persistence: ObjectBox holds the scraped `User` graph (profile, attendance, timetable, exams, marks, grade history) + `SemesterCache`, `UserPreferences`, outing reports. `flutter_secure_storage` holds only credentials (`stu_credentials`). SharedPreferences holds flags, color theme, milestones, mess-menu cache. Home-screen widget data via `home_widget` (key `timetable`, native `UpcomingClassWidget.kt`).
- Demo mode: login with `21BCE7625` / `Demo@1234` bypasses VTOP entirely; viewmodels short-circuit to bundled `assets/demo/demo_dataset.json`. Write actions (outing submit, assignment upload, Open VTOP) are hidden or show a friendly message in demo mode.

## Theme
- Design language: monochrome base + curated accent themes in `lib/core/theme/app_theme.dart` (`AppColorTheme`: mono, gold, emerald, pink, red). Dark mode offers mono/gold/emerald/red; light mode mono/pink/gold/red (gold/emerald/red-dark swap in whole surface palettes with specular card edges). Do NOT reintroduce arbitrary seed colors; if adding a theme, follow the existing pattern (ColorScheme overrides + `AppCard` specular edge palette + optional heading color).
- Fonts: **Outfit** is the primary font (headings/titles/body, weights 300–700). **Inter** is for small details (captions, timestamps, metadata, labels — e.g. the "Last synced" line is Inter 13 `onSurfaceVariant`). Use text theme roles; avoid hardcoding other fonts.
- Colors: semantic status colors (green/orange/red) are reserved for status meaning (attendance %, Present/Absent, outing Approved/Pending/Rejected, assignment Submitted/Pending/Missed). Everything else uses `colorScheme` — no hardcoded blues/purples etc.
- Icons: **Iconsax** (`iconsax_flutter` package) everywhere; do not use Material `Icons.*` in new code.
- Buttons: primary form actions use `FilledButton` (theme = black/white); secondary/quiet actions use `TextButton` with no explicit color. Standard states: `EmptyContentView` / `ErrorContentView` / `Loader` in `lib/core/common/widget/`.
- Signature widgets: `AppCard` (hairline card; gold/emerald/red themes render a specular gradient edge), `AccentGradientText` section headers, gradient hairline dividers, floating blurred capsule nav bar, blurred-background popup sheets.

## Academics hub (third tab)
`lib/features/attendance/view/pages/academics_hub_page.dart` lists Attendance, Marks and Exam Schedule (always visible), then Grades, Digital Assignment Upload, Outing, Faculty Info and Open VTOP — the latter five can each be hidden from **Account > Customization** (`customization_page.dart`, wrench tile below Appearance; stored as `hide*` flags in `UserPreferences`, default false = visible). "Open VTOP" is the auto-authenticated VTOP webview (`features/vtop_webview`) that transfers the Rust session's cookies + CSRF and POST-navigates into the portal; it hard-fails with a friendly message in demo mode.

## Liquid Glass navbar (opt-in, default OFF)
`shaders/liquid_glass.frag` runs in the navbar's `BackdropFilter` via `ImageFilter.shader` (Impeller-only; `ImageFilter.isShaderFilterSupported` gates it, frosted blur is the fallback; toggle in Customization, default off). **Engine contract** (verified in `impeller/entity/contents/filters/runtime_effect_filter_contents.cc`): the engine OVERWRITES uniform indices 0-1 with the backdrop texture's pixel size and draws the shader quad at texture size, so `FlutterFragCoord()` is in SCREEN physical pixels — the shader locates the capsule via `uCapsuleOrigin`/`uCapsuleSize` uniforms (physical px, measured via `localToGlobal * dpr` in `bottom_navigation_bar.dart`). **Y-flip is a BACKEND property, not a platform one**: Impeller/Vulkan needs no flip, Impeller/OpenGLES reverses the y-axis (gl_FragCoord bottom-up) and needs `uv.y = 1.0 - uv.y`. Devices silently differ (this project's test phone falls back to GLES — see logcat `android_context_gl_impeller.cc` — while most modern phones run Vulkan), so the flip MUST live in the shader as `#ifdef IMPELLER_TARGET_OPENGLES` (the .frag ships as raw GLSL and is compiled on-device per backend — verified in the APK assets). Hard-coding the flip per platform shipped broken on Play (Vulkan devices showed top-of-screen content mirrored in the glass); hard-coding no-flip breaks GLES devices the same way. Iconsax has no wrench glyph (`setting_4` is sliders — verified from the font), so the Customization tile uses Material `Icons.build_rounded`.

## Timetable design decisions
- Only Morning and Afternoon sections (no Evening; classes at/after 12:00 go under Afternoon).
- Lab vs Theory: labs run ~2 hours (e.g. 8:00–9:50), theory runs 50 min (e.g. 2:00–2:50). Detect by `courseType` containing "lab", falling back through venue, slot prefix `^L\d`, then session duration >= 90 minutes (`lib/core/utils/get_classes.dart`).
- Days with no classes are hidden from the day strip entirely.
- Class rows show minimal info only (name, LAB/THEORY pill, time, room in Inter). Full details appear in a centered popup box with a blurred background when a class is tapped; tap anywhere outside to dismiss.

## Versioning / release
- `pubspec.yaml` `version:` is the single source of truth: `versionName+versionCode` (e.g. `1.1.0+2014`). Android/Play reject installs and uploads whose versionCode is not higher than everything before it (the closed track already has 2002+, and local test installs ran 2003–2013 via `--build-number` overrides), so each release must bump the code above the last — do not reset it to a small number. Version names like 1.0.6 are tagged in git commits.
