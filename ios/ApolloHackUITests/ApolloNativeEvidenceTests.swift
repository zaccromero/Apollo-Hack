import XCTest
final class ApolloNativeEvidenceTests:XCTestCase {
    func testCurrentResearchAndPausedProviderTrail() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--apollo-backend-url=http://127.0.0.1:8769","--apollo-test-storage=evidence-"+UUID().uuidString,"--apollo-owner-comparison"];app.launch()
        let done=app.buttons["Done"];XCTAssertTrue(done.waitForExistence(timeout:20));done.tap();app.tabBars.buttons["Discover"].tap()
        let card=app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch;XCTAssertTrue(card.waitForExistence(timeout:15));card.tap()
        XCTAssertTrue(app.staticTexts["asset-detail-title"].waitForExistence(timeout:5));capture("Apple actual cached chart detail",app)
        let evidence=app.buttons["Evidence"];reveal(evidence,app);evidence.tap()
        for title in ["Leadership","Promises vs results","Public sentiment"] {
            let track=app.staticTexts[title];reveal(track,app);XCTAssertTrue(track.exists);capture(title+" current Apple evidence",app)
        }
        let sources=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Published"))
        XCTAssertGreaterThan(sources.count,0)
        let source=sources.element(boundBy:sources.count-1)
        reveal(source,app);XCTAssertTrue(source.exists);XCTAssertTrue(source.isEnabled);capture("Apple dated source action",app)
        app.buttons["detail-done"].tap();app.tabBars.buttons["Learn"].tap()
        // Current HTTP catalog was read and verified AAPL then WINA; Learn uses that same order.
        let stocks=app.buttons.matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@","Stock","Which source would change your view"))
        let winmark=stocks.element(boundBy:1);reveal(winmark,app);XCTAssertTrue(winmark.exists);winmark.tap()
        XCTAssertTrue(app.navigationBars["WINA"].waitForExistence(timeout:5),app.debugDescription)
        let challenge=app.buttons["detail-challenge-thesis"];reveal(challenge,app);challenge.tap()
        let context=app.descendants(matching:.any).matching(identifier:"challenge-context-notice").firstMatch;reveal(context,app);capture("Assigned historical corpus versus current card",app)
        for (id,value) in [("challenge-reason","Review Winmark franchise evidence."),("challenge-risk","Franchise performance may weaken."),("challenge-invalidation","Changed source evidence would change this thesis.")] {
            let field=app.textFields[id];reveal(field,app);XCTAssertTrue(field.exists);field.tap();field.typeText(value);app.swipeUp()
        }
        let submit=app.buttons["challenge-thesis"];reveal(submit,app);XCTAssertTrue(submit.isEnabled);capture("Historical versus current corpus before request",app);submit.tap()
        let paused=app.staticTexts["Provider calls are paused"];reveal(paused,app);XCTAssertTrue(paused.waitForExistence(timeout:15));capture("Actual HTTP paused provider response",app)
        let process=app.descendants(matching:.any).matching(identifier:"challenge-process").firstMatch;reveal(process,app);XCTAssertTrue(process.exists);process.tap();capture("Actual recorded process trail",app)
        let saved=app.buttons["Saved sponsor evidence"];reveal(saved,app);XCTAssertTrue(saved.exists);saved.tap();capture("Separate historical sponsor evidence",app)
    }
    private func reveal(_ element:XCUIElement,_ app:XCUIApplication) {
        for _ in 0..<18 {if element.exists && element.isHittable{return};let down=element.exists && element.frame.midY < 100;app.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:down ? 0.27 : 0.78)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.92,dy:down ? 0.78 : 0.27)))}
    }
    private func capture(_ name:String,_ app:XCUIApplication){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
}
