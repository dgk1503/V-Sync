use super::super::types::*;
use scraper::{ElementRef, Html, Selector};
use std::sync::LazyLock;

static COURSE_ROWS: LazyLock<Selector> =
    LazyLock::new(|| Selector::parse("tr.tableContent").expect("valid selector"));
static CELLS: LazyLock<Selector> =
    LazyLock::new(|| Selector::parse("td").expect("valid selector"));
static DETAIL_ROWS: LazyLock<Selector> =
    LazyLock::new(|| Selector::parse("tr.tableContent-level1").expect("valid selector"));

/// The text of a cell with VTOP's tabs and line breaks removed, or an empty
/// string when the cell is not there.
fn cell_text(cell: Option<&ElementRef>) -> String {
    cell.map(|e| e.text().collect::<Vec<_>>().join(""))
        .unwrap_or_default()
        .trim()
        .replace(['\t', '\n'], "")
}

/// Parses the marks page.
///
/// The page is a table whose rows come in two kinds: a **course row** (serial
/// number, code, title, type, faculty, slot) and, after it, a **details row**
/// that holds a nested table of that course's individual marks. The two used to
/// be told apart purely by position (course, details, course, details...), so a
/// course with no details row shifted every row after it onto the wrong kind,
/// and a short row panicked on an out-of-range index. A row is now classified by
/// what it contains, and a missing cell reads as empty rather than aborting.
pub fn parse_marks(html: String) -> Vec<Marks> {
    let document = Html::parse_document(&html);
    let mut courses: Vec<Marks> = Vec::new();
    let mut current: Option<Marks> = None;

    for row in document.select(&COURSE_ROWS) {
        let detail_rows: Vec<_> = row.select(&DETAIL_ROWS).collect();

        if !detail_rows.is_empty() {
            // A details row belongs to the course row before it. One with no
            // course to belong to is not data.
            let Some(course) = current.as_mut() else {
                continue;
            };
            course.details = detail_rows
                .iter()
                .map(|detail| {
                    let cells: Vec<_> = detail.select(&CELLS).collect();
                    MarksRecordEach {
                        serial_number: cell_text(cells.first()),
                        mark_title: cell_text(cells.get(1)),
                        max_mark: cell_text(cells.get(2)),
                        weightage: cell_text(cells.get(3)),
                        status: cell_text(cells.get(4)),
                        scored_mark: cell_text(cells.get(5)),
                        weightage_mark: cell_text(cells.get(6)),
                        remark: cell_text(cells.get(7)),
                    }
                })
                .collect();
            continue;
        }

        let cells: Vec<_> = row.select(&CELLS).collect();
        // A course row has the code, title, type, faculty and slot columns; a
        // row narrower than that is a notice or a spacer, not a course.
        if cells.len() < 8 {
            continue;
        }

        if let Some(done) = current.take() {
            courses.push(done);
        }
        current = Some(Marks {
            serial_number: cell_text(cells.first()),
            course_code: cell_text(cells.get(2)),
            course_title: cell_text(cells.get(3)),
            course_type: cell_text(cells.get(4)),
            faculty: cell_text(cells.get(6)),
            slot: cell_text(cells.get(7)),
            details: vec![],
        });
    }

    if let Some(done) = current {
        courses.push(done);
    }
    courses
}
