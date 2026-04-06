import XCTest
@testable import ADHDAlarm

final class ArchitectureChecklistTests: XCTestCase {

    func testNavigationView_IsNotUsedAnywhereInAppSource() throws {
        let sourceFiles = try appSourceFiles()
        let offenders = try sourceFiles.filter { url in
            try sourceText(relativePath: relativePath(for: url)).contains("NavigationView")
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "NavigationView は使わない方針のため、検出ファイル: \(offenders.map { relativePath(for: $0) })"
        )
    }

    func testEventRow_UsesRectangleContentShape() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/EventRow.swift")
        XCTAssertTrue(source.contains(".contentShape(Rectangle())"))
    }

    func testFamilySendTab_TemplateCardUsesRectangleContentShape() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilySendTab.swift")
        XCTAssertTrue(source.contains(".contentShape(Rectangle())"))
    }

    func testPersonHomeView_FABUsesCircleContentShape() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")
        XCTAssertTrue(source.contains(".contentShape(Circle())"))
    }

    func testPersonHomeView_CollapseButtonsUseRectangleContentShape() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")
        let marker = ".frame(minHeight: ComponentSize.small)\n                    }\n                    .contentShape(Rectangle())"
        let count = source.components(separatedBy: marker).count - 1

        XCTAssertGreaterThanOrEqual(count, 4, "今日/明日以降の展開・折りたたみボタンにcontentShapeを付けること")
    }

    func testSettingsViews_UseRectangleContentShapeForSettingRows() throws {
        let settingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")
        let advancedSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/AdvancedSettingsView.swift")

        XCTAssertTrue(settingsSource.contains(".contentShape(Rectangle())"))
        XCTAssertTrue(advancedSource.contains(".contentShape(Rectangle())"))
    }

    func testComponentSizes_KeepTapTargetsAtLeastFortyFourPoints() {
        XCTAssertGreaterThanOrEqual(ComponentSize.small, 44)
        XCTAssertGreaterThanOrEqual(ComponentSize.settingRow, 44)
        XCTAssertGreaterThanOrEqual(ComponentSize.eventRow, 44)
        XCTAssertGreaterThanOrEqual(ComponentSize.fab, 44)
        XCTAssertGreaterThanOrEqual(ComponentSize.inputField, 44)
    }

    func testToastBannerView_UsesRegularMaterialForOwlTip() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Shared/ToastBannerView.swift")
        XCTAssertTrue(source.contains(".background(.regularMaterial)"))
    }

    func testToastBannerView_ErrorToastComesFromTop() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Shared/ToastBannerView.swift")
        XCTAssertTrue(source.contains(".transition(.move(edge: .top).combined(with: .opacity))"))
    }

    func testRootView_BranchesByOnboardingStateAndAppMode() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        XCTAssertTrue(source.contains("if !appState.isOnboardingComplete || appState.appMode == nil"))
        XCTAssertTrue(source.contains("ModeSelectionView()"))
        XCTAssertTrue(source.contains("} else if appState.appMode == .person {"))
        XCTAssertTrue(source.contains("PersonHomeView()"))
        XCTAssertTrue(source.contains("FamilyHomeView()"))
    }

    func testAppDelegate_SetsForegroundNotificationDelegate() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")
        XCTAssertTrue(source.contains("UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared"))
    }

    func testSettingsAndPaywalls_ArePresentedBySheet() throws {
        let personHomeSource = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")
        let settingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")
        let advancedSettingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/AdvancedSettingsView.swift")
        let familyPaywallSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyPaywallView.swift")

        XCTAssertTrue(personHomeSource.contains(".sheet(isPresented: $viewModel.showSettings)"))
        XCTAssertTrue(personHomeSource.contains(".sheet(isPresented: $showPaywall)"))
        XCTAssertFalse(personHomeSource.contains(".fullScreenCover(isPresented: $viewModel.showSettings)"))
        XCTAssertFalse(personHomeSource.contains(".fullScreenCover(isPresented: $showPaywall)"))

        XCTAssertTrue(settingsSource.contains(".sheet(isPresented: $showPaywall)"))
        XCTAssertTrue(advancedSettingsSource.contains(".sheet(isPresented: $showPaywall)"))
        XCTAssertTrue(familyPaywallSource.contains(".sheet(isPresented: $showStoreKitPaywall)"))
    }

    func testFullScreenCover_IsOnlyUsedToPresentRingingView() throws {
        let matchedPaths = try appSourceFiles()
            .filter { url in
                let path = relativePath(for: url)
                let source = try sourceText(relativePath: path)
                return source.contains(".fullScreenCover(")
            }
            .map(relativePath(for:))
            .sorted()

        XCTAssertEqual(
            matchedPaths,
            [
                "ADHDAlarm/ADHDAlarmApp.swift",
                "ADHDAlarm/Views/Onboarding/MagicDemoView.swift",
            ]
        )

        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")
        let magicDemoSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoView.swift")

        XCTAssertTrue(appSource.contains("RingingView(alarm: alarm)"))
        XCTAssertTrue(magicDemoSource.contains("RingingView(alarm: demoAlarm)"))
    }

    func testScenePhaseActive_RefreshesNotificationPermissionStatuses() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        XCTAssertTrue(source.contains("if newPhase == .active {"))
        XCTAssertTrue(source.contains("permissionsService.refreshStatuses()"))
    }

    func testMagicDemo_MarkesOutputVolumeDetectionAsUnreliable() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoView.swift")

        XCTAssertTrue(source.contains("⚠️⚠️⚠️ マナーモード検知の制限について"))
        XCTAssertTrue(source.contains("この検知は不確実であり AlarmKit の動作には影響しない。"))
        XCTAssertTrue(source.contains("この検知ロジックに依存した「アラームが鳴らない」ケースを作ってはいけない。"))
        XCTAssertTrue(source.contains("outputVolume <= 0.1"))
    }

    func testWidget_NoInteractiveCompletionPathRemains() throws {
        let widgetSources = try widgetSourceFiles().map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")

        XCTAssertFalse(widgetSources.contains("CompleteAlarmIntent"), "旧完了AppIntentを残さないこと")
        XCTAssertFalse(widgetSources.contains("予定を完了にする"), "旧完了アクション文言を残さないこと")
        XCTAssertFalse(widgetSources.contains("✓ 済み"), "旧完了ボタン文言を残さないこと")
        XCTAssertFalse(widgetSources.contains("Button(intent:"), "ウィジェットから完了操作する導線を残さないこと")
    }

    func testWidget_EmptyStatesDoNotShowLegacyCompletionButtonArea() throws {
        let source = try sourceText(relativePath: "ADHDAlarmWidget/ADHDAlarmWidget.swift")

        XCTAssertTrue(source.contains("private var emptyView"))
        XCTAssertTrue(source.contains("if entry.todayAlarms.isEmpty"))
        XCTAssertFalse(source.contains("Button("), "現行ウィジェットに旧完了ボタンを置かないこと")
    }

    func testWidget_TimelineRefreshStillDependsOnAppSideReloads() throws {
        let providerSource = try sourceText(relativePath: "ADHDAlarmWidget/WidgetDataProvider.swift")
        let alarmStoreSource = try sourceText(relativePath: "ADHDAlarm/Services/AlarmEventStore.swift")
        let inputSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/InputViewModel.swift")
        let ringingSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/RingingViewModel.swift")

        XCTAssertTrue(providerSource.contains("読み取りのみ"), "ウィジェット側は読み取り専用を維持すること")
        XCTAssertTrue(alarmStoreSource.contains("WidgetCenter.shared.reloadAllTimelines()"))
        XCTAssertTrue(inputSource.contains("WidgetCenter.shared.reloadAllTimelines()"))
        XCTAssertTrue(ringingSource.contains("WidgetCenter.shared.reloadAllTimelines()"))
    }

    func testWidgetExtension_DoesNotWriteToAppGroupUserDefaults() throws {
        let widgetSources = try widgetSourceFiles().map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")

        XCTAssertFalse(widgetSources.contains("UserDefaults(suiteName: Constants.appGroupID)?.set("))
        XCTAssertFalse(widgetSources.contains("UserDefaults(suiteName: \"group.com.yosuke.WasurenboAlarm\")?.set("))
    }

    func testCompleteAlarmIntent_DoesNotWriteToAppGroupUserDefaults() throws {
        let intentRoot = repoRootURL().appendingPathComponent("ADHDAlarm/AppIntents")
        let enumerator = FileManager.default.enumerator(at: intentRoot, includingPropertiesForKeys: nil)
        let intentSources = (enumerator?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "swift" }
        let combinedSource = try intentSources
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        XCTAssertFalse(combinedSource.contains("struct CompleteAlarmIntent"))
        XCTAssertFalse(combinedSource.contains("class CompleteAlarmIntent"))
        XCTAssertFalse(combinedSource.contains("UserDefaults(suiteName: Constants.appGroupID)?.set("))
    }

    func testXPAddition_OnlyRunsInMainAppProcess() throws {
        let widgetSources = try widgetSourceFiles().map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        let intentRoot = repoRootURL().appendingPathComponent("ADHDAlarm/AppIntents")
        let enumerator = FileManager.default.enumerator(at: intentRoot, includingPropertiesForKeys: nil)
        let intentSources = (enumerator?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "swift" }
        let intentCombinedSource = try intentSources
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        let appStateSource = try sourceText(relativePath: "ADHDAlarm/App/AppState.swift")

        XCTAssertTrue(appStateSource.contains("func addXP(_ amount: Int)"))
        XCTAssertFalse(widgetSources.contains("addXP("))
        XCTAssertFalse(intentCombinedSource.contains("addXP("))
    }

    func testTodayBoundary_UsesCurrentCalendarWithoutUTCConversion() throws {
        let appStateSource = try sourceText(relativePath: "ADHDAlarm/App/AppState.swift")
        let personHomeViewModelSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/PersonHomeViewModel.swift")
        let syncEngineSource = try sourceText(relativePath: "ADHDAlarm/Services/SyncEngine.swift")
        let combined = [appStateSource, personHomeViewModelSource, syncEngineSource].joined(separator: "\n")

        XCTAssertTrue(combined.contains("Calendar.current.isDateInToday("))
        XCTAssertFalse(combined.localizedCaseInsensitiveContains("utc"))
        XCTAssertFalse(combined.contains("TimeZone(secondsFromGMT: 0)"))
    }

    func testWidgetGuideView_CanBeSkippedLater() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/WidgetGuideView.swift")

        XCTAssertTrue(source.contains("Button(\"あとでやる\")"))
        XCTAssertTrue(source.contains("finishOnboarding()"))
    }

    func testWidgetGuideView_IsPartOfOnboardingFlow() throws {
        let magicDemoSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoView.swift")
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        XCTAssertTrue(magicDemoSource.contains("appState.onboardingPath.append(OnboardingDestination.widgetGuide)"))
        XCTAssertTrue(appSource.contains("case .widgetGuide:      WidgetGuideView()"))
    }

    func testWidget_SupportsMediumFamilyAndReadsOwlXPFromAppGroup() throws {
        let source = try sourceText(relativePath: "ADHDAlarmWidget/ADHDAlarmWidget.swift")

        XCTAssertTrue(source.contains("case .systemMedium: mediumView(alarm: alarm)"))
        XCTAssertTrue(source.contains(".supportedFamilies([.systemSmall, .systemMedium, .systemLarge])"))
        XCTAssertTrue(source.contains("UserDefaults(suiteName: \"group.com.yosuke.WasurenboAlarm\")?.integer(forKey: \"owl_xp\")"))
    }

    func testWidget_UsesContainerBackgroundForWidgetSurfaces() throws {
        let source = try sourceText(relativePath: "ADHDAlarmWidget/ADHDAlarmWidget.swift")
        let count = source.components(separatedBy: ".containerBackground(.fill.tertiary, for: .widget)").count - 1

        XCTAssertGreaterThanOrEqual(count, 4, "ウィジェット面は containerBackground(for: .widget) を使うこと")
    }

    func testPronunciationMap_IsExtractedAsDedicatedConstant() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Services/VoiceFileGenerator.swift")

        XCTAssertTrue(source.contains("private nonisolated static let pronunciationMap"))
        XCTAssertTrue(source.contains("pronunciationMap.reduce(text)"))
    }

    func testWidgetGuideView_UsesSwipeCarouselWithFourPagesAndIndicators() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/WidgetGuideView.swift")

        XCTAssertTrue(source.contains("TabView(selection: $currentPage)"))
        XCTAssertTrue(source.contains(".tabViewStyle(.page(indexDisplayMode: .always))"))
        XCTAssertTrue(source.contains("private let pageInstructions = ["))
        XCTAssertEqual(source.components(separatedBy: "\"① ").count - 1, 1)
        XCTAssertEqual(source.components(separatedBy: "\"②").count - 1, 1)
        XCTAssertEqual(source.components(separatedBy: "\"③").count - 1, 1)
        XCTAssertEqual(source.components(separatedBy: "\"④").count - 1, 1)
    }

    func testMagicDemoWarningView_ExplainsLoudAudioBeforeDemo() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoWarningView.swift")
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")
        let owlNamingSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/OwlNamingView.swift")

        XCTAssertTrue(source.contains("Text(\"これから音が鳴ります\")"))
        XCTAssertTrue(source.contains("周りに人がいますか？"))
        XCTAssertTrue(source.contains("Button(\"🔔 鳴らしてみる！\")"))
        XCTAssertTrue(source.contains("Button(\"音を出さずにスキップ →\")"))
        XCTAssertTrue(appSource.contains("case .magicDemoWarning: MagicDemoWarningView()"))
        XCTAssertTrue(owlNamingSource.contains("appState.onboardingPath.append(OnboardingDestination.magicDemoWarning)"))
    }

    // MARK: - Helpers

    private func repoRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func appSourceFiles() throws -> [URL] {
        let root = repoRootURL().appendingPathComponent("ADHDAlarm")
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )

        return (enumerator?.allObjects as? [URL] ?? []).filter {
            $0.pathExtension == "swift"
        }
    }

    private func widgetSourceFiles() throws -> [URL] {
        let root = repoRootURL().appendingPathComponent("ADHDAlarmWidget")
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )

        return (enumerator?.allObjects as? [URL] ?? []).filter {
            $0.pathExtension == "swift"
        }
    }

    private func sourceText(relativePath: String) throws -> String {
        let url = repoRootURL().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func relativePath(for url: URL) -> String {
        url.path.replacingOccurrences(of: repoRootURL().path + "/", with: "")
    }
}
