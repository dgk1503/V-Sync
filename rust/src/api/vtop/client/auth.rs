use crate::api::vtop::vtop_config::MAX_CAPTCHA_RELOAD_ATTEMPTS;
use crate::api::vtop::{
    captcha_solver as captcha_parser,
    vtop_client::VtopClient,
    vtop_errors::VtopError,
    vtop_errors::VtopResult,
    vtop_errors::{map_reqwest_error, map_response_read_error},
};
use reqwest::multipart::Form;
use reqwest::{cookie::CookieStore, Url};
use scraper::{Html, Selector};
use serde_json::Value;

/// VTOP's catch-all refusal, served with an HTTP 200.
///
/// Matched without the trailing exclamation marks so it does not hinge on
/// punctuation VTOP might change.
const MENU_UNAVAILABLE_MARKER: &str = "This menu is not available at present";

/// Reads a response body, turning VTOP's refusal into an error.
///
/// The refusal is a 200 with a body, so nothing upstream catches it and the
/// fragment used to reach a parser. Parsers return an empty result for markup
/// they cannot recognise, so a refused request showed up as "no data" on screen
/// with no error, no log line, and no way to tell it from a student who
/// genuinely has no records.
/// Whether a response body is VTOP's refusal rather than a page.
///
/// Two causes produce a byte-identical body and the response carries nothing to
/// separate them: the request shape was wrong, or the portal has switched that
/// menu off. Callers should not claim to know which.
///
/// Crate-private deliberately: `pub` made flutter_rust_bridge generate a Dart
/// binding for it, putting an internal predicate on the app's API surface.
pub(crate) fn is_menu_unavailable(body: &str) -> bool {
    body.contains(MENU_UNAVAILABLE_MARKER)
}

pub(crate) async fn read_body(response: reqwest::Response) -> VtopResult<String> {
    let text = response.text().await.map_err(map_response_read_error)?;
    if is_menu_unavailable(&text) {
        return Err(VtopError::MenuUnavailable);
    }
    Ok(text)
}

impl VtopClient {
    /// Retrieves the current session's cookies as a byte vector.
    ///
    /// Returns an error if the session is not authenticated.
    ///
    /// # Returns
    /// A vector of bytes representing the session cookies, or an error if the session has expired.
    ///
    /// # Examples
    ///
    /// ```
    /// let cookies = client.get_cookie().await?;
    /// assert!(!cookies.is_empty());
    /// ```
    #[cfg(not(target_arch = "wasm32"))]
    pub async fn get_cookie(&self) -> VtopResult<Vec<u8>> {
        if !self.session.is_authenticated() {
            return Err(VtopError::SessionExpired);
        }

        let mut data = vec![];
        let url = format!("{}/vtop", self.config.base_url);
        let k = self
            .session
            .get_cookie_store()
            .cookies(&Url::parse(&url).unwrap());
        if let Some(cookie) = k {
            data = cookie.as_bytes().to_vec();
        }
        Ok(data)
    }

    /// Helper method to check for session expiration and automatically re-authenticate if needed.
    ///
    /// # Arguments
    /// * `response` - The HTTP response to check for session expiration
    ///
    /// # Returns
    /// Returns `Ok(())` if session is valid or re-authentication succeeded.
    /// Returns `Err(VtopError::SessionExpiredRetryNeeded)` if session expired and re-authentication
    /// succeeded, indicating the calling method should retry the request.
    /// Returns other errors if authentication failed.
    /// Sends a form POST and, if VTOP has dropped the session, logs back in and
    /// sends it again before the caller reads the body.
    ///
    /// [`Self::handle_session_check`] re-authenticates but cannot re-issue the
    /// request, so callers went on to read the response captured *before* the
    /// re-login — the expired-session page. The parsers return an empty result
    /// for that rather than an error, so an expired session reached the screen
    /// as "no data" with nothing to say anything had gone wrong.
    ///
    /// An expired session is *reported* here, never repaired.
    ///
    /// Re-authenticating in this layer is what sent users several OTP emails.
    /// VTOP mails a fresh code for every credentials POST it sees from an IP
    /// it has not verified, and a feature page issues several requests at
    /// once — so one expiry became one login per in-flight request, none of
    /// which the user had a prompt for. Each of those logins also opened its
    /// own server session, so the code the OTP sheet was about to validate
    /// could come back as "Invalid OTP".
    ///
    /// The caller owns re-authentication, where it is deduplicated into a
    /// single login and surfaced as the OTP prompt.
    pub(crate) async fn post_form_with_session_retry(
        &mut self,
        url: impl reqwest::IntoUrl + Clone,
        body: String,
    ) -> VtopResult<reqwest::Response> {
        let response = self
            .client
            .post(url)
            .body(body)
            .send()
            .await
            .map_err(map_reqwest_error)?;

        self.session.check_session_expiration(&response)?;
        Ok(response)
    }

    /// The multipart counterpart of [`Self::post_form_with_session_retry`],
    /// and reported rather than repaired for the same reason: a re-login here
    /// is another credentials POST, and VTOP answers those with another OTP
    /// email.
    ///
    /// A `multipart::Form` cannot be cloned, so the caller supplies a closure
    /// that builds it from the CSRF token that is current when the request is
    /// actually sent.
    pub(crate) async fn post_multipart_with_session_retry<F>(
        &mut self,
        url: impl reqwest::IntoUrl + Clone,
        build_form: F,
    ) -> VtopResult<reqwest::Response>
    where
        F: Fn(&str) -> reqwest::multipart::Form,
    {
        let csrf = self
            .session
            .get_csrf_token()
            .ok_or(VtopError::SessionExpired)?;

        let response = self
            .client
            .post(url)
            .multipart(build_form(&csrf))
            .send()
            .await
            .map_err(map_reqwest_error)?;

        self.session.check_session_expiration(&response)?;
        Ok(response)
    }

    /// The GET counterpart of [`Self::post_form_with_session_retry`], and
    /// reported rather than repaired for the same reason.
    pub(crate) async fn get_with_session_retry(
        &mut self,
        url: impl reqwest::IntoUrl + Clone,
    ) -> VtopResult<reqwest::Response> {
        let response = self
            .client
            .get(url)
            .send()
            .await
            .map_err(map_reqwest_error)?;

        self.session.check_session_expiration(&response)?;
        Ok(response)
    }

    /// Reports whether a response means the session expired.
    ///
    /// It used to log back in and then return `Ok`, which was worse than
    /// useless on the two write paths that call it: they go on to read the
    /// response captured *before* the re-login, so the write still failed —
    /// after a credentials POST, and therefore possibly another OTP email.
    pub(crate) async fn handle_session_check(
        &mut self,
        response: &reqwest::Response,
    ) -> VtopResult<()> {
        self.session.check_session_expiration(response)
    }

    /// Authenticates the user with the VTOP system using provided credentials.
    ///
    /// This method performs a complete login flow including:
    /// 1. Loading the initial login page to obtain session cookies
    /// 2. Extracting CSRF tokens for security
    /// 3. Solving CAPTCHA challenges automatically
    /// 4. Submitting credentials and validating the response
    /// 5. Establishing an authenticated session
    ///
    /// The method automatically retries up to 4 times if CAPTCHA verification fails,
    /// loading a fresh CAPTCHA image for each attempt.
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` if authentication succeeds and a valid session is established.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - The username or password is incorrect (`VtopError::InvalidCredentials`)
    /// - CAPTCHA solving fails repeatedly (`VtopError::CaptchaRequired` or `VtopError::AuthenticationFailed`)
    /// - Maximum login attempts (4) are exceeded (`VtopError::AuthenticationFailed`)
    /// - Network communication fails (`VtopError::NetworkError`)
    /// - The VTOP server is unavailable (`VtopError::VtopServerError`)
    /// - CSRF token extraction fails (`VtopError::ParseError`)
    ///
    /// # Examples
    ///
    /// ```
    /// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// use lib_vtop::{VtopClient, VtopConfig, SessionManager};
    ///
    /// let config = VtopConfig::default();
    /// let session = SessionManager::new();
    /// let mut client = VtopClient::with_config(
    ///     config,
    ///     session,
    ///     "21BCE1234".to_string(),
    ///     "password123".to_string()
    /// );
    ///
    /// match client.login().await {
    ///     Ok(_) => println!("Login successful!"),
    ///     Err(e) => eprintln!("Login failed: {:?}", e),
    /// }
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// # Notes
    ///
    /// - This method must be called before any other API methods that require authentication
    /// - The session remains valid until explicitly logged out or until VTOP server invalidates it
    /// - Failed login attempts may temporarily lock the account after multiple failures
    pub async fn login(&mut self) -> VtopResult<()> {
        #[allow(non_snake_case)]
        let MAX_CAP_TRY = 4;
        for i in 0..MAX_CAP_TRY {
            if i == 0 {
                self.load_login_page(true).await?;
            } else {
                self.load_login_page(false).await?;
            }

            let captcha_answer = if let Some(captcha_data) = &self.captcha_data {
                // Call the new, separated captcha solver
                captcha_parser::solve_captcha(captcha_data).await?
            } else {
                return Err(VtopError::CaptchaRequired);
            };
            match self.perform_login(&captcha_answer).await {
                Ok(_) => {
                    self.session.set_authenticated(true);
                    return Ok(());
                }
                Err(VtopError::AuthenticationFailed(msg)) if msg.contains("Invalid Captcha") => {
                    continue;
                }
                Err(e) => return Err(e),
            }
        }
        Err(VtopError::AuthenticationFailed(
            "Max login attempts exceeded".to_string(),
        ))
    }

    /// Verifies the OTP sent during login authentication.
    ///
    /// This method submits the OTP entered by the user to VTOP.
    /// If the OTP is correct, the session is finalized and the user is
    /// fully authenticated. On success, the method also loads the
    /// authenticated dashboard page and extracts session details.
    ///
    /// # Sample Response (Success)
    /// ```json
    /// {
    ///   "status": "SUCCESS",
    ///   "redirectUrl": "/vtop/content"
    /// }
    /// ```
    ///
    /// # Sample Response (Failure)
    /// ```json
    /// {
    ///   "status": "INVALID",
    ///   "message": "Invalid OTP. Please try again."
    /// }
    /// ```
    ///
    /// # Sample Response (Failure)
    /// ```json
    /// {
    ///   "status": "EXPIRED",
    ///   "message": "OTP has expired. Please resend."
    /// }
    /// ```
    ///
    /// # Returns
    /// Returns `Ok(())` if OTP verification succeeds and session is authenticated.
    ///
    /// # Errors
    /// - `LoginOtpIncorrect` → OTP is wrong
    /// - `LoginOtpExpired` → OTP expired
    /// - `AuthenticationFailed` → server or parsing error
    /// - `SessionExpired` → missing CSRF/session token
    pub async fn verify_login_otp(&mut self, otp: &str) -> VtopResult<()> {
        let csrf = self
            .session
            .get_csrf_token()
            .ok_or(VtopError::SessionExpired)?;

        let url = format!("{}/vtop/validateSecurityOtp", self.config.base_url);
        let form_data = Form::new()
            .text("otpCode", otp.to_string())
            .text("_csrf", csrf);

        let response = self
            .client
            .post(url)
            .multipart(form_data)
            .send()
            .await
            .map_err(map_reqwest_error)?;

        if !response.status().is_success() {
            return Err(VtopError::AuthenticationFailed(format!(
                "Failed to verify OTP. Server responded with status: {}",
                response.status()
            )));
        }

        let response_text = response.text().await.map_err(map_response_read_error)?;
        // Parsed leniently on purpose: the endpoint answers JSON when it is
        // happy, and plain text or an HTML fragment on other days. There is no
        // `?` after this parse because a reply we cannot read is not evidence
        // about the code.
        let reply: Value = serde_json::from_str(&response_text).unwrap_or(Value::Null);
        let status = reply
            .get("status")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_ascii_uppercase();
        let message = reply.get("message").and_then(|v| v.as_str());

        // The two unambiguous rejections, both of which mean the user needs a
        // new code rather than a different one.
        if status == "EXPIRED" {
            return Err(VtopError::LoginOtpExpired);
        }
        if status == "INVALID" || response_text.to_lowercase().contains("invalid otp") {
            return Err(VtopError::LoginOtpIncorrect);
        }

        // Anything else is settled by the session, not by the reply. Calling a
        // code that VTOP actually accepted a failure sends the user to Resend,
        // and every resend is another email.
        let landing = reply
            .get("redirectUrl")
            .and_then(|v| v.as_str())
            .filter(|url| !url.trim().is_empty())
            .unwrap_or("/vtop/content");
        let landing = if landing.starts_with("http") {
            landing.to_string()
        } else {
            format!("{}{}", self.config.base_url, landing)
        };

        match self.adopt_authenticated_page(&landing).await {
            Ok(()) => Ok(()),
            Err(error) => Err(match status.as_str() {
                "" => error,
                "SUCCESS" | "VALID" | "OK" => VtopError::AuthenticationFailed(
                    "VTOP accepted the code but did not open a signed-in session. Please try again."
                        .to_string(),
                ),
                _ => VtopError::AuthenticationFailed(match message {
                    Some(message) => format!("{}: {}", status, message),
                    None => status.clone(),
                }),
            }),
        }
    }

    /// Opens a page only a signed-in session can serve, and adopts it.
    ///
    /// `_csrf` and `authorizedIDX` are what the dashboard carries for a session
    /// that is signed in, so a page with both is the proof — which is why this,
    /// and not the OTP endpoint's reply, decides whether a code was accepted.
    async fn adopt_authenticated_page(&mut self, url: &str) -> VtopResult<()> {
        let response = self
            .client
            .get(url.to_string())
            .send()
            .await
            .map_err(map_reqwest_error)?;

        if !response.status().is_success() {
            return Err(VtopError::AuthenticationFailed(format!(
                "VTOP did not open a signed-in session (HTTP {})",
                response.status()
            )));
        }

        let response_text = response.text().await.map_err(map_response_read_error)?;
        self.current_page = Some(response_text);
        let adopted = self.extract_csrf_token().and_then(|_| self.get_regno());
        self.current_page = None;
        adopted?;

        self.captcha_data = None;
        self.session.set_authenticated(true);
        Ok(())
    }

    /// Requests a new OTP to be sent for login authentication.
    ///
    /// This method triggers the VTOP server to resend the OTP to the user.
    /// It is used when the previous OTP expires or is not received.
    ///
    /// # Sample Response (Success)
    /// ```json
    /// {
    ///   "otpSentAt": "2026-04-17T23:18:03.719",
    ///   "message": "OTP sent successfully",
    ///   "status": "SUCCESS"
    /// }
    /// ```
    ///
    /// # Returns
    /// Returns `Ok(())` if OTP is successfully requested.
    ///
    /// # Errors
    /// - `AuthenticationFailed` → OTP request failed or server error
    /// - `SessionExpired` → missing CSRF/session token
    pub async fn resend_login_otp(&mut self) -> VtopResult<()> {
        let csrf = self
            .session
            .get_csrf_token()
            .ok_or(VtopError::SessionExpired)?;

        // VTOP has served this endpoint under two spellings. A 404 means the
        // route is not there, and only then is the other spelling tried: a
        // second POST after one VTOP accepted would be a second email.
        for path in ["/vtop/resendSecurityOtp", "/vtop/resendSecurityOTP"] {
            let url = format!("{}{}", self.config.base_url, path);
            let form_data = Form::new().text("_csrf", csrf.clone());

            let response = self
                .client
                .post(url)
                .multipart(form_data)
                .send()
                .await
                .map_err(map_reqwest_error)?;

            if response.status().as_u16() == 404 {
                continue;
            }

            if !response.status().is_success() {
                return Err(VtopError::AuthenticationFailed(format!(
                    "Failed to request OTP. Server responded with status: {}",
                    response.status()
                )));
            }

            let response_text = response.text().await.map_err(map_response_read_error)?;
            return Self::interpret_resend_reply(&response_text);
        }

        Err(VtopError::AuthenticationFailed(
            "Failed to request OTP. Please try again.".to_string(),
        ))
    }

    /// Reads whatever VTOP answered the resend endpoint with.
    ///
    /// Requiring JSON here was a bug with a cost: the endpoint answers plain
    /// text or an HTML fragment too, so a resend that *did* send an email could
    /// come back to the app as a failure. The user — told it failed — tapped
    /// Resend again as soon as the countdown allowed, and VTOP sent another
    /// email for each tap. A reply that is not JSON is now read for what it
    /// says instead of being treated as a defect.
    fn interpret_resend_reply(body: &str) -> VtopResult<()> {
        let reply: Value = serde_json::from_str(body).unwrap_or(Value::Null);
        let status = reply
            .get("status")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_ascii_uppercase();

        if !status.is_empty() {
            return if matches!(status.as_str(), "SUCCESS" | "SENT" | "VALID" | "OK") {
                Ok(())
            } else {
                let message = reply
                    .get("message")
                    .and_then(|v| v.as_str())
                    .unwrap_or("VTOP refused to send a new OTP.");
                Err(VtopError::AuthenticationFailed(format!(
                    "{}: {}",
                    status, message
                )))
            };
        }

        // No JSON to read, so the words are all there is. A body that says the
        // code was sent and shows no sign of a refusal counts; an error page
        // that happens to contain "OTP" and "sent" ("OTP was not sent") does
        // not, which is why the two are checked together.
        let lower = body.to_lowercase();
        let looks_sent = lower.contains("otp") && lower.contains("sent");
        let looks_refused = ["not sent", "failed", "error", "invalid", "try again"]
            .iter()
            .any(|marker| lower.contains(marker));

        if looks_sent && !looks_refused {
            Ok(())
        } else {
            Err(VtopError::AuthenticationFailed(
                "VTOP did not confirm the new OTP. Please try again.".to_string(),
            ))
        }
    }

    /// Performs the actual login submission with credentials and CAPTCHA answer.
    ///
    /// This is an internal helper method that handles the HTTP POST request to submit
    /// login credentials along with the solved CAPTCHA. It processes the server response
    /// to determine if authentication was successful or if an error occurred.
    ///
    /// OTP is not always required.
    /// It is required when there is inactivity or a new IP address.
    /// After successful username, password, and captcha verification,
    /// the server may redirect to the OTP verification page (vtop/error).
    /// Sometimes, the login page (vtop/login) itself will include
    /// the "securityOtpForm" if OTP is required.
    ///
    /// # Arguments
    ///
    /// * `captcha_answer` - The solved CAPTCHA string to be submitted with credentials
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` if the login submission is successful and credentials are valid.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - The CAPTCHA answer is incorrect (`VtopError::AuthenticationFailed` with "Invalid Captcha")
    /// - The username or password is incorrect (`VtopError::InvalidCredentials`)
    /// - The CSRF token is missing (`VtopError::SessionExpired`)
    /// - Network request fails (`VtopError::NetworkError`)
    /// - The server returns an unexpected error (`VtopError::AuthenticationFailed`)
    /// - OTP is required for login (`VtopError::LoginOtpRequired`)
    async fn perform_login(&mut self, captcha_answer: &String) -> VtopResult<()> {
        let csrf = self
            .session
            .get_csrf_token()
            .ok_or(VtopError::SessionExpired)?;

        let login_data = format!(
            "_csrf={}&username={}&password={}&captchaStr={}",
            csrf,
            urlencoding::encode(&self.username),
            urlencoding::encode(&self.password),
            captcha_answer
        );
        let url = format!("{}/vtop/login", self.config.base_url);

        let response = self
            .client
            .post(url)
            .body(login_data)
            .send()
            .await
            .map_err(map_reqwest_error)?;
        let response_url = response.url().to_string();
        let response_text = read_body(response).await?;

        if response_url.contains("error") {
            // The OTP form is checked first, and structurally — by the form's
            // id, never by a substring. A page that carries it is VTOP asking
            // for the emailed code whatever else it says, and the captcha
            // branch below this is the one that loops: each trip around it
            // POSTs the credentials again, which is another OTP email.
            if Self::is_otp_required(&response_text) {
                self.current_page = Some(response_text);
                let _ = self.extract_csrf_token();
                self.current_page = None;
                Err(VtopError::LoginOtpRequired)
            } else if response_text.contains("Invalid Captcha") {
                return Err(VtopError::AuthenticationFailed(
                    "Invalid Captcha".to_string(),
                ));
            } else if response_text.contains("Invalid LoginId/Password")
                || response_text.contains("Invalid  Username/Password")
            {
                Err(VtopError::InvalidCredentials)
            } else {
                Err(VtopError::AuthenticationFailed(Self::get_login_page_error(
                    &response_text,
                )))
            }
        } else if Self::is_otp_required(&response_text) {
            self.current_page = Some(response_text);
            let _ = self.extract_csrf_token();
            self.current_page = None;
            Err(VtopError::LoginOtpRequired)
        } else {
            self.current_page = Some(response_text);
            self.extract_csrf_token()?;
            self.get_regno()?;

            self.current_page = None;
            self.captcha_data = None;
            Ok(())
        }
    }

    /// Loads the login page and extracts the CAPTCHA image.
    ///
    /// This internal method handles loading the VTOP login page and extracting the CAPTCHA
    /// image for solving. It can optionally load the initial page first to establish cookies,
    /// and will retry up to 8 times if the CAPTCHA image is not immediately available.
    ///
    /// # Arguments
    ///
    /// * `k` - If `true`, loads the initial VTOP page first to establish session cookies
    ///         and extract initial CSRF tokens. If `false`, skips initial page load.
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` when the login page is successfully loaded and CAPTCHA is extracted.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - Failed to load initial page (`VtopError::NetworkError`)
    /// - Failed to extract CSRF token (`VtopError::ParseError`)
    /// - Network request fails (`VtopError::NetworkError`)
    /// - Server returns error status (`VtopError::VtopServerError`)
    /// - CAPTCHA image not found after maximum retries (`VtopError::CaptchaRequired`)
    async fn load_login_page(&mut self, k: bool) -> VtopResult<()> {
        if k {
            self.load_initial_page().await?;
            self.extract_csrf_token()?;
        }
        let csrf = self
            .session
            .get_csrf_token()
            .ok_or(VtopError::SessionExpired)?;
        let url = format!("{}/vtop/prelogin/setup", self.config.base_url);
        let body = format!("_csrf={}&flag=VTOP", csrf);
        for _ in 0..MAX_CAPTCHA_RELOAD_ATTEMPTS {
            let response = self
                .client
                .post(&url)
                .body(body.clone())
                .send()
                .await
                .map_err(map_reqwest_error)?;
            if !response.status().is_success() {
                return Err(VtopError::VtopServerError);
            }
            let text = read_body(response).await?;
            if text.contains("base64,") {
                self.current_page = Some(text);
                self.extract_captcha_data()?;
                return Ok(());
            }
            println!("No captcha found Reloading the page ");
        }

        // Falling out of the loop means the captcha never arrived. Returning
        // Ok here told the caller the login page had loaded, and the login went
        // on with `current_page` unset -- failing later for a reason that had
        // nothing to do with the real cause.
        Err(VtopError::CaptchaRequired)
    }

    /// Extracts the base64-encoded CAPTCHA image data from the login page HTML.
    ///
    /// This internal method parses the HTML document to locate the CAPTCHA image element
    /// and extracts its base64-encoded source data. The CAPTCHA data is stored internally
    /// for later solving and submission.
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` if CAPTCHA data is successfully extracted and stored.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - The current page HTML is not available (`VtopError::ParseError`)
    /// - The CAPTCHA image element is not found in the HTML (`VtopError::CaptchaRequired`)
    /// - The image source doesn't contain base64 data (`VtopError::CaptchaRequired`)
    fn extract_captcha_data(&mut self) -> VtopResult<()> {
        let document = Html::parse_document(&self.current_page.as_ref().ok_or(
            VtopError::ParseError("Current page not found at captcha extration".into()),
        )?);
        let selector = Selector::parse("img.form-control.img-fluid.bg-light.border-0").unwrap();
        let captcha_src = document
            .select(&selector)
            .next()
            .and_then(|element| element.value().attr("src"))
            .ok_or(VtopError::CaptchaRequired)?;

        if captcha_src.contains("base64,") {
            self.captcha_data = Some(captcha_src.to_string());
        } else {
            return Err(VtopError::CaptchaRequired);
        }

        Ok(())
    }

    /// Extracts and updates the registration number from the authenticated page.
    ///
    /// After successful login, VTOP returns the user's registration number in a hidden
    /// form field. This method extracts that registration number and updates the client's
    /// stored username to ensure consistency across the session.
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` if the registration number is successfully extracted and stored.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - The current page HTML is not available (`VtopError::ParseError`)
    /// - The authorizedIDX hidden input field is not found (`VtopError::RegistrationParsingError`)
    fn get_regno(&mut self) -> VtopResult<()> {
        let document = Html::parse_document(&self.current_page.as_ref().ok_or(
            VtopError::ParseError("Current page not found at captcha extration".into()),
        )?);
        let selector = Selector::parse("input[type=hidden][name=authorizedIDX]").unwrap();
        let k = document
            .select(&selector)
            .next()
            .and_then(|element| element.value().attr("value").map(|value| value.to_string()))
            .ok_or(VtopError::RegistrationParsingError)?;

        self.username = k;
        Ok(())
    }

    /// Extracts the CSRF (Cross-Site Request Forgery) token from the page HTML.
    ///
    /// CSRF tokens are security tokens that VTOP uses to prevent unauthorized requests.
    /// This method locates and extracts the token from hidden form fields in the HTML
    /// and stores it in the session manager for use in subsequent requests.
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` if the CSRF token is successfully extracted and stored in the session.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - The current page HTML is not available (`VtopError::ParseError`)
    /// - The CSRF token input field is not found in the HTML (`VtopError::ParseError`)
    fn extract_csrf_token(&mut self) -> VtopResult<()> {
        let document = Html::parse_document(&self.current_page.as_ref().ok_or(
            VtopError::ParseError("Current page not found at csrf extration".into()),
        )?);
        let selector = Selector::parse("input[name='_csrf']").unwrap();
        let csrf_token = document
            .select(&selector)
            .next()
            .and_then(|element| element.value().attr("value"))
            .ok_or(VtopError::ParseError("CSRF token not found".to_string()))?;
        self.session.set_csrf_token(csrf_token.to_string());
        Ok(())
    }

    /// Loads the initial VTOP landing page to establish session cookies.
    ///
    /// This is the first step in the authentication flow. It makes a GET request to
    /// the VTOP landing page to establish initial session cookies and retrieve the
    /// base HTML structure needed for subsequent login steps.
    ///
    /// # Returns
    ///
    /// Returns `Ok(())` if the initial page is successfully loaded and stored.
    ///
    /// # Errors
    ///
    /// This function will return an error if:
    /// - Network request fails (`VtopError::NetworkError`)
    /// - Server returns a non-success status code (`VtopError::VtopServerError`)
    /// - Failed to read response body (`VtopError::NetworkError`)
    async fn load_initial_page(&mut self) -> VtopResult<()> {
        let url = format!("{}/vtop/open/page", self.config.base_url);
        let response = self
            .client
            .get(url)
            .send()
            .await
            .map_err(map_reqwest_error)?;

        if !response.status().is_success() {
            return Err(VtopError::VtopServerError);
        }
        self.current_page = Some(read_body(response).await?);

        Ok(())
    }

    /// Extracts and returns error messages from the login page HTML.
    ///
    /// When login fails, VTOP displays error messages in specific HTML elements.
    /// This method parses the error page to extract these messages and return them
    /// as a descriptive error string.
    ///
    /// # Arguments
    ///
    /// * `data` - The HTML content of the error page
    ///
    /// # Returns
    ///
    /// Returns a string containing the error message extracted from the page.
    /// If no error message is found, returns "Unknown login error".
    fn get_login_page_error(data: &str) -> String {
        let ptext = r#"span.text-danger.text-center[role="alert"]"#;
        let document = Html::parse_document(data);
        let selector = Selector::parse(&ptext).unwrap();
        if let Some(element) = document.select(&selector).next() {
            let error_message = element.text().collect::<Vec<_>>().join(" ");
            error_message.trim().into()
        } else {
            "Unknown login error".into()
        }
    }

    /// Checks if authentication requires OTP by looking for a form with id="securityOtpForm" in the response.
    fn is_otp_required(data: &str) -> bool {
        let form_selector = Selector::parse(r#"form#securityOtpForm"#).unwrap();
        let document = Html::parse_document(data);
        document.select(&form_selector).next().is_some()
    }

    /// Checks if the client has an active authenticated session.
    ///
    /// This method verifies whether the current session is authenticated and valid
    /// for making API requests to VTOP. It should be called before attempting
    /// operations that require authentication.
    ///
    /// # Returns
    ///
    /// Returns `true` if the session is authenticated and active, `false` otherwise.
    ///
    /// # Examples
    ///
    /// ```
    /// # fn example(client: &mut VtopClient) {
    /// if client.is_authenticated() {
    ///     println!("Session is active");
    ///     // Proceed with authenticated operations
    /// } else {
    ///     println!("Need to login first");
    ///     // Call client.login() before making requests
    /// }
    /// # }
    /// ```
    pub fn is_authenticated(&mut self) -> bool {
        self.session.is_authenticated()
    }
}

#[cfg(test)]
mod resend_reply_tests {
    use super::VtopClient;
    use crate::api::vtop::vtop_errors::VtopError;

    /// The happy path: VTOP's own JSON.
    #[test]
    fn a_success_status_is_accepted() {
        let body = r#"{"otpSentAt":"2026-04-17T23:18:03.719","message":"OTP sent successfully","status":"SUCCESS"}"#;
        assert!(VtopClient::interpret_resend_reply(body).is_ok());
    }

    #[test]
    fn a_refusal_surfaces_its_message() {
        let body = r#"{"status":"FAILED","message":"Please wait before requesting a new OTP."}"#;
        match VtopClient::interpret_resend_reply(body) {
            Err(VtopError::AuthenticationFailed(message)) => {
                assert!(message.contains("Please wait"), "got {message}")
            }
            other => panic!("expected a refusal, got {other:?}"),
        }
    }

    /// The shape that used to be read as a failure although a code had just
    /// gone out: no JSON at all. Each of those put the user back on Resend.
    #[test]
    fn an_html_reply_that_says_it_was_sent_is_accepted() {
        assert!(VtopClient::interpret_resend_reply(
            "<div class=\"alert alert-success\">OTP sent successfully to your registered email</div>"
        )
        .is_ok());
    }

    /// An unreadable reply is not proof either way, so it is reported as
    /// unconfirmed rather than as a sent code.
    #[test]
    fn an_unreadable_reply_is_reported_as_unconfirmed() {
        let error = VtopClient::interpret_resend_reply("<html><body>Something went wrong</body></html>");
        assert!(matches!(error, Err(VtopError::AuthenticationFailed(_))));
    }

    /// ...and an error page cannot be read as a success just because both words
    /// appear somewhere in it.
    #[test]
    fn an_html_error_page_is_not_a_success() {
        let body = "<div class=\"alert alert-danger\">OTP was not sent. Try again later.</div>";
        assert!(VtopClient::interpret_resend_reply(body).is_err());
    }
}

#[cfg(test)]
mod menu_unavailable_tests {
    use super::is_menu_unavailable;

    /// The real refusal, trimmed. VTOP serves this with an HTTP 200, so nothing
    /// about the status says anything is wrong, and the fragment used to reach a
    /// parser — which returns an empty result for markup it cannot recognise.
    /// The screen then showed "no data" with no error and no log line.
    const REFUSAL: &str = r#"
        <div class="modal" tabindex="-1" id="msgBox">
          <div class="modal-body">
            <span class="text-danger fw-bold h6" id="msgBoxInfoText">
              This menu is not available at present!!!
            </span>
          </div>
        </div>
    "#;

    #[test]
    fn a_real_refusal_is_recognised() {
        assert!(is_menu_unavailable(REFUSAL));
    }

    #[test]
    fn a_real_page_is_not() {
        assert!(!is_menu_unavailable(
            r#"<table id="AttendanceDetailDataTable"><tr><td>1</td></tr></table>"#
        ));
    }

    #[test]
    fn an_empty_body_is_not() {
        assert!(!is_menu_unavailable(""));
    }

    /// VTOP writes "!!!" today. Matching them would make this hinge on
    /// punctuation that is not load-bearing.
    #[test]
    fn the_match_does_not_depend_on_the_exclamation_marks() {
        assert!(is_menu_unavailable(
            "<span>This menu is not available at present</span>"
        ));
    }
}
