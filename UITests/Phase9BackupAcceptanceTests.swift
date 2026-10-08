import XCTest

final class Phase9BackupAcceptanceTests:XCTestCase {
    @MainActor private func launch(_ appearance:String,_ size:String)->XCUIApplication {
        let app=XCUIApplication();app.launchArguments=["-phase9-fixture","-phase9-screen","backup","-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size]
        app.launch();XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["backup.connect"].waitForExistence(timeout:15));return app
    }
    @MainActor private func capture(_ app:XCUIApplication,_ name:String){let item=XCTAttachment(screenshot:app.screenshot());item.name="Phase9-"+name;item.lifetime = .keepAlways;add(item)}
    @MainActor func testBackupRestoreVisualBoardsAndReachability(){
        for (appearance,size,label) in [("Light","UICTContentSizeCategoryL","Light-Standard"),("Dark","UICTContentSizeCategoryL","Dark-Standard"),("Light","UICTContentSizeCategoryAccessibilityXXXL","Light-Accessibility-XXXL")] {
            let app=launch(appearance,size);capture(app,label+"-GitHub-Configuration")
            XCTAssertTrue(app.secureTextFields["backup.pat"].exists);XCTAssertTrue(app.buttons["backup.connect"].isEnabled)
            for _ in 0..<8 where !app.buttons["backup.restore.confirm"].isHittable { app.swipeUp() }
            XCTAssertTrue(app.buttons["backup.restore.confirm"].exists);XCTAssertTrue(app.buttons["backup.restore.confirm"].isHittable)
            XCTAssertTrue(app.staticTexts["Private repository verified · manual backup ready"].exists)
            capture(app,label+"-Export-Restore-Preview");app.terminate()
        }
    }
}
