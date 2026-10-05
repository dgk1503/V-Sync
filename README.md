<div align="center">
  <img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" alt="V-Sync" width="110">
  <h3>V-Sync</h3>
  <p>A VTOP companion for VITAP students.</p>
</div>

---

## What it does

VTOP is a portal built for desktop browsers. V-Sync puts the parts students
actually check every day on their phone, in an app that opens instantly and
works from a cache.

- **Four tabs** — For You, Timetable, Academics, Account
- **Offline-first** — the calendar and attendance history are cached, so they
  paint immediately and only reach for VTOP when the answer may have changed
- **No web view** for anything VTOP exposes as data

## Features

### Attendance

Percentage per course, with the arithmetic that actually matters: how many
classes you can skip, or how many you must attend to stay above 75%.

Each course opens to a day-wise calendar — attended days ringed green, missed
ones red — with a month slider, and a count of how many classes are left before
the next FAT, computed from the academic calendar and your timetable.

### Academic calendar

VTOP's semester calendar as a month grid: closures, exams, no-instructional
days and your own countdowns, each colour-coded. Opens on the current month,
caches for five days, and merges your countdowns in.

### Timetable

Your weekly classes, per day, with today's highlighted.

### Academics

Marks, grades, exam schedule, faculty info, outing submissions and history,
digital assignment uploads, and a web view for anything else.

### Account

Profile, credential management, appearance (five accent themes, dark mode, font
scale), and toggles for which cards appear on each tab.

### Verification

When VTOP demands an OTP, the prompt floats above the app rather than blocking
it: collapse it to a capsule, carry on using the app, tap it back open. Your
login can wait for the code instead of the app waiting for you.

## Built with

Flutter, with a Rust scraper ([`lib_vtop`](rust/)) bridged in through
`flutter_rust_bridge` and cargokit. The scraper owns one authenticated VTOP
session and exposes typed structs; the app never parses HTML.

- Offline cache — ObjectBox
- State — Riverpod
- Design — Material 3, Instrument Sans

## Building

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after changing any @Entity or @freezed model
flutter run
```

Release APKs and Play bundles need all three Rust ABIs, so a cold build is
slow. `build/lib_vtop/build` is that cache — do not delete it. `rust/target/`
is debug-only and is safe to.

```bash
flutter build apk --release
flutter build appbundle --release
```

## Demo mode

A bundled dataset serves the whole app without touching VTOP, for review and
screenshots:

```
username: 25VSYNC
password: dgklynx
```

## Tests

```bash
flutter analyze lib test
flutter test
cargo test --manifest-path rust/Cargo.toml --lib --tests
```

The Rust parser tests run against real captured VTOP HTML in
`rust/tests/fixtures/`, including its malformed markup — an `<h4>` nested
inside the calendar `<table>`, unclosed rows — which is the part that breaks
hand-tuned parsers.

`cargo test` without `--lib --tests` also runs doctests that call live VTOP and
will fail offline.
