import XCTest
final class ApolloOwnerLaunchTests:XCTestCase {
    func testUpdatedAppLaunchesNormalSavedSession() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=[];app.launch()
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:15),app.debugDescription)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Updated Apollo normal owner session no overrides";shot.lifetime = .keepAlways;add(shot)
        let tree=XCTAttachment(string:app.debugDescription);tree.name="Normal session read-only launch state";tree.lifetime = .keepAlways;add(tree)
        app.activate()
    }
}
