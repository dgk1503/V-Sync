# Handover: the login OTP prompt when the user leaves for Gmail

Reported: "when the user is prompted, the OTP screen just goes away in the
meantime when the user goes to Gmail and reads the OTP, but when the OTP screen
is minimized it stays."

## What was measured

A widget test probe (`LoginOtpOverlay` mounted exactly as `MaterialApp.builder`
mounts it, an active challenge, a 360×640 screen) was driven through the real
Android lifecycle ordering — `resumed → inactive → hidden → paused` and back
`hidden → inactive → resumed` — and reported the card's rect and any exception
at each step:

```
[fresh]      card_rect=Rect.fromLTRB(20.0, 114.3, 340.0, 525.8) title=1 exception=null
[inactive]   card_rect=Rect.fromLTRB(20.0, 114.3, 340.0, 525.8) title=1 exception=null
[hidden]     card_rect=Rect.fromLTRB(20.0, 114.3, 340.0, 525.8) title=1 exception=null
[paused]     card_rect=Rect.fromLTRB(20.0, 114.3, 340.0, 525.8) title=1 exception=null
[resumed]    card_rect=Rect.fromLTRB(20.0, 114.3, 340.0, 525.8) title=1 exception=null
[inset320]   card_rect=Rect.fromLTRB(20.0,  60.9, 340.0, 472.4) title=1 exception=null
[focus] hasFocus=true
```

Conclusions:

- **Nothing in the app hides the prompt.** The challenge lives in a keep-alive
  provider and the prompt is mounted above the Navigator, so a background/
  resume cycle leaves it exactly where it was: same rect, still on screen, no
  exception. A tall IME inset (320dp) does not push the card off-screen either.
- **The field keeps `hasFocus` while the IME is gone.** That is the keyboard
  bug: Android drops the input connection when the app is backgrounded, and a
  node that is *already focused* is not re-opened by asking for focus again.
- **The only remaining way the prompt can vanish is the process (or the
  activity) being destroyed while the user is in Gmail.** Everything a pending
  login needs — the Rust `VtopClient`, its cookie jar, its CSRF token and the
  Dart `Completer` — exists only in memory. When Android reclaims the app, the
  user comes back to a cold start with no prompt, and signing in again is
  another credentials POST, i.e. another OTP email. The collapse above makes
  the in-app state predictable; it cannot help once the process is gone, which
  is what the snapshot below is for.

## Fixed here

- **The prompt collapses to the capsule when the app goes to the background.**
  That is the state that works across a trip to Gmail: no keyboard to lose, the
  countdown still visible, and one tap back to the card and the keyboard. It
  also means there is no longer a "returning to a card that lost its keyboard"
  state to confuse with a prompt that disappeared. The digits already typed
  survive the collapse: the `TextEditingController` lives above the
  card/capsule switch (in `_PromptState`) rather than in the card.
- `inactive` deliberately does **not** collapse it: Android reports that for the
  notification shade, a permission dialog and the app switcher.
- `login_otp_overlay.dart` is a `WidgetsBindingObserver`: on
  `AppLifecycleState.resumed` it re-asks for the keyboard
  (`_requestOtpKeyboard`), which is the piece Flutter cannot infer. That covers
  the interruptions that leave the card up. Tapping the boxes goes through the
  same helper, so a field that still holds focus is asked for the keyboard
  explicitly instead of leaving it to `EditableText`.
- The single-flight login in `lib/core/services/vtop_service.dart` makes sure a
  second login is never started for an account that is already mid-OTP, so the
  user's return trip cannot itself trigger a duplicate email.

Regression tests in `test/features/auth/login_otp_overlay_test.dart`, all of
which fail against the pre-change widget: "tapping the boxes re-asks for the
keyboard", "leaving the app collapses the prompt to the capsule", "tapping the
capsule brings the card and the keyboard back", "the code typed so far survives
the collapse", "a transient interruption keeps the prompt expanded and
focused".

## Not fixed yet: surviving a restart (needs a session snapshot)

The remaining cause cannot be fixed in Dart, because the session it would have
to restore does not exist anywhere outside the process. The reference
implementation of the fix is vendored at `vitmate/vitap-mate`; see
`docs/scraper-comparison-vitmate.md`. Concretely:

1. **Rust** (`rust/src/api/vtop/session_manager.rs`): the cookie plumbing is
   half-built here — `set_cookie_from_external` is present but commented out,
   and there is no way to iterate the jar. Add:
   - `SessionManager::add_cookie_str(&str, &Url)` (reqwest's `Jar` already has
     it) and `header_for(&Url) -> Option<String>` for export;
   - a `SessionState` struct (cookie header, CSRF token, registration number,
     login time) with `export_session(&VtopClient)` / `resume_session(&mut
     VtopClient, SessionState)`.
2. **Regenerate the bindings.** No `flutter_rust_bridge.yaml` is checked in and
   `flutter_rust_bridge_codegen` is not installed on this machine
   (`rust/Cargo.toml` pins 2.12.0 as a dev-dependency). This has to be done
   before the Dart side can call the new functions — the generated files under
   `lib/src/rust/**` must not be hand-edited.
3. **Dart**: when a login parks on OTP, snapshot the session (username-keyed,
   with a TTL) before the app can be killed; on startup, if a snapshot exists
   and a challenge was pending, resume the session and raise the challenge
   again instead of logging in. Vitmate's `vtop_session_store.dart` is the
   shape to copy; `try_restore_existing_session()` in its Rust is the check that
   keeps a stale cookie jar from wasting an OTP email.

Until then the honest statement is: the prompt cannot survive the app being
killed, and the app will not be able to avoid one fresh email per sign-in on a
network VTOP has not verified.
