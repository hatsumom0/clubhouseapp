import XCTest

/// Drives the real Glyph sign-in flow far enough to verify the native
/// plumbing: splash → login screen → ASWebAuthenticationSession opens the
/// glyph-auth-bridge page → the bridge's Glyph connect step is reachable.
/// Requires the bridge dev server running on localhost:5173.
final class GlyphLoginFlowTests: XCTestCase {

    @MainActor
    func testGlyphSignInOpensBridgeInWebAuthSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset-auth"]
        app.launch()

        // Splash → login
        let forMembers = app.buttons["FOR MEMBERS"]
        XCTAssertTrue(forMembers.waitForExistence(timeout: 10), "Splash FOR MEMBERS button not found")
        forMembers.tap()

        // Login screen → trigger the real Glyph flow
        sleep(3)
        print("DEBUG-BUTTONS: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        print("DEBUG-TEXTS: \(app.staticTexts.allElementsBoundByIndex.map(\.label).prefix(20))")
        let glyphButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Sign in with Glyph'")
        ).firstMatch
        XCTAssertTrue(glyphButton.waitForExistence(timeout: 10), "Glyph sign-in button not found")
        glyphButton.tap()

        // ASWebAuthenticationSession consent alert ("...wants to use localhost to sign in")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let continueButton = springboard.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 10) {
            continueButton.tap()
        }

        // The bridge page should now be visible inside the auth sheet
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 20), "Web auth sheet did not appear")

        let bridgeSignIn = webView.buttons["Sign in with Glyph"]
        XCTAssertTrue(
            bridgeSignIn.waitForExistence(timeout: 20),
            "Bridge page did not render the Glyph sign-in button"
        )
        attachScreenshot(app, name: "bridge-loaded")

        // Tap through to the actual Glyph login — this is the step that
        // exercises the Privy cross-app popup inside the auth session.
        bridgeSignIn.tap()
        sleep(12) // give the Glyph/Privy handshake time to render whatever it will
        attachScreenshot(app, name: "after-glyph-connect")

        // Leave the sheet up briefly so an external screenshot can capture it too.
        sleep(5)
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
