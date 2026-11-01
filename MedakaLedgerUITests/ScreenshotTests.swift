import XCTest

// 主要画面のスクリーンショットを撮るためだけのUIテスト（ARCHITECTURE.md 8）。
// 画面の動作は検証しない。CIでは SCREENSHOT_DIR に PNG を書き出し、PRに貼る（DECISIONS.md A）。

final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureMainScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSampleData", "-hasCompletedOnboarding", "YES", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
        snapshot("01-ホーム")

        tapTab(app, "容器")
        snapshot("02-容器一覧")

        let card = app.buttons["tankCard.A-1"]
        if card.waitForExistence(timeout: 5) {
            card.tap()
            _ = app.navigationBars["A-1"].waitForExistence(timeout: 5)
            snapshot("03-容器詳細")
        }

        tapTab(app, "繁殖")
        snapshot("07-繁殖")
        let setRow = app.buttons.matching(identifier: "breedingSetRow").firstMatch
        if setRow.waitForExistence(timeout: 5) {
            setRow.tap()
            sleepBriefly()
            snapshot("08-親魚セット詳細")
        }

        tapTab(app, "系統")
        snapshot("04-系統一覧")

        let strainRow = app.buttons["strainRow.楊貴妃"]
        if strainRow.waitForExistence(timeout: 5) {
            strainRow.tap()
            sleepBriefly()
            snapshot("05-系統詳細")

            let cohortRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cohortRow.")).firstMatch
            if cohortRow.waitForExistence(timeout: 5) {
                cohortRow.tap()
                sleepBriefly()
                snapshot("06-群詳細")
                app.navigationBars.buttons.firstMatch.tap()
                sleepBriefly()
            }

            // 血統図：系統詳細の「血統図」タブから、いちばん新しい世代の群を開く
            let lineageTab = app.segmentedControls.buttons["血統図"]
            if lineageTab.waitForExistence(timeout: 5) {
                lineageTab.tap()
                sleepBriefly()
                snapshot("09-系統詳細の血統図")
                let salesTab = app.segmentedControls.buttons["販売"]
                if salesTab.waitForExistence(timeout: 5) {
                    salesTab.tap()
                    sleepBriefly()
                    snapshot("13-系統詳細の販売")
                    lineageTab.tap()
                    sleepBriefly()
                }
                let firstRow = app.buttons.matching(identifier: "lineageRow").firstMatch
                if firstRow.waitForExistence(timeout: 5) {
                    firstRow.tap()
                    sleepBriefly()
                    snapshot("10-血統図")
                }
            }
        }

        captureSalesAndSettings(app)
    }

    /// 販売台帳（全期間）、販売記録のシート、設定のバックアップ。
    @MainActor
    private func captureSalesAndSettings(_ app: XCUIApplication) {
        tapTab(app, "販売")
        let all = app.segmentedControls.buttons["全期間"]
        if all.waitForExistence(timeout: 5) {
            all.tap()
            sleepBriefly()
        }
        snapshot("11-販売台帳")

        let menu = app.buttons["salesMenu"]
        if menu.waitForExistence(timeout: 5) {
            menu.tap()
            let add = app.buttons["販売を記録"]
            if add.waitForExistence(timeout: 5) {
                add.tap()
                sleepBriefly()
                snapshot("12-販売記録")
                let cancel = app.buttons["キャンセル"]
                if cancel.waitForExistence(timeout: 5) {
                    cancel.tap()
                    sleepBriefly()
                }
            }
        }

        tapTab(app, "ホーム")
        let settings = app.buttons["settingsButton"]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            sleepBriefly()
            snapshot("14-設定")
            app.swipeUp()
            app.swipeUp()
            sleepBriefly()
            snapshot("15-設定のバックアップ")
        }
    }

    @MainActor
    private func tapTab(_ app: XCUIApplication, _ title: String) {
        let tab = app.tabBars.buttons[title]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            sleepBriefly()
        }
    }

    @MainActor
    private func sleepBriefly() {
        // 画面遷移のアニメーションが終わるのを待つ
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.0)
    }

    @MainActor
    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !directory.isEmpty else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            print("screenshot write failed: \(error)")
        }
    }

    // MARK: - 第5週

    /// 初回の案内（3ページ）。空のストアで、案内が済んでいない状態から始める。
    @MainActor
    func testCaptureOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestEmpty", "-hasCompletedOnboarding", "NO", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        let next = app.buttons["onboardingNext"]
        if next.waitForExistence(timeout: 10) {
            snapshot("20-案内1")
            next.tap()
            sleepBriefly()
            snapshot("21-案内2-容器")
            if next.waitForExistence(timeout: 5) {
                next.tap()
                sleepBriefly()
                let name = app.textFields["onboardingBreedName"]
                if name.waitForExistence(timeout: 5) {
                    name.tap()
                    name.typeText("楊貴妃")
                }
                snapshot("22-案内3-系統")
            }
        }
    }

    /// Free：Paywall（設定のProから）。サンプルを入れた状態。
    @MainActor
    func testCaptureFreePaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSampleData", "-hasCompletedOnboarding", "YES", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        let settings = app.buttons["settingsButton"]
        if settings.waitForExistence(timeout: 10) {
            settings.tap()
            let paywall = app.buttons["showPaywallButton"]
            for _ in 0..<6 where !paywall.exists { app.swipeUp() }
            snapshot("23-設定のPro")
            if paywall.waitForExistence(timeout: 5) {
                paywall.tap()
                sleepBriefly()
                snapshot("24-Paywall")
            }
        }
    }

    /// Pro：出品文、年別の集計、設定の雛形。
    @MainActor
    func testCaptureProScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSampleData", "-uiTestPro", "-hasCompletedOnboarding", "YES", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)

        tapTab(app, "販売")
        let all = app.segmentedControls.buttons["全期間"]
        if all.waitForExistence(timeout: 5) {
            all.tap()
            sleepBriefly()
        }
        snapshot("25-販売台帳のPro")

        let menu = app.buttons["salesMenu"]
        if menu.waitForExistence(timeout: 5) {
            menu.tap()
            let listing = app.buttons["listingMenuItem"]
            if listing.waitForExistence(timeout: 5) {
                listing.tap()
                sleepBriefly()
                let picker = app.buttons["listingCohortPicker"]
                if picker.waitForExistence(timeout: 5) {
                    picker.tap()
                    sleepBriefly()
                    let first = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "F1")).firstMatch
                    if first.waitForExistence(timeout: 5) {
                        first.tap()
                        sleepBriefly()
                    }
                }
                snapshot("26-出品文")
            }
        }
    }

    // MARK: - ダークモードと大きな文字

    /// ダークモード：ホーム、容器一覧、群詳細。
    @MainActor
    func testCaptureDarkMode() {
        captureAppearance(prefix: "30-ダーク", extra: ["-AppleInterfaceStyle", "Dark"])
    }

    /// 文字を最大級に大きくした状態：ホーム、容器一覧、群詳細。
    @MainActor
    func testCaptureLargeText() {
        captureAppearance(prefix: "40-大文字", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
    }

    @MainActor
    private func captureAppearance(prefix: String, extra: [String]) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSampleData", "-hasCompletedOnboarding", "YES", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] + extra
        app.launch()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
        snapshot("\(prefix)-ホーム")

        tapTab(app, "容器")
        snapshot("\(prefix)-容器一覧")

        tapTab(app, "系統")
        let strainRow = app.buttons["strainRow.楊貴妃"]
        if strainRow.waitForExistence(timeout: 5) {
            strainRow.tap()
            sleepBriefly()
            let cohortRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cohortRow.")).firstMatch
            if cohortRow.waitForExistence(timeout: 5) {
                cohortRow.tap()
                sleepBriefly()
                snapshot("\(prefix)-群詳細")
            }
        }
    }
}
