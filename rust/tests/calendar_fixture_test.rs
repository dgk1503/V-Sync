//! Parser tests against genuine VTOP HTML.
//!
//! `fixtures/calendar_months.html` and `fixtures/calendar_month.html` are real
//! responses from `getDateForSemesterPreview` and `processViewCalendar`, copied
//! verbatim. They are deliberately not tidied: VTOP nests an `<h4>` inside the
//! `<table>`, omits `<tbody>`, and leaves rows and cells unclosed. That slop is
//! the whole reason these tests exist — a parser tuned against well-formed
//! hand-written markup will pass the other tests in this crate and still return
//! nothing for the real response.

use lib_vtop::api::vtop::parser::calendar_parser::{
    parse_calendar_month, parse_calendar_months, parse_class_groups,
};

fn months_page() -> String {
    std::fs::read_to_string("tests/fixtures/calendar_months.html")
        .expect("calendar_months.html fixture")
}

fn month_grid() -> String {
    std::fs::read_to_string("tests/fixtures/calendar_month.html")
        .expect("calendar_month.html fixture")
}

/// The expected entries vitmate's parser produced from the same HTML, used here
/// as an independent check rather than a self-fulfilling expectation.
fn expected_entries() -> Vec<serde_json::Value> {
    serde_json::from_str(
        &std::fs::read_to_string("tests/fixtures/calendar_month.expected.json")
            .expect("calendar_month.expected.json fixture"),
    )
    .expect("expected entries parse as JSON")
}

#[test]
fn real_page_yields_every_class_group() {
    let groups = parse_class_groups(months_page());

    assert_eq!(
        groups.iter().map(|g| g.id.as_str()).collect::<Vec<_>>(),
        vec!["COMB", "ALL"],
        "COMB is the combined default the app requests"
    );
    assert!(groups[0].name.contains("All Class Group"));
}

#[test]
fn real_page_yields_all_six_month_buttons() {
    let months = parse_calendar_months(months_page());

    let dates: Vec<&str> = months.iter().map(|m| m.cal_date.as_str()).collect();
    assert_eq!(
        dates,
        vec![
            "01-JUL-2026",
            "01-AUG-2026",
            "01-SEP-2026",
            "01-OCT-2026",
            "01-NOV-2026",
            "01-DEC-2026",
        ],
        "a Jul-Dec semester is six months, in the order VTOP lists them"
    );

    // The button text and the calDate processViewCalendar wants differ.
    assert_eq!(months[0].label, "JUL-2026");
}

#[test]
fn real_month_grid_yields_every_day() {
    let days = parse_calendar_month(month_grid(), "01-OCT-2026".to_string());

    assert_eq!(
        days.len(),
        31,
        "October has 31 days and every one carries a day number"
    );
    assert_eq!(days[0].date, "2026-10-01");
    assert_eq!(days[0].weekday, "Thursday");
    assert_eq!(days[30].date, "2026-10-31");
}

#[test]
fn real_month_grid_matches_an_independent_parse_of_the_same_html() {
    let days = parse_calendar_month(month_grid(), "01-OCT-2026".to_string());

    // Rebuild vitmate's flat (date, kind, group, note) shape from ours so the
    // two parsers can be compared entry for entry. Ours keeps the whole
    // "Kind - Group" string in `description` and the bracketed note in
    // `label`, so `rsplit_once(" - ")` recovers the same split.
    let actual: Vec<serde_json::Value> = days
        .iter()
        .flat_map(|day| {
            day.events.iter().map(move |event| {
                let (kind, group) = match event.description.rsplit_once(" - ") {
                    Some((kind, group)) => (kind.trim(), group.trim()),
                    None => (event.description.trim(), ""),
                };
                serde_json::json!({
                    "date": day.date,
                    "kind": kind,
                    "group": group,
                    "note": event.label,
                })
            })
        })
        .collect();

    let expected = expected_entries();
    assert_eq!(
        actual.len(),
        expected.len(),
        "entry count differs from the reference parse"
    );

    for (index, (got, want)) in actual.iter().zip(expected.iter()).enumerate() {
        assert_eq!(got["date"], want["date"], "date at entry {index}");
        assert_eq!(got["kind"], want["kind"], "kind at entry {index}");
        assert_eq!(got["group"], want["group"], "group at entry {index}");
        assert_eq!(got["note"], want["note"], "note at entry {index}");
    }
}

#[test]
fn real_month_grid_recognises_the_kinds_the_app_classifies() {
    let days = parse_calendar_month(month_grid(), "01-OCT-2026".to_string());
    let notes: Vec<&str> = days
        .iter()
        .flat_map(|d| d.events.iter().map(|e| e.label.as_str()))
        .collect();

    // The exact tokens the Dart classifier matches on. "WorkingDay" is one word
    // with no space, which is the easiest one to get wrong.
    assert!(
        notes.contains(&"WorkingDay"),
        "an ordinary teaching day must be labelled WorkingDay, got {notes:?}"
    );
    assert!(
        notes.contains(&"No Instructional Day"),
        "got {notes:?}"
    );
    assert!(
        notes.iter().any(|n| n.contains("Jayanti") || n.contains("Dasami")),
        "a named holiday note must survive, got {notes:?}"
    );
}

#[test]
fn a_cat_day_keeps_its_internal_hyphen() {
    let days = parse_calendar_month(month_grid(), "01-OCT-2026".to_string());

    let cat = days
        .iter()
        .flat_map(|d| d.events.iter())
        .find(|e| e.description.starts_with("CAT"))
        .expect("October has CAT days");

    assert!(
        cat.description.starts_with("CAT - "),
        "CAT keeps its own \" - \" so the group split cannot swallow it: {}",
        cat.description
    );
}
