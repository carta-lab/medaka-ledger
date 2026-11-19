import XCTest

/// v2 の導線を実際の Simulator 上で確認する。画面が無ければ失敗とし、実画面を PR に残す。
final class RedesignFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyLedgersAndTankCreation() {
        let app = launch(sample: false)
        XCTAssertTrue(app.buttons["resumeOnboardingButton"].waitForExistence(timeout: 10))
        capture("50-v2-empty-home")

        for (tab, title, action) in [
            ("容器", "容器がありません", "addFirstTankButton"),
            ("系統", "系統がありません", "addFirstStrainButton"),
            ("繁殖", "親魚セットがありません", "createBreedingSetButton"),
            ("販売", "販売の記録はまだありません", "addFirstSaleButton"),
        ] {
            tap(app.tabBars.buttons[tab])
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            capture("51-v2-empty-\(tab)")
            tap(app.buttons[action])
            XCTAssertTrue(app.buttons["キャンセル"].waitForExistence(timeout: 5))
            tap(app.buttons["キャンセル"])
        }

        tap(app.tabBars.buttons["容器"])
        tap(app.buttons["addTankButton"])
        let name = app.textFields["tankNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveTankButton"].isEnabled)
        name.tap()
        name.typeText("V2-01")
        XCTAssertTrue(app.buttons["saveTankButton"].isEnabled)
        capture("52-v2-tank-entry")
        tap(app.buttons["saveTankButton"])
        tap(app.alerts.buttons["閉じる"])
        let tank = app.buttons["tankCard.V2-01"]
        XCTAssertTrue(tank.waitForExistence(timeout: 5))
        tap(tank)
        XCTAssertTrue(app.navigationBars["V2-01"].waitForExistence(timeout: 5))
        capture("53-v2-created-tank")
    }

    @MainActor
    func testQuickRecordFormsAndCountUpdate() {
        let app = launch(sample: true)
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
        reveal(app.buttons["quickEggBatch"], in: app)
        tap(app.buttons["quickEggBatch"])
        XCTAssertTrue(app.navigationBars["採卵を記録"].waitForExistence(timeout: 5))
        capture("54-v2-egg-entry")
        tap(app.buttons["キャンセル"])

        reveal(app.buttons["quickWaterChange"], in: app)
        tap(app.buttons["quickWaterChange"])
        XCTAssertTrue(app.buttons["saveMaintenanceButton"].waitForExistence(timeout: 5))
        capture("55-v2-maintenance-entry")
        tap(app.buttons["キャンセル"])

        reveal(app.buttons["quickCount"], in: app)
        tap(app.buttons["quickCount"])
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quickCountRow.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let rowID = row.identifier
        let before = row.label
        tap(row)
        let amount = app.textFields["減った匹数"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveOperationButton"].isEnabled)
        amount.tap()
        amount.typeText("1")
        XCTAssertTrue(app.buttons["saveOperationButton"].isEnabled)
        capture("56-v2-count-entry")
        tap(app.buttons["saveOperationButton"])
        let changed = app.buttons[rowID]
        XCTAssertTrue(changed.waitForExistence(timeout: 5))
        XCTAssertNotEqual(changed.label, before, "保存した匹数が群の一覧に反映される")
        capture("57-v2-count-saved")
    }

    @MainActor
    func testSettingsBackupAndPurchaseRoutes() {
        let app = launch(sample: true)
        tap(app.buttons["settingsButton"])
        XCTAssertTrue(app.buttons["showPaywallButton"].waitForExistence(timeout: 10))
        capture("58-v2-settings")
        tap(app.buttons["showPaywallButton"])
        XCTAssertTrue(app.buttons["purchaseProButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["restoreProButton"].exists)
        capture("59-v2-pro")
        tap(app.buttons["paywallCloseButton"])

        reveal(app.buttons["exportBackupWithPhotos"], in: app)
        XCTAssertTrue(app.buttons["exportBackupWithPhotos"].isEnabled)
        XCTAssertTrue(app.buttons["importBackup"].exists)
        capture("60-v2-backup")
        let cultivation = app.buttons["cultivationSettingsLink"]
        reveal(cultivation, in: app)
        tap(cultivation)
        // 入力欄の種類（textField か別の要素）は表示の作りで変わるため、種類を問わず識別子で探す
        let degreeDays = app.descendants(matching: .any)["degreeDaysField"]
        let found = degreeDays.waitForExistence(timeout: 10)
        capture("61-v2-cultivation-settings")
        XCTAssertTrue(found)
        XCTAssertTrue(app.descendants(matching: .any)["defaultTempField"].exists)
        let reminder = app.descendants(matching: .any)["selectionReminderToggle"]
        reveal(reminder, in: app)
        XCTAssertTrue(reminder.exists)
        capture("62-v2-season-notifications")
    }

    @MainActor
    func testDetailOperationScreens() {
        let app = launch(sample: true)
        tap(app.tabBars.buttons["系統"])
        tap(app.buttons["strainRow.楊貴妃"])
        let cohort = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cohortRow.")).firstMatch
        reveal(cohort, in: app)
        tap(cohort)
        XCTAssertTrue(app.staticTexts["cohortCount"].waitForExistence(timeout: 5))
        capture("63-v2-cohort-detail")

        for action in ["move", "split", "selection", "sale"] {
            let button = app.buttons["cohortAction.\(action)"]
            reveal(button, in: app)
            tap(button)
            XCTAssertTrue(app.buttons["キャンセル"].waitForExistence(timeout: 5))
            capture("64-v2-operation-\(action)")
            tap(app.buttons["キャンセル"])
        }

        tap(app.tabBars.buttons["繁殖"])
        let batch = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "incubatingBatch.")).firstMatch
        reveal(batch, in: app)
        tap(batch)
        XCTAssertTrue(app.buttons["saveHatchButton"].waitForExistence(timeout: 5))
        capture("65-v2-hatch-entry")
    }

    @MainActor
    private func launch(sample: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            sample ? "-uiTestSampleData" : "-uiTestEmpty",
            "-hasCompletedOnboarding", "YES",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), file: file, line: line)
        element.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, file: file, line: line)
    }

    @MainActor
    private func capture(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !directory.isEmpty else { return }
        do {
            try shot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("スクリーンショットを保存できませんでした: \(error)")
        }
    }
}
