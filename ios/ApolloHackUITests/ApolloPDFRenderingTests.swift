import XCTest

/// Fresh, bounded rendered-document acceptance; does not alter the closed URL-dispatch test.
final class ApolloPDFRenderingTests: XCTestCase {
    func testBothAppleSourceActionsRenderFinancialStatements() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--apollo-test-storage=pdf-render-" + UUID().uuidString, "--apollo-owner-comparison"]
        app.launch()
        XCTAssertTrue(app.buttons["compare-close"].waitForExistence(timeout: 15))
        app.buttons["compare-close"].tap()
        app.tabBars.buttons["Discover"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "asset-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let ticker = app.staticTexts["company-ticker"]
        XCTAssertTrue(ticker.waitForExistence(timeout: 5)); XCTAssertEqual(ticker.label, "AAPL")
        // Current stock cards browse company panels on tap; the explicit Research button opens asset details.
        let research = app.buttons["company-full-research"]
        for _ in 0..<12 {
            if research.exists && research.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(research.exists && research.isHittable); research.tap()
        XCTAssertTrue(app.navigationBars["AAPL"].waitForExistence(timeout: 5))
        let expected = URL(string: "https://www.apple.com/newsroom/pdfs/fy2026q3/FY26_Q3_Consolidated_Financial_Statements.pdf")!
        for id in ["AAPL-R2", "AAPL-R3"] {
            let source = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", id + " ·")).firstMatch
            for _ in 0..<25 {
                if source.exists && source.isHittable { break }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.75)).press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.30)))
            }
            XCTAssertTrue(source.exists && source.isHittable)
            capture(id + " native source action", app); source.tap()
            let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
            XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
            // Only dismiss the observed informational first-run screen. Never accept login/terms prompts.
            let intro = safari.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Safari search now shows personalized")).firstMatch
            if intro.waitForExistence(timeout: 3) {
                XCTAssertTrue(safari.buttons["Continue"].exists)
                safari.buttons["Continue"].tap()
                XCTAssertFalse(intro.waitForExistence(timeout: 1), "Safari setup overlay remained visible")
                // First-run setup can consume the initial navigation: repeat this SAME native source action.
                app.activate()
                XCTAssertTrue(source.waitForExistence(timeout: 5) && source.isHittable)
                source.tap()
                XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10))
            }
            let address = safari.textFields["Address"]
            XCTAssertTrue(address.waitForExistence(timeout: 10)); address.tap()
            let edited = safari.textFields.firstMatch
            XCTAssertTrue(edited.waitForExistence(timeout: 5))
            let completeURL = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (edited.value as? String ?? "").contains("FY26_Q3_Consolidated_Financial_Statements.pdf")
            }, object: edited)
            XCTAssertEqual(XCTWaiter.wait(for: [completeURL], timeout: 15), .completed, "Full PDF URL did not become available; do not accept collapsed domain")
            let raw = (edited.value as? String ?? "").replacingOccurrences(of: "\u{200E}", with: "").replacingOccurrences(of: "\u{200F}", with: "")
            let url = URL(string: raw.hasPrefix("http") ? raw : "https://" + raw)
            XCTAssertEqual(url?.scheme, "https")
            XCTAssertTrue(["apple.com", "www.apple.com"].contains(url?.host?.lowercased() ?? ""))
            XCTAssertEqual(url?.path, expected.path)
            attach(id + " actual URL", raw)
            // Submit the unchanged, validated URL to leave address editing and expose the document.
            let go = safari.keyboards.buttons["Go"]
            XCTAssertTrue(go.waitForExistence(timeout: 3), safari.debugDescription); go.tap()
            let operations = safari.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "CONSOLIDATED STATEMENTS OF OPERATIONS")).firstMatch
            let bodyVisible = operations.waitForExistence(timeout: 40)
            capture(id + " rendered PDF operations", safari)
            attach(id + " PDF accessibility tree", safari.debugDescription)
            XCTAssertTrue(bodyVisible, "Expected financial-statement body was not exposed; screenshot alone requires separate visual inspection")
            XCTAssertFalse(safari.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Safari search now shows personalized")).firstMatch.exists)
            if id == "AAPL-R3" {
                let cashFlows = safari.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "CONSOLIDATED STATEMENTS OF CASH FLOWS")).firstMatch
                for _ in 0..<8 {
                    if cashFlows.exists && cashFlows.frame.intersects(safari.frame) { break }
                    safari.swipeUp()
                }
                capture(id + " cash-flow page after manual scroll", safari)
                attach(id + " cash-flow accessibility tree", safari.debugDescription)
                XCTAssertTrue(cashFlows.exists && cashFlows.frame.intersects(safari.frame), "Cash-flow page not visible after bounded scroll; no automatic page-jump claim")
            }
            app.activate()
            XCTAssertTrue(app.navigationBars["AAPL"].waitForExistence(timeout: 5))
        }
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func attach(_ name: String, _ value: String) {
        let a = XCTAttachment(string: value); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
