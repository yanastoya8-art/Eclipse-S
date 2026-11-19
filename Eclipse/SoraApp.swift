//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 12/08/25.
//

import SwiftUI
import Combine
#if os(iOS)
import BackgroundTasks
#endif
import GoogleCast
#if canImport(Kingfisher)
import Kingfisher
#endif
#if !os(tvOS)
import Nuke
#endif

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        EclipseCastCoordinator.shared.configure()
#if os(iOS)
        if #available(iOS 26.0, *) {
            // Register the continued-processing wildcard during launch, before
            // BGTaskScheduler's registration window closes.
            _ = HLSBackgroundDownloadCoordinator.shared
        }
        registerAnimeScheduleRefresh()
#endif
        return true
    }

#if os(iOS)
    private var animeScheduleRefreshIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "app.Eclipse.Soupy").anime-schedule-refresh"
    }

    private func registerAnimeScheduleRefresh() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: animeScheduleRefreshIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAnimeScheduleRefresh(refreshTask)
        }
        scheduleNextAnimeScheduleRefresh()
    }

    private func scheduleNextAnimeScheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: animeScheduleRefreshIdentifier)
        request.earliestBeginDate = AppCalendar.nextDailyRefreshDate(after: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.shared.log(
                "Daily anime schedule background refresh could not be scheduled: \(error.localizedDescription)",
                type: "Anime"
            )
        }
    }

    private func handleAnimeScheduleRefresh(_ task: BGAppRefreshTask) {
        scheduleNextAnimeScheduleRefresh()
        let refreshWork = Task {
            await ScheduleViewModel.shared.refreshCalendarIfNeeded()
        }
        task.expirationHandler = { refreshWork.cancel() }
        Task {
            let succeeded = await refreshWork.value
            task.setTaskCompleted(success: succeeded)
        }
    }
#endif

#if !os(tvOS)
    private static var orientationLocksByScene: [String: UIInterfaceOrientationMask] = [:]

    static func setOrientationLock(_ mask: UIInterfaceOrientationMask, for scene: UIWindowScene) {
        let identifier = scene.session.persistentIdentifier
        if mask == .all {
            orientationLocksByScene.removeValue(forKey: identifier)
        } else {
            orientationLocksByScene[identifier] = mask
        }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(
                .iOS(interfaceOrientations: mask)
            ) { error in
                Logger.shared.log(
                    "Player orientation geometry update failed: \(error.localizedDescription)",
                    type: "Player"
                )
            }
        }
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if let identifier = window?.windowScene?.session.persistentIdentifier {
            return AppDelegate.orientationLocksByScene[identifier] ?? .all
        }

        let activeMasks = Array(AppDelegate.orientationLocksByScene.values)
        return activeMasks.count == 1 ? activeMasks[0] : .all
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        for session in sceneSessions {
            AppDelegate.orientationLocksByScene.removeValue(forKey: session.persistentIdentifier)
        }
    }
#endif

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        if identifier == "app.eclipse.soupy.downloads" {
            DownloadManager.shared.backgroundCompletionHandler = completionHandler
        }
    }
}

@main
struct SoraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = Settings.shared
    @StateObject private var theme = EclipseTheme.shared
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var trackerManager = TrackerManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var startupReady = false
    @State private var startupFallbackScheduled = false
    @State private var schedulePrefetchScheduled = false
    @State private var scheduleWarmupComplete = false
    @State private var homeHydrationComplete = false
    @State private var showSplash = true
    @State private var showProfilePicker: Bool
    @State private var didEvaluateLaunchPicker = false
    @State private var launchUnlockProfile: Profile?
    @State private var showOnboarding: Bool
    @State private var cloudKitUpgradeNoticePending = false
    @State private var showCloudKitUpgradeNotice = false

    @AppStorage("hideSplashScreen", store: .standard) private var hideSplashScreen = false

    @AppStorage(OnboardingState.completedKey, store: .standard)
    private var onboardingCompleted = false
#if !os(tvOS)
    @State private var showAppHubNotice = false

    @AppStorage(OnboardingState.appHubNoticeSeenKey, store: .standard)
    private var appHubNoticeSeen = false
#endif
    private let startupFallbackDelay: TimeInterval = 20
#if os(iOS)
    @State private var lastNotificationMaintenanceDay = AppCalendar.current.startOfDay(for: Date())
    private let notificationMaintenanceTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    private let cloudSyncMaintenanceTimer = Timer.publish(every: 900, on: .main, in: .common).autoconnect()
#endif


    init() {

        OnboardingState.bootstrapIfNeeded()
        _ = AppPerformanceRuntimeContext.shared
        _ = LocalizationManager.shared
#if canImport(Kingfisher)
        KingfisherImageCacheConfigurator.configureIfNeeded()
#endif
        CrashReportManager.shared.start()
        GitHubReleaseChecker.registerDefaults()
        ExperimentalFeatureState.configureLaunchState()
        MediaStateSyncBootstrap.startIfAvailable()
#if !os(tvOS)
        LocalNotificationManager.shared.configure()
#endif

        DispatchQueue.global(qos: .background).async {
            CacheManager.shared.checkAndAutoClearIfNeeded()
        }
        _ = DownloadManager.shared

        let onboardingCompletedAtLaunch = UserDefaults.standard.bool(forKey: OnboardingState.completedKey)
#if (DEBUG || ECLIPSE_PERF_HARNESS) && os(iOS)
        let debugAutoplayRequested = EclipseDebugAutoplay.isRequested
            || ProcessInfo.processInfo.environment["ECLIPSE_DEBUG_RATINGS_FIXTURE"] == "1"
#else
        let debugAutoplayRequested = false
#endif
        _showOnboarding = State(initialValue: !onboardingCompletedAtLaunch && !debugAutoplayRequested)
        _showProfilePicker = State(initialValue: onboardingCompletedAtLaunch && !debugAutoplayRequested && ProfileManager.shared.shouldPresentLaunchPicker)
        _launchUnlockProfile = State(initialValue: ProfileManager.shared.launchProfileRequiringUnlock)
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG && os(iOS)
            if ProcessInfo.processInfo.environment["ECLIPSE_DEBUG_RATINGS_FIXTURE"] == "1" {
                EclipseRatingsFixtureView()
                    .environmentObject(theme)
            } else {
                applicationRoot
            }
#else
            applicationRoot
#endif
        }
    }

    private var applicationRoot: some View {
            ZStack {
#if os(tvOS)
                ContentView(onStartupReady: markStartupReady)
                    .onAppear { scheduleStartupFallback() }
#else
                Group {
                    if ExperimentalFeatureState.isEnabledAtLaunch {
                        ExperimentalContentView(onStartupReady: markStartupReady)
                            .environmentObject(theme)
                    } else {
                        ContentView(onStartupReady: markStartupReady)
                            .environmentObject(theme)
                    }
                }
                .onAppear { scheduleStartupFallback() }
#endif

                if showProfilePicker {
                    ProfilePickerView(
                        autoUnlockProfile: launchUnlockProfile
                    ) {
                        showProfilePicker = false
                        presentCloudKitUpgradeNoticeIfReady()
                    }
                    .ignoresSafeArea()
                    .zIndex(4)
                }

                if showSplash && !hideSplashScreen {
                    SplashScreenView(isFinished: $startupReady) {
                        withAnimation(.easeInOut(duration: 0.34)) {
                            showSplash = false
                        }
                        presentCloudKitUpgradeNoticeIfReady()
                    }
                        .ignoresSafeArea()
                        .zIndex(6)
                }

                if showOnboarding, !(showSplash && !hideSplashScreen) {

                    OnboardingView {
                        showOnboarding = false
                        presentCloudKitUpgradeNoticeIfReady()
                    }
                        .transition(.opacity)
                        .zIndex(5)
                }

#if !os(tvOS)
                if showAppHubNotice, !showOnboarding, !(showSplash && !hideSplashScreen) {

                    AppHubUpdateNoticeView {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            showAppHubNotice = false
                        }
                        presentCloudKitUpgradeNoticeIfReady()
                    }
                    .transition(.opacity)
                    .zIndex(5)
                }
#endif
            }
            .onAppear {

                guard !didEvaluateLaunchPicker else { return }
                didEvaluateLaunchPicker = true
                showOnboarding = !onboardingCompleted
#if (DEBUG || ECLIPSE_PERF_HARNESS) && os(iOS)
                if EclipseDebugAutoplay.isRequested {
                    showOnboarding = false
                    showProfilePicker = false
                    EclipseDebugAutoplay.scheduleLaunch()
                    return
                }
#endif
#if !os(tvOS)
                showAppHubNotice = onboardingCompleted && !appHubNoticeSeen
#endif

                showProfilePicker = !showOnboarding && ProfileManager.shared.shouldPresentLaunchPicker
                launchUnlockProfile = ProfileManager.shared.launchProfileRequiringUnlock
                cloudKitUpgradeNoticePending =
                    MediaStateSyncBootstrap.prepareCloudKitUpgradeNoticeIfNeeded()
                presentCloudKitUpgradeNoticeIfReady()
            }
            .modifier(AppPerformanceOverlayPresentation(
                startupReady: startupReady,
                homeHydrationComplete: homeHydrationComplete,
                splashVisible: showSplash && !hideSplashScreen,
                appMode: performanceAppMode,
                modeSwitchActive: performanceModeSwitchActive
            ))
#if os(iOS)
            .modifier(EclipseWindowSceneScopeModifier())
#endif
            .environment(\.eclipseStartupOverlayVisible, showSplash && !hideSplashScreen)

            .defaultAppStorage(ProfileSettingsStore.shared.store(for: profileManager.activeProfileID))
            .environment(\.locale, localization.locale)
            .environment(\.calendar, AppCalendar.current)
            .environment(\.layoutDirection, localization.layoutDirection)
            .environmentObject(localization)
            .alert(item: $trackerManager.authenticationNotice) { notice in
                Alert(
                    title: Text(notice.title),
                    message: Text(notice.message),
                    primaryButton: .default(Text("Log In")) {
                        trackerManager.reconnectTracker(notice.service)
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(
                "Cloud Sync Changed",
                isPresented: $showCloudKitUpgradeNotice
            ) {
                Button("Resume Sync") {
                    MediaStateSyncBootstrap.markCloudKitUpgradeNoticeHandled()
                    MediaStateSyncBootstrap.setCloudKitSyncEnabled(true)
                }
                Button("Keep Off", role: .cancel) {
                    MediaStateSyncBootstrap.markCloudKitUpgradeNoticeHandled()
                }
            } message: {
                Text("Earlier versions of Eclipse automatically synced your library and watch progress through iCloud on this device. That sync is now off, and no data was deleted. You can keep it off or explicitly resume syncing.")
            }
            .onAppear {
                trackerManager.checkForExpiredTrackerSessions()
            }
            .onReceive(NotificationCenter.default.publisher(for: .homeInitialHydrationDidComplete)) { _ in
                homeHydrationComplete = true
                warmSchedulesAfterStartup()
            }
#if DEBUG
            .onOpenURL { url in
                guard url.scheme?.lowercased() == "luna",
                      url.host?.lowercased() == "open" else { return }
                let components = url.pathComponents.dropFirst()
                switch components.first?.lowercased() {
#if !os(tvOS)
#endif
                case "settings":
                    NotificationCenter.default.post(name: .eclipseDebugOpenSettings, object: nil)
                case "tab":
                    guard let tab = components.dropFirst().first?.lowercased() else { return }
                    NotificationCenter.default.post(
                        name: .eclipseDebugOpenTab,
                        object: nil,
                        userInfo: ["tab": tab]
                    )
                default:
                    break
                }
            }
#endif
#if os(iOS)
            .onAppear {
                MediaStateSyncBootstrap.syncOnActivation()
                ExperimentalCloudSyncManager.shared.syncOnActivationIfNeeded(reason: "launch")
                Task {
                    await LocalNotificationManager.shared.refreshAuthorizationStatus()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    trackerManager.checkForExpiredTrackerSessions()
                    MediaStateSyncBootstrap.syncOnActivation()
                    ExperimentalCloudSyncManager.shared.syncOnActivationIfNeeded(reason: "active")
                    Task {
                        _ = await ScheduleViewModel.shared.refreshCalendarIfNeeded()
                        await LocalNotificationManager.shared.refreshAuthorizationStatus()
                        await LocalNotificationManager.shared.syncDeliveredNotificationHistory()
                        guard scheduleWarmupComplete else { return }
                        await LocalNotificationManager.shared.refreshSchedulesIfNeeded()
                    }
                }
            }
            .onReceive(notificationMaintenanceTimer) { _ in
                guard scenePhase == .active else { return }
                Task { _ = await ScheduleViewModel.shared.refreshCalendarIfNeeded() }
                guard scheduleWarmupComplete else { return }
                let today = AppCalendar.current.startOfDay(for: Date())
                guard today != lastNotificationMaintenanceDay else { return }
                lastNotificationMaintenanceDay = today
                guard LocalNotificationManager.shared.hasNotificationSelections else { return }
                Task {

                    await LocalNotificationManager.shared.refreshSchedulesIfNeeded()
                }
            }
            .onReceive(cloudSyncMaintenanceTimer) { _ in
                guard scenePhase == .active else { return }
                ExperimentalCloudSyncManager.shared.syncOnActivationIfNeeded(
                    reason: "foreground-periodic"
                )

                MediaStateSyncBootstrap.syncOnActivation()
            }
#endif
    }


    private func presentCloudKitUpgradeNoticeIfReady() {
        guard cloudKitUpgradeNoticePending,
              !showOnboarding,
              !showProfilePicker,
              !(showSplash && !hideSplashScreen) else { return }
#if !os(tvOS)
        guard !showAppHubNotice else { return }
#endif
        cloudKitUpgradeNoticePending = false
        showCloudKitUpgradeNotice = true
    }


    private var performanceAppMode: String { "media" }

    private var performanceModeSwitchActive: Bool { false }

    private func markStartupReady() {
        guard !startupReady else { return }
        startupReady = true
        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            _ = await ScheduleViewModel.shared.refreshCalendarIfNeeded()
        }
        warmSchedulesAfterStartup()
    }

    private func warmSchedulesAfterStartup() {
        guard !schedulePrefetchScheduled else { return }
        schedulePrefetchScheduled = true

        Task(priority: .utility) {

            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            // Daily refresh is scheduled independently by markStartupReady().
#if os(tvOS)
            let requestedDayCount = ScheduleWindow.current.rawValue
            _ = await ScheduleViewModel.shared.notificationScheduleSnapshot(
                dayCount: requestedDayCount
            )
#else

            let requestedDayCount = ScheduleWindow.current.rawValue
            let snapshot = await ScheduleViewModel.shared.notificationScheduleSnapshot(
                dayCount: requestedDayCount
            )
#if os(iOS)
            await LocalNotificationManager.shared.consumeStartupScheduleSnapshot(snapshot)
#endif
            await MainActor.run { scheduleWarmupComplete = true }
#endif
        }
    }

    private func scheduleStartupFallback() {
        guard !startupFallbackScheduled else { return }
        startupFallbackScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + startupFallbackDelay) {
            markStartupReady()
        }
    }
}

#if (DEBUG || ECLIPSE_PERF_HARNESS) && os(iOS)
enum EclipseDebugAutoplay {

    static var isRequested: Bool {
        requestedURL != nil
    }

    private static var requestedURL: URL? {
        guard let urlString = ProcessInfo.processInfo.environment["ECLIPSE_DEBUG_AUTOPLAY_URL"],
              !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    static func scheduleLaunch() {
        let environment = ProcessInfo.processInfo.environment
        guard let url = requestedURL else { return }

        if let modeRaw = environment["ECLIPSE_DEBUG_UPSCALING_MODE"],
           let mode = MPVUpscalingMode(rawValue: modeRaw) {
            Settings.shared.mpvUpscalingMode = mode
        }
        if let upscalerRaw = environment["ECLIPSE_DEBUG_NEURAL_UPSCALER"],
           let upscaler = MPVNeuralUpscaler(rawValue: upscalerRaw) {
            Settings.shared.mpvNeuralUpscaler = upscaler
        }
        let animationHint = environment["ECLIPSE_DEBUG_ANIMATION_HINT"] == "1"

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            present(url: url, animationHint: animationHint)
        }
    }

    private static func present(url: URL, animationHint: Bool) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            Logger.shared.log("[EclipseDebugAutoplay] no root view controller", type: "Plugin")
            return
        }
        var host = root
        while let presented = host.presentedViewController {
            host = presented
        }
        let preset = PlayerPreset.presets.first
            ?? PlayerPreset(id: .sdrRec709, title: "Default", summary: "", stream: nil, commands: [])
        let controller = PlayerViewController(
            url: url,
            preset: preset,
            mediaSelectionIntent: .currentDefaults(isAnime: animationHint)
        )
        controller.isAnimationContentHint = animationHint
        controller.playerTitleOverride = "Debug Autoplay"
        controller.modalPresentationStyle = .fullScreen
        Logger.shared.log(
            "[EclipseDebugAutoplay] presenting url=\(url.absoluteString) animationHint=\(animationHint) mode=\(Settings.shared.mpvUpscalingMode.rawValue) neural=\(Settings.shared.mpvNeuralUpscaler.rawValue)",
            type: "Plugin"
        )
        host.present(controller, animated: false)
    }
}
#endif

