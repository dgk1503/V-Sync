# Scraper comparison: vitmate (`vitmate/vitap-mate`) vs ours

Reference checkout is vendored at `vitmate/vitap-mate` (gitignored, not ours).
Its scraper is a **separate crate**, `rust/vtop-core`, with a thin
`flutter_rust_bridge` surface in `rust/src/api/`, plus an optional server
(`rust/vtop-server`) that can run the login remotely.

Ours is one crate, `rust/src/api/vtop/**`, with the same frb surface in
`rust/src/api/vtop_get_client.rs`. Same portal, same CAPTCHA, same OTP
endpoints — the differences below are the parts worth knowing about.

## The OTP flow, side by side

| Concern | ours (now) | vitmate |
| --- | --- | --- |
| Where the pending OTP lives | a `Completer` parked inside `VtopClientService`; the login future simply does not return | an explicit auth stage in Rust: `AuthStage::AwaitingOtp { issued_at_unix_seconds }`, and `login()` **returns** `VtopError::OTPRequired(message, issued_at)` |
| Who owns the countdown | the Dart prompt starts at 180 s of its own | the timestamp comes from VTOP's own send time (`issued_at`), so the window is the server's |
| Detecting "OTP required" | `form#securityOtpForm`, checked **before** VTOP's "Invalid Captcha" text — the captcha branch retries, and each retry is another credentials POST | same idea (`is_security_otp_required_response`) plus the CSRF token from that page is stored before returning |
| Verifying the code | tolerant parse (JSON, plain text or HTML), then **validates the session** by loading `/vtop/content` and adopting it (`adopt_authenticated_page`), rather than trusting the reply | same shape: tolerant `OtpReply`, then `validate_authenticated_session` |
| Resend | both spellings, the second only after a 404, and a non-JSON reply is read for what it says (`interpret_resend_reply`) | tries `/vtop/resendSecurityOtp` *and* `/vtop/resendSecurityOTP` |
| Retrying a request whose session died | reports it (`SessionExpired`) — the caller re-authenticates | reports it; `ensure_authenticated_session` returns `false` |
| Deciding a session died | a bounce to `/vtop/login...` or a bare 404; 429/5xx are server errors | `validate_authenticated_session`: a login URL or a non-2xx |
| Second login after a restart | full login again — another credentials POST, so another OTP email | reuses the persisted cookie jar: `try_restore_existing_session()` validates saved cookies and only falls back to a real login if VTOP rejects them |
| Session across process death | nothing survives; the client, jar and CSRF are all in memory | `SessionState` snapshot (`PersistedVtopSession`) in `SharedPreferences`, keyed per username, with a 30-minute reuse TTL |
| Cookie injection | `session_manager.rs` has `set_cookie_from_external` **commented out** | `add_cookie_str()`, `header_for()`, `set_external_cookie_header()` — first-class |
| Diagnostics | `println!` in a few places | `auth_log` with levels, a stage machine and an auth-flow id |
| Getting the code to the user | the user leaves for Gmail and types it back | optional Gmail OAuth auto-fetch (`email_otp.rs`, `gmail.rs`); in the server mode the *backend* reads the mail and answers VTOP, so the phone never leaves the app |
| Transport | reqwest defaults + the shared browser-ish headers | per-request `Origin`, `Referer` (`/vtop/login/error`), `Sec-Fetch-*` on the OTP calls, and a `send_with()` wrapper that logs every request |

## What that means for our bugs

1. **"OTP is sent twice."** VTOP mails a fresh code for *every* credentials
   POST it sees from an IP it has not verified. Any second login — a racing
   caller, a retry classifier that fires on the wrong error, a re-login after
   the session was torn down — is another email. vitmate's shape (one explicit
   auth stage, an error the caller handles, a session that can be reused) makes
   that hard to do by accident; ours now matches it in the two places that
   mattered:

   - **Dart** (single-flight login, type-only retry classification; see
     `lib/core/utils/single_flight.dart` and
     `lib/core/services/vtop_service.dart`). The retry path drops the cached
     session without clearing the login claim, so two expiries a moment apart
     share one login instead of starting one each.
   - **Rust** — the important one, because it was invisible to Dart. Every
     feature request that met an expired session called `login()` itself, so a
     page issuing several requests turned one expiry into one credentials POST
     per request, and each of those opened its own server session with its own
     pending code — which is how a correctly typed OTP came back as "Invalid
     OTP". The request helpers (`post_form_with_session_retry` and friends,
     `handle_session_check`) now report the expiry and leave re-authentication
     to the caller, where it is deduplicated and surfaced as the prompt.
     `login()` is reachable from exactly one place again: Dart's login flight.

2. **"The prompt goes away when I read the mail."** This is exactly the case
   vitmate's session snapshot exists for: the app is destroyed while
   backgrounded, and on restart its restored cookies mean the *same* login
   continues rather than a new one being started. Our snapshot is the missing
   piece; see `docs/handover-otp-prompt-vanishing.md`.

3. **"The OTP is sent as soon as I ask for it, and the request looked like it
   failed."** Two more things made VTOP mail a code and then appear to refuse:
   a 429/5xx from the portal was classified as an expired session (the answer
   to which is another credentials POST), and `resendSecurityOtp` required a
   JSON reply, so an HTML or plain-text answer was reported as a failure even
   though an email had gone out — and the user, told it failed, tapped Resend
   again. Both fixed in Rust (`session_manager.rs`,
   `client/auth.rs::interpret_resend_reply`).

4. **"The keyboard does not come back."** Nothing to do with the scraper — it
   is the same Android behaviour vitmate hit: the IME connection is dropped
   while the app is away, and a field that still holds focus will not re-open
   on its own. Both apps now ask for the keyboard again on resume; ours does it
   in `login_otp_overlay.dart`.

## What we deliberately did not copy

- **Gmail OAuth auto-fetch.** It needs a Google OAuth client, a consent screen
  and mailbox-read consent, and their version can also hand the password to a
  server. Ours keeps the password on the phone; reading the code from the mail
  app is the privacy-preserving default.
- **The Rust rewrite.** Their crate was restructured by hand (inputs/ and
  parsers split out, a stage machine, a rate limiter in the server). Our
  scraper has its own tested structure and the same behaviour on the wire;
  rewriting it would not fix anything on its own.
- **The remote login path.** Our app is offline-first for credentials by
  design.
