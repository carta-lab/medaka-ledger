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
        app.launchArguments = ["-uiTestSampleData", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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
                let firstRow = app.buttons.matching(identifier: "lineageRow").firstMatch
                if firstRow.waitForExistence(timeout: 5) {
                    firstRow.tap()
                    sleepBriefly()
                    snapshot("10-血統図")
                }
            }
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
}
