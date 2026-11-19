//
//  HomeViewModel.swift
//  Eclipse
//
//  Created by Soupy-dev
//

import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif


enum HomeCatalogFilterPolicy {
    private static let animeCatalogIDs: Set<String> = [
        "trendingAnime", "popularAnime", "topRatedAnime", "airingAnime", "bestAnime"
    ]

    static func usesAnimeFiltering(catalogID: String) -> Bool {
        animeCatalogIDs.contains(catalogID)
    }

    static func allowsUpcomingContent(catalogID: String) -> Bool {
        catalogID == "upcomingMovies" || catalogID == "upcomingTV"
    }
}

enum HomeCatalogLoadPolicy {
    static func requiresTrendingSeed(enabledCatalogIDs: Set<String>) -> Bool {
        enabledCatalogIDs.contains("trending") || enabledCatalogIDs.contains("forYou")
    }

    static func hasLoadedContent(
        tmdbCatalogCount: Int,
        animeCatalogCount: Int,
        stremioCatalogCount: Int,
        traktCatalogCount: Int,
        widgetCatalogCount: Int,
        permitsEmptyResults: Bool
    ) -> Bool {
        permitsEmptyResults
            || tmdbCatalogCount > 0
            || animeCatalogCount > 0
            || stremioCatalogCount > 0
            || traktCatalogCount > 0
            || widgetCatalogCount > 0
    }
}

enum HomeCatalogFailurePresentation {
    static func message(for error: Error) -> String {
        // Classify the real TMDBError cases before falling back to localized
        // text. The app wraps URLSession failures in TMDBError.networkError and
        // exposes HTTP failures as associated status codes, so checking only
        // NSError descriptions can mislabel real API failures as generic errors.
        if let tmdbError = error as? TMDBError {
            switch tmdbError {
            case .missingAPIKey:
                return missingAPIKeyMessage
            case .httpError(let statusCode, _, _):
                return message(forHTTPStatusCode: statusCode)
            case .networkError(let underlying):
                return message(for: underlying)
            case .invalidURL:
                return "Eclipse could not build the TMDB request URL. Check the API configuration, then tap Retry."
            case .decodingError:
                return "TMDB returned a response Eclipse could not read. Check the API service, then tap Retry."
            }
        }

        let nsError = error as NSError
        let diagnostic = "\(error.localizedDescription) \(String(reflecting: error))"
        let normalized = diagnostic.lowercased()

        if normalized.contains("missingapikey") || normalized.contains("missing api key") {
            return missingAPIKeyMessage
        }

        if normalized.contains("invalid api key")
            || normalized.contains("statuscode: 401")
            || normalized.contains("statuscode: 403")
            || normalized.contains("http 401")
            || normalized.contains("http 403") {
            return "TMDB rejected the API key (HTTP 401/403). Verify that TMDB_API_KEY is a valid v3 API key, then rebuild the app."
        }

        if normalized.contains("statuscode: 429")
            || normalized.contains("http 429")
            || normalized.contains("rate limit") {
            return "TMDB rate-limited the Home requests (HTTP 429). Wait briefly, then tap Retry."
        }

        if (500...599).contains(where: {
            normalized.contains("statuscode: \($0)")
                || normalized.contains("http \($0)")
        }) {
            return "TMDB is temporarily unavailable. Wait a moment, then tap Retry."
        }

        if nsError.domain == NSURLErrorDomain {
            switch URLError.Code(rawValue: nsError.code) {
            case .timedOut:
                return "TMDB took too long to respond. Check your connection, then tap Retry."
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed, .resourceUnavailable:
                return "Eclipse could not reach TMDB. Check your internet connection, then tap Retry."
            default:
                break
            }
        }

        if normalized.contains("timedout")
            || normalized.contains("notconnectedtointernet")
            || normalized.contains("networkconnectionlost")
            || normalized.contains("cannotconnecttohost")
            || normalized.contains("cannotfindhost")
            || normalized.contains("dnslookupfailed") {
            return "Eclipse could not reach TMDB. Check your internet connection, then tap Retry."
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty
            ? "TMDB did not return Home catalog data. Check the API configuration and tap Retry."
            : "TMDB request failed: \(message.prefix(180))"
    }

    private static let missingAPIKeyMessage =
        "TMDB API key is missing from this app build. Add the TMDB_API_KEY repository secret and rebuild the app."

    private static func message(forHTTPStatusCode statusCode: Int) -> String {
        switch statusCode {
        case 401, 403:
            return "TMDB rejected the API key (HTTP 401/403). Verify that TMDB_API_KEY is a valid v3 API key, then rebuild the app."
        case 429:
            return "TMDB rate-limited the Home requests (HTTP 429). Wait briefly, then tap Retry."
        case 408, 425:
            return "TMDB could not complete the Home request (HTTP \(statusCode)). Wait briefly, then tap Retry."
        case 500...599:
            return "TMDB is temporarily unavailable (HTTP \(statusCode)). Wait a moment, then tap Retry."
        case 400...499:
            return "TMDB rejected a Home request (HTTP \(statusCode)). Check the API request, then tap Retry."
        default:
            return "TMDB request failed (HTTP \(statusCode)). Check the API service, then tap Retry."
        }
    }
}

private actor HomeCatalogFailureRecorder {
    private var firstFailure: String?

    func reset() {
        firstFailure = nil
    }

    func record(_ message: String) {
        guard firstFailure == nil else { return }
        firstFailure = String(message.prefix(240))
    }

    func firstFailureMessage() -> String? {
        firstFailure
    }
}

enum HomeHeroSelectionSettings {
    static let storageKey = "homeHeroSelectedTitlesV1"
    static let didChangeNotification = Notification.Name("homeHeroSelectionDidChange")

    static func load(defaults: UserDefaults = ProfileSettingsStore.active) -> [TMDBSearchResult] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TMDBSearchResult].self, from: data) else {
            return []
        }
        var seen: Set<String> = []
        return decoded.filter { seen.insert($0.stableIdentity).inserted }
    }

    static func save(_ titles: [TMDBSearchResult], defaults: UserDefaults = ProfileSettingsStore.active) {
        var seen: Set<String> = []
        let uniqueTitles = titles.filter { seen.insert($0.stableIdentity).inserted }
        if let data = try? JSONEncoder().encode(uniqueTitles) {
            defaults.set(data, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}

final class HomeViewModel: ObservableObject {
    @Published var catalogResults: [String: [TMDBSearchResult]] = [:]
    private var unfilteredCatalogResults: [String: [TMDBSearchResult]] = [:]
    private var unfilteredWidgetData: [String: [TMDBSearchResult]] = [:]
    private var pendingCatalogFilterRefresh = false
    private var catalogFilterGeneration = UUID()
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var heroContent: TMDBSearchResult?
    @Published var ambientColor: Color = Color.black
    @Published var hasLoadedContent = false
    @Published var hasCompletedInitialLoad = false
    @Published var hasRenderableStartupContent = false
    @Published var widgetData: [String: [TMDBSearchResult]] = [:]
    @Published var becauseYouWatchedTitle: String = ""
    private var heroCarouselItems: [TMDBSearchResult] = []
    private var heroCarouselIndex = 0
    private var heroCarouselGeneration: UUID?
    private var heroLaunchSelectionKey: String?
    private static let maxHeroCarouselItems = 12

    var heroCarouselCount: Int { heroCarouselItems.count }

    var heroCarouselCurrentIndex: Int { min(heroCarouselIndex, max(0, heroCarouselItems.count - 1)) }

    func upcomingHeroCarouselItems(limit: Int) -> [TMDBSearchResult] {
        guard limit > 0, heroCarouselItems.count > 1 else { return [] }
        let itemCount = min(limit, heroCarouselItems.count - 1)
        return (1...itemCount).map { offset in
            heroCarouselItems[(heroCarouselCurrentIndex + offset) % heroCarouselItems.count]
        }
    }
    private var activeLoadTask: Task<Void, Never>?
    private let catalogFailureRecorder = HomeCatalogFailureRecorder()
    private weak var activeContentFilter: TMDBContentFilter?
    private var catalogFilterObserver: NSObjectProtocol?

    private var loadGeneration = UUID()

    init() {
        catalogFilterObserver = NotificationCenter.default.addObserver(
            forName: TMDBContentFilter.catalogFiltersDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reapplyCatalogFilters()
            }
        }
    }

    deinit {
        if let catalogFilterObserver {
            NotificationCenter.default.removeObserver(catalogFilterObserver)
        }
    }

    @MainActor
    private func reapplyCatalogFilters() async {
        guard hasLoadedContent else {
            pendingCatalogFilterRefresh = true
            return
        }
        guard let contentFilter = activeContentFilter else { return }
        let filterGeneration = UUID()
        catalogFilterGeneration = filterGeneration
        let loadGenerationSnapshot = loadGeneration
        var catalogSnapshot = unfilteredCatalogResults
        for (key, value) in catalogResults where catalogSnapshot[key] == nil {
            catalogSnapshot[key] = value
        }
        if catalogSnapshot.isEmpty {
            catalogSnapshot = catalogResults
        }
        var widgetSnapshot = unfilteredWidgetData
        for (key, value) in widgetData where widgetSnapshot[key] == nil {
            widgetSnapshot[key] = value
        }
        // A title commonly appears in several shelves and widgets. Prepare expensive
        // age/runtime/audio metadata once per unique media identity instead of once
        // per shelf occurrence whenever a filter changes.
        var seenIdentities = Set<String>()
        let allResults = (Array(catalogSnapshot.values.joined()) + Array(widgetSnapshot.values.joined()))
            .filter { seenIdentities.insert($0.stableIdentity).inserted }
        await contentFilter.prepareMaturityRatings(for: allResults)

        // Actor reentrancy allows another filter refresh or catalog load to begin
        // while rating metadata is fetched. Never publish this stale snapshot.
        guard catalogFilterGeneration == filterGeneration,
              loadGeneration == loadGenerationSnapshot,
              hasLoadedContent else { return }

        var filteredCatalogSnapshot: [String: [TMDBSearchResult]] = [:]
        for (catalogID, items) in catalogSnapshot {
            if HomeCatalogFilterPolicy.usesAnimeFiltering(catalogID: catalogID) {
                filteredCatalogSnapshot[catalogID] = contentFilter.filterFastAnimeSearchResults(items)
            } else {
                filteredCatalogSnapshot[catalogID] = contentFilter.filterSearchResults(
                    items,
                    allowUpcomingContent: HomeCatalogFilterPolicy.allowsUpcomingContent(catalogID: catalogID)
                )
            }
        }
        catalogResults = filteredCatalogSnapshot
        widgetData = widgetSnapshot.mapValues { contentFilter.filterSearchResults($0) }
        let renderableCount = catalogResults.values.filter { !$0.isEmpty }.count
            + widgetData.values.filter { !$0.isEmpty }.count
        hasRenderableStartupContent = renderableCount > 0
        if renderableCount > 0 {
            errorMessage = nil
        }
        applyHeroBannerSelection()
    }

    func loadContent(
        tmdbService: TMDBService,
        catalogManager: CatalogManager,
        contentFilter: TMDBContentFilter,
        showLoading: Bool = true
    ) {

        Task { @MainActor [weak self] in
            self?.activeContentFilter = contentFilter
        }

        guard !hasLoadedContent else {
            return
        }
        guard activeLoadTask == nil else {
            return
        }

        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        hasCompletedInitialLoad = false
        if catalogResults.values.allSatisfy(\.isEmpty) && widgetData.values.allSatisfy(\.isEmpty) {
            hasRenderableStartupContent = false
        }

        activeLoadTask = Task {
            await catalogFailureRecorder.reset()
            let (enabledCatalogSnapshot, generation) = await MainActor.run {

                _ = StremioAddonManager.shared
                return (catalogManager.getEnabledCatalogs(), self.loadGeneration)
            }
            // Every early return, including task cancellation during an awaited
            // catalog/provider request, must release the load slot. Otherwise
            // Home can remain stuck with an orphaned activeLoadTask and never
            // retry on the next appearance.
            defer {
                Task { @MainActor [weak self] in
                    guard let self, self.loadGeneration == generation else { return }
                    self.activeLoadTask = nil
                    if self.isLoading {
                        self.isLoading = false
                        self.hasCompletedInitialLoad = true
                    }
                }
            }

            // An empty catalog list is a valid user configuration, not a network
            // failure. Finish the load without showing the generic Wi-Fi error.
            if enabledCatalogSnapshot.isEmpty {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.catalogResults = [:]
                    self.widgetData = [:]
                    self.heroContent = nil
                    self.heroCarouselItems = []
                    self.heroCarouselIndex = 0
                    self.heroLaunchSelectionKey = nil
                    self.isLoading = false
                    self.hasLoadedContent = true
                    self.hasCompletedInitialLoad = true
                    self.hasRenderableStartupContent = false
                    self.errorMessage = nil
                    self.activeLoadTask = nil
                }
                return
            }

            let enabledCatalogIds = Set(enabledCatalogSnapshot.map(\.id))
            let needsTopRatedTVShows = enabledCatalogIds.contains("topRatedTVShows") || enabledCatalogIds.contains("bestTVShows")
            let needsTopRatedMovies = enabledCatalogIds.contains("topRatedMovies") || enabledCatalogIds.contains("bestMovies")
            let needsTopRatedAnime = enabledCatalogIds.contains("topRatedAnime") || enabledCatalogIds.contains("bestAnime")

            async let trending: [TMDBSearchResult] = self.loadHomeCatalogIfNeeded(
                "trending",
                shouldLoad: HomeCatalogLoadPolicy.requiresTrendingSeed(enabledCatalogIDs: enabledCatalogIds)
            ) {
                try await tmdbService.getTrending()
            }
            async let popularM: [TMDBMovie] = self.loadHomeCatalogIfNeeded("popularMovies", shouldLoad: enabledCatalogIds.contains("popularMovies")) {
                try await tmdbService.getPopularMovies()
            }
            async let nowPlayingM: [TMDBMovie] = self.loadHomeCatalogIfNeeded("nowPlayingMovies", shouldLoad: enabledCatalogIds.contains("nowPlayingMovies")) {
                try await tmdbService.getNowPlayingMovies()
            }
            async let upcomingM: [TMDBMovie] = self.loadHomeCatalogIfNeeded("upcomingMovies", shouldLoad: enabledCatalogIds.contains("upcomingMovies")) {
                try await tmdbService.getUpcomingMovies()
            }
            async let popularTV: [TMDBTVShow] = self.loadHomeCatalogIfNeeded("popularTVShows", shouldLoad: enabledCatalogIds.contains("popularTVShows")) {
                try await tmdbService.getPopularTVShows()
            }
            async let onTheAirTV: [TMDBTVShow] = self.loadHomeCatalogIfNeeded("onTheAirTV", shouldLoad: enabledCatalogIds.contains("onTheAirTV")) {
                try await tmdbService.getOnTheAirTVShows()
            }
            async let airingTodayTV: [TMDBTVShow] = self.loadHomeCatalogIfNeeded("airingTodayTV", shouldLoad: enabledCatalogIds.contains("airingTodayTV")) {
                try await tmdbService.getAiringTodayTVShows()
            }
            async let topRatedTV: [TMDBTVShow] = self.loadHomeCatalogIfNeeded("topRatedTVShows", shouldLoad: needsTopRatedTVShows) {
                try await tmdbService.getTopRatedTVShows()
            }
            async let topRatedM: [TMDBMovie] = self.loadHomeCatalogIfNeeded("topRatedMovies", shouldLoad: needsTopRatedMovies) {
                try await tmdbService.getTopRatedMovies()
            }
            async let upcomingTV: [TMDBTVShow] = self.loadHomeCatalogIfNeeded("upcomingTV", shouldLoad: enabledCatalogIds.contains("upcomingTV")) {
                try await tmdbService.getUpcomingTVShows()
            }

            let tmdbResults = await (
                trending, popularM, nowPlayingM, upcomingM, popularTV, onTheAirTV,
                airingTodayTV, topRatedTV, topRatedM, upcomingTV
            )
            guard !Task.isCancelled else { return }

            let rawTMDBLoadedCatalogs: [String: [TMDBSearchResult]] = [
                "trending": tmdbResults.0,
                "popularMovies": tmdbResults.1.map { self.movieSearchResult($0) },
                "nowPlayingMovies": tmdbResults.2.map { self.movieSearchResult($0) },
                "upcomingMovies": tmdbResults.3.map { self.movieSearchResult($0) },
                "popularTVShows": tmdbResults.4.map { self.tvSearchResult($0) },
                "onTheAirTV": tmdbResults.5.map { self.tvSearchResult($0) },
                "airingTodayTV": tmdbResults.6.map { self.tvSearchResult($0) },
                "topRatedTVShows": tmdbResults.7.map { self.tvSearchResult($0) },
                "topRatedMovies": tmdbResults.8.map { self.movieSearchResult($0) },
                "upcomingTV": tmdbResults.9.map { self.tvSearchResult($0) }
            ]

            await MainActor.run {
                guard self.loadGeneration == generation else { return }
                self.unfilteredCatalogResults = rawTMDBLoadedCatalogs
                if enabledCatalogIds.contains("bestTVShows") {
                    self.unfilteredCatalogResults["bestTVShows"] = rawTMDBLoadedCatalogs["topRatedTVShows"] ?? []
                }
                if enabledCatalogIds.contains("bestMovies") {
                    self.unfilteredCatalogResults["bestMovies"] = rawTMDBLoadedCatalogs["topRatedMovies"] ?? []
                }
            }
            await contentFilter.prepareMaturityRatings(
                for: Array(rawTMDBLoadedCatalogs.values.joined())
            )
            guard !Task.isCancelled else { return }
            let rawKidsCatalogs = await self.loadKidsCatalogs(
                tmdbService: tmdbService,
                catalogs: enabledCatalogSnapshot
            )
            guard !Task.isCancelled else { return }
            await contentFilter.prepareMaturityRatings(for: Array(rawKidsCatalogs.values.joined()))
            let kidsLoadedCatalogs = rawKidsCatalogs.mapValues { contentFilter.filterSearchResults($0) }
            await MainActor.run {
                guard self.loadGeneration == generation else { return }
                self.unfilteredCatalogResults.merge(rawKidsCatalogs) { _, kids in kids }
            }
            var tmdbLoadedCatalogs = rawTMDBLoadedCatalogs
                .map { catalogID, results in
                    let isExplicitUpcomingCatalog = catalogID == "upcomingMovies" || catalogID == "upcomingTV"
                    return (
                        catalogID,
                        contentFilter.filterSearchResults(
                            results,
                            allowUpcomingContent: isExplicitUpcomingCatalog
                        )
                    )
                }
                .reduce(into: [String: [TMDBSearchResult]]()) { $0[$1.0] = $1.1 }
                .merging(kidsLoadedCatalogs) { _, kids in kids }

            // "Best" shelves share the corresponding top-rated data source,
            // but retain their own catalog IDs because Home renders each
            // selected catalog by its ID. Without these aliases the requests
            // succeed yet the selected ranked shelves remain blank.
            if enabledCatalogIds.contains("bestTVShows") {
                tmdbLoadedCatalogs["bestTVShows"] = tmdbLoadedCatalogs["topRatedTVShows"] ?? []
            }
            if enabledCatalogIds.contains("bestMovies") {
                tmdbLoadedCatalogs["bestMovies"] = tmdbLoadedCatalogs["topRatedMovies"] ?? []
            }
            let tmdbLoadedCatalogCount = tmdbLoadedCatalogs.values.filter { !$0.isEmpty }.count

            if tmdbLoadedCatalogCount > 0 {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    self.catalogResults = tmdbLoadedCatalogs
                    self.applyHeroBannerSelection()
                    self.errorMessage = nil
                    self.hasRenderableStartupContent = true
                }
            }

            let requiredAnimeCatalogs = self.requiredAnimeCatalogKinds(
                enabledCatalogIds: enabledCatalogIds,
                needsTopRatedAnime: needsTopRatedAnime
            )
            let rawAnimeCatalogs = await self.loadFastAnimeCatalogs(
                tmdbService: tmdbService,
                requiredKinds: requiredAnimeCatalogs
            )
            guard !Task.isCancelled else { return }
            await contentFilter.prepareMaturityRatings(for: Array(rawAnimeCatalogs.values.joined()))
            let animeCatalogs = rawAnimeCatalogs.mapValues { contentFilter.filterFastAnimeSearchResults($0) }
            let rawAnimeByCatalogID: [String: [TMDBSearchResult]] = [
                "trendingAnime": rawAnimeCatalogs[.trending] ?? [],
                "popularAnime": rawAnimeCatalogs[.popular] ?? [],
                "topRatedAnime": rawAnimeCatalogs[.topRated] ?? [],
                "airingAnime": rawAnimeCatalogs[.airing] ?? []
            ]
            await MainActor.run {
                guard self.loadGeneration == generation else { return }
                self.unfilteredCatalogResults.merge(rawAnimeByCatalogID) { _, anime in anime }
                if enabledCatalogIds.contains("bestAnime") {
                    self.unfilteredCatalogResults["bestAnime"] = rawAnimeByCatalogID["topRatedAnime"] ?? []
                }
            }
            let trendingAnime = animeCatalogs[.trending] ?? []
            let popularAnime = animeCatalogs[.popular] ?? []
            let topRatedAnime = animeCatalogs[.topRated] ?? []
            let airingAnime = animeCatalogs[.airing] ?? []

            var animeLoadedCatalogs: [String: [TMDBSearchResult]] = [
                "trendingAnime": trendingAnime,
                "popularAnime": popularAnime,
                "topRatedAnime": topRatedAnime,
                "airingAnime": airingAnime
            ]
            if enabledCatalogIds.contains("bestAnime") {
                animeLoadedCatalogs["bestAnime"] = topRatedAnime
            }
            let loadedCatalogs = tmdbLoadedCatalogs.merging(animeLoadedCatalogs) { _, anime in anime }
            let loadedCatalogCount = loadedCatalogs.values.filter { !$0.isEmpty }.count

            await MainActor.run {
                guard self.loadGeneration == generation else { return }
                self.catalogResults = loadedCatalogs
                self.applyHeroBannerSelection()
                self.errorMessage = nil
                if loadedCatalogCount > 0 {
                    self.hasRenderableStartupContent = true
                }
            }

            // Recommendation catalogs depend on the first provider snapshot.
            // Start them now instead of waiting for optional widgets and remote
            // catalogs, so app-provided shelves can render independently.
            await self.loadRecommendationCatalogs(
                enabledCatalogs: enabledCatalogSnapshot,
                tmdbService: tmdbService,
                contentFilter: contentFilter,
                generation: generation
            )
            guard !Task.isCancelled else { return }

            // Resolve clean AniList covers after the first catalog render. This
            // keeps the home screen responsive while replacing TMDB's anime
            // posters as soon as the higher-quality anime artwork is available.
            if !rawAnimeByCatalogID.isEmpty {
                Task { [weak self] in
                    guard let self else { return }
                    let enriched = await self.enrichAnimePosterArtwork(rawAnimeByCatalogID)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard self.loadGeneration == generation else { return }
                        self.unfilteredCatalogResults.merge(enriched) { _, incoming in incoming }
                        let filtered = enriched.mapValues {
                            contentFilter.filterFastAnimeSearchResults($0)
                        }
                        self.catalogResults.merge(filtered) { _, incoming in incoming }
                        self.applyHeroBannerSelection()
                    }
                }
            }

            var seenTVMazeIDs = Set<Int>()
            let tvMazeRequests = loadedCatalogs.values
                .flatMap { $0 }
                .compactMap { result -> TVMazePosterRequest? in
                    let language = result.originalLanguage?.lowercased() ?? ""
                    let likelyAnime = result.animeIdentitySeed != nil
                        || result.isAnimeHint == true
                        || (result.genreIds?.contains(16) == true
                            && (["ja", "zh", "ko"].contains(language)
                                || result.originCountry?.contains(where: { ["JP", "CN", "KR", "TW"].contains($0) }) == true))
                    guard result.mediaType.lowercased() == "tv",
                          !likelyAnime,
                          seenTVMazeIDs.insert(result.id).inserted else { return nil }
                    let rawYear = result.firstAirDate ?? result.releaseDate
                    return TVMazePosterRequest(
                        id: result.id,
                        title: result.displayTitle,
                        year: rawYear.flatMap { Int($0.prefix(4)) }
                    )
                }

            let fanartRequests = Array(
                Set(loadedCatalogs.values.flatMap { $0 }.compactMap { result -> Int? in
                    guard result.mediaType.lowercased() == "movie",
                          result.animeIdentitySeed == nil,
                          result.isAnimeHint != true else { return nil }
                    return result.id
                })
            ).map { FanartTVMoviePosterRequest(id: $0) }

            if !tvMazeRequests.isEmpty || !fanartRequests.isEmpty {
                Task { [weak self] in
                    async let tvMazePostersTask = TVMazeArtworkPosterService.shared.posters(for: tvMazeRequests)
                    async let fanartPostersTask = FanartTVMovieArtworkService.shared.posters(for: fanartRequests)
                    let (tvMazePosters, fanartPosters) = await (tvMazePostersTask, fanartPostersTask)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self, self.loadGeneration == generation else { return }
                        self.unfilteredCatalogResults = self.unfilteredCatalogResults.mapValues { items in
                            items.map { item in
                                var enriched = item
                                if let poster = tvMazePosters[item.id] {
                                    enriched = enriched.withTVMazePosterURL(poster)
                                }
                                if let poster = fanartPosters[item.id] {
                                    enriched = enriched.withFanartTVPosterURL(poster)
                                }
                                return enriched
                            }
                        }
                        self.catalogResults = self.catalogResults.mapValues { items in
                            items.map { item in
                                var enriched = item
                                if let poster = tvMazePosters[item.id] {
                                    enriched = enriched.withTVMazePosterURL(poster)
                                }
                                if let poster = fanartPosters[item.id] {
                                    enriched = enriched.withFanartTVPosterURL(poster)
                                }
                                return enriched
                            }
                        }
                        self.applyHeroBannerSelection()
                    }
                }
            }

            async let stremioCatalogs = self.loadStremioCatalogs(
                enabledCatalogs: enabledCatalogSnapshot,
                tmdbService: tmdbService
            )
            async let traktCatalogs = self.loadTraktCatalogs(
                enabledCatalogs: enabledCatalogSnapshot,
                tmdbService: tmdbService
            )
            async let widgetsLoaded: Void = self.loadWidgetData(
                tmdbService: tmdbService,
                enabledCatalogs: enabledCatalogSnapshot,
                contentFilter: contentFilter,
                generation: generation
            )

            let loadedStremioCatalogs = await stremioCatalogs
            let loadedTraktCatalogs = await traktCatalogs
            let externalCatalogResults = Array(loadedStremioCatalogs.values.joined())
                + Array(loadedTraktCatalogs.values.joined())
            await contentFilter.prepareMaturityRatings(for: externalCatalogResults)
            let filteredStremioCatalogs = loadedStremioCatalogs.mapValues {
                contentFilter.filterSearchResults($0)
            }
            let filteredTraktCatalogs = loadedTraktCatalogs.mapValues {
                contentFilter.filterSearchResults($0)
            }
            await MainActor.run {
                guard self.loadGeneration == generation else { return }
                self.unfilteredCatalogResults.merge(loadedStremioCatalogs) { _, raw in raw }
                self.unfilteredCatalogResults.merge(loadedTraktCatalogs) { _, raw in raw }
            }
            _ = await widgetsLoaded
            let firstCatalogFailure = await catalogFailureRecorder.firstFailureMessage()

            await MainActor.run {

                guard self.loadGeneration == generation else { return }
                let currentlyEnabledCatalogIds = Set(catalogManager.getEnabledCatalogs().map(\.id))
                let enabledStremioCatalogs = filteredStremioCatalogs.filter {
                    currentlyEnabledCatalogIds.contains($0.key)
                }
                if !enabledStremioCatalogs.isEmpty {
                    self.catalogResults.merge(enabledStremioCatalogs) { _, stremio in stremio }
                }
                if !filteredTraktCatalogs.isEmpty {
                    self.catalogResults.merge(filteredTraktCatalogs) { _, trakt in trakt }
                }

                let finalLoadedCount = self.catalogResults.values.filter { !$0.isEmpty }.count
                    + self.widgetData.values.filter { !$0.isEmpty }.count
                let tmdbCatalogCount = rawTMDBLoadedCatalogs.values.filter { !$0.isEmpty }.count
                let animeCatalogCount = rawAnimeCatalogs.values.filter { !$0.isEmpty }.count
                let stremioCatalogCount = loadedStremioCatalogs.values.filter { !$0.isEmpty }.count
                let traktCatalogCount = loadedTraktCatalogs.values.filter { !$0.isEmpty }.count
                let widgetCatalogCount = self.unfilteredWidgetData.values.filter { !$0.isEmpty }.count
                self.applyHeroBannerSelection()
                self.isLoading = false
                let permitsEmptyResults = enabledCatalogSnapshot.allSatisfy { $0.source == .local }
                // Count every provider that can render Home content. In particular,
                // AniList-only profiles must not be treated as an unsuccessful load
                // just because their TMDB catalog snapshot is empty.
                self.hasLoadedContent = HomeCatalogLoadPolicy.hasLoadedContent(
                    tmdbCatalogCount: tmdbCatalogCount,
                    animeCatalogCount: animeCatalogCount,
                    stremioCatalogCount: stremioCatalogCount,
                    traktCatalogCount: traktCatalogCount,
                    widgetCatalogCount: widgetCatalogCount,
                    permitsEmptyResults: permitsEmptyResults
                )
                if self.hasLoadedContent && self.pendingCatalogFilterRefresh {
                    self.pendingCatalogFilterRefresh = false
                    Task { @MainActor [weak self] in
                        await self?.reapplyCatalogFilters()
                    }
                }
                self.hasCompletedInitialLoad = true
                self.hasRenderableStartupContent = finalLoadedCount > 0
                if finalLoadedCount == 0 && !permitsEmptyResults {
                    if let firstCatalogFailure {
                        self.errorMessage = "Home data could not be loaded. \(firstCatalogFailure)"
                    } else {
                        self.errorMessage = "No results were returned by the enabled catalogs. Check your content filters and catalog selections."
                    }
                } else {
                    self.errorMessage = nil
                }
                self.activeLoadTask = nil
            }
        }
    }

    private func loadRecommendationCatalogs(
        enabledCatalogs: [Catalog],
        tmdbService: TMDBService,
        contentFilter: TMDBContentFilter,
        generation: UUID
    ) async {
        let owner = await MainActor.run { ProfileManager.shared.activeProfileID }

        if enabledCatalogs.contains(where: { $0.id == "forYou" }) {
            let currentResults = await MainActor.run { self.catalogResults }
            let rawForYou = await RecommendationEngine.shared.generateRecommendations(
                catalogResults: currentResults,
                tmdbService: tmdbService
            )
            await contentFilter.prepareMaturityRatings(for: rawForYou)
            let forYou = contentFilter.filterSearchResults(rawForYou)
            if !rawForYou.isEmpty {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    guard ProfileManager.shared.isStillActive(owner) else { return }
                    self.unfilteredCatalogResults["forYou"] = rawForYou
                    self.catalogResults["forYou"] = forYou
                    if !forYou.isEmpty { self.hasRenderableStartupContent = true }
                    self.applyHeroBannerSelection()
                }
            }
        }

        if enabledCatalogs.contains(where: { $0.id == "becauseYouWatched" }) {
            let (bywTitle, rawBYWResults) = await RecommendationEngine.shared.generateBecauseYouWatched(
                tmdbService: tmdbService
            )
            await contentFilter.prepareMaturityRatings(for: rawBYWResults)
            let bywResults = contentFilter.filterSearchResults(rawBYWResults)
            if !rawBYWResults.isEmpty {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    guard ProfileManager.shared.isStillActive(owner) else { return }
                    self.unfilteredCatalogResults["becauseYouWatched"] = rawBYWResults
                    self.catalogResults["becauseYouWatched"] = bywResults
                    if !bywResults.isEmpty { self.hasRenderableStartupContent = true }
                    self.becauseYouWatchedTitle = bywTitle
                    self.applyHeroBannerSelection()
                }
            }
        }
    }

    private func loadKidsCatalogs(
        tmdbService: TMDBService,
        catalogs: [Catalog]
    ) async -> [String: [TMDBSearchResult]] {
        let kinds = catalogs.compactMap { KidsHomeCatalog.from(catalogID: $0.id) }
        guard !kinds.isEmpty else { return [:] }

        var raw: [String: [TMDBSearchResult]] = [:]
        await withTaskGroup(of: (String, [TMDBSearchResult]).self) { group in
            for kind in kinds {
                group.addTask {
                    do {
                        let items = try await tmdbService.discoverForKids(query: kind.query)
                        return (kind.catalogID, items)
                    } catch {
                        await self.catalogFailureRecorder.record(
                            "Catalog \(kind.catalogID): \(HomeCatalogFailurePresentation.message(for: error))"
                        )
                        return (kind.catalogID, [])
                    }
                }
            }
            for await (id, items) in group {
                raw[id] = items
            }
        }

        return raw
    }

    private func loadHomeCatalog<T>(_ id: String, fetch: () async throws -> [T]) async -> [T] {
        // Home is composed from independent providers/catalogs. A transient
        // connection reset or TMDB 5xx must not permanently turn an otherwise
        // healthy Home launch into an empty catalog screen.
        let retryDelays: [UInt64] = [400_000_000, 1_000_000_000]
        var lastError: Error?

        for attempt in 0...retryDelays.count {
            guard !Task.isCancelled else { return [] }
            do {
                let items = try await fetch()
                Logger.shared.log(
                    "HomeViewModel: catalog \(id) loaded count=\(items.count) attempt=\(attempt + 1)",
                    type: "TMDB"
                )
                return items
            } catch {
                lastError = error
                await catalogFailureRecorder.record("Catalog \(id): \(HomeCatalogFailurePresentation.message(for: error))")
                guard attempt < retryDelays.count,
                      Self.shouldRetryHomeCatalogRequest(after: error),
                      !Task.isCancelled else {
                    break
                }
                Logger.shared.log(
                    "HomeViewModel: catalog \(id) transient failure on attempt \(attempt + 1); retrying: \(error.localizedDescription)",
                    type: "TMDB"
                )
                do {
                    try await Task.sleep(nanoseconds: retryDelays[attempt])
                } catch {
                    return []
                }
            }
        }

        Logger.shared.log(
            "HomeViewModel: catalog \(id) failed after retries: \(lastError?.localizedDescription ?? "unknown error")",
            type: "Error"
        )
        return []
    }

    private static func shouldRetryHomeCatalogRequest(after error: Error) -> Bool {
        if let tmdbError = error as? TMDBError {
            switch tmdbError {
            case .networkError(let underlying):
                return shouldRetryHomeCatalogRequest(after: underlying)
            case .httpError(let statusCode, _, _):
                return statusCode == 408 || statusCode == 425 || statusCode == 429 || (500...599).contains(statusCode)
            case .invalidURL, .decodingError, .missingAPIKey:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch URLError.Code(rawValue: nsError.code) {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
                 .notConnectedToInternet, .dnsLookupFailed, .resourceUnavailable:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func loadHomeCatalogIfNeeded<T>(
        _ id: String,
        shouldLoad: Bool,
        fetch: () async throws -> [T]
    ) async -> [T] {
        guard shouldLoad else { return [] }
        return await loadHomeCatalog(id, fetch: fetch)
    }

    private func requiredAnimeCatalogKinds(
        enabledCatalogIds: Set<String>,
        needsTopRatedAnime: Bool
    ) -> Set<AniListService.AniListCatalogKind> {
        var kinds = Set<AniListService.AniListCatalogKind>()
        if enabledCatalogIds.contains("trendingAnime") { kinds.insert(.trending) }
        if enabledCatalogIds.contains("popularAnime") { kinds.insert(.popular) }
        if needsTopRatedAnime { kinds.insert(.topRated) }
        if enabledCatalogIds.contains("airingAnime") { kinds.insert(.airing) }

        // The hero banner is independent from the visible shelf configuration.
        // Selecting Anime must still load candidates when anime shelves are hidden.
        if ProfileSettingsStore.active.string(forKey: "heroBannerCatalogId") == "anime" {
            kinds.formUnion([.trending, .popular])
        }
        return kinds
    }

    private func loadFastAnimeCatalogs(
        tmdbService: TMDBService,
        requiredKinds: Set<AniListService.AniListCatalogKind>
    ) async -> [AniListService.AniListCatalogKind: [TMDBSearchResult]] {
        guard !requiredKinds.isEmpty else { return [:] }

        return await withTaskGroup(
            of: (AniListService.AniListCatalogKind, [TMDBSearchResult]).self
        ) { group in
            for kind in requiredKinds {
                let fastKind = fastAnimeCatalogKind(for: kind)
                group.addTask {
                    let items: [TMDBSearchResult] = await self.loadHomeCatalog("fastAnime:\(kind)") {
                        try await tmdbService.getFastAnimeCatalog(kind: fastKind, limit: 20)
                    }
                    return (kind, items)
                }
            }

            var loaded: [AniListService.AniListCatalogKind: [TMDBSearchResult]] = [:]
            for await (kind, items) in group where !items.isEmpty {
                loaded[kind] = items
            }
            let loadedSummary = loaded
                .map { "\(String(describing: $0.key))=\($0.value.count)" }
                .sorted()
                .joined(separator: ",")
            Logger.shared.log("HomeViewModel: performance anime catalogs loaded \(loadedSummary.isEmpty ? "none" : loadedSummary)", type: "TMDB")
            return loaded
        }
    }

    private func fastAnimeCatalogKind(for kind: AniListService.AniListCatalogKind) -> TMDBService.FastAnimeCatalogKind {
        switch kind {
        case .trending:
            return .trending
        case .popular:
            return .popular
        case .topRated:
            return .topRated
        case .airing:
            return .airing
        }
    }

    private func enrichAnimePosterArtwork(
        _ catalogs: [String: [TMDBSearchResult]]
    ) async -> [String: [TMDBSearchResult]] {
        let flattened = catalogs.flatMap { catalogID, results in
            results.enumerated().map { (catalogID, $0.offset, $0.element) }
        }
        guard !flattened.isEmpty else { return catalogs }

        let resolved = await withTaskGroup(of: (String, Int, TMDBSearchResult).self) { group in
            var iterator = flattened.makeIterator()
            let concurrencyLimit = 8
            for _ in 0..<min(concurrencyLimit, flattened.count) {
                guard let item = iterator.next() else { continue }
                group.addTask {
                    await Self.enrichAnimePosterArtwork(item.2, catalogID: item.0, index: item.1)
                }
            }

            var resolved: [String: [Int: TMDBSearchResult]] = [:]
            while let (catalogID, index, result) = await group.next() {
                resolved[catalogID, default: [:]][index] = result
                if let item = iterator.next() {
                    group.addTask {
                        await Self.enrichAnimePosterArtwork(item.2, catalogID: item.0, index: item.1)
                    }
                }
            }

            var output: [String: [TMDBSearchResult]] = [:]
            for (catalogID, results) in catalogs {
                let replacements = resolved[catalogID] ?? [:]
                output[catalogID] = results.enumerated().map { replacements[$0.offset] ?? $0.element }
            }
            return output
        }

        let artworkByID = await TaizenAnimeArtworkService.shared.artworks(
            forAniListIDs: resolved.values.flatMap { $0.compactMap { $0.animeIdentitySeed?.anilistId } }
        )
        return resolved.mapValues { results in
            results.map { result in
                guard let anilistID = result.animeIdentitySeed?.anilistId,
                      let artwork = artworkByID[anilistID] else { return result }
                return result
                    .withAnimeArtworkURL(artwork.posterURL ?? result.animeArtworkURL)
                    .withAnimeLogoURL(artwork.logoURL ?? result.animeLogoURL)
            }
        }
    }

    private static func enrichAnimePosterArtwork(
        _ result: TMDBSearchResult,
        catalogID: String,
        index: Int
    ) async -> (String, Int, TMDBSearchResult) {
        let mappings = await AniMapMappingService.shared.mappings(forTMDBShowId: result.id)
        let mapping = mappings
            .filter { $0.mediaType?.lowercased() != "movie" }
            .first { $0.anilistId != nil }
            ?? mappings.first { $0.anilistId != nil }
        guard let anilistID = result.animeIdentitySeed?.anilistId ?? mapping?.anilistId,
              anilistID > 0 else {
            return (catalogID, index, result)
        }

        let identity = await AniListService.shared.fetchAnimeSeasonIdentity(
            anilistId: anilistID,
            tmdbShowId: result.id,
            title: result.displayTitle
        )
        guard let posterURL = identity?.posterURL ?? result.animeArtworkURL else {
            return (catalogID, index, result)
        }

        let enriched = TMDBSearchResult(
            id: result.id,
            mediaType: result.mediaType,
            title: result.title,
            name: result.name,
            overview: result.overview,
            posterPath: result.posterPath,
            backdropPath: result.backdropPath,
            releaseDate: result.releaseDate,
            firstAirDate: result.firstAirDate,
            voteAverage: result.voteAverage,
            popularity: result.popularity,
            adult: result.adult,
            genreIds: result.genreIds,
            originalLanguage: result.originalLanguage,
            originCountry: result.originCountry,
            voteCount: result.voteCount,
            isAnimeHint: true,
            animeIdentitySeed: result.animeIdentitySeed ?? AnimeMediaIdentitySeed(
                anilistId: anilistID,
                malId: mapping?.malId,
                kitsuId: mapping?.kitsuId,
                format: mapping?.mediaType
            ),
            animeArtworkURL: posterURL,
            animeLogoURL: result.animeLogoURL,
            tvMazePosterURL: result.tvMazePosterURL,
            fanartTVPosterURL: result.fanartTVPosterURL
        )
        return (catalogID, index, enriched)
    }

    private func loadStremioCatalogs(
        enabledCatalogs: [Catalog],
        tmdbService: TMDBService
    ) async -> [String: [TMDBSearchResult]] {
        let catalogs = enabledCatalogs.filter { $0.source == .stremio }
        guard !catalogs.isEmpty else { return [:] }

        var loaded: [String: [TMDBSearchResult]] = [:]
        for catalog in catalogs {
            if Task.isCancelled { break }
            let items = await StremioAddonManager.shared.fetchCatalogItems(
                for: catalog,
                tmdbService: tmdbService,
                limit: 15
            )
            if !items.isEmpty {
                loaded[catalog.id] = items
            }
        }

        let summary = loaded
            .map { "\($0.key)=\($0.value.count)" }
            .sorted()
            .joined(separator: ",")
        Logger.shared.log("HomeViewModel: Stremio catalogs loaded \(summary.isEmpty ? "none" : summary)", type: "Stremio")
        return loaded
    }

    private func loadTraktCatalogs(
        enabledCatalogs: [Catalog],
        tmdbService: TMDBService
    ) async -> [String: [TMDBSearchResult]] {
        let catalogs = enabledCatalogs.filter { $0.source == .trakt }
        guard !catalogs.isEmpty else { return [:] }

        var loaded: [String: [TMDBSearchResult]] = [:]
        for catalog in catalogs {
            if Task.isCancelled { break }
            let items = await TrackerManager.shared.fetchTraktPublicListCatalogItems(
                for: catalog,
                tmdbService: tmdbService,
                limit: 15
            )
            if !items.isEmpty {
                loaded[catalog.id] = items
            }
        }

        let summary = loaded
            .map { "\($0.key)=\($0.value.count)" }
            .sorted()
            .joined(separator: ",")
        Logger.shared.log("HomeViewModel: Trakt public catalogs loaded \(summary.isEmpty ? "none" : summary)", type: "Tracker")
        return loaded
    }

    private func movieSearchResult(_ movie: TMDBMovie) -> TMDBSearchResult {
        TMDBSearchResult(
            id: movie.id,
            mediaType: "movie",
            title: movie.title,
            name: nil,
            overview: movie.overview,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            releaseDate: movie.releaseDate,
            firstAirDate: nil,
            voteAverage: movie.voteAverage,
            popularity: movie.popularity,
            adult: movie.adult,
            genreIds: movie.genreIds
        )
    }

    private func tvSearchResult(_ show: TMDBTVShow) -> TMDBSearchResult {
        TMDBSearchResult(
            id: show.id,
            mediaType: "tv",
            title: nil,
            name: show.name,
            overview: show.overview,
            posterPath: show.posterPath,
            backdropPath: show.backdropPath,
            releaseDate: nil,
            firstAirDate: show.firstAirDate,
            voteAverage: show.voteAverage,
            popularity: show.popularity,
            adult: show.adult,
            genreIds: show.genreIds
        )
    }

    func loadWidgetData(
        tmdbService: TMDBService,
        enabledCatalogs: [Catalog],
        contentFilter: TMDBContentFilter,
        generation: UUID
    ) async {
            guard !Task.isCancelled else { return }

            let rankedMappings: [(catalogId: String, sourceKey: String)] = [
                ("bestTVShows", "topRatedTVShows"),
                ("bestMovies", "topRatedMovies"),
                ("bestAnime", "topRatedAnime")
            ]
            let currentResults = await MainActor.run { (self.catalogResults, self.unfilteredCatalogResults) }
            for mapping in rankedMappings {
                let rawItems = currentResults.1[mapping.sourceKey] ?? currentResults.0[mapping.sourceKey] ?? []
                if enabledCatalogs.contains(where: { $0.id == mapping.catalogId }), !rawItems.isEmpty {
                    let items = await contentFilter.filterSearchResultsResolvingRatings(rawItems)
                    await MainActor.run {
                        guard self.loadGeneration == generation else { return }
                        self.unfilteredWidgetData[mapping.catalogId] = rawItems
                        self.widgetData[mapping.catalogId] = items
                        if !items.isEmpty { self.hasRenderableStartupContent = true }
                        self.applyHeroBannerSelection()
                    }
                }
            }

            if enabledCatalogs.contains(where: { $0.id == "networks" }) {
                await withTaskGroup(of: (Int, [TMDBSearchResult], [TMDBSearchResult]).self) { group in
                    for network in WidgetNetwork.active {
                        group.addTask {
                            let raw = (try? await tmdbService.discoverByNetwork(networkId: network.id)) ?? []
                            let filtered = await contentFilter.filterSearchResultsResolvingRatings(raw)
                            return (network.id, raw, filtered)
                        }
                    }
                    for await (networkId, raw, results) in group {
                        guard !Task.isCancelled else { return }
                        if !raw.isEmpty {
                            await MainActor.run {
                                guard self.loadGeneration == generation else { return }
                                self.unfilteredWidgetData["network_\(networkId)"] = raw
                                self.widgetData["network_\(networkId)"] = results
                                if !results.isEmpty { self.hasRenderableStartupContent = true }
                                self.applyHeroBannerSelection()
                            }
                        }
                    }
                }
            }

            if enabledCatalogs.contains(where: { $0.id == "genres" }) {
                await withTaskGroup(of: (Int, [TMDBSearchResult], [TMDBSearchResult]).self) { group in
                    for genre in WidgetGenre.active {
                        group.addTask {
                            let raw = (try? await tmdbService.discoverByGenre(genreId: genre.id)) ?? []
                            let filtered = await contentFilter.filterSearchResultsResolvingRatings(raw)
                            return (genre.id, raw, filtered)
                        }
                    }
                    for await (genreId, raw, results) in group {
                        guard !Task.isCancelled else { return }
                        if !raw.isEmpty {
                            await MainActor.run {
                                guard self.loadGeneration == generation else { return }
                                self.unfilteredWidgetData["genre_\(genreId)"] = raw
                                self.widgetData["genre_\(genreId)"] = results
                                if !results.isEmpty { self.hasRenderableStartupContent = true }
                                self.applyHeroBannerSelection()
                            }
                        }
                    }
                }
            }

            if enabledCatalogs.contains(where: { $0.id == "companies" }) {
                await withTaskGroup(of: (Int, [TMDBSearchResult], [TMDBSearchResult]).self) { group in
                    for company in WidgetCompany.active {
                        group.addTask {
                            let raw = (try? await tmdbService.discoverByCompany(companyId: company.id)) ?? []
                            let filtered = await contentFilter.filterSearchResultsResolvingRatings(raw)
                            return (company.id, raw, filtered)
                        }
                    }
                    for await (companyId, raw, results) in group {
                        guard !Task.isCancelled else { return }
                        if !raw.isEmpty {
                            await MainActor.run {
                                guard self.loadGeneration == generation else { return }
                                self.unfilteredWidgetData["company_\(companyId)"] = raw
                                self.widgetData["company_\(companyId)"] = results
                                if !results.isEmpty { self.hasRenderableStartupContent = true }
                                self.applyHeroBannerSelection()
                            }
                        }
                    }
                }
            }

            if enabledCatalogs.contains(where: { $0.id == "featured" }) {
                guard !Task.isCancelled else { return }
                guard let randomGenre = WidgetGenre.activeTV.randomElement() else { return }
                let rawResults = (try? await tmdbService.discoverByGenre(genreId: randomGenre.id, mediaType: "tv")) ?? []
                let results = await contentFilter.filterSearchResultsResolvingRatings(rawResults)
                if !rawResults.isEmpty {
                    await MainActor.run {
                        guard self.loadGeneration == generation else { return }
                        self.unfilteredWidgetData["featured"] = rawResults
                        self.widgetData["featured"] = results
                        if !results.isEmpty { self.hasRenderableStartupContent = true }
                        self.widgetData["featured_genreName"] = []
                        self.applyHeroBannerSelection()
                    }

                    await MainActor.run {
                        guard self.loadGeneration == generation else { return }
                        self.featuredGenreName = randomGenre.name
                    }
            }
        }
    }

    @Published var featuredGenreName: String = ""

    func refreshHeroContentForSettingsChange() {
        applyHeroBannerSelection()
    }

    func advanceHeroCarouselIfNeeded(by offset: Int = 1) {
        let behaviorRaw = ProfileSettingsStore.active.string(forKey: "heroBannerBehavior") ?? HeroBannerBehavior.defaultValue.rawValue
        guard HeroBannerBehavior(rawValue: behaviorRaw) == .carousel else { return }
        guard heroCarouselGeneration == loadGeneration, heroCarouselItems.count > 1 else { return }
        let count = heroCarouselItems.count
        let normalizedOffset = ((offset % count) + count) % count
        guard normalizedOffset != 0 else { return }
        heroCarouselIndex = (heroCarouselIndex + normalizedOffset) % count
        heroContent = heroCarouselItems[heroCarouselIndex]
    }

    private func applyHeroBannerSelection() {
        let catalogId = ProfileSettingsStore.active.string(forKey: "heroBannerCatalogId") ?? "trending"
        let behaviorRaw = ProfileSettingsStore.active.string(forKey: "heroBannerBehavior") ?? HeroBannerBehavior.defaultValue.rawValue
        let behavior = HeroBannerBehavior(rawValue: behaviorRaw) ?? .defaultValue
        let selectedTitles = HomeHeroSelectionSettings.load()
        let usesCustomSelection = !selectedTitles.isEmpty
        let selectionKey = usesCustomSelection
            ? "custom:" + selectedTitles.map(\.stableIdentity).joined(separator: "|")
            : "catalog:\(catalogId)"
        // Explicitly selected hero titles are an intentional user override.
        // Do not silently discard them when the optional dub catalogue has no
        // identity match (which previously left the hero banner completely empty).
        let rawCandidates = usesCustomSelection
            ? selectedTitles
            : heroCandidates(for: catalogId).filter { MyDubListDubFilter.shared.shouldInclude($0) }
#if os(iOS)
        let iPadBackdropCandidates = rawCandidates.filter { $0.fullBackdropURL != nil }
        let candidates = !usesCustomSelection && UIDevice.current.userInterfaceIdiom == .pad && !iPadBackdropCandidates.isEmpty
            ? iPadBackdropCandidates
            : rawCandidates
#elseif os(tvOS)
        let tvBackdropCandidates = rawCandidates.filter { $0.fullBackdropURL != nil }
        let candidates = !usesCustomSelection && !tvBackdropCandidates.isEmpty ? tvBackdropCandidates : rawCandidates
#else
        let candidates = rawCandidates
#endif

        guard !candidates.isEmpty else {
            heroCarouselItems = []
            heroCarouselIndex = 0
            heroCarouselGeneration = nil
            heroContent = nil
            heroLaunchSelectionKey = nil
            return
        }
        heroCarouselGeneration = loadGeneration

        switch behavior {
        case .static:
            heroCarouselItems = candidates
            heroLaunchSelectionKey = nil
            heroCarouselIndex = 0
            heroContent = candidates.first
        case .carousel:

            heroCarouselItems = usesCustomSelection ? candidates : Array(candidates.prefix(Self.maxHeroCarouselItems))
            heroLaunchSelectionKey = nil
            if let current = heroContent,
               let currentIndex = heroCarouselItems.firstIndex(where: { $0.stableIdentity == current.stableIdentity }) {
                heroCarouselIndex = currentIndex
            } else {
                heroCarouselIndex = 0
                heroContent = heroCarouselItems.first
            }
        case .launch:
            heroCarouselItems = candidates
            if heroLaunchSelectionKey == selectionKey,
               let current = heroContent,
               let currentIndex = candidates.firstIndex(where: { $0.stableIdentity == current.stableIdentity }) {
                heroCarouselIndex = currentIndex
                return
            }
            let selectedIndex = candidates.indices.randomElement() ?? candidates.startIndex
            heroLaunchSelectionKey = selectionKey
            heroCarouselIndex = selectedIndex
            heroContent = candidates[selectedIndex]
        }
    }

    private func heroCandidates(for catalogId: String) -> [TMDBSearchResult] {
        if catalogId == "anime" {
            let animeCatalogIDs = ["trendingAnime", "popularAnime", "topRatedAnime", "airingAnime", "bestAnime"]
            var seen = Set<String>()
            return animeCatalogIDs
                .flatMap { catalogResults[$0] ?? [] }
                .filter { seen.insert($0.stableIdentity).inserted }
        }

        if let items = catalogResults[catalogId], !items.isEmpty {
            return items
        }

        if let items = widgetData[catalogId], !items.isEmpty {
            return items
        }

        if catalogId == "networks" {
            let items = WidgetNetwork.active.flatMap { widgetData["network_\($0.id)"] ?? [] }
            if !items.isEmpty { return items }
        }

        if catalogId == "genres" {
            let items = WidgetGenre.active.flatMap { widgetData["genre_\($0.id)"] ?? [] }
            if !items.isEmpty { return items }
        }

        if catalogId == "companies" {
            let items = WidgetCompany.active.flatMap { widgetData["company_\($0.id)"] ?? [] }
            if !items.isEmpty { return items }
        }

        if let trending = catalogResults["trending"], !trending.isEmpty {
            return trending
        }

        for kind in KidsHomeCatalog.allCases {
            if let items = catalogResults[kind.catalogID], !items.isEmpty {
                return items
            }
        }
        return catalogResults
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .first?
            .value ?? []
    }

    func resetContent(
        preserveVisibleContent: Bool = false,
        invalidateRecommendations: Bool = true
    ) {
        activeLoadTask?.cancel()
        activeLoadTask = nil

        loadGeneration = UUID()
        heroCarouselGeneration = preserveVisibleContent ? loadGeneration : nil
        if !preserveVisibleContent {
            heroCarouselItems = []
            heroCarouselIndex = 0
            catalogResults = [:]
            widgetData = [:]
            unfilteredCatalogResults = [:]
            unfilteredWidgetData = [:]
            isLoading = true
            heroContent = nil
            heroLaunchSelectionKey = nil
            featuredGenreName = ""
            becauseYouWatchedTitle = ""
            hasRenderableStartupContent = false
        }
        errorMessage = nil
        hasLoadedContent = false
        hasCompletedInitialLoad = false
        if invalidateRecommendations {
            RecommendationEngine.shared.invalidateCache()
        }
    }
}
