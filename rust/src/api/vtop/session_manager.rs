use std::sync::Arc;

#[cfg(not(target_arch = "wasm32"))]
use reqwest::cookie::Jar;
pub use reqwest::Response;

use crate::api::vtop::vtop_errors::{VtopError, VtopResult};

/// Whether a URL path is VTOP's sign-in page.
///
/// `/vtop/login` and everything under it — `/vtop/login/error` is the page
/// that carries the OTP form. Deliberately not a substring search over the
/// whole URL: that also fires for any endpoint whose name happens to contain
/// `login`, and a false positive here costs a credentials POST.
fn is_login_path(path: &str) -> bool {
    let path = path.trim_end_matches('/');
    path == "/vtop/login" || path.starts_with("/vtop/login/")
}

#[derive(Debug)]

pub struct SessionManager {
    csrf_token: Option<String>,
    #[cfg(not(target_arch = "wasm32"))]
    cookie_store: Arc<Jar>,
    is_authenticated: bool,
}

impl SessionManager {
    pub fn new() -> Self {
        #[cfg(not(target_arch = "wasm32"))]
        let jar = Jar::default();
        #[cfg(not(target_arch = "wasm32"))]
        let cookie_store = Arc::new(jar);
        Self {
            csrf_token: None,
            #[cfg(not(target_arch = "wasm32"))]
            cookie_store,
            is_authenticated: false,
        }
    }

    pub fn set_csrf_token(&mut self, token: String) {
        self.csrf_token = Some(token);
    }

    pub fn get_csrf_token(&self) -> Option<String> {
        self.csrf_token.clone()
    }
    #[cfg(not(target_arch = "wasm32"))]
    pub fn get_cookie_store(&self) -> Arc<Jar> {
        self.cookie_store.clone()
    }

    pub fn set_authenticated(&mut self, authenticated: bool) {
        self.is_authenticated = authenticated;
    }

    pub fn is_authenticated(&self) -> bool {
        self.is_authenticated
    }

    pub fn clear(&mut self) {
        self.csrf_token = None;
        self.is_authenticated = false;
    }

    pub fn set_csrf_from_external(&mut self, token: String) {
        self.csrf_token = Some(token);
    }

    /// Checks whether a response means the session is gone, clearing the
    /// authenticated flag when it does.
    ///
    /// Exactly two shapes count, and both are the portal refusing us *because
    /// of the session*:
    ///
    /// - a bounce to the sign-in page (`/vtop/login...`), matched on the URL
    ///   path rather than on a substring of the whole URL;
    /// - a bare 404, which is what an expired CSRF token actually looks like:
    ///   VTOP's stack rejects the request before it is routed, and Tomcat
    ///   answers without a body.
    ///
    /// Everything else that is not 2xx — a 429 from the portal's rate limiter,
    /// a 5xx from its application server — is reported as a server error and
    /// leaves the session flag alone. That distinction is load-bearing. The
    /// answer to an expiry is a fresh credentials POST, and VTOP mails an OTP
    /// for every one of those it sees from an IP it has not verified, so
    /// calling an unrelated hiccup an expiry is how a single non-200 turned
    /// into a login per in-flight request — and several emails.
    pub fn check_session_expiration(&mut self, response: &Response) -> VtopResult<()> {
        if is_login_path(response.url().path()) {
            self.set_authenticated(false);
            return Err(VtopError::SessionExpired);
        }

        let status = response.status();
        if status.is_success() {
            return Ok(());
        }

        if status.as_u16() == 404 {
            self.set_authenticated(false);
            return Err(VtopError::SessionExpired);
        }

        Err(VtopError::VtopServerError)
    }

    //  pub fn set_cookie_from_external(&mut self, token: String) {
    //     self.csrf_token = Some(token);

    // }
}

#[cfg(test)]
mod login_path_tests {
    use super::is_login_path;

    #[test]
    fn the_sign_in_page_and_the_page_under_it_are_recognised() {
        assert!(is_login_path("/vtop/login"));
        assert!(is_login_path("/vtop/login/"));
        assert!(is_login_path("/vtop/login/error"));
    }

    /// The check used to be a substring search over the whole URL, which also
    /// fires for a portal page whose name happens to contain `login`. The cost
    /// of that mistake is a credentials POST, so the boundary has to be a
    /// path prefix.
    #[test]
    fn a_portal_page_is_not_mistaken_for_the_sign_in_page() {
        assert!(!is_login_path("/vtop/academics/common/StudentTimeTable"));
        assert!(!is_login_path("/vtop/student/payments"));
        assert!(!is_login_path("/vtop/loginActivity"));
    }
}
