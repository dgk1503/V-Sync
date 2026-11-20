use lib_vtop::api::vtop::parser::timetable_parser::parse_timetable;

/// A trimmed slice of a real Fall 2026-27 VTOP timetable page, kept inline so the
/// test carries no external fixture (and never bloats the shared library).
///
/// It preserves the exact grid layout that exposed the bug:
///   * the course tbody has the CSE4007 Embedded Theory + Embedded Lab rows,
///   * the grid tbody has all four header rows (THEORY Start/End, LAB Start/End)
///     at full width so column indices line up like the real page, plus the FRI
///     THEORY/LAB day pair.
///
/// The theory rows and lab rows carry DIFFERENT timings, so a lab slot that reads
/// its time from the theory row lands on a "-" / wrong value — the exact defect.
fn sample_html() -> String {
    r#"<!DOCTYPE html><html><body><table>
  <tbody>
    <tr><td>2</td><td>General (Semester)</td><td>CSE4007 - Digital Image Processing ( Embedded Theory )</td><td>3 0 0 0 3.0</td><td>-</td><td>Regular</td><td>AP2026272000042</td><td><p>A1+TA1 - </p><p>G17-AB-2</p></td><td>Sucharitha M - SENSE</td></tr>
    <tr><td>3</td><td>General (Semester)</td><td>CSE4007 - Digital Image Processing ( Embedded Lab )</td><td>0 0 2 0 1.0</td><td>-</td><td>Regular</td><td>AP2026272000235</td><td><p>L23+L24 - </p><p>114-AB-2</p></td><td>Sucharitha M - SENSE</td></tr>
  </tbody>
  <tbody>
    <tr><td>THEORY</td><td>Start</td><td>08:00</td><td>09:00</td><td>09:01</td><td>10:00</td><td>10:01</td><td>11:00</td><td>11:01</td><td>12:00</td><td>12:01</td><td>-</td><td>Lunch</td><td>14:00</td><td>14:01</td><td>15:00</td><td>15:01</td><td>16:00</td><td>16:01</td><td>17:00</td><td>17:01</td><td>18:00</td><td>-</td></tr>
    <tr><td>End</td><td>08:50</td><td>09:50</td><td>09:51</td><td>10:50</td><td>10:51</td><td>11:50</td><td>11:51</td><td>12:50</td><td>12:51</td><td>-</td><td>Lunch</td><td>14:50</td><td>14:51</td><td>15:50</td><td>15:51</td><td>16:50</td><td>16:51</td><td>17:50</td><td>17:51</td><td>18:50</td><td>-</td></tr>
    <tr><td>LAB</td><td>Start</td><td>08:00</td><td>08:50</td><td>08:51</td><td>09:50</td><td>09:51</td><td>10:40</td><td>10:41</td><td>11:40</td><td>11:41</td><td>12:30</td><td>Lunch</td><td>14:00</td><td>14:01</td><td>14:50</td><td>14:51</td><td>15:50</td><td>15:51</td><td>16:40</td><td>16:41</td><td>17:40</td><td>18:30</td></tr>
    <tr><td>End</td><td>08:50</td><td>09:40</td><td>09:41</td><td>10:40</td><td>10:41</td><td>11:30</td><td>11:31</td><td>12:30</td><td>12:31</td><td>13:10</td><td>Lunch</td><td>14:50</td><td>14:51</td><td>15:40</td><td>15:41</td><td>16:40</td><td>16:41</td><td>17:30</td><td>17:31</td><td>18:30</td><td>19:10</td></tr>
    <tr><td>FRI</td><td>THEORY</td><td>TCC1</td><td>TB1</td><td>-</td><td>TA1-CSE4007-ETH-G17-AB-2-ALL</td><td>-</td><td>F1</td><td>-</td><td>TE1</td><td>SD2</td><td>-</td><td>Lunch</td><td>C2</td><td>-</td><td>TB2</td><td>-</td><td>TA2</td><td>-</td><td>F2</td><td>-</td><td>TEE2</td><td>-</td></tr>
    <tr><td>LAB</td><td>L19</td><td>L20</td><td>--</td><td>L21</td><td>--</td><td>L22</td><td>--</td><td>L23-CSE4007-ELA-114-AB-2-ALL</td><td>--</td><td>L24-CSE4007-ELA-114-AB-2-ALL</td><td>Lunch</td><td>L49</td><td>--</td><td>L50</td><td>--</td><td>L51</td><td>--</td><td>L52</td><td>--</td><td>L53</td><td>L54</td></tr>
  </tbody>
</table></body></html>"#
    .to_string()
}

#[test]
fn theory_and_lab_slots_use_their_own_timings() {
    let tt = parse_timetable(sample_html());

    let friday = &tt.friday;
    assert_eq!(
        friday.len(),
        2,
        "expected one theory + one lab class on Friday"
    );

    // Theory class TA1 (grid column 4) -> theory timings 10:00 / 10:50.
    let theory = friday
        .iter()
        .find(|c| c.course_type == "ETH")
        .expect("theory class missing");
    assert_eq!(theory.start_time, "10:00");
    assert_eq!(theory.end_time, "10:50");

    // Lab class L23+L24 (grid columns 8 & 10) -> LAB timings 11:40 / 13:10.
    // Before the fix this reused the theory row (12:00 / "-") and produced the
    // broken "-" / "-" class shown on the home screen.
    let lab = friday
        .iter()
        .find(|c| c.course_type == "ELA")
        .expect("lab class missing");
    assert_eq!(lab.start_time, "11:40");
    assert_eq!(lab.end_time, "13:10");
    assert_ne!(lab.start_time, "-");
    assert_ne!(lab.end_time, "-");

    // The two consecutive lab periods collapse into a single class...
    assert_eq!(lab.slot, "L23+L24 -");
    // ...and the slot string carries no stray newline from the multi-line cell.
    assert!(
        !lab.slot.contains('\n'),
        "slot should not contain a newline"
    );
    assert_eq!(lab.venue, "114-AB-2");
    assert_eq!(lab.faculty, "Sucharitha M");
}

/// Each part of a course carries its own credits, read from the last number of
/// the "L T P J C" line: the GPA planner sums a course's parts to get its credit
/// weight.
#[test]
fn each_part_of_a_course_carries_its_own_credits() {
    let tt = parse_timetable(sample_html());

    let theory = tt.friday.iter().find(|c| c.course_type == "ETH").unwrap();
    let lab = tt.friday.iter().find(|c| c.course_type == "ELA").unwrap();

    assert_eq!(theory.credits, "3.0");
    assert_eq!(lab.credits, "1.0");
}

/// A page that gives no credit column must still parse; the credits are just
/// empty rather than a failure.
#[test]
fn a_missing_credit_column_leaves_credits_empty() {
    let html = sample_html().replace("<td>3 0 0 0 3.0</td>", "<td>-</td>");
    let tt = parse_timetable(html);

    let theory = tt.friday.iter().find(|c| c.course_type == "ETH").unwrap();
    assert_eq!(theory.credits, "");
}


/// A course table with every kind of row the planner has to get right: parts of
/// one course, a Lab Only course, a project that never meets (no slot, no grid
/// row), a course whose name has a dash and brackets of its own, and a course
/// with no credits at all.
fn course_table_html() -> String {
    r#"<!DOCTYPE html><html><body><table>
  <tbody>
    <tr><td>1</td><td>General (Semester)</td><td>CSE4007 - Digital Image Processing ( Embedded Theory )</td><td>3 0 0 0 3.0</td><td>-</td><td>Regular</td><td>AP2026272000042</td><td><p>A1+TA1 - </p><p>G17-AB-2</p></td><td>Sucharitha M - SENSE</td></tr>
    <tr><td>2</td><td>General (Semester)</td><td>CSE4007 - Digital Image Processing ( Embedded Lab )</td><td>0 0 2 0 1.0</td><td>-</td><td>Regular</td><td>AP2026272000235</td><td><p>L23+L24 - </p><p>114-AB-2</p></td><td>Sucharitha M - SENSE</td></tr>
    <tr><td>3</td><td>General (Semester)</td><td>CSE1006 - Programming Lab ( Lab Only )</td><td>0 0 4 0 2.0</td><td>-</td><td>Regular</td><td>AP2026272000300</td><td><p>L1+L2 - </p><p>101-AB-1</p></td><td>Some Faculty - SCOPE</td></tr>
    <tr><td>4</td><td>General (Semester)</td><td>CSE4099 - Capstone Project ( Project )</td><td>0 0 0 20 10.0</td><td>-</td><td>Regular</td><td>AP2026272000400</td><td>NIL</td><td>Another Faculty - SCOPE</td></tr>
    <tr><td>5</td><td>General (Semester)</td><td>HUM1001 - Qualitative And Quantitative Skills Practice - I (Soft Skill)</td><td>3 0 0 0 1.5</td><td>-</td><td>Regular</td><td>AP2026272000500</td><td><p>D1 - </p><p>G01-AB-1</p></td><td>Kumaran R - SAS</td></tr>
    <tr><td>6</td><td>General (Semester)</td><td>ENG1002 - Audit Course (Advanced) ( Theory Only )</td><td>1 0 0 0 0.0</td><td>-</td><td>Regular</td><td>AP2026272000600</td><td>NIL</td><td>Audit Faculty - SAS</td></tr>
    <tr><td>7</td><td>General (Semester)</td><td>MGT1001 - No Credit Column ( Theory Only )</td><td>-</td><td>-</td><td>Regular</td><td>AP2026272000700</td><td>NIL</td><td>Nobody - SAS</td></tr>
    <tr><td colspan="10">Total Number Of Credits: 17.5</td></tr>
  </tbody>
  <tbody>
    <tr><td>THEORY</td><td>Start</td><td>08:00</td><td>09:00</td><td>09:01</td><td>10:00</td><td>10:01</td><td>11:00</td><td>11:01</td><td>12:00</td><td>12:01</td><td>-</td><td>Lunch</td><td>14:00</td><td>14:01</td><td>15:00</td><td>15:01</td><td>16:00</td><td>16:01</td><td>17:00</td><td>17:01</td><td>18:00</td><td>-</td></tr>
    <tr><td>End</td><td>08:50</td><td>09:50</td><td>09:51</td><td>10:50</td><td>10:51</td><td>11:50</td><td>11:51</td><td>12:50</td><td>12:51</td><td>-</td><td>Lunch</td><td>14:50</td><td>14:51</td><td>15:50</td><td>15:51</td><td>16:50</td><td>16:51</td><td>17:50</td><td>17:51</td><td>18:50</td><td>-</td></tr>
    <tr><td>LAB</td><td>Start</td><td>08:00</td><td>08:50</td><td>08:51</td><td>09:50</td><td>09:51</td><td>10:40</td><td>10:41</td><td>11:40</td><td>11:41</td><td>12:30</td><td>Lunch</td><td>14:00</td><td>14:01</td><td>14:50</td><td>14:51</td><td>15:50</td><td>15:51</td><td>16:40</td><td>16:41</td><td>17:40</td><td>18:30</td></tr>
    <tr><td>End</td><td>08:50</td><td>09:40</td><td>09:41</td><td>10:40</td><td>10:41</td><td>11:30</td><td>11:31</td><td>12:30</td><td>12:31</td><td>13:10</td><td>Lunch</td><td>14:50</td><td>14:51</td><td>15:40</td><td>15:41</td><td>16:40</td><td>16:41</td><td>17:30</td><td>17:31</td><td>18:30</td><td>19:10</td></tr>
    <tr><td>FRI</td><td>THEORY</td><td>TCC1</td><td>TB1</td><td>-</td><td>TA1-CSE4007-ETH-G17-AB-2-ALL</td><td>-</td><td>F1</td><td>-</td><td>TE1</td><td>SD2</td><td>-</td><td>Lunch</td><td>C2</td><td>-</td><td>TB2</td><td>-</td><td>TA2</td><td>-</td><td>F2</td><td>-</td><td>TEE2</td><td>-</td></tr>
    <tr><td>LAB</td><td>L19</td><td>L20</td><td>--</td><td>L21</td><td>--</td><td>L22</td><td>--</td><td>L23-CSE4007-ELA-114-AB-2-ALL</td><td>--</td><td>L24-CSE4007-ELA-114-AB-2-ALL</td><td>Lunch</td><td>L49</td><td>--</td><td>L50</td><td>--</td><td>L51</td><td>--</td><td>L52</td><td>--</td><td>L53</td><td>L54</td></tr>
  </tbody>
</table></body></html>"#
        .to_string()
}

/// The course table lists EVERY registered course, including ones that never
/// meet and so are not in the weekly grid at all.
#[test]
fn the_course_table_lists_courses_that_have_no_slot() {
    let tt = parse_timetable(course_table_html());
    let codes: Vec<&str> = tt.courses.iter().map(|c| c.course_code.as_str()).collect();

    assert!(codes.contains(&"CSE4099"), "the capstone has no slot: {codes:?}");
    assert!(codes.contains(&"ENG1002"));
    assert!(codes.contains(&"MGT1001"));
    // Nothing in the grid for it.
    let in_grid = tt.friday.iter().any(|c| c.course_code == "CSE4099");
    assert!(!in_grid);
}

#[test]
fn every_part_keeps_its_own_kind_and_credits() {
    let tt = parse_timetable(course_table_html());
    let find = |code: &str, kind: &str| {
        tt.courses
            .iter()
            .find(|c| c.course_code == code && c.course_type == kind)
            .unwrap_or_else(|| panic!("{code} / {kind} missing: {:?}", tt.courses))
    };

    assert_eq!(find("CSE4007", "Embedded Theory").credits, "3.0");
    assert_eq!(find("CSE4007", "Embedded Theory").type_code, "ETH");
    assert_eq!(find("CSE4007", "Embedded Lab").credits, "1.0");
    assert_eq!(find("CSE4007", "Embedded Lab").type_code, "ELA");
    assert_eq!(find("CSE1006", "Lab Only").credits, "2.0");
    assert_eq!(find("CSE1006", "Lab Only").type_code, "LO");
    assert_eq!(find("CSE4099", "Project").credits, "10.0");
    // Fractional credits stay fractional.
    assert_eq!(find("HUM1001", "Soft Skill").credits, "1.5");
}

#[test]
fn a_name_with_a_dash_and_brackets_still_gives_the_right_kind() {
    let tt = parse_timetable(course_table_html());

    let skills = tt.courses.iter().find(|c| c.course_code == "HUM1001").unwrap();
    assert_eq!(skills.course_name, "Qualitative And Quantitative Skills Practice - I");
    assert_eq!(skills.course_type, "Soft Skill", "no spaces inside the brackets");

    let audit = tt.courses.iter().find(|c| c.course_code == "ENG1002").unwrap();
    assert_eq!(audit.course_name, "Audit Course (Advanced)");
    assert_eq!(audit.course_type, "Theory Only", "the LAST bracket pair is the kind");
}

#[test]
fn a_part_without_credits_is_listed_with_none() {
    let tt = parse_timetable(course_table_html());
    let none = tt.courses.iter().find(|c| c.course_code == "MGT1001").unwrap();
    assert_eq!(none.credits, "");
    // A zero is a real value, not a missing one.
    let zero = tt.courses.iter().find(|c| c.course_code == "ENG1002").unwrap();
    assert_eq!(zero.credits, "0.0");
}

#[test]
fn a_part_is_listed_once() {
    let tt = parse_timetable(course_table_html());
    let n = tt
        .courses
        .iter()
        .filter(|c| c.course_code == "CSE4007")
        .count();
    assert_eq!(n, 2, "one theory part and one lab part");
}

/// A Lab Only part used to read its credits under a different key from the
/// weekly grid's code for it, so it came out with none.
#[test]
fn a_lab_only_class_in_the_grid_gets_its_credits() {
    let html = course_table_html().replace(
        "<td>L23-CSE4007-ELA-114-AB-2-ALL</td>",
        "<td>L23-CSE1006-LO-101-AB-1-ALL</td>",
    );
    let tt = parse_timetable(html);
    let lab = tt
        .friday
        .iter()
        .find(|c| c.course_type == "LO")
        .unwrap_or_else(|| panic!("no Lab Only class on Friday: {:?}", tt.friday));
    assert_eq!(lab.credits, "2.0");
}
