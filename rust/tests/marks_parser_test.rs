use lib_vtop::api::vtop::parser::marks_parser::parse_marks;

/// One course row in the shape VTOP serves: serial, class number, code, title,
/// type, (unused), faculty, slot.
fn course_row(serial: &str, code: &str, title: &str) -> String {
    format!(
        r#"<tr class="tableContent">
             <td>{serial}</td><td>AP2025</td><td>{code}</td><td>{title}</td>
             <td>Theory</td><td>x</td><td>Dr Someone</td><td>A1+TA1</td>
           </tr>"#
    )
}

/// The details row that follows a course row: a nested table of its marks.
fn details_row(scores: &[(&str, &str)]) -> String {
    let rows: String = scores
        .iter()
        .enumerate()
        .map(|(i, (title, scored))| {
            format!(
                r#"<tr class="tableContent-level1">
                     <td>{}</td><td>{title}</td><td>50</td><td>20</td>
                     <td>Present</td><td>{scored}</td><td>8</td><td></td>
                   </tr>"#,
                i + 1
            )
        })
        .collect();
    format!(
        r#"<tr class="tableContent"><td colspan="8"><table>{rows}</table></td></tr>"#
    )
}

fn page(rows: &str) -> String {
    format!("<html><body><table>{rows}</table></body></html>")
}

#[test]
fn a_course_and_its_marks_are_read() {
    let html = page(&format!(
        "{}{}",
        course_row("1", "MAT1007", "Discrete Mathematics"),
        details_row(&[("CAT-1", "42"), ("Quiz", "9")])
    ));

    let marks = parse_marks(html);

    assert_eq!(marks.len(), 1);
    assert_eq!(marks[0].course_code, "MAT1007");
    assert_eq!(marks[0].course_title, "Discrete Mathematics");
    assert_eq!(marks[0].faculty, "Dr Someone");
    assert_eq!(marks[0].details.len(), 2);
    assert_eq!(marks[0].details[0].mark_title, "CAT-1");
    assert_eq!(marks[0].details[0].scored_mark, "42");
}

/// The old parser alternated "course, details, course, details" by position, so
/// one course with no marks yet turned the next course row into a details row
/// and every course after it came out wrong or missing.
#[test]
fn a_course_with_no_marks_does_not_shift_the_ones_after_it() {
    let html = page(&format!(
        "{}{}{}{}{}",
        course_row("1", "MAT1007", "Discrete Mathematics"),
        details_row(&[("CAT-1", "42")]),
        course_row("2", "MGT1040", "Entrepreneurship"),
        // no details row for MGT1040 yet
        course_row("3", "SWE2001", "Data Structures"),
        details_row(&[("Lab", "30")])
    ));

    let marks = parse_marks(html);

    let codes: Vec<_> = marks.iter().map(|m| m.course_code.as_str()).collect();
    assert_eq!(codes, ["MAT1007", "MGT1040", "SWE2001"]);
    assert_eq!(marks[0].details.len(), 1);
    assert!(marks[1].details.is_empty(), "MGT1040 has no marks yet");
    assert_eq!(marks[2].details[0].scored_mark, "30");
}

/// A row narrower than a course row used to index past the end and panic,
/// which reached the app as an unexplained "unexpected error".
#[test]
fn a_short_row_is_skipped_instead_of_panicking() {
    let html = page(&format!(
        r#"<tr class="tableContent"><td>No records found</td></tr>{}{}"#,
        course_row("1", "MAT1007", "Discrete Mathematics"),
        details_row(&[("CAT-1", "42")])
    ));

    let marks = parse_marks(html);

    assert_eq!(marks.len(), 1);
    assert_eq!(marks[0].course_code, "MAT1007");
}

#[test]
fn a_details_row_with_no_course_before_it_is_ignored() {
    let html = page(&details_row(&[("CAT-1", "42")]));
    assert!(parse_marks(html).is_empty());
}

#[test]
fn a_page_with_no_table_is_empty_rather_than_a_crash() {
    assert!(parse_marks("<html><body>Session timed out</body></html>".to_string()).is_empty());
    assert!(parse_marks(String::new()).is_empty());
}

#[test]
fn a_details_row_with_too_few_cells_reads_the_rest_as_empty() {
    let html = page(&format!(
        "{}{}",
        course_row("1", "MAT1007", "Discrete Mathematics"),
        r#"<tr class="tableContent"><td><table>
             <tr class="tableContent-level1"><td>1</td><td>CAT-1</td></tr>
           </table></td></tr>"#
    ));

    let marks = parse_marks(html);

    assert_eq!(marks[0].details.len(), 1);
    assert_eq!(marks[0].details[0].mark_title, "CAT-1");
    assert_eq!(marks[0].details[0].scored_mark, "");
}
