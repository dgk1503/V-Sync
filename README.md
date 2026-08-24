<p align="center">
  <img src="assets/images/logo/app_icon_legacy.png" width="96" alt="V-Sync logo" />
</p>

<h1 align="center">V-Sync</h1>
<p align="center"><i>A minimal, lightweight academic companion for VIT-AP students.</i></p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Dart-blue?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/core-Rust-orange?logo=rust" alt="Rust" />
  <img src="https://img.shields.io/badge/platform-Android-black" alt="Platform" />
  <img src="https://img.shields.io/badge/theme-monochrome-black" alt="Monochrome" />
</p>

---

## About

V-Sync is a lightweight, unopinionated way to access VTOP — the essentials, without
everything else it comes bundled with. Marks, attendance, timetable, mess menu, and exam
countdowns, in one focused black-and-white interface.

No custom themes, no clutter, no screens you don't need — just a simplified read on what
VTOP already has, kept fast and out of your way.

## Features

- **Marks & Grades** — a clean per-course breakdown
- **Attendance** — synced automatically, no manual logging
- **Timetable** — Morning / Afternoon layout, Lab vs Theory auto-detected, empty days hidden entirely
- **Mess Menu** — upload the month's sheet once, step through it day by day
- **Countdowns** — track upcoming CATs, FATs, and other key dates
- **Automatic VTOP sync** — handled by an embedded Rust core, isolated from the UI

## Tech Stack

- **Flutter + Dart** — UI and app shell
- **Rust** — VTOP scraping and parsing, bridged in via `flutter_rust_bridge`
- **build_runner** — codegen for data models
