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
        let appStateSource = try sourceText(relativePath: "ADHDAlarm/App/AppState.swift")
        let alarmStoreSource = try sourceText(relativePath: "ADHDAlarm/Services/AlarmEventStore.swift")
        let inputSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/InputViewModel.swift")
        let ringingSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/RingingViewModel.swift")

        XCTAssertTrue(providerSource.contains("読み取りのみ"), "ウィジェット側は読み取り専用を維持すること")
        XCTAssertTrue(appStateSource.contains("WidgetCenter.shared.reloadAllTimelines()"))
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
        XCTAssertTrue(source.contains("Button(\"あとで試す →\")"))
        XCTAssertTrue(appSource.contains("case .magicDemoWarning: MagicDemoWarningView()"))
        XCTAssertTrue(owlNamingSource.contains("appState.onboardingPath.append(OnboardingDestination.magicDemoWarning)"))
    }

    func testMagicDemoWarningView_IsPresentedBeforeMagicDemo() throws {
        let owlNamingSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/OwlNamingView.swift")
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        XCTAssertTrue(owlNamingSource.contains("appState.onboardingPath.append(OnboardingDestination.magicDemoWarning)"))
        XCTAssertTrue(appSource.contains("case .magicDemoWarning: MagicDemoWarningView()"))
        XCTAssertTrue(appSource.contains("case .magicDemo:        MagicDemoView()"))
    }

    func testPersonHomeViewModel_DynamicTypeExtremeUsesScreenHeightBasedCount() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ViewModels/PersonHomeViewModel.swift")

        XCTAssertTrue(source.contains("let sizeCategory = UIApplication.shared.preferredContentSizeCategory"))
        XCTAssertTrue(source.contains("let isExtremeSize = sizeCategory >= .accessibilityLarge"))
        XCTAssertTrue(source.contains("let availableHeight = (screenHeight > 0 ? screenHeight : 812) * 0.5"))
    }

    func testPersonHomeViewModel_DynamicTypeExtremeKeepsAtLeastOneVisibleEvent() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ViewModels/PersonHomeViewModel.swift")

        XCTAssertTrue(source.contains("return max(1, Int(availableHeight / ComponentSize.eventRow))"))
    }

    func testSyncEngine_IsDefinedAsActor() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Services/SyncEngine.swift")

        XCTAssertTrue(source.contains("actor SyncEngine {"))
        XCTAssertFalse(source.contains("final class SyncEngine"))
    }

    func testBackgroundToUIBridges_UseMainActorRun() throws {
        let syncEngineSource = try sourceText(relativePath: "ADHDAlarm/Services/SyncEngine.swift")
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")
        let toastSource = try sourceText(relativePath: "ADHDAlarm/Services/ToastWindowManager.swift")
        let combined = [syncEngineSource, appSource, toastSource].joined(separator: "\n")

        XCTAssertTrue(combined.contains("await MainActor.run"))
    }

    func testProject_DefaultActorIsolationIsMainActor() throws {
        let source = try sourceText(relativePath: "ADHDAlarm.xcodeproj/project.pbxproj")

        XCTAssertTrue(source.contains("SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;"))
    }

    func testFamilyRemoteService_SignsInAnonymouslyWhenSessionIsMissing() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Services/FamilyRemoteService.swift")

        XCTAssertTrue(source.contains("if let existing = try? await client.auth.session"))
        XCTAssertTrue(source.contains("session = try await client.auth.signInAnonymously()"))
    }

    func testOfflineActionQueue_FlushesBeforeForegroundSync() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        guard let flushRange = source.range(of: "await OfflineActionQueue.shared.flush()"),
              let syncRange = source.range(of: "await syncEngine.performFullSync()")
        else {
            return XCTFail("オフラインキューflushとフル同期呼び出しが見つかりません")
        }

        XCTAssertLessThan(flushRange.lowerBound, syncRange.lowerBound)
    }

    func testPersonMode_UsesRealtimeListenerForRemoteFamilyEventsWhileActive() throws {
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")
        let protocolSource = try sourceText(relativePath: "ADHDAlarm/Protocols/FamilyScheduling.swift")
        let serviceSource = try sourceText(relativePath: "ADHDAlarm/Services/FamilyRemoteService.swift")

        XCTAssertTrue(appSource.contains(".task(id: shouldListenToRemoteEvents)"))
        XCTAssertTrue(appSource.contains("appState.appMode == .person && scenePhase == .active"))
        XCTAssertTrue(appSource.contains("await watchRemoteFamilyEvents()"))
        XCTAssertTrue(appSource.contains("FamilyRemoteService.shared.listenToNewEvents()"))
        XCTAssertTrue(appSource.contains("let newCount = await syncEngine.syncRemoteEvents()"))
        XCTAssertTrue(protocolSource.contains("func listenToNewEvents() -> AsyncStream<RemoteEventRecord>"))
        XCTAssertTrue(serviceSource.contains("let channel = client.realtimeV2.channel(\"public:remote_events:target=\\(deviceId)\")"))
    }

    func testWidgetGuideView_HasImagePlaceholderFrameAndSingleInstructionText() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/WidgetGuideView.swift")

        XCTAssertTrue(source.contains("Rectangle()"))
        XCTAssertTrue(source.contains("Text(\"（ここに画像が入ります）\")"))
        XCTAssertTrue(source.contains("Text(instruction)"))
        XCTAssertTrue(source.contains(".aspectRatio(16.0 / 9.0, contentMode: .fit)"))
    }

    func testWidgetGuideView_CanBeReopenedFromSettings() throws {
        let settingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")
        let widgetGuideSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/WidgetGuideView.swift")

        XCTAssertTrue(settingsSource.contains("@State private var showWidgetGuide = false"))
        XCTAssertTrue(settingsSource.contains("listRow(icon: \"rectangle.stack.badge.plus\", title: \"ウィジェットの置き方\")"))
        XCTAssertTrue(settingsSource.contains(".sheet(isPresented: $showWidgetGuide)"))
        XCTAssertTrue(widgetGuideSource.contains("var onFinished: (() -> Void)? = nil"))
        XCTAssertTrue(widgetGuideSource.contains("onFinished?()"))
    }

    func testMicrophoneInputView_CanOpenPersonManualInputView() throws {
        let microphoneSource = try sourceText(relativePath: "ADHDAlarm/Views/Input/MicrophoneInputView.swift")
        let dashboardSource = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(microphoneSource.contains("Text(\"文字で入力する\")"))
        XCTAssertTrue(microphoneSource.contains("showManualInput = true"))
        XCTAssertTrue(microphoneSource.contains("PersonManualInputView(viewModel: viewModel, onSaved: onSaved)"))
        XCTAssertTrue(dashboardSource.contains("PersonManualInputView("))
    }

    func testPersonManualInputView_ShowsTemplateButtonsAndTimePresets() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Input/PersonManualInputView.swift")

        XCTAssertTrue(source.contains("ManualEventTemplate(emoji: \"💊\", title: \"くすり\")"))
        XCTAssertTrue(source.contains("ManualEventTemplate(emoji: \"🗑\", title: \"ゴミ出し\")"))
        XCTAssertTrue(source.contains("ManualEventTemplate(emoji: \"🏥\", title: \"病院\")"))
        XCTAssertTrue(source.contains("ManualEventTemplate(emoji: \"📞\", title: \"電話\")"))
        XCTAssertTrue(source.contains("ManualEventTemplate(emoji: \"☕\", title: \"カフェ\")"))
        XCTAssertTrue(source.contains("ManualEventTemplate(emoji: \"✏️\", title: \"その他\", isCustom: true)"))
        XCTAssertTrue(source.contains("timeButton(.morning)"))
        XCTAssertTrue(source.contains("timeButton(.noon)"))
        XCTAssertTrue(source.contains("timeButton(.evening)"))
        XCTAssertTrue(source.contains("timeButton(.relative(10))"))
        XCTAssertTrue(source.contains("timeButton(.relative(30))"))
        XCTAssertTrue(source.contains("timeButton(.relative(60))"))
        XCTAssertTrue(source.contains("Text(showDatePicker ? \"閉じる\" : \"⚙️ 細かく設定\")"))
    }

    func testInputViewModel_DuplicateDetectionChecksUpcomingSevenDays() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ViewModels/InputViewModel.swift")

        XCTAssertTrue(source.contains("let sevenDaysLater = Date().addingTimeInterval(7 * 24 * 3600)"))
        XCTAssertTrue(source.contains("$0.fireDate > Date() && $0.fireDate < sevenDaysLater"))
        XCTAssertTrue(source.contains("$0.completionStatus == nil"))
    }

    func testMicrophoneInputView_DuplicateWarningOffersTwoChoices() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Input/MicrophoneInputView.swift")

        XCTAssertTrue(source.contains("Button(\"追加しない（安心した！）\")"))
        XCTAssertTrue(source.contains("Button(\"別の予定として追加\")"))
        XCTAssertTrue(source.contains("viewModel.dismissDuplicateWarning()"))
    }

    func testOwlNamingView_IsPlacedAfterPermissionsAndBeforeMagicDemo() throws {
        let permissionsSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/PermissionsCTAView.swift")
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        XCTAssertTrue(permissionsSource.contains("appState.onboardingPath.append(OnboardingDestination.owlNaming)"))
        XCTAssertTrue(appSource.contains("case .owlNaming:        OwlNamingView()"))
        XCTAssertTrue(appSource.contains("case .magicDemoWarning: MagicDemoWarningView()"))
    }

    func testOwlNamingView_UpdatesFeedbackTextInRealTimeAndFallsBackToDefaultName() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/OwlNamingView.swift")

        XCTAssertTrue(source.contains(".onChange(of: owlNameInput)"))
        XCTAssertTrue(source.contains("\"🦉「よろしくね！\\(owlNameInput)って呼んでもらえるの嬉しいよ！」\""))
        XCTAssertTrue(source.contains("appState.owlName = owlNameInput.isEmpty ? \"ふくろう\" : owlNameInput"))
    }

    func testPersonHomeViewModel_GreetingInterpolatesOwlName() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ViewModels/PersonHomeViewModel.swift")

        XCTAssertTrue(source.contains("let name = appState?.owlName ?? \"ふくろう\""))
        XCTAssertTrue(source.contains("\"\\(name)だよ！"))
        XCTAssertTrue(source.contains("\"\\(name)も眠い"))
    }

    func testSettingsView_CanEditOwlName() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")

        XCTAssertTrue(source.contains(".alert(\"ふくろうの名前を変える\""))
        XCTAssertTrue(source.contains("owlNameDraft = appState.owlName"))
        XCTAssertTrue(source.contains("appState.owlName = trimmed.isEmpty ? \"ふくろう\" : trimmed"))
        XCTAssertTrue(source.contains("Text(\"ふくろうの名前\")"))
    }

    func testEventRow_ShowsEmojiAtLeadingEdgeAndCompletedCheckmark() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/EventRow.swift")

        XCTAssertTrue(source.contains("Text(alarm.resolvedEmoji)"))
        XCTAssertTrue(source.contains(".font(.title2)"))
        XCTAssertTrue(source.contains("Image(systemName: \"checkmark.circle.fill\")"))
        XCTAssertTrue(source.contains("frame(width: 60, height: 60)"))
    }

    func testPersonHomeView_DeleteDialogsCoverRecurringAndNormalEvents() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(source.contains("Button(\"今回のみ削除する\", role: .destructive)"))
        XCTAssertTrue(source.contains("Button(\"繰り返しを全部削除する\", role: .destructive)"))
        XCTAssertTrue(source.contains("Button(\"削除する\", role: .destructive)"))
        XCTAssertTrue(source.contains("Button(\"やめる\", role: .cancel)"))
    }

    func testWidgetRoom_UsesSplitLayoutAndUnlocksItemsByXPThreshold() throws {
        let source = try sourceText(relativePath: "ADHDAlarmWidget/ADHDAlarmWidget.swift")

        XCTAssertTrue(source.contains("HStack(spacing: 0)"))
        XCTAssertTrue(source.contains("owlRoomView(alarm: alarm)\n                .frame(maxWidth: 140)"))
        XCTAssertTrue(source.contains("if xp >= 100 { Text(\"🪵\")"))
        XCTAssertTrue(source.contains("if xp >= 300 { Text(\"🪴\")"))
        XCTAssertTrue(source.contains("if xp >= 700 { Text(\"🕯️\")"))
        XCTAssertTrue(source.contains("if xp >= 1000 { Text(\"🔭\")"))
    }

    func testWidgetTimelines_ReloadAfterXPRelevantMutations() throws {
        let appStateSource = try sourceText(relativePath: "ADHDAlarm/App/AppState.swift")
        let storeSource = try sourceText(relativePath: "ADHDAlarm/Services/AlarmEventStore.swift")
        let inputSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/InputViewModel.swift")
        let ringingSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/RingingViewModel.swift")
        let personHomeSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/PersonHomeViewModel.swift")
        let combined = [appStateSource, storeSource, inputSource, ringingSource, personHomeSource].joined(separator: "\n")

        XCTAssertTrue(combined.contains("WidgetCenter.shared.reloadAllTimelines()"))
    }

    func testPermissionsCTAView_RequestsNotificationAndCalendarAfterPrePrompts() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/PermissionsCTAView.swift")

        XCTAssertTrue(source.contains("if step == .notifications"))
        XCTAssertTrue(source.contains("Text(\"通知を許可する\")"))
        XCTAssertTrue(source.contains("await permissions.requestNotification()"))
        XCTAssertTrue(source.contains("withAnimation { step = .calendar }"))
        XCTAssertTrue(source.contains("Text(\"カレンダーを連携する\")"))
        XCTAssertTrue(source.contains("await permissions.requestCalendar()"))
    }

    func testMagicDemoView_CanBeSkippedLater() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoView.swift")

        XCTAssertTrue(source.contains("Button(\"あとで試す →\") { navigateToWidgetGuide() }"))
    }

    func testDataMigrationService_RunsAtAppLaunchBeforeOtherStartupWork() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        guard let migrationRange = source.range(of: "DataMigrationService.migrateIfNeeded()"),
              let bgRegisterRange = source.range(of: "BGTaskScheduler.shared.register"),
              let startupTaskRange = source.range(of: ".task { await startupTasks() }")
        else {
            return XCTFail("起動時マイグレーションの構造が見つかりません")
        }

        XCTAssertLessThan(migrationRange.lowerBound, bgRegisterRange.lowerBound)
        XCTAssertLessThan(migrationRange.lowerBound, startupTaskRange.lowerBound)
    }

    func testRingingView_ShowsAlarmTitleOnStageTwoCard() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")

        XCTAssertTrue(source.contains("Text(alarm.title)"))
        XCTAssertTrue(source.contains("standardEventCard(alarm: alarm"))
        XCTAssertTrue(source.contains("largeTypeEventCard(alarm: alarm"))
    }

    func testRingingView_ShowsThirtyMinuteSnoozeButton() throws {
        let ringingSource = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")
        let viewModelSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/RingingViewModel.swift")

        XCTAssertTrue(ringingSource.contains("Text(\"⏱️\")"))
        XCTAssertTrue(ringingSource.contains("Text(viewModel.snoozeButtonTitle)"))
        XCTAssertTrue(ringingSource.contains("if viewModel.canSnooze"))
        XCTAssertTrue(viewModelSource.contains("\"30分後にまた教えて\""))
    }

    func testRingingView_ReducesDecorativeMotionForAccessibilityAndLowPower() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")

        XCTAssertTrue(source.contains("@Environment(\\.accessibilityReduceMotion) private var accessibilityReduceMotion"))
        XCTAssertTrue(source.contains("accessibilityReduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled"))
        XCTAssertTrue(source.contains("if !shouldReduceMotionEffects {"))
        XCTAssertTrue(source.contains("withAnimation(.easeOut(duration: shouldReduceMotionEffects ? 0.2 : 0.5))"))
    }

    func testPersonHomeView_UsesOpacityOnlyForCollapsedListsWhenReduceMotionIsEnabled() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(source.contains("accessibilityReduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)"))
        XCTAssertTrue(source.contains("withAnimation(expandCollapseAnimation)"))
        XCTAssertTrue(source.contains(".transition(eventListTransition)"))
    }

    func testEventRow_ShowsCarriedOverBadge() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/EventRow.swift")

        XCTAssertTrue(source.contains("Text(isCarriedOver ? \"🔁 昨日から\" : \"ToDo\")"))
        XCTAssertTrue(source.contains("let isCarriedOver = Calendar.current.startOfDay(for: alarm.fireDate) < Calendar.current.startOfDay(for: Date())"))
    }

    func testDashboardEventRows_ShowFamilySourceAndNotificationTiming() throws {
        let eventRowSource = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/EventRow.swift")
        let personHomeSource = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(eventRowSource.contains("Label(\"家族から受信\", systemImage: \"person.2.fill\")"))
        XCTAssertTrue(eventRowSource.contains("Label(notificationTimingLabel, systemImage: \"bell.fill\")"))
        XCTAssertTrue(eventRowSource.contains("alarm.remoteEventId != nil"))

        XCTAssertTrue(personHomeSource.contains("nextAlarmMetadataRow(alarm: alarm)"))
        XCTAssertTrue(personHomeSource.contains("Label(timingLabel, systemImage: \"bell.fill\")"))
        XCTAssertTrue(personHomeSource.contains("Label(\"家族から受信\", systemImage: \"person.2.fill\")"))
    }

    func testFamilySendTab_DatePickerStartsCollapsed() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilySendTab.swift")

        XCTAssertTrue(source.contains("var selectedTiming: FamilySendTimingOption = .in15Minutes"))
        XCTAssertTrue(source.contains("if viewModel.selectedTiming == .custom {"))
        XCTAssertTrue(source.contains("DatePicker("))
    }

    func testAdvancedSettingsView_ShowsDeleteAccountButtonAndConfirmationDialog() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Settings/AdvancedSettingsView.swift")

        XCTAssertTrue(source.contains("Label(\"アカウントを削除する\""))
        XCTAssertTrue(source.contains("showDeleteAccountConfirm = true"))
        XCTAssertTrue(source.contains(".confirmationDialog("))
        XCTAssertTrue(source.contains("Button(\"削除する\", role: .destructive)"))
        XCTAssertTrue(source.contains("Button(\"やめる\", role: .cancel)"))
    }

    func testPersonWelcomeView_HasWingFlapAnimation() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/PersonWelcomeView.swift")

        XCTAssertTrue(source.contains("@State private var wingFlap = false"))
        XCTAssertTrue(source.contains(".scaleEffect(wingFlap ? 1.05 : 1.0)"))
        XCTAssertTrue(source.contains(".easeInOut(duration: 1.5).repeatForever(autoreverses: true)"))
        XCTAssertTrue(source.contains(".onAppear { wingFlap = true }"))
    }

    func testExistingUsers_SeeModeSelectionOnlyAndSkipRemainingOnboarding() throws {
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")
        let modeSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/ModeSelectionView.swift")

        XCTAssertTrue(appSource.contains("if !appState.isOnboardingComplete || appState.appMode == nil"))
        XCTAssertTrue(appSource.contains("ModeSelectionView()"))
        XCTAssertTrue(modeSource.contains("if appState.isOnboardingComplete {"))
        XCTAssertTrue(modeSource.contains("// 既存ユーザー: モード変更のみ。RootView が自動切替"))
        XCTAssertTrue(modeSource.contains("return"))
        XCTAssertTrue(modeSource.contains("appState.onboardingPath.append(OnboardingDestination.personWelcome)"))
    }

    func testExistingUserModeSelectionButtonUsesKonoSetteiDeTsukau() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/ModeSelectionView.swift")

        XCTAssertTrue(source.contains("Button(appState.isOnboardingComplete ? \"この設定で使う\" : \"🦉 はじめる\")"))
    }

    func testFamilyDashboard_FreeTierLocksSOSAndHistoryButStillShowsTodaySection() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyDashboardTab.swift")
        let homeSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyHomeView.swift")

        XCTAssertTrue(source.contains("todaySection"))
        XCTAssertTrue(source.contains("Text(\"今日の予定\")"))
        XCTAssertTrue(source.contains("ここでは、あなたが送った予定だけをまとめて確認できます。相手が自分で追加した予定は表示されません。"))
        XCTAssertTrue(source.contains("if isPro {"))
        XCTAssertTrue(source.contains("lockedSOSBanner"))
        XCTAssertTrue(source.contains("lockedHistoryCard"))
        XCTAssertTrue(source.contains("Button(\"PROを見る\")"))
        XCTAssertTrue(source.contains("Button(\"PROプランを見る\")"))
        XCTAssertTrue(homeSource.contains("onUpgradeTapped: { showFamilyPaywall = true }"))
        XCTAssertTrue(homeSource.contains(".sheet(isPresented: $showFamilyPaywall)"))
        XCTAssertTrue(homeSource.contains("FamilyPaywallView()"))
    }

    func testFamilyDashboard_ShowsFirstCompletionBannerOnlyForOneTimeFreeTierUpsell() throws {
        let dashboardSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyDashboardTab.swift")
        let homeSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyHomeView.swift")
        let viewModelSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/FamilyHomeViewModel.swift")
        let constantsSource = try sourceText(relativePath: "ADHDAlarm/App/Constants.swift")

        XCTAssertTrue(dashboardSource.contains("var showFirstCompletionBanner: Bool = false"))
        XCTAssertTrue(dashboardSource.contains("Text(\"✓✓ が届きました\")"))
        XCTAssertTrue(dashboardSource.contains("Button(\"あとで\")"))
        XCTAssertTrue(dashboardSource.contains("Button(\"PROを見る\")"))
        XCTAssertTrue(homeSource.contains("showFirstCompletionBanner: viewModel.shouldShowFirstCompletionBanner"))
        XCTAssertTrue(homeSource.contains("viewModel.dismissFirstCompletionBanner()"))
        XCTAssertTrue(viewModelSource.contains("sentEvents = try await service.fetchSentEvents(linkId: linkId)"))
        XCTAssertTrue(viewModelSource.contains("events.contains(where: { $0.status == \"completed\" })"))
        XCTAssertTrue(viewModelSource.contains("Constants.Keys.familyFirstCompletedBannerShown"))
        XCTAssertTrue(constantsSource.contains("static let familyFirstCompletedBannerShown"))
    }

    func testSettingsFamilyAndRingingBackgrounds_FollowCurrentSurfaceRules() throws {
        let settingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")
        let familyPaywallSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyPaywallView.swift")
        let familySettingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilySettingsTab.swift")
        let familySendSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilySendTab.swift")
        let ringingSource = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")

        XCTAssertTrue(settingsSource.contains(".background(.background)"))
        XCTAssertTrue(settingsSource.contains(".background(.regularMaterial)"))
        XCTAssertFalse(settingsSource.contains(".background(Color(.systemBackground))"))

        XCTAssertTrue(familyPaywallSource.contains(".background(.background)"))
        XCTAssertTrue(familyPaywallSource.contains(".background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.lg))"))
        XCTAssertFalse(familyPaywallSource.contains(".background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: CornerRadius.lg))"))

        XCTAssertTrue(familySettingsSource.contains("Color(uiColor: .systemGroupedBackground)"))
        XCTAssertTrue(familySettingsSource.contains(".shadow(color: .black.opacity(0.04), radius: 10, y: 4)"))
        XCTAssertTrue(familySendSource.contains("Color(uiColor: .systemGroupedBackground)"))
        XCTAssertTrue(familySendSource.contains(".shadow(color: .black.opacity(0.04), radius: 10, y: 4)"))

        XCTAssertTrue(ringingSource.contains("Rectangle()"))
        XCTAssertTrue(ringingSource.contains(".fill(.ultraThickMaterial)"))
        XCTAssertTrue(ringingSource.contains(".fill(.regularMaterial)"))
        XCTAssertTrue(ringingSource.contains(".background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))"))
        XCTAssertTrue(ringingSource.contains(".background(.regularMaterial)"))
    }

    func testFamilyPaywall_CanBeDismissedLater() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyPaywallView.swift")

        XCTAssertTrue(source.contains("Button(\"あとで\")"))
        XCTAssertTrue(source.contains("dismiss()"))
    }

    func testToastWindowManager_RendersAboveFullScreenCover() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Services/ToastWindowManager.swift")

        XCTAssertTrue(source.contains("window.windowLevel = .alert + 1"))
        XCTAssertTrue(source.contains("/// .fullScreenCover（RingingView）の上にも表示できる"))
    }

    func testDashboard_DoesNotShowLegacyLevelNumberUI() throws {
        let appSources = try appSourceFiles()
        let combined = try appSources
            .map { try sourceText(relativePath: relativePath(for: $0)) }
            .joined(separator: "\n")

        XCTAssertFalse(combined.contains("Lv."))
        XCTAssertFalse(combined.contains("Level"))
        XCTAssertFalse(combined.contains("レベル"))
    }

    func testFamilyUnlink_ClearsLocalLinkIdentifiers() throws {
        let settingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")
        let familyLinkSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/FamilyLinkView.swift")
        let personFamilyLinkSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/PersonFamilyLinkView.swift")
        let familySettingsSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilySettingsTab.swift")
        let combined = [settingsSource, familyLinkSource, personFamilyLinkSource, familySettingsSource].joined(separator: "\n")

        XCTAssertTrue(combined.contains("appState.familyLinkId = nil"))
        XCTAssertTrue(combined.contains("appState.familyChildLinkIds = []"))
        XCTAssertTrue(combined.contains("appState.familyChildLinkIds.removeAll"))
    }

    func testLowBatteryCheck_ShowsToastOnlyWhenBatteryIsLowAndAlarmExists() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        XCTAssertTrue(source.contains("let level = UIDevice.current.batteryLevel"))
        XCTAssertTrue(source.contains("guard level > 0, level < 0.10 else { return }"))
        XCTAssertTrue(source.contains("$0.fireDate > Date() && $0.completionStatus == nil && !$0.isToDo"))
        XCTAssertTrue(source.contains("ToastWindowManager.shared.show(ToastMessage("))
        XCTAssertTrue(source.contains("充電残量が少なくなっています。充電してからアラームを使ってね"))
    }

    func testDeleteAccount_ClearsFamilyLinksWithoutDeletingLocalAlarmData() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")

        XCTAssertTrue(source.contains("try await FamilyRemoteService.shared.deleteAccount()"))
        XCTAssertTrue(source.contains("appState.familyLinkId = nil"))
        XCTAssertTrue(source.contains("appState.familyChildLinkIds = []"))
        XCTAssertFalse(source.contains("AlarmEventStore.shared.delete"))
        XCTAssertFalse(source.contains("eventStore.delete"))
        XCTAssertFalse(source.contains("loadAll().removeAll"))
    }

    func testReviewRequests_AreTriggeredOnlyAfterCompletionFlow() throws {
        let ringingSource = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")
        let reviewSource = try sourceText(relativePath: "ADHDAlarm/Services/ReviewManager.swift")
        let paywallSource = try sourceText(relativePath: "ADHDAlarm/Views/Paywall/PaywallView.swift")
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")

        XCTAssertTrue(ringingSource.contains("ReviewManager.shared.recordCompletionAndRequestIfNeeded(isSOSFired: sosWasFired)"))
        XCTAssertFalse(ringingSource.contains("viewModel.skip()\n        ReviewManager.shared"))
        XCTAssertTrue(reviewSource.contains("/// 「とめる」ボタンを押して予定が完了した直後にのみリクエストを発火する。"))
        XCTAssertTrue(reviewSource.contains("guard !isSOSFired else { return }"))
        XCTAssertFalse(paywallSource.contains("requestReview"))
        XCTAssertFalse(paywallSource.contains("ReviewManager.shared"))
        XCTAssertFalse(appSource.contains("ReviewManager.shared.recordCompletionAndRequestIfNeeded"))
    }

    func testPaywallPurchase_UnlocksProFeaturesBySettingSubscriptionTierToPro() throws {
        let paywallViewModelSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/PaywallViewModel.swift")
        let settingsViewModelSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/SettingsViewModel.swift")
        let inputViewModelSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/InputViewModel.swift")

        XCTAssertTrue(paywallViewModelSource.contains("appState.subscriptionTier = .pro"))
        XCTAssertTrue(paywallViewModelSource.contains("successMessage = \"PROプランへのアップグレードが完了しました！\""))
        XCTAssertTrue(settingsViewModelSource.contains("var isPro: Bool { appState.subscriptionTier == .pro }"))
        XCTAssertTrue(inputViewModelSource.contains("guard appState.subscriptionTier.canSelectCalendar else { return }"))
    }

    func testRingingView_UsesLargeTypeFallbackAboveAccessibility3() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")

        XCTAssertTrue(source.contains("if dynamicTypeSize >= .accessibility3 {"))
        XCTAssertTrue(source.contains("largeTypeEventCard(alarm: alarm, minutesToEvent: minutesToEvent)"))
        XCTAssertTrue(source.contains("Text(\"今\")"))
        XCTAssertTrue(source.contains("Text(\"分\")"))
    }

    func testRingingView_LargeTypeKeepsCountdownLargerThanEventTitle() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")

        XCTAssertTrue(source.contains(".font(.system(size: 84, weight: .black, design: .rounded))"))
        XCTAssertTrue(source.contains(".font(.system(size: 88, weight: .black, design: .rounded))"))
        XCTAssertTrue(source.contains("Text(alarm.title)"))
        XCTAssertTrue(source.contains(".font(.title2.weight(.black))"))
    }

    func testMagicDemoCompletion_UsesSameTenXPPathAsRealAlarmCompletion() throws {
        let magicDemoSource = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoView.swift")
        let ringingSource = try sourceText(relativePath: "ADHDAlarm/Views/Alarm/RingingView.swift")
        let viewModelSource = try sourceText(relativePath: "ADHDAlarm/ViewModels/RingingViewModel.swift")

        XCTAssertTrue(magicDemoSource.contains("RingingView(alarm: demoAlarm)"))
        XCTAssertTrue(ringingSource.contains("viewModel.dismiss()"))
        XCTAssertTrue(viewModelSource.contains("appState?.addXP(10)"))
        XCTAssertTrue(ringingSource.contains("text: \"よくできました！ ⭐️ +10ポイント\""))
    }

    func testWidgetOwlRoom_UsesOneThirdAndTwoThirdsSplitLayout() throws {
        let source = try sourceText(relativePath: "ADHDAlarmWidget/ADHDAlarmWidget.swift")

        XCTAssertTrue(source.contains("HStack(spacing: 0)"))
        XCTAssertTrue(source.contains("owlRoomView(alarm: alarm)"))
        XCTAssertTrue(source.contains(".frame(maxWidth: 140)"))
        XCTAssertTrue(source.contains("// 左ペイン（1/3）: ふくろうの部屋（箱庭）"))
        XCTAssertTrue(source.contains("// 右ペイン（2/3）: 残り時間 + タイトル + 事前通知"))
    }

    func testWidgetOwlRoom_ShowsOnlyOwlBelowOneHundredXP() throws {
        let source = try sourceText(relativePath: "ADHDAlarmWidget/ADHDAlarmWidget.swift")

        XCTAssertTrue(source.contains("if xp >= 100 { Text(\"🪵\")"))
        XCTAssertTrue(source.contains("if xp >= 300 { Text(\"🪴\")"))
        XCTAssertTrue(source.contains("if xp >= 700 { Text(\"🕯️\")"))
        XCTAssertTrue(source.contains("if xp >= 1000 { Text(\"🔭\")"))
        XCTAssertTrue(source.contains("Image(owlImageName(for: alarm))"))
    }

    func testManualInputTimePresets_SetDateImmediatelyAndClosePicker() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Input/PersonManualInputView.swift")

        XCTAssertTrue(source.contains("timeButton(.morning)"))
        XCTAssertTrue(source.contains("timeButton(.noon)"))
        XCTAssertTrue(source.contains("timeButton(.evening)"))
        XCTAssertTrue(source.contains("selectedTime = preset"))
        XCTAssertTrue(source.contains("showDatePicker = false"))
    }

    func testDashboardExpandCollapse_UsesEaseInOutPointThreeAnimation() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(source.contains("withAnimation(.easeInOut(duration: 0.3)) {"))
        XCTAssertTrue(source.contains("viewModel.isEventListExpanded = true"))
        XCTAssertTrue(source.contains("viewModel.isEventListExpanded = false"))
    }

    func testDashboardExpandCollapse_PersistsWithSceneStorage() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(source.contains("@SceneStorage(\"isEventListExpanded\")"))
        XCTAssertTrue(source.contains("storedIsEventListExpanded = true"))
        XCTAssertTrue(source.contains("storedIsEventListExpanded = false"))
    }

    func testManualInputFineTuning_ExpandsDatePickerWithAnimation() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Input/PersonManualInputView.swift")

        XCTAssertTrue(source.contains("Text(showDatePicker ? \"閉じる\" : \"⚙️ 細かく設定\")"))
        XCTAssertTrue(source.contains("withAnimation(.spring(duration: 0.2)) {"))
        XCTAssertTrue(source.contains("showDatePicker.toggle()"))
        XCTAssertTrue(source.contains("DatePicker("))
    }

    func testFamilyUnlinkButtons_UseDestructiveRole() throws {
        let familyLinkSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/FamilyLinkView.swift")
        let personLinkSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/PersonFamilyLinkView.swift")
        let sosSource = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SOSPairingView.swift")

        XCTAssertTrue(familyLinkSource.contains("Button(role: .destructive)"))
        XCTAssertTrue(personLinkSource.contains("Button(role: .destructive)"))
        XCTAssertTrue(sosSource.contains("Button(role: .destructive)"))
        XCTAssertTrue(familyLinkSource.contains("Label(\"連携を解除する\""))
    }

    func testPersonHomeView_BlocksInteractionWhenPermissionsAreDenied() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(source.contains("@Environment(PermissionsService.self) private var permissionsService"))
        XCTAssertTrue(source.contains("if permissionsService.hasDeniedPermissions"))
        XCTAssertTrue(source.contains("Text(\"設定の確認が必要です\")"))
        XCTAssertTrue(source.contains("Button(\"設定アプリを開く\")"))
        XCTAssertTrue(source.contains("UIApplication.openSettingsURLString"))
    }

    func testPersonHomeView_AllowsCompletingMissedEventsFromActionDialog() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/PersonHomeView.swift")

        XCTAssertTrue(source.contains("if alarm.completionStatus == nil || alarm.completionStatus == .missed"))
        XCTAssertTrue(source.contains("Button(\"完了にする\")"))
        XCTAssertTrue(source.contains("if alarm.completionStatus == .missed {"))
    }

    func testFamilyHomeView_ShowsOfflineYellowBannerFromNetworkMonitor() throws {
        let appSource = try sourceText(relativePath: "ADHDAlarm/ADHDAlarmApp.swift")
        let homeSource = try sourceText(relativePath: "ADHDAlarm/Views/Family/FamilyHomeView.swift")
        let monitorSource = try sourceText(relativePath: "ADHDAlarm/Services/NetworkMonitorService.swift")

        XCTAssertTrue(appSource.contains("private let networkMonitor     = NetworkMonitorService()"))
        XCTAssertTrue(appSource.contains(".environment(networkMonitor)"))
        XCTAssertTrue(homeSource.contains("@Environment(NetworkMonitorService.self) private var networkMonitor"))
        XCTAssertTrue(homeSource.contains("if networkMonitor.isOffline"))
        XCTAssertTrue(homeSource.contains("wifi.slash"))
        XCTAssertTrue(homeSource.contains("最新の予定や見守り状況の読み込みが遅れることがあります。"))
        XCTAssertTrue(homeSource.contains(".background(Color.yellow.opacity(0.88))"))
        XCTAssertTrue(monitorSource.contains("final class NetworkMonitorService"))
        XCTAssertTrue(monitorSource.contains("NWPathMonitor()"))
    }

    func testAlarmKitScheduler_ActionableNotificationUsesGenericPrivacyTitle() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Services/AlarmKitScheduler.swift")

        XCTAssertTrue(source.contains("content.title = \"🦉 ふくろうからのお知らせ\""))
        XCTAssertFalse(source.contains("content.title = alarm.title"))
    }

    func testSettingsView_CalendarPickerAvoidsDefaultITLabel() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")

        XCTAssertTrue(source.contains("Text(\"自動で選ぶ\").tag(\"\")"))
        XCTAssertFalse(source.contains("Text(\"デフォルト\").tag(\"\")"))
    }

    func testOwlAmberButtonsAndBadges_AvoidWhiteText() throws {
        let onboarding = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/WidgetGuideView.swift")
        let modeSelection = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/ModeSelectionView.swift")
        let permissions = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/PermissionsCTAView.swift")
        let welcome = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/PersonWelcomeView.swift")
        let magicDemo = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoView.swift")
        let magicWarning = try sourceText(relativePath: "ADHDAlarm/Views/Onboarding/MagicDemoWarningView.swift")
        let eventRow = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/EventRow.swift")
        let settings = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")
        let voicePicker = try sourceText(relativePath: "ADHDAlarm/Views/Settings/VoiceCharacterPicker.swift")
        let combined = [onboarding, modeSelection, permissions, welcome, magicDemo, magicWarning, eventRow, settings, voicePicker].joined(separator: "\n")

        XCTAssertFalse(combined.contains(".background(Color.owlAmber)\n                    .foregroundStyle(.white)"))
        XCTAssertFalse(combined.contains(".background(Color.owlAmber)\n                .foregroundStyle(.white)"))
        XCTAssertTrue(onboarding.contains(".background(Color.owlAmber)\n                .foregroundStyle(.black)"))
        XCTAssertTrue(modeSelection.contains(".background(Color.owlAmber)\n            .foregroundStyle(.black)"))
        XCTAssertTrue(permissions.contains(".background(Color.owlAmber)\n                .foregroundStyle(.black)"))
        XCTAssertTrue(welcome.contains(".background(Color.owlAmber)\n            .foregroundStyle(.black)"))
        XCTAssertTrue(magicDemo.contains(".background(Color.owlAmber)\n                    .foregroundStyle(.black)"))
        XCTAssertTrue(magicWarning.contains(".background(Color.owlAmber)\n                .foregroundStyle(.black)"))
        XCTAssertTrue(settings.contains(".foregroundStyle(.black)\n                    .padding(.horizontal, 6)\n                    .padding(.vertical, 2)\n                    .background(Color.owlAmber)"))
        XCTAssertTrue(voicePicker.contains(".foregroundStyle(.black)\n                        .padding(.horizontal, 6)\n                        .padding(.vertical, 2)\n                        .background(Color.owlAmber)"))
        XCTAssertTrue(eventRow.contains(".foregroundStyle(.black)\n                    .padding(.horizontal, 6)\n                    .padding(.vertical, 2)\n                    .background(isCarriedOver ? Color.secondary : Color.owlAmber)"))
    }

    func testEventRow_EmojiIconFollowsDynamicTypeAndCompletedOpacityRule() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Dashboard/EventRow.swift")

        XCTAssertTrue(source.contains("Text(alarm.resolvedEmoji)"))
        XCTAssertTrue(source.contains(".font(.title2)"))
        XCTAssertTrue(source.contains("if isPast { return 0.4 }"))
        XCTAssertFalse(source.contains(".font(.system(size: 20))"))
    }

    func testSettingsView_ShowsDeleteProgressOverlayAndReturnsToOnboardingAfterAccountDeletion() throws {
        let source = try sourceText(relativePath: "ADHDAlarm/Views/Settings/SettingsView.swift")

        XCTAssertTrue(source.contains("@State private var isDeletingAccount = false"))
        XCTAssertTrue(source.contains("if isDeletingAccount {"))
        XCTAssertTrue(source.contains("Text(\"削除中...\")"))
        XCTAssertTrue(source.contains(".interactiveDismissDisabled(isDeletingAccount)"))
        XCTAssertTrue(source.contains(".disabled(isDeletingAccount)"))
        XCTAssertTrue(source.contains("appState.isOnboardingComplete = false"))
        XCTAssertTrue(source.contains("appState.appMode = nil"))
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
