import XCTest
final class ApolloProviderRecoveryTests:XCTestCase {
    func testFinalAuthorizedDisclosureCapture() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--apollo-backend-url=http://127.0.0.1:8769","--apollo-test-storage=provider-recovery-"+UUID().uuidString,"--apollo-owner-comparison"];app.launch()
        let close=app.buttons["compare-close"];XCTAssertTrue(close.waitForExistence(timeout:20));close.tap();app.tabBars.buttons["Learn"].tap()
        let stocks=app.buttons.matching(NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@","Stock","Which source would change your view"));let winmark=stocks.element(boundBy:1);reveal(winmark,app);XCTAssertTrue(winmark.exists);winmark.tap();XCTAssertTrue(app.navigationBars["WINA"].waitForExistence(timeout:5))
        let challenge=app.buttons["detail-challenge-thesis"];reveal(challenge,app);challenge.tap()
        for (title,id,value) in [("Why this investment?","challenge-reason","Review franchise evidence."),("What could go wrong?","challenge-risk","Franchise performance may weaken."),("What would change your mind?","challenge-invalidation","Changed source evidence.")] {
            let label=app.staticTexts[title]
            for _ in 0..<16 {
                let f=label.frame
                let ceiling=app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY-110 : app.frame.maxY-140
                if label.exists && f.midY.isFinite && f.midY>160 && f.midY<ceiling {break}
                drag(app,down:label.exists && (!f.midY.isFinite || f.midY<160))
            }
            let field=app.descendants(matching:.any).matching(identifier:id).firstMatch
            XCTAssertTrue(field.exists);XCTAssertTrue(label.frame.midY.isFinite && label.frame.midY>160,app.debugDescription);label.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:1)).withOffset(CGVector(dx:0,dy:42)).tap();XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:3));app.typeText(value);XCTAssertTrue((field.value as? String ?? "").contains(value))
        }
        let context=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Assigned historical version:")).firstMatch;reveal(context,app);capture("Assigned historical source version",app)
        let current=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Current card research:")).firstMatch;reveal(current,app);XCTAssertTrue(current.exists);capture("Current and historical corpus remain separate",app)
        let submit=app.buttons["challenge-thesis"];reveal(submit,app);XCTAssertTrue(submit.isEnabled);submit.tap()
        let paused=app.staticTexts["Provider calls are paused"];XCTAssertTrue(paused.waitForExistence(timeout:15));reveal(paused,app);capture("Actual paused HTTP503 no model result",app)
        let process=app.buttons["See how Apollo checked this"];reveal(process,app);XCTAssertTrue(process.exists);process.tap();capture("Recorded five-step process overview",app)
        for title in ["Question & source version","PRISM passages","Nicrron thesis challenge","Apollo source/response checks","PRISM trace status"] {
            let label=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@",title)).firstMatch;reveal(label,app);XCTAssertTrue(label.exists);label.tap();position(label,app);capture(title+" actual recorded state and detail",app)
        }
        let saved=app.buttons["Saved sponsor evidence"];reveal(saved,app);XCTAssertTrue(saved.exists);saved.tap();position(saved,app);capture("Saved historical sponsor evidence separate from current path",app)
    }
    private func drag(_ app:XCUIApplication,down:Bool){app.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:down ? 0.30 : 0.55)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:down ? 0.50 : 0.35)))}
    private func reveal(_ e:XCUIElement,_ app:XCUIApplication){for _ in 0..<28{if e.exists && e.isHittable{return};if e.exists {let f=e.frame;drag(app,down:!f.midY.isFinite || f.midY<130)} else {drag(app,down:false)}}}
    private func position(_ e:XCUIElement,_ app:XCUIApplication){for _ in 0..<8{guard e.exists else{return};let y=e.frame.midY;if y>160 && y<300{return};drag(app,down:y<160)}}
    private func capture(_ name:String,_ app:XCUIApplication){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
}
