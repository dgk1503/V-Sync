use crate::api::vtop::vtop_config::validate_semester_id;
use crate::api::vtop::{
    parser, types::*, vtop_client::VtopClient, vtop_errors::map_response_read_error,
    vtop_errors::VtopError, vtop_errors::VtopResult,
};
use chrono::Utc;

/// VTOP's default class group, "All Class Group (Combined)".
pub const DEFAULT_CLASS_GROUP: &str = "COMB";

/// How many month requests to have in flight at once.
///
/// Four keeps a six-month semester to two waves while staying well short of
/// what would look like hammering VTOP. Going higher would only shave a little
/// more off a fetch that is already down to two round-trips.
const MAX_CONCURRENT_MONTH_REQUESTS: usize = 4;

impl VtopClient {
    /// Posts one of the calendar's AJAX lookups.
    ///
    /// They all take the same envelope and differ only in the extra fields, so
    /// the envelope is built once here.
    async fn post_calendar(&mut self, path: &str, extra: &str) -> VtopResult<String> {
        if !self.session.is_authenticated() {
            return Err(VtopError::SessionExpired);
        }
        let url = format!("{}{}", self.config.base_url, path);
        let timestamp = Utc::now().format("%a, %d %b %Y %H:%M:%S GMT").to_string();
        let body = format!(
            "_csrf={}&authorizedID={}&x={}&{}",
            self.session
                .get_csrf_token()
                .ok_or(VtopError::SessionExpired)?,
            self.username,
            timestamp,
            extra
        );
        let res = self.post_form_with_session_retry(url, body).await?;
        res.text().await.map_err(map_response_read_error)
    }

    /// Retrieves the class groups available for a semester.
    ///
    /// Class groups are semester dependent, so VTOP only renders them once a
    /// semester is chosen.
    ///
    /// # Arguments
    ///
    /// * `semester_id` - The unique identifier for the semester.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - The session is not authenticated (`VtopError::SessionExpired`)
    /// - Network communication fails (`VtopError::NetworkError`)
    /// - The VTOP server returns an error response (`VtopError::VtopServerError`)
    pub async fn get_calendar_class_groups(
        &mut self,
        semester_id: &str,
    ) -> VtopResult<Vec<ClassGroup>> {
        validate_semester_id(semester_id)?;
        let text = self
            .post_calendar(
                "/vtop/getDateForSemesterPreview",
                &format!("paramReturnId=getDateForSemesterPreview&semSubId={semester_id}"),
            )
            .await?;
        Ok(parser::calendar_parser::parse_class_groups(text))
    }

    /// Retrieves the months a semester's calendar covers.
    ///
    /// # Arguments
    ///
    /// * `semester_id` - The unique identifier for the semester.
    /// * `class_group_id` - The class group, e.g. [`DEFAULT_CLASS_GROUP`].
    ///
    /// # Returns
    ///
    /// One entry per month, each carrying the `cal_date` that
    /// [`Self::get_calendar_month`] expects.
    pub async fn get_calendar_months(
        &mut self,
        semester_id: &str,
        class_group_id: &str,
    ) -> VtopResult<Vec<CalendarMonthRef>> {
        validate_semester_id(semester_id)?;
        // `getDateForSemesterPreview` is the one page that carries BOTH the
        // class-group dropdown and every month button, so this shares its
        // request with `get_calendar_class_groups` instead of asking VTOP for a
        // second page that only differs in a `paramReturnId`.
        let text = self
            .post_calendar(
                "/vtop/getDateForSemesterPreview",
                &format!(
                    "paramReturnId=getDateForSemesterPreview&semSubId={semester_id}&classGroupId={class_group_id}"
                ),
            )
            .await?;
        Ok(parser::calendar_parser::parse_calendar_months(text))
    }

    /// Retrieves one month of a semester's calendar.
    ///
    /// # Arguments
    ///
    /// * `semester_id` - The unique identifier for the semester.
    /// * `cal_date` - The month to view, from [`CalendarMonthRef::cal_date`] —
    ///   e.g. "01-AUG-2026".
    /// * `class_group_id` - The class group, e.g. [`DEFAULT_CLASS_GROUP`].
    ///
    /// # Returns
    ///
    /// The month's days, in date order.
    pub async fn get_calendar_month(
        &mut self,
        semester_id: &str,
        cal_date: &str,
        class_group_id: &str,
    ) -> VtopResult<Vec<CalendarDay>> {
        validate_semester_id(semester_id)?;
        let text = self
            .post_calendar(
                "/vtop/processViewCalendar",
                &format!("calDate={cal_date}&semSubId={semester_id}&classGroupId={class_group_id}"),
            )
            .await?;
        Ok(parser::calendar_parser::parse_calendar_month(
            text,
            cal_date.to_string(),
        ))
    }

    /// Retrieves a semester's whole academic calendar.
    ///
    /// VTOP serves the calendar a month at a time, so this is one request for
    /// the month list plus one per month — seven or so for a semester. It is
    /// meant to be called once and the result cached, not on every page open.
    ///
    /// A month that fails to load is skipped rather than failing the whole
    /// calendar: a calendar missing one month is still worth showing, and the
    /// gap is visible in `months` against `days`.
    ///
    /// # Arguments
    ///
    /// * `semester_id` - The unique identifier for the semester.
    /// * `class_group_id` - The class group, e.g. [`DEFAULT_CLASS_GROUP`].
    pub async fn get_academic_calendar(
        &mut self,
        semester_id: &str,
        class_group_id: &str,
    ) -> VtopResult<AcademicCalendar> {
        validate_semester_id(semester_id)?;
        let months = self
            .get_calendar_months(semester_id, class_group_id)
            .await?;

        // Each month is an independent request, and VTOP serves them one at a
        // time, so fetching them in sequence made a six-month semester seven
        // serial round-trips before the app could show anything. They carry no
        // shared state, so they go out in waves instead.
        //
        // The CSRF token is read once up front. `getDateForSemesterPreview`
        // does not hand back a fresh one, and neither do the month pages, so
        // there is nothing to refresh between requests. A session that dies
        // mid-flight is not repaired here either: `&mut self` cannot be shared
        // across the spawned tasks, and re-logging in is the caller's job via
        // the session-expiry retry that wraps this call.
        let csrf = self
            .session
            .get_csrf_token()
            .ok_or(VtopError::SessionExpired)?;
        let http = self.client.clone();
        let base_url = self.config.base_url.clone();
        let username = self.username.clone();

        let mut days: Vec<CalendarDay> = Vec::new();
        for wave in months.chunks(MAX_CONCURRENT_MONTH_REQUESTS) {
            let mut tasks = tokio::task::JoinSet::new();

            for month in wave {
                let http = http.clone();
                let base_url = base_url.clone();
                let username = username.clone();
                let csrf = csrf.clone();
                let semester_id = semester_id.to_string();
                let cal_date = month.cal_date.clone();
                let class_group_id = class_group_id.to_string();

                tasks.spawn(async move {
                    let body = format!(
                        "_csrf={csrf}&authorizedID={username}&x={}&calDate={}&semSubId={semester_id}&classGroupId={class_group_id}",
                        Utc::now().format("%a, %d %b %Y %H:%M:%S GMT"),
                        urlencoding::encode(&cal_date),
                    );
                    let url = format!("{base_url}/vtop/processViewCalendar");

                    let outcome = async {
                        let res = http
                            .post(&url)
                            .body(body)
                            .send()
                            .await
                            .map_err(map_response_read_error)?;
                        // A redirect back to the login page is VTOP saying the
                        // session died, not that the month is missing.
                        if !res.status().is_success()
                            || res.url().to_string().contains("login")
                        {
                            return Err(VtopError::SessionExpired);
                        }
                        res.text().await.map_err(map_response_read_error)
                    }
                    .await;

                    outcome.map(|html| {
                        parser::calendar_parser::parse_calendar_month(html, cal_date)
                    })
                });
            }

            // A month that fails is skipped, not fatal: a calendar missing one
            // month still beats an empty screen. `join_next` collects each task
            // as it lands, so a slow month does not hold up the wave.
            while let Some(joined) = tasks.join_next().await {
                if let Ok(Ok(month_days)) = joined {
                    days.extend(month_days);
                }
            }
        }

        days.sort_by(|a, b| a.date.cmp(&b.date));

        Ok(AcademicCalendar {
            semester_id: semester_id.to_string(),
            class_group_id: class_group_id.to_string(),
            months,
            days,
        })
    }
}
