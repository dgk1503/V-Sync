# Handover: navbar rides up with the keyboard

**Repo:** `C:\Users\dkart\StudioProjects\vitap_student_app`
**Branch:** `main` · **Version:** 1.3.0+9 · **Tests:** 164 Dart, all passing
**Status:** bug is open, diagnosed but NOT fixed. Do not trust any prior claim that it was fixed — it was attempted twice and failed twice. Details below so you don't repeat it.

---

## The symptom

When the OTP prompt appears and the keyboard opens, the floating capsule navbar jumps **up** to roughly the middle of the screen and sits there, overlapping page content. It returns to the bottom when the keyboard closes. Cosmetic — no crash, no data loss — but very visible.

---

## Architecture (this is the key to understanding it)

The navbar is **not** in `Scaffold.bottomNavigationBar`. It is a `Positioned.fill` inside the **body Stack**. This was a deliberate design decision, documented at `lib/core/common/widget/bottom_navigation_bar.dart:70-74`:

```dart
child: Scaffold(
  extendBody: true,
  body: Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(child: AnimatedSwitcher(... page ...)),
      // Keep the navigation surface in the body layer rather than in
      // Scaffold's bottomNavigationBar slot. That makes the capsule
      // genuinely float over the content instead of appearing attached
      // to the bottom layout edge.
      const Positioned.fill(child: _FloatingCapsuleNavBar()),
    ],
  ),
),
```

`extendBody: true` only removes the bottom padding from the body. It does **not** stop `Scaffold` from **resizing** the body when the IME opens. So the body Stack shrinks to `screenHeight - keyboardHeight`, and `Positioned.fill` + `Align(bottomCenter)` pins the capsule to the bottom of that **resized** box — which is the keyboard height above the real screen bottom.

That's the whole bug.

---

## Measured evidence

From a diagnostic run at 400×850 logical, `devicePixelRatio` 3.0, keyboard inset 320 **physical** px (= 106.67 logical):

```
screen            850.0
navbar bottom     743.33   ← exactly 850 − 106.67, i.e. the resized body
navbar top          0.0   ← fills its parent
navbar height     743.33   ← the resized body height
MediaQuery.viewInsetsOf(context).bottom    0.0   ← !!! stripped
MediaQueryData.fromView(tester.view)       106.67 ← the true value
```

The navbar sits at the bottom of the resized body. Confirmed.

---

## What I tried, and why both failed

### Attempt 1 — add `viewInsetsOf(context).bottom` to the navbar's bottom padding

**Failed.** `Scaffold` wraps a resizing body in `MediaQuery.removeViewInsets(removeBottom: true)`. So by the time you are inside the navbar, `MediaQuery.viewInsetsOf(context).bottom` is **already 0**. The expression evaluated to the original value and changed nothing. See the `mqInsets=0.0` line above.

### Attempt 2 — read it from the View instead

```dart
MediaQueryData.fromView(View.of(context)).viewInsets.bottom
```

**Also failed.** In a widget-test context `View.of(context)` did not return the root view — it reported 0 while `tester.view` reported 106.67. *This may be a test-harness artefact rather than a real failure in the running app.* I could not establish which, so treat attempt 2 as unproven rather than definitively wrong. If you can verify on a real device or a faithful test host, it may be the cheapest fix.

**Both attempts were reverted.** The navbars are back to `14 + MediaQuery.paddingOf(context).bottom` (static) and `10 + MediaQuery.paddingOf(context).bottom` (liquid glass), with a comment recording the diagnosis.

---

## Where the fix has to go

**Capture the keyboard inset above the Scaffold and pass it down.** `lib/main.dart:109` — `MaterialApp.builder` — is the last place where the real `MediaQuery` is still intact:

```dart
builder: (context, child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(userPreferences.fontScale ?? 1.0),
    ),
    child: LoginOtpOverlay(
      child: Stack(children: [child!]),
    ),
  );
},
```

Three viable approaches, roughly in order of preference:

**A. Pass the inset down explicitly (recommended).**
Capture `MediaQuery.viewInsetsOf(context).bottom` in `MaterialApp.builder`, put it in a Riverpod provider or an `InheritedWidget`, and have both navbars add it to their bottom offset. Unambiguous, testable, no reliance on which `View` `View.of` resolves to.

**B. `resizeToAvoidBottomInset: false` on the shell Scaffold.**
One line in `bottom_navigation_bar.dart`. The body never shrinks, so the navbar cannot move.
⚠️ **Check the blast radius first.** The OTP card currently lifts itself above the keyboard using its own `MediaQuery.viewInsetsOf(context).bottom` padding in `lib/features/auth/view/widgets/login_otp_overlay.dart`. With the resize disabled, does that value still reach it? The OTP prompt also hosts its own `Overlay` — verify the `TextField` still takes focus and the card still clears the IME. Other text inputs exist (faculty search, outing forms) and must be checked too.

**C. `MediaQuery.removeViewInsets` + explicit inset.** Rebroadcast the inset inside the navbar via a nested `MediaQuery` whose `viewInsets.bottom` is re-set from a captured value. More convoluted than A; only pick this if A is blocked.

**Note on all three:** the *page* content also rides up with the keyboard today. That's normal Flutter behaviour and users expect it. Only the navbar is wrong — it should be pinned to the physical screen bottom while everything else scrolls.

---

## Files involved

| File | Role |
|---|---|
| `lib/core/common/widget/bottom_navigation_bar.dart` | The shell. `Scaffold(extendBody: true)` + body `Stack`. `Positioned.fill(_FloatingCapsuleNavBar())` at ~line 76. **Approach B goes here.** |
| `lib/core/common/widget/static_capsule_nav_bar.dart` | Default navbar. `Align(bottomCenter)` + `Padding` bottom `14 + MediaQuery.paddingOf(context).bottom` at ~line 43. |
| `lib/core/common/widget/liquid_glass_navigation_bar.dart` | Alternative navbar (Liquid Glass setting). Same shape, bottom offset base `10`, ~line 506. |
| `lib/main.dart` | `MaterialApp.builder` at ~line 109. **Approach A captures the inset here.** |
| `lib/features/auth/view/widgets/login_otp_overlay.dart` | The OTP prompt. Uses `MediaQuery.viewInsetsOf(context).bottom` to lift its own card. Check this under approach B. |

Both navbars must be fixed — the user can toggle between them in Settings → Customization → Liquid Glass.

---

## How to verify

**Write the test first, and make sure it fails before you fix anything.** A test that passes against the broken code is worse than no test; I shipped one of those this session and had to throw it out.

The host must reproduce the real nesting. This is what I got wrong twice:

```dart
// WRONG - MediaQuery injected below the Scaffold, so the Scaffold never
// resizes and the whole thing is a no-op.
Scaffold(body: Stack(children: [MediaQuery(data: ..., child: navbar)]))

// RIGHT - drive the inset from the view, which is what the platform does.
tester.view.viewInsets = const FakeViewPadding(bottom: 320);
await tester.pumpWidget(shell());
```

`tester.view.viewInsets` is in **physical** pixels — with `devicePixelRatio: 3.0`, `320` is 106.67 logical. Getting this wrong makes the keyboard far shorter than intended and the test meaningless.

Measure the capsule by a **destination icon's** rect, never the navbar widget's own rect:

```dart
// WRONG - the navbar fills the Stack it's given, so its rect tells you nothing.
tester.getRect(find.byType(StaticCapsuleNavBar))

// RIGHT
tester.getRect(find.byIcon(LucideIcons.house).first).top
```

The shell to replicate is in `bottom_navigation_bar.dart:56-77`. Test at 400×850 logical / dpr 3.0 with keyboard insets of 0, ~320, and ~640 physical px.

Verify on a **real device** too. The OTP path only triggers after a real login, so: log out, sign in again, complete the OTP.

---

## Constraints

- `AGENTS.md` (gitignored, read it): Instrument Sans, **no bold weights** (`w500` max), theme colours not literals, never commit `build/`/`.dart_tool/`/`.env`/keystores.
- Don't change the navbar's visual design. Only its vertical position.
- `build/lib_vtop/build` is a 3.46 GB Rust release cache for all three ABIs — **do not delete**. `rust/target/` is debug-only and is safe.
- Repo is ~4 GB after cleanup; a root `.gitignore` now exists and correctly excludes `vitmate/` (a reference checkout, not ours).

## Commands

```powershell
flutter analyze lib test
flutter test
flutter build apk --release --target-platform android-arm64
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

---

## Related, still open

Not required for this bug, but you'll trip over them:

- The **double-login race** was fixed this session (`vtop_service.dart`, `_ensureInitialized`). Don't reintroduce an unguarded `_initializeClient`.
- `cargo test` exits **101** because ~15 doctests call live VTOP. Real tests: `cargo test --lib --tests` → 76 pass. Not a regression.
- The navbar also ignores keyboard insets for `home_page.dart`'s bottom padding, which is only `safeAreaBottom + 12` — that's a separate, pre-existing cosmetic issue the user accepted.
