# Automatic OTP from Gmail

VTOP emails a six-digit code (from `noreply.sdc@vitap.ac.in`, subject "VTOP Login ...", valid 3 minutes)
every time it logs in from a network it does not trust. Students' mail is normally a Google Workspace
account (`@vitapstudent.ac.in`). This is how VSync reads that code for them, and why this way.

## What was built (v1.4.1+)

On the phone, no server of ours:

1. Settings > Automatic OTP Fetching opens `OtpAutofetchPage`. The student makes a Google **app password**
   (2-Step Verification on, https://myaccount.google.com/apppasswords) and pastes it with their Gmail address.
2. Saved with `flutter_secure_storage` (Android Keystore) by `GmailOtpStore`; never logged, never sent anywhere
   but Gmail.
3. When VTOP asks for an OTP, `LoginOtpChallenge` starts `_autoRead`: `GmailOtpReader` opens
   `imap.gmail.com:993` (TLS), `EXAMINE`s INBOX (read-only), polls every 3 s for up to 45 s for mail
   `FROM "noreply.sdc@vitap.ac.in"`, takes the newest one received since the request (2 min slack),
   reads the code with `VtopOtpEmail.extractCode` (six digits, or six spaced digits), closes the
   connection, and enters it with the normal `submitOtp`.
4. A refused code (an older mail) is skipped (`ignoreUids`) in favour of a newer one. Resend starts a fresh read.
   Typing a code by hand always still works and wins.

Files: `features/auth/model/otp_email.dart`, `features/auth/services/{gmail_otp_reader,otp_auto_fill}.dart`,
`core/services/gmail_otp_store.dart`, `features/account/view/pages/otp_autofetch_page.dart`,
`features/auth/viewmodel/login_otp_challenge.dart` (the hook), `login_otp_overlay.dart` (status line).
Library: `enough_mail` (pure Dart IMAP). No Kotlin needed.

Mail is fetched with `BODY.PEEK` and the inbox is `EXAMINE`d, so nothing is ever marked read, moved or deleted.

## Options considered

| Option | Verdict |
|---|---|
| **Gmail IMAP + app password, on the phone** (built) | No backend, no restricted permission. Works only if the college's Google Workspace allows app passwords and IMAP (unknown until tried on a real `@vitapstudent.ac.in` account). Stores a Google credential on the phone (revocable). |
| Gmail API with OAuth | `gmail.readonly` is a restricted scope: Google verification plus a yearly security assessment for a public app. vitap-mate avoids it by making each user create their own Google Cloud project (about 10 minutes, tokens expire weekly in Testing mode). Too heavy. |
| Gmail filter forwarding to a tiny service | vitap-mate does this (Cloudflare Worker `vtop-edge` parses mail, keeps a code briefly, the phone fetches it). Needs a domain, an inbound-mail receiver and hosting that WE run, and the student's VTOP codes pass through it. A Kotlin SMTP service is the hard way; an email-routing Worker is the easy way. Keep as the fallback if the college blocks app passwords. |
| Notification listener | Restricted by Play (that is why the old tile said it was unsupported). Not for the Play build. |
| Clipboard / "Process text" assist | Zero permissions and works for any mail app: the student selects the code in Gmail and one tap sends it to VSync. Weaker automation, fully Play-safe. A good second layer. |

## Play Store

Not objectionable by itself: no restricted permission, no background service, no mail leaves the phone. But Google
can still object to how it is presented, so:
- keep the in-app disclosure on the page (what is read, that it is read-only, where the password lives, how to remove it);
- say the same in the privacy policy (email access for OTP only, credentials stored on device, not transmitted to us);
- answer the Data safety form accordingly (nothing collected or shared with us; data is processed on device).
Nothing here can promise approval.

## Open question (answered)

Whether `@vitapstudent.ac.in` accounts can create app passwords and allow IMAP: **yes** for the owner's account (connected and
"Test connection" worked on the phone). Other colleges' or students' admin settings may differ, so the page says what to do if
Google refuses. The mail must arrive in the **Inbox** (a Gmail filter that skips the inbox hides it from the reader).
