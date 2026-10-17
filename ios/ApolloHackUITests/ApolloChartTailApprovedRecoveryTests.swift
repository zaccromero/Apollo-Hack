import XCTest

/// Workspace-only driver. Integration owns import, exclusive runtime, recording and outcome.
/// Direct human call_cc0c1feaf8d049fc9ba3fc32fe304d70: one shared six-minute tail recovery, ends15:19:30EDT.
/// No green controls/fullmatrix/retry/orders/watchlist/reset/owner namespace use.
final class ApolloChartTailApprovedRecoveryTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 120 }
    func testRemainingChartViewsOnly() {
        app = XCUIApplication()
        app.launchArguments = ["--apollo-test-storage=chart-tail-approved-" + UUID().uuidString]
        app.launch()
        let next = app.buttons["onboarding-continue"]
        if next.waitForExistence(timeout: 6) {
            tap(next)
            let risk = element("onboarding-risk-adventurous")
            XCTAssertTrue(risk.waitForExistence(timeout: 5)); tap(risk)
            tap(next); tap(next)
        }
        XCTAssertTrue(element("asset-card").waitForExistence(timeout: 15), app.debugDescription)
        // Learn opens exact asset identity without making a discovery decision or trade.
        app.tabBars.buttons["Learn"].tap()
        open("AAPL", title: "Apple")
        let events = element("chart-events")
        tapDisclosure(events, label: "Earnings and source events")
        let earnings = app.switches["chart-events-earnings"]
        reveal(earnings); XCTAssertTrue(earnings.exists)
        let before = earnings.value as? String
        // Existing failed event tapped row center x201; native thumb is at x~328.
        // Target observed right-hand native switch body, retain state assertion with bounded settling.
        earnings.coordinate(withNormalizedOffset: .init(dx: 0.90, dy: 0.50)).tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", before ?? "1"), object: earnings)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed, app.debugDescription)
        XCTAssertNotEqual(earnings.value as? String, before)
        capture("Approved tail 01 actual earnings toggle off")
        earnings.coordinate(withNormalizedOffset: .init(dx: 0.90, dy: 0.50)).tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", before ?? "1"), object: earnings)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 3), .completed, app.debugDescription)
        XCTAssertEqual(earnings.value as? String, before)
        tapDisclosure(events, label: "Earnings and source events")
        let table = element("chart-exact-table")
        tapDisclosure(table, label: "Exact OHLCV · latest 20 observed bars")
        XCTAssertTrue(textContaining("Saved daily observations; not live.").exists)
        capture("Approved tail 02 exact daily OHLCV")
        closeDetail()
        open("WINA", title: nil)
        let metric = app.buttons["financial-metric"]
        reveal(metric); XCTAssertTrue(metric.exists, app.debugDescription)
        XCTAssertTrue(element("financial-comparison-plot").exists)
        capture("Approved tail 03 WINA sourced revenue bars")
        metric.tap(); XCTAssertTrue(app.buttons["Royalties"].waitForExistence(timeout: 3)); app.buttons["Royalties"].tap()
        XCTAssertTrue(textContaining("Royalties · USD").exists, app.debugDescription)
        capture("Approved tail 04 WINA royalties picker")
        closeDetail()
        open("USDC-USD_DEMO", title: nil)
        let deviation = element("stablecoin-deviation-plot")
        reveal(deviation); XCTAssertTrue(deviation.exists, app.debugDescription)
        capture("Approved tail 05 USDC sourced deviation")
        let slider = app.sliders["stablecoin-scenario"]
        reveal(slider); XCTAssertTrue(slider.isHittable)
        capture("Approved tail 06 peg scenario before")
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertTrue(textContaining("$50.00").exists, app.debugDescription)
        capture("Approved tail 07 peg scenario after")
        closeDetail()
        open("DEMO_USD_BOND_20281115", title: nil)
        reveal(element("bond-cashflow-plot")); XCTAssertTrue(element("bond-cashflow-plot").exists, app.debugDescription)
        capture("Approved tail 08 fictional bond schedule")
        reveal(element("bond-sensitivity-plot")); XCTAssertTrue(element("bond-sensitivity-plot").exists)
        capture("Approved tail 09 bond sensitivity")
        closeDetail()
        open("DEMO_PATIENT_BUILDER", title: nil)
        reveal(element("category-allocation-plot")); XCTAssertTrue(element("category-allocation-plot").exists, app.debugDescription)
        capture("Approved tail 10 fictional strategy allocation")
        closeDetail()
        app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["portfolio-cash"].label, "$10,000.00", "Isolated paper cash unchanged; no orders performed")
        capture("Approved tail 11 isolated cash unchanged")
    }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func textContaining(_ value: String) -> XCUIElement { app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch }
    private func tap(_ target: XCUIElement) {
        reveal(target); XCTAssertTrue(target.exists && target.isHittable && target.isEnabled, app.debugDescription); target.tap()
    }
    private func open(_ id: String, title: String?) {
        tap(app.buttons["learn-asset-" + id])
        XCTAssertTrue(app.staticTexts["asset-detail-title"].waitForExistence(timeout: 5), app.debugDescription)
        if let title { XCTAssertEqual(app.staticTexts["asset-detail-title"].label, title) }
    }
    private func closeDetail() { app.buttons["detail-done"].tap(); XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 4)) }
    private func tapDisclosure(_ target: XCUIElement, label: String) {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if button.exists { tap(button) }
        else { tap(target) }
    }
    private func reveal(_ target: XCUIElement) {
        for _ in 0..<14 {
            let exists = target.exists
            let frame = exists ? target.frame : .zero
            if exists && target.isHittable && frame.midY > 110 && frame.midY < app.frame.height - 95 { return }
            let moveDown = target.exists && frame.midY < 130
            // Edge-only scroll avoids chart/card gestures and order controls.
            let a = app.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: moveDown ? 0.28 : 0.78))
            let b = app.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: moveDown ? 0.76 : 0.32))
            a.press(forDuration: 0.02, thenDragTo: b)
        }
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + " accessibility"; tree.lifetime = .keepAlways; add(tree)
    }
}
