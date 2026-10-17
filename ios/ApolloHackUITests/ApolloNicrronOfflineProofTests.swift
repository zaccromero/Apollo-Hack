import XCTest
// Prepared only. Integration owns import, execution, simulator lease, one-case cap and evidence export.
final class ApolloNicrronOfflineProofTests: XCTestCase {
    func testHistoricalSuccessThenProviderErrorOverHTTP() {
        continueAfterFailure = false
        executionTimeAllowance = 240
        let app = XCUIApplication()
        app.launchArguments = ["--apollo-backend-url=http://[::1]:8767", "--apollo-test-storage=nicrron-offline-" + UUID().uuidString, "--apollo-owner-comparison"]
        app.launch()
        let close = app.buttons["compare-close"]; XCTAssertTrue(close.waitForExistence(timeout: 20)); close.tap()
        app.tabBars.buttons["Learn"].tap()
        let winmark = app.buttons["learn-asset-WINA"]; reveal(winmark, app); XCTAssertTrue(winmark.exists); winmark.tap()
        XCTAssertTrue(app.navigationBars["WINA"].waitForExistence(timeout: 5))
        let open = app.buttons["detail-challenge-thesis"]; reveal(open, app); open.tap()
        for (title, id, value) in [("Why this investment?", "challenge-reason", "Review franchise evidence."), ("What could go wrong?", "challenge-risk", "Franchise performance may weaken."), ("What would change your mind?", "challenge-invalidation", "Changed source evidence.")] {
            let label = app.staticTexts[title]
            for _ in 0..<16 {
                let f = label.frame
                let ceiling = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY - 110 : app.frame.maxY - 140
                if label.exists && f.midY.isFinite && f.midY > 160 && f.midY < ceiling { break }
                drag(app, down: label.exists && (!f.midY.isFinite || f.midY < 160))
            }
            let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(field.exists); XCTAssertTrue(label.frame.midY.isFinite && label.frame.midY > 160)
            label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(CGVector(dx: 0, dy: 42)).tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3)); app.typeText(value)
            XCTAssertTrue((field.value as? String ?? "").contains(value))
        }
        let historical = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Assigned historical version: a12ef01a")).firstMatch
        reveal(historical, app); XCTAssertTrue(historical.exists)
        let current = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Current card research: f4ac7c6b")).firstMatch
        reveal(current, app); XCTAssertTrue(current.exists); capture("Historical a12e explicitly separate from current f4ac", app)
        let submit = app.buttons["challenge-thesis"]; reveal(submit, app); XCTAssertTrue(submit.isEnabled); submit.tap()
        let success = app.staticTexts["Thesis challenge from source notes"]; XCTAssertTrue(success.waitForExistence(timeout: 12)); reveal(success, app)
        XCTAssertTrue(app.staticTexts["OFFLINE TEST RESPONSE · no live provider execution is established."].exists); capture("Offline Nicrron fixture success", app)
        for id in ["leadership", "promises_results", "public_sentiment", "supporting_evidence", "opposing_evidence"] {
            let group = app.descendants(matching: .any).matching(identifier: "challenge-track-" + id).firstMatch
            reveal(group, app); XCTAssertTrue(group.exists); capture("Offline evidence group " + id, app)
        }
        let unknown = app.staticTexts.matching(NSPredicate(format: "label == %@", "Unknown · no relevant quoted evidence was supplied for this group.")).firstMatch
        XCTAssertTrue(unknown.exists)
        let excerpt = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Source note excerpt")).firstMatch; reveal(excerpt, app); XCTAssertTrue(excerpt.exists)
        let quote = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Quarter ended September 26, 2026: net income")).firstMatch
        reveal(quote, app); XCTAssertTrue(quote.exists)
        let interpretation = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Generated interpretation")).firstMatch; reveal(interpretation, app); XCTAssertTrue(interpretation.exists); capture("Exact source note versus generated interpretation", app)
        let process = app.buttons["See how Apollo checked this"]; reveal(process, app); process.tap()
        let nicrron = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Nicrron thesis challenge")).firstMatch
        reveal(nicrron, app); XCTAssertTrue(nicrron.exists); nicrron.tap(); capture("Nicrron role and offline provenance", app)
        // Second explicit action on the same retained draft returns HTTP502 typed provider_error.
        reveal(submit, app); XCTAssertTrue(submit.isEnabled); submit.tap()
        let error = app.staticTexts["Thesis challenge unavailable"]; XCTAssertTrue(error.waitForExistence(timeout: 12)); reveal(error, app)
        XCTAssertTrue(app.staticTexts["OFFLINE STATE FIXTURE — The research provider failed. No answer was substituted and no retry occurred."].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "challenge-track-promises_results").firstMatch.exists)
        capture("HTTP502 typed error without substituted answer", app)
        app.buttons["Done"].tap(); reveal(open, app); open.tap()
        let reason = app.descendants(matching: .any).matching(identifier: "challenge-reason").firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 5)); XCTAssertTrue((reason.value as? String ?? "").contains("Review franchise evidence."))
        capture("Draft survives return and reopen", app)
    }
    private func drag(_ app: XCUIApplication, down: Bool) { app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: down ? 0.30 : 0.55)).press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: down ? 0.50 : 0.35))) }
    private func reveal(_ e: XCUIElement, _ app: XCUIApplication) { for _ in 0..<22 { if e.exists && e.isHittable { return }; drag(app, down: e.exists && (!e.frame.midY.isFinite || e.frame.midY < 130)) } }
    private func capture(_ name: String, _ app: XCUIApplication) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
}
