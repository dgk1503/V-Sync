<!-- TODO: point this at whichever file ends up as your final app icon -->
<p align="center">
  <img src="assets/images/logo/preview_dark_bg.png" width="96" alt="V-Sync logo" />
</p>

<h1 align="center">V-Sync</h1>
<p align="center"><i>A minimal, lightweight academic companion for VIT-AP students.</i></p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Dart-blue?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/core-Rust-orange?logo=rust" alt="Rust" />
  <img src="https://img.shields.io/badge/platform-Android-black" alt="Platform" />
  <img src="https://img.shields.io/badge/theme-customizable-black" alt="Themes" />
</p>

---

## About

V-Sync is a lightweight, unopinionated way to access VTOP — the essentials, without
everything else it comes bundled with. Marks, attendance, timetable, mess menu, and exam
countdowns, in one focused interface.


## Features

- **Marks & Grades** — a clean per-course breakdown
- **Attendance** — synced automatically, no manual logging
- **Attendance Calculator** — plan your bunks and see how they affect your attendance, helping you stay above the 75% requirement
- **Timetable** — Morning / Afternoon layout, Lab vs Theory auto-detected, empty days hidden entirely
- **Mess Menu** — upload the month's sheet once, step through it day by day
- **Countdowns** — track upcoming CATs, FATs, and other key dates
- **Themes** — choose the look that suits you
- **Automatic VTOP sync** — handled by an embedded Rust core, isolated from the UI

## Tech Stack

- **Flutter + Dart** — UI and app shell
- **Rust** — VTOP scraping and parsing, bridged in via `flutter_rust_bridge`
- **build_runner** — codegen for data models
