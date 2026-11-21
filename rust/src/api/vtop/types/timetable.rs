use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed", "immutable" import "package:meta/meta.dart" as meta))]
#[frb(json_serializable)]
#[frb]
pub struct TimetableClass {
    pub start_time: String,
    pub end_time: String,
    pub course_name: String,
    pub slot: String,
    pub venue: String,
    pub faculty: String,
    pub course_code: String,
    pub course_type: String,
    /// Credits of this part of the course (theory or lab), as VTOP prints them
    /// in the last column of the "L T P J C" line, e.g. `"3.0"`. Empty when the
    /// page does not give one. A course with a theory part and a lab part has
    /// two slots with their own credits.
    #[serde(default)]
    pub credits: String,
}

/// One row of VTOP's course table: a course the student is registered for, or
/// one *part* of it (a course with a theory and a lab part has a row for each).
///
/// This is the whole list of registered courses with their credits, whether or
/// not a part has a weekly slot. The weekly grid only has courses that meet at
/// set times, so a project, an online course or anything else without a slot is
/// in this table and nowhere in the grid.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed", "immutable" import "package:meta/meta.dart" as meta))]
#[frb(json_serializable)]
#[frb]
pub struct TimetableCourse {
    pub course_code: String,
    pub course_name: String,
    /// The part's kind as VTOP words it: "Embedded Theory", "Lab Only", ...
    pub course_type: String,
    /// The short code the weekly grid uses for it: `ETH`, `ELA`, `TH`, `LO`, `PJT`,
    /// `EPJ`, `SS`; `UNK` for a kind not recognised.
    pub type_code: String,
    /// The last number of the "L T P J C" line, e.g. `"3.0"`; empty when the
    /// page gives none.
    pub credits: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed", "immutable" import "package:meta/meta.dart" as meta))]
#[frb(json_serializable)]
#[frb]
pub struct Timetable {
    #[serde(rename = "Monday")]
    pub monday: Vec<TimetableClass>,
    #[serde(rename = "Tuesday")]
    pub tuesday: Vec<TimetableClass>,
    #[serde(rename = "Wednesday")]
    pub wednesday: Vec<TimetableClass>,
    #[serde(rename = "Thursday")]
    pub thursday: Vec<TimetableClass>,
    #[serde(rename = "Friday")]
    pub friday: Vec<TimetableClass>,
    #[serde(rename = "Saturday")]
    pub saturday: Vec<TimetableClass>,
    #[serde(rename = "Sunday")]
    pub sunday: Vec<TimetableClass>,
    /// Every registered course and part with its credits (VTOP's course table).
    /// Empty on a timetable saved before this was read.
    #[serde(default)]
    pub courses: Vec<TimetableCourse>,
}
