//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

@MainActor
private enum SkyStreamAutoUpdateState {
    static var isRunning = false
}

@MainActor
private func autoUpdateSkyStreamSourcesIfNeeded() async {
#if os(iOS) && !targetEnvironment(macCatalyst)
    guard PlatformCapabilities.current.supportsSkyStreamPlugins,
          ProfileSettingsStore.services.object(forKey: "autoUpdateServicesEnabled") == nil
            || ProfileSettingsStore.services.bool(forKey: "autoUpdateServicesEnabled") else {
        return
    }

    let timestampKey = "lastSkyStreamAutoUpdateTimestamp"
    let lastTimestamp = UserDefaults.standard.double(forKey: timestampKey)
    if lastTimestamp > 0,
       Date().timeIntervalSince1970 - lastTimestamp < 3_600 {
        return
    }
    guard !SkyStreamAutoUpdateState.isRunning else { return }
    SkyStreamAutoUpdateState.isRunning = true
    defer { SkyStreamAutoUpdateState.isRunning = false }

    let manager = SkyStreamPluginManager.shared
    for _ in 0..<40 where !manager.isLoaded {
        do {
            try await Task.sleep(nanoseconds: 50_000_000)
        } catch {
            return
        }
    }
    guard !Task.isCancelled,
          manager.isLoaded,
          !manager.installedPlugins.isEmpty || !manager.repositories.isEmpty else {
        return
    }
    await manager.refreshRepositoriesAndInstalledPlugins(autoUpdate: true)
    guard !Task.isCancelled else { return }
    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
#endif
}


enum MainAppSection: String, CaseIterable, Identifiable {
    case home, schedule, downloads, search
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .schedule: return "Schedule"
        case .downloads: return "Downloads"
        case .search: return "Search"
        }
    }
    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .schedule: return "calendar"
        case .downloads: return "arrow.down.circle.fill"
        case .search: return "magnifyingglass"
        }
    }
}

@MainActor
final class MainTabConfiguration: ObservableObject {
    static let shared = MainTabConfiguration()
    private let visibilityKey = "mainTabVisibilityV1"
    private let orderKey = "mainTabOrderV1"
    @Published private(set) var visibleSections: [MainAppSection] = MainAppSection.allCases
    @Published private(set) var orderedSections: [MainAppSection] = MainAppSection.allCases

    private init() {
        reload()
        NotificationCenter.default.addObserver(forName: .activeProfileDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        let defaults = ProfileSettingsStore.active
        let all = MainAppSection.allCases
        let hidden = Set(defaults.stringArray(forKey: visibilityKey) ?? [])
        let visible = all.filter { !hidden.contains($0.rawValue) }
        visibleSections = visible.isEmpty ? [.home] : visible
        let savedOrder = defaults.stringArray(forKey: orderKey) ?? []
        let decoded = savedOrder.compactMap(MainAppSection.init(rawValue:))
        orderedSections = (decoded + all.filter { !decoded.contains($0) }).reduce(into: [MainAppSection]()) { result, item in
            if !result.contains(item) { result.append(item) }
        }
    }

    func setVisible(_ section: MainAppSection, _ isVisible: Bool) {
        let defaults = ProfileSettingsStore.active
        var hidden = Set(defaults.stringArray(forKey: visibilityKey) ?? [])
        if isVisible { hidden.remove(section.rawValue) } else { hidden.insert(section.rawValue) }
        if hidden.count == MainAppSection.allCases.count { hidden.remove(section.rawValue) }
        defaults.set(Array(hidden), forKey: visibilityKey)
        reload()
    }

    func move(from source: IndexSet, to destination: Int) {
        var order = orderedSections
        order.move(fromOffsets: source, toOffset: destination)
        orderedSections = order
        ProfileSettingsStore.active.set(order.map(\.rawValue), forKey: orderKey)
    }

    var tabsForDisplay: [MainAppSection] {
        orderedSections.filter { visibleSections.contains($0) }
    }
}

struct MainTabCustomizationView: View {
    @StateObject private var configuration = MainTabConfiguration.shared

    var body: some View {
        List {
            Section {
                ForEach(configuration.orderedSections) { section in
                    HStack {
                        Label(section.title, systemImage: section.systemImage)
                        Spacer()
                        Toggle("Show", isOn: Binding(
                            get: { configuration.visibleSections.contains(section) },
                            set: { configuration.setVisible(section, $0) }
                        ))
                        .labelsHidden()
                    }
                    .accessibilityIdentifier("settings.tabs.\\(section.rawValue)")
                }
                .onMove(perform: configuration.move)
            } footer: {
                Text("Choose which main sections appear in the tab bar. Drag the handles to change their order. At least one section must remain visible.")
            }
        }
        .navigationTitle("Main Sections")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
    }
}

struct ContentView: View {
    private enum AppTab: String, Hashable {
        case home, schedule, downloads, library, search
    }

    @ObservedObject private var downloadManager = DownloadManager.shared
    @StateObject private var accentColorManager = AccentColorManager.shared
    @StateObject private var glassAppearance = LiquidGlassAppearanceSettings.shared
    @StateObject private var tabConfiguration = MainTabConfiguration.shared
    @AppStorage("githubReleaseShowAlertPending", store: .standard) private var githubReleaseShowAlertPending = false
    @AppStorage("githubReleaseLatestVersion", store: .standard) private var githubReleaseLatestVersion = ""
    @AppStorage("githubReleaseURL", store: .standard) private var githubReleaseURL = ""

    @State private var selectedTab: AppTab = .home
    @State private var showingSettings = false
    @State private var showingReleaseAlert = false
    @State private var showingAniListFallbackAlert = false
    @State private var playerInterfaceCoverage = PlayerInterfaceCoverageState()

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.eclipseWindowSceneSessionIdentifier) private var windowSceneSessionIdentifier
    @Namespace private var heroNamespace
    private let onStartupReady: () -> Void

    init(onStartupReady: @escaping () -> Void = {}) {
        self.onStartupReady = onStartupReady
        configureTabBarAppearance()
    }

    private var playerCoversInterface: Bool {
        playerInterfaceCoverage.isCovered(in: windowSceneSessionIdentifier)
    }

    private func configureTabBarAppearance() {
        #if !os(tvOS)
        // iOS 26 owns the native Liquid Glass tab bar; let the toolbar background
        // tint it instead of replacing it with an opaque UIKit appearance.
        if #available(iOS 26.0, *) { return }

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(glassAppearance.bottomBarColor).withAlphaComponent(0.46)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.shadowColor = .clear

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.gray
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }

    var body: some View {
        Group {
#if compiler(>=6.0)
            if #available(iOS 26.0, tvOS 26.0, *) {
                ZStack {
                    modernTabView
                        .heroNamespace(heroNamespace)
                        .appHub(
                            showingSettings: $showingSettings,
                            isSuppressed: showingSettings || playerCoversInterface,
                            tvPlacementActive: selectedTab == .home || selectedTab == .schedule
                        )

                    if showingSettings {
                        settingsFullScreen
                            .zIndex(1)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.95, anchor: .trailing))
                            ))
                    }
                }
            } else {
                ZStack {
                    olderTabView
                        .heroNamespace(heroNamespace)
                        .appHub(
                            showingSettings: $showingSettings,
                            isSuppressed: showingSettings || playerCoversInterface,
                            tvPlacementActive: selectedTab == .home || selectedTab == .schedule
                        )

                    if showingSettings {
                        settingsFullScreen
                            .zIndex(1)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.95, anchor: .trailing))
                            ))
                    }
                }
            }
#else
            ZStack {
                olderTabView
                    .heroNamespace(heroNamespace)
                    .appHub(
                        showingSettings: $showingSettings,
                        isSuppressed: showingSettings || playerCoversInterface,
                        tvPlacementActive: selectedTab == .home || selectedTab == .schedule
                    )

                if showingSettings {
                    settingsFullScreen
                        .zIndex(1)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.95, anchor: .trailing))
                        ))
                }
            }
#endif
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showingSettings)
        .task { await runBackgroundAutoChecks() }
        .onChange(of: scenePhase) { newPhase in
            publishScenePhase(newPhase)
            if newPhase == .active {
#if !os(tvOS)
                openPendingNotificationRouteIfNeeded()
#endif
                Task { await runBackgroundAutoChecks() }
            }
        }
        .onAppear {
            updatePerformanceSurface()
            publishScenePhase(scenePhase)
            presentUpdateAlertIfNeeded()
#if !os(tvOS)
            openPendingNotificationRouteIfNeeded()
#endif
        }
#if !os(tvOS)
        .onChange(of: windowSceneSessionIdentifier) { _ in
            openPendingNotificationRouteIfNeeded()
        }
#endif
        .onChange(of: githubReleaseShowAlertPending) { pending in
            if pending {
                presentUpdateAlertIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _ in
            updatePerformanceSurface()
        }
        .onReceive(tabConfiguration.$visibleSections) { visible in
            if !visible.contains(where: { AppTab(rawValue: $0.rawValue) == selectedTab }) {
                selectedTab = visible.first.map { AppTab(rawValue: $0.rawValue) ?? .home } ?? .home
            }
        }
        .onChange(of: showingSettings) { _ in
            updatePerformanceSurface()
        }
        .onReceive(glassAppearance.$bottomBarColor.dropFirst()) { _ in
            configureTabBarAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerInterfaceCoverageDidChange)) { notification in
            playerInterfaceCoverage.consume(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .animeMetadataDidSwitchToMALFallback)) { _ in
            showingAniListFallbackAlert = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("eclipse.openDownloadsFromLiveActivity"))) { _ in
            showingSettings = false
            selectedTab = .downloads
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScheduleFromLocalNotification)) { _ in
#if !os(tvOS)
            openPendingNotificationRouteIfNeeded()
#endif
        }
#if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .eclipseDebugOpenSettings)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                showingSettings = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eclipseDebugOpenTab)) { notification in
            guard let raw = notification.userInfo?["tab"] as? String else { return }
            showingSettings = false
            switch raw {
            case "home": selectedTab = .home
            case "schedule": selectedTab = .schedule
            case "downloads": selectedTab = .downloads
            case "library": selectedTab = .library
            case "search": selectedTab = .search
            default: break
            }
        }
#endif
        .alert("Update Available", isPresented: $showingReleaseAlert) {
            Button("Later", role: .cancel) {
                consumeUpdateAlert()
            }

            Button("Open Release") {
                consumeUpdateAlert()
                if let url = URL(string: githubReleaseURL), !githubReleaseURL.isEmpty {
                    openURL(url)
                }
            }
        } message: {
            if githubReleaseLatestVersion.isEmpty {
                Text("A new Eclipse release is available on GitHub.")
            } else {
                Text("A new Eclipse release (\(githubReleaseLatestVersion)) is available on GitHub.")
            }
        }
        .alert("AniList Unavailable", isPresented: $showingAniListFallbackAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("AniList is currently unavailable. Eclipse will use MyAnimeList for anime metadata and AnimeSchedule for episode schedules when available. Schedules may be incomplete or out of date, and season or special mappings may be less accurate until AniList recovers.")
        }
    }

    private func runBackgroundAutoChecks() async {

        do {
            try await Task.sleep(nanoseconds: 6_000_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        await ServiceManager.shared.autoUpdateServicesIfNeeded()
        await autoUpdateSkyStreamSourcesIfNeeded()
        await SourceHealthMonitor.shared.runDailyEnabledSourceChecksIfNeeded()
        await GitHubReleaseChecker.checkForUpdatesIfNeeded()

        await MainActor.run {
            presentUpdateAlertIfNeeded()
        }
    }

    private func presentUpdateAlertIfNeeded() {
        guard GitHubReleaseChecker.shouldShowPendingUpdatePrompt else {
            githubReleaseShowAlertPending = false
            return
        }
        showingReleaseAlert = true
    }

    private func consumeUpdateAlert() {
        GitHubReleaseChecker.consumePendingUpdatePrompt()
        githubReleaseShowAlertPending = false
        showingReleaseAlert = false
    }

#if compiler(>=6.0)
    @available(iOS 26.0, tvOS 26.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabConfiguration.tabsForDisplay) { section in
                switch section {
                case .home:
                    Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                        HomeView(isActive: selectedTab == .home && !showingSettings && !playerCoversInterface, onStartupReady: onStartupReady)
                    }
                case .schedule:
                    Tab("Schedule", systemImage: "calendar", value: AppTab.schedule) {
                        ScheduleView(isActive: selectedTab == .schedule)
                    }
                case .downloads:
                    Tab("Downloads", systemImage: "arrow.down.circle.fill", value: AppTab.downloads) {
                        DownloadsView()
                    }
#if !os(tvOS)
                    .badge(downloadManager.activeDownloadCount > 0 ? downloadManager.activeDownloadCount : 0)
#endif
                case .search:
                    Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                        SearchView()
                    }
                }
            }

            Tab("Library", systemImage: "books.vertical.fill", value: AppTab.library) {
                LibraryView()
            }
        }
#if !os(tvOS)
        .tabBarMinimizeBehavior(.never)
#endif
        .tint(accentColorManager.currentAccentColor)
#if os(iOS)
        .toolbarBackground(LiquidGlassAppearanceSettings.shared.bottomBarTint, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
#endif
    }
#endif

    private var settingsFullScreen: some View {
        ZStack {
            EclipseTheme.shared.backgroundBase
                .ignoresSafeArea()

#if os(tvOS)
            if #available(iOS 16.0, *) {
                NavigationStack {
                    SettingsView(onRootDismiss: dismissSettings)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: dismissSettings) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                }
                            }
                        }
                }
            } else {
                NavigationView {
                    SettingsView(onRootDismiss: dismissSettings)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: dismissSettings) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Back")
                                    }
                                }
                            }
                        }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
#else
            SettingsView(onRootDismiss: dismissSettings)
#endif
        }
        .preferredColorScheme(.dark)
    }

    private func dismissSettings() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            showingSettings = false
        }
    }

#if !os(tvOS)
    private func openPendingNotificationRouteIfNeeded() {
        guard scenePhase == .active,
              LocalNotificationManager.shared.shouldHandlePendingNavigation(
                inSceneSessionIdentifier: windowSceneSessionIdentifier
              ) else { return }
        showingSettings = false
        selectedTab = .schedule
    }
#endif

    private func publishScenePhase(_ phase: ScenePhase) {
        let phaseName: String
        switch phase {
        case .active:
            phaseName = "active"
        case .inactive:
            phaseName = "inactive"
        case .background:
            phaseName = "background"
        @unknown default:
            phaseName = "unknown"
        }
        NotificationCenter.default.post(
            name: .eclipseScenePhaseDidChange,
            object: nil,
            userInfo: ["phase": phaseName]
        )
    }

    private func updatePerformanceSurface() {
        if showingSettings {
            AppPerformanceRuntimeContext.shared.setSurface("settings")
            return
        }
        switch selectedTab {
        case .home: AppPerformanceRuntimeContext.shared.setSurface("home")
        case .schedule: AppPerformanceRuntimeContext.shared.setSurface("schedule")
        case .downloads: AppPerformanceRuntimeContext.shared.setSurface("downloads")
        case .library: AppPerformanceRuntimeContext.shared.setSurface("library")
        case .search: AppPerformanceRuntimeContext.shared.setSurface("search")
        }
    }

    private var olderTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabConfiguration.tabsForDisplay) { section in
                Group {
                    switch section {
                    case .home:
                        HomeView(isActive: selectedTab == .home && !showingSettings && !playerCoversInterface, onStartupReady: onStartupReady)
                            .tabItem { Image(systemName: section.systemImage); Text(section.title) }
                            .tag(AppTab.home)
                    case .schedule:
                        ScheduleView(isActive: selectedTab == .schedule)
                            .tabItem { Image(systemName: section.systemImage); Text(section.title) }
                            .tag(AppTab.schedule)
                    case .downloads:
                        DownloadsView()
                            .tabItem { Image(systemName: section.systemImage); Text(section.title) }
                            .tag(AppTab.downloads)
#if !os(tvOS)
                            .badge(downloadManager.activeDownloadCount > 0 ? downloadManager.activeDownloadCount : 0)
#endif
                    case .search:
                        SearchView()
                            .tabItem { Image(systemName: section.systemImage); Text(section.title) }
                            .tag(AppTab.search)
                    }
                }
            }
            LibraryView()
                .tabItem { Image(systemName: "books.vertical.fill"); Text("Library") }
                .tag(AppTab.library)
        }
        .tint(accentColorManager.currentAccentColor)
#if os(iOS)
        .toolbarBackground(LiquidGlassAppearanceSettings.shared.bottomBarTint, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
#endif
    }
}


#if !os(tvOS)
private enum ExperimentalMediaTab: Hashable {
    case home
    case schedule
    case downloads
    case library
    case search
}

struct ExperimentalContentView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @StateObject private var accentColorManager = AccentColorManager.shared
    @AppStorage("githubReleaseShowAlertPending", store: .standard) private var githubReleaseShowAlertPending = false
    @AppStorage("githubReleaseLatestVersion", store: .standard) private var githubReleaseLatestVersion = ""
    @AppStorage("githubReleaseURL", store: .standard) private var githubReleaseURL = ""

    @State private var selectedTab: ExperimentalMediaTab = .home
    @State private var showingSettings = false
    @State private var showingReleaseAlert = false
    @State private var showingAniListFallbackAlert = false
    @State private var playerInterfaceCoverage = PlayerInterfaceCoverageState()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.eclipseWindowSceneSessionIdentifier) private var windowSceneSessionIdentifier
    @Namespace private var heroNamespace

    private let onStartupReady: () -> Void

    init(onStartupReady: @escaping () -> Void = {}) {
        self.onStartupReady = onStartupReady
        configureTabBarAppearance()
    }

    private var playerCoversInterface: Bool {
        playerInterfaceCoverage.isCovered(in: windowSceneSessionIdentifier)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 0.92)
        appearance.shadowColor = .clear

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.gray
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        itemAppearance.selected.iconColor = UIColor.white
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            GlobalGradientBackground(allowsAnimatedBackground: false)
                .ignoresSafeArea()

            experimentalTabView
                .heroNamespace(heroNamespace)
                .appHub(
                    showingSettings: $showingSettings,
                    isSuppressed: showingSettings || playerCoversInterface,
                    tvPlacementActive: selectedTab == .home || selectedTab == .schedule
                )

            if showingSettings {
                experimentalSettingsFullScreen
                    .zIndex(2)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showingSettings)
        .task { await runBackgroundAutoChecks() }
        .onChange(of: scenePhase) { newPhase in
            publishScenePhase(newPhase)
            if newPhase == .active {
                openPendingNotificationRouteIfNeeded()
                Task { await runBackgroundAutoChecks() }
            }
        }
        .onAppear {
            updatePerformanceSurface()
            publishScenePhase(scenePhase)
            presentUpdateAlertIfNeeded()
            openPendingNotificationRouteIfNeeded()
        }
        .onChange(of: windowSceneSessionIdentifier) { _ in
            openPendingNotificationRouteIfNeeded()
        }
        .onChange(of: githubReleaseShowAlertPending) { pending in
            if pending {
                presentUpdateAlertIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _ in
            updatePerformanceSurface()
        }
        .onChange(of: showingSettings) { _ in
            updatePerformanceSurface()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerInterfaceCoverageDidChange)) { notification in
            playerInterfaceCoverage.consume(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .animeMetadataDidSwitchToMALFallback)) { _ in
            showingAniListFallbackAlert = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("eclipse.openDownloadsFromLiveActivity"))) { _ in
            showingSettings = false
            selectedTab = .downloads
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScheduleFromLocalNotification)) { _ in
            openPendingNotificationRouteIfNeeded()
        }
#if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .eclipseDebugOpenSettings)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                showingSettings = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eclipseDebugOpenTab)) { notification in
            guard let raw = notification.userInfo?["tab"] as? String else { return }
            showingSettings = false
            switch raw {
            case "home": selectedTab = .home
            case "schedule": selectedTab = .schedule
            case "downloads": selectedTab = .downloads
            case "library": selectedTab = .library
            case "search": selectedTab = .search
            default: break
            }
        }
#endif
        .alert("Update Available", isPresented: $showingReleaseAlert) {
            Button("Later", role: .cancel) { consumeUpdateAlert() }
            Button("Open Release") {
                consumeUpdateAlert()
                if let url = URL(string: githubReleaseURL), !githubReleaseURL.isEmpty {
                    openURL(url)
                }
            }
        } message: {
            if githubReleaseLatestVersion.isEmpty {
                Text("A new Eclipse release is available on GitHub.")
            } else {
                Text("A new Eclipse release (\(githubReleaseLatestVersion)) is available on GitHub.")
            }
        }
        .alert("AniList Unavailable", isPresented: $showingAniListFallbackAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("AniList is currently unavailable. Eclipse will use MyAnimeList for anime metadata and AnimeSchedule for episode schedules when available. Schedules may be incomplete or out of date, and season or special mappings may be less accurate until AniList recovers.")
        }
    }

    private var experimentalTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                isActive: selectedTab == .home && !showingSettings && !playerCoversInterface,
                onStartupReady: onStartupReady
            )
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(ExperimentalMediaTab.home)

            ScheduleView(isActive: selectedTab == .schedule)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Schedule")
                }
                .tag(ExperimentalMediaTab.schedule)

            DownloadsView()
                .tabItem {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Downloads")
                }
                .tag(ExperimentalMediaTab.downloads)
                .badge(downloadManager.activeDownloadCount > 0 ? downloadManager.activeDownloadCount : 0)

            LibraryView()
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("Library")
                }
                .tag(ExperimentalMediaTab.library)

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(ExperimentalMediaTab.search)
        }
        .tint(accentColorManager.currentAccentColor)
#if os(iOS)
        .toolbarBackground(LiquidGlassAppearanceSettings.shared.bottomBarTint, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
#endif
    }

    private var experimentalSettingsFullScreen: some View {
        ZStack(alignment: .topLeading) {
            GlobalGradientBackground(allowsAnimatedBackground: false)
                .ignoresSafeArea()

            SettingsView(onRootDismiss: dismissSettings)
        }
    }

    private func dismissSettings() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            showingSettings = false
        }
    }

    private func openPendingNotificationRouteIfNeeded() {
        guard scenePhase == .active,
              LocalNotificationManager.shared.shouldHandlePendingNavigation(
                inSceneSessionIdentifier: windowSceneSessionIdentifier
              ) else { return }
        showingSettings = false
        selectedTab = .schedule
    }

    private func runBackgroundAutoChecks() async {

        do {
            try await Task.sleep(nanoseconds: 6_000_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        await ServiceManager.shared.autoUpdateServicesIfNeeded()
        await autoUpdateSkyStreamSourcesIfNeeded()
        await SourceHealthMonitor.shared.runDailyEnabledSourceChecksIfNeeded()
        await GitHubReleaseChecker.checkForUpdatesIfNeeded()

        await MainActor.run {
            presentUpdateAlertIfNeeded()
        }
    }

    private func publishScenePhase(_ phase: ScenePhase) {
        let phaseName: String
        switch phase {
        case .active:
            phaseName = "active"
        case .inactive:
            phaseName = "inactive"
        case .background:
            phaseName = "background"
        @unknown default:
            phaseName = "unknown"
        }
        NotificationCenter.default.post(
            name: .eclipseScenePhaseDidChange,
            object: nil,
            userInfo: ["phase": phaseName]
        )
    }

    private func updatePerformanceSurface() {
        if showingSettings {
            AppPerformanceRuntimeContext.shared.setSurface("settings")
            return
        }
        switch selectedTab {
        case .home: AppPerformanceRuntimeContext.shared.setSurface("home")
        case .schedule: AppPerformanceRuntimeContext.shared.setSurface("schedule")
        case .downloads: AppPerformanceRuntimeContext.shared.setSurface("downloads")
        case .library: AppPerformanceRuntimeContext.shared.setSurface("library")
        case .search: AppPerformanceRuntimeContext.shared.setSurface("search")
        }
    }

    private func presentUpdateAlertIfNeeded() {
        guard GitHubReleaseChecker.shouldShowPendingUpdatePrompt else {
            githubReleaseShowAlertPending = false
            return
        }
        showingReleaseAlert = true
    }

    private func consumeUpdateAlert() {
        GitHubReleaseChecker.consumePendingUpdatePrompt()
        githubReleaseShowAlertPending = false
        showingReleaseAlert = false
    }
}

#endif

extension Notification.Name {
#if DEBUG
    static let eclipseDebugOpenSettings = Notification.Name("eclipseDebugOpenSettings")
    static let eclipseDebugOpenTab = Notification.Name("eclipseDebugOpenTab")
#endif
}

#Preview {
    ContentView()
}
