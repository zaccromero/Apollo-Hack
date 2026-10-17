import XCTest
final class ApolloOwnerComparisonTests:XCTestCase {
    func testOwnerReadOnlyAppleStrategyWalkthroughStopsBeforeConfirmation() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=[];app.launch()
        let portfolio=app.tabBars.buttons["Portfolio"];XCTAssertTrue(portfolio.waitForExistence(timeout:10),app.debugDescription);portfolio.tap()
        let cash=app.staticTexts["portfolio-cash"],equity=app.staticTexts["portfolio-total"];XCTAssertTrue(cash.waitForExistence(timeout:5))
        let cashBefore=cash.label,equityBefore=equity.label,financialBefore=financialLabels(app)
        capture("Owner actual portfolio before read-only comparison",app)
        let compare=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Compare all three risk profiles")).firstMatch;reveal(compare,app);compare.tap()
        XCTAssertTrue(app.staticTexts["Compare all three profiles"].waitForExistence(timeout:10));capture("Owner Apple1 share versus fictional strategy read-only",app)
        for profile in ["conservative","balanced","adventurous"] {
            let button=app.buttons["compare-profile-"+profile];reveal(button,app);XCTAssertTrue(button.exists);button.tap()
            let title=app.staticTexts[profile.capitalized+" example"];reveal(title,app);XCTAssertTrue(title.exists);capture("Owner "+profile+" current portfolio investment strategy",app)
            let cashProjection=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Cash ")).firstMatch;reveal(cashProjection,app);XCTAssertTrue(cashProjection.exists);capture("Owner "+profile+" cash risk sentiment delta",app)
        }
        let scenarios=app.buttons["Allocations and scenario outcomes"];reveal(scenarios,app);scenarios.tap()
        let warning=app.staticTexts["Hypothetical sensitivity · not a forecast"];reveal(warning,app);XCTAssertTrue(warning.exists);capture("Owner hypothetical outcomes stop before any order",app)
        app.buttons["compare-close"].tap();XCTAssertTrue(cash.waitForExistence(timeout:5));XCTAssertEqual(cash.label,cashBefore);XCTAssertEqual(equity.label,equityBefore);XCTAssertEqual(financialLabels(app),financialBefore)
        capture("Owner unchanged cash profile holdings costs and thesis",app)
        reveal(compare,app);compare.tap();XCTAssertTrue(app.staticTexts["Compare all three profiles"].waitForExistence(timeout:5));capture("Owner read-only comparison foreground no confirmation",app);app.activate()
    }
    private func financialLabels(_ app:XCUIApplication)->[String] {app.staticTexts.allElementsBoundByIndex.map(\.label).filter{$0.hasPrefix("Cost ") || $0.hasPrefix("Reason:") || $0=="Simulated fill" || $0.contains(" · ceiling ")}.sorted()}
    private func reveal(_ e:XCUIElement,_ app:XCUIApplication){for _ in 0..<22 {if e.exists && e.isHittable{return};let down=e.exists && e.frame.midY<130;app.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:down ? 0.28 : 0.75)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:down ? 0.65 : 0.35)))}}
    private func capture(_ name:String,_ app:XCUIApplication){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
}
