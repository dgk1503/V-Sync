use lib_vtop::api::vtop::session_manager::SessionManager;
use lib_vtop::api::vtop::vtop_errors::VtopError;

/// Builds a `reqwest::Response` with the given status, without a network call.
///
/// The URL cannot be set this way — it comes from the request — so these cover
/// the status arm of the check. The "redirected to /login" arm needs a real
/// request and is left to the live path.
fn response(status: u16) -> reqwest::Response {
    reqwest::Response::from(http::Response::builder().status(status).body("").unwrap())
}

/// An expired CSRF token does not redirect to the login page: VTOP's stack
/// refuses the request before it is routed, and Tomcat answers with a bare 404.
/// Recognising that is what lets the caller re-authenticate instead of showing
/// the student an empty page.
#[test]
fn a_404_is_treated_as_an_expired_session() {
    let mut session = SessionManager::new();
    session.set_authenticated(true);

    assert!(session.check_session_expiration(&response(404)).is_err());
    assert!(
        !session.is_authenticated(),
        "an expiry must clear the authenticated flag, or the next call skips the login"
    );
}

/// A 5xx is the portal failing, not the session ending.
///
/// This used to be reported as an expiry, and the answer to an expiry is a
/// fresh credentials POST — which VTOP replies to with another OTP email. One
/// error page was therefore enough to mail a code for every request that
/// happened to be in flight, and for the app to lose a session that was never
/// gone.
#[test]
fn a_server_error_is_not_a_session_expiry() {
    let mut session = SessionManager::new();
    session.set_authenticated(true);

    let error = session.check_session_expiration(&response(500));
    assert!(
        matches!(error, Err(VtopError::VtopServerError)),
        "a 5xx must be reported as a server error, got {error:?}"
    );
    assert!(
        session.is_authenticated(),
        "a server error says nothing about the session and must not clear it"
    );
}

/// The portal's rate limiter answering 429 is the worst case to confuse with an
/// expiry: re-authenticating means another credentials POST, so a throttle
/// would be answered by asking VTOP for yet another OTP email.
#[test]
fn rate_limiting_is_not_a_session_expiry() {
    let mut session = SessionManager::new();
    session.set_authenticated(true);

    let error = session.check_session_expiration(&response(429));
    assert!(
        matches!(error, Err(VtopError::VtopServerError)),
        "a 429 is the portal throttling us, got {error:?}"
    );
    assert!(session.is_authenticated());
}

#[test]
fn a_normal_response_leaves_the_session_alone() {
    let mut session = SessionManager::new();
    session.set_authenticated(true);

    assert!(session.check_session_expiration(&response(200)).is_ok());
    assert!(session.is_authenticated());
}

/// VTOP answers a refused request with a 200 and a "menu is not available"
/// body, so the status alone cannot tell that apart. It is not a session
/// problem and must not trigger a re-login; detecting it is tracked separately.
#[test]
fn a_200_is_never_an_expiry_whatever_the_body_says() {
    let mut session = SessionManager::new();
    session.set_authenticated(true);

    assert!(session.check_session_expiration(&response(200)).is_ok());
    assert!(session.is_authenticated());
}
