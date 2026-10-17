import XCTest
final class ApolloCompactComparisonTests:XCTestCase {
    func testThreeProfilesAndOutcomesDoNotSelectProfileOrOrder() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--apollo-test-storage=compare-current-"+UUID().uuidString,"--apollo-owner-comparison"];app.launch()
        XCTAssertTrue(app.staticTexts["Compare all three profiles"].waitForExistence(timeout:15),app.debugDescription)
        capture("New compact all three profile comparison",app)
        for profile in ["conservative","balanced","adventurous"] {
            let button=app.buttons["compare-profile-"+profile];reveal(button,app);XCTAssertTrue(button.exists);button.tap()
            let heading=app.staticTexts[profile.capitalized+" example"];reveal(heading,app);XCTAssertTrue(heading.exists)
            capture(profile+" current investment and fictional strategy example",app)
        }
        let outcomes=app.buttons["Allocations and scenario outcomes"];reveal(outcomes,app);XCTAssertTrue(outcomes.exists);outcomes.tap()
        let warning=app.staticTexts["Hypothetical sensitivity · not a forecast"];reveal(warning,app);XCTAssertTrue(warning.exists);capture("Explicit hypothetical scenario outcomes",app)
        let shock=app.buttons["+20%"];reveal(shock,app);XCTAssertTrue(shock.exists);shock.tap();capture("Plus20percent demo sensitivity",app)
        let notice=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","No profile was selected for you.")).firstMatch;reveal(notice,app);XCTAssertTrue(notice.exists)
        app.buttons["compare-close"].tap();let cash=app.staticTexts["portfolio-cash"];XCTAssertTrue(cash.waitForExistence(timeout:5));XCTAssertEqual(cash.label,"$10,000.00")
        XCTAssertTrue(app.staticTexts["No profile selected"].exists || app.buttons["portfolio-risk-profile"].exists || app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","No risk profile")).count>0)
        capture("Unchanged paper account after comparison",app)
    }
    private func reveal(_ e:XCUIElement,_ app:XCUIApplication){for _ in 0..<20{if e.exists && e.isHittable{return};let down=e.exists && e.frame.midY<130;app.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:down ? 0.28 : 0.75)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:down ? 0.65 : 0.35)))}}
    private func capture(_ name:String,_ app:XCUIApplication){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
}
