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
        let allResults = Array(catalogSnapshot.values.joined()) + Array(widgetSnapshot.values.joined())
        await contentFilter.prepareMaturityRatings(for: allResults)

        catalogResults = catalogSnapshot.mapValues { contentFilter.filterSearchResults($0) }
        widgetData = widgetSnapshot.mapValues { contentFilter.filterSearchResults($0) }
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
            let (enabledCatalogSnapshot, generation) = await MainActor.run {

                _ = StremioAddonManager.shared
                return (catalogManager.getEnabledCatalogs(), self.loadGeneration)
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

            async let trending: [TMDBSearchResult] = self.loadHomeCatalogIfNeeded("trending", shouldLoad: enabledCatalogIds.contains("trending")) {
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
            }
            await contentFilter.prepareMaturityRatings(
                for: Array(rawTMDBLoadedCatalogs.values.joined())
            )
            guard !Task.isCancelled else { return }
            let kidsLoadedCatalogs = await self.loadKidsCatalogs(
                tmdbService: tmdbService,
                contentFilter: contentFilter,
                catalogs: enabledCatalogSnapshot
            )
            guard !Task.isCancelled else { return }
            let tmdbLoadedCatalogs = rawTMDBLoadedCatalogs
                .mapValues { contentFilter.filterSearchResults($0) }
                .merging(kidsLoadedCatalogs) { _, kids in kids }
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
            }
            let trendingAnime = animeCatalogs[.trending] ?? []
            let popularAnime = animeCatalogs[.popular] ?? []
            let topRatedAnime = animeCatalogs[.topRated] ?? []
            let airingAnime = animeCatalogs[.airing] ?? []

            let animeLoadedCatalogs: [String: [TMDBSearchResult]] = [
                "trendingAnime": trendingAnime,
                "popularAnime": popularAnime,
                "topRatedAnime": topRatedAnime,
                "airingAnime": airingAnime
            ]
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

            async let stremioCatalogs = self.loadStremioCatalogs(
                enabledCatalogs: enabledCatalogSnapshot,
                tmdbService: tmdbService,
                contentFilter: contentFilter
            )
            async let traktCatalogs = self.loadTraktCatalogs(
                enabledCatalogs: enabledCatalogSnapshot,
                tmdbService: tmdbService,
                contentFilter: contentFilter
            )
            async let widgetsLoaded: Void = self.loadWidgetData(
                tmdbService: tmdbService,
                enabledCatalogs: enabledCatalogSnapshot,
                contentFilter: contentFilter,
                generation: generation
            )
            async let recommendationsLoaded: Void = self.loadRecommendationCatalogs(
                enabledCatalogs: enabledCatalogSnapshot,
                tmdbService: tmdbService,
                contentFilter: contentFilter,
                generation: generation
            )

            let loadedStremioCatalogs = await stremioCatalogs
            let loadedTraktCatalogs = await traktCatalogs
            _ = await widgetsLoaded
            _ = await recommendationsLoaded
            guard !Task.isCancelled else { return }

            await MainActor.run {

                guard self.loadGeneration == generation else { return }
                let currentlyEnabledCatalogIds = Set(catalogManager.getEnabledCatalogs().map(\.id))
                let enabledStremioCatalogs = loadedStremioCatalogs.filter {
                    currentlyEnabledCatalogIds.contains($0.key)
                }
                if !enabledStremioCatalogs.isEmpty {
                    self.catalogResults.merge(enabledStremioCatalogs) { _, stremio in stremio }
                }
                if !loadedTraktCatalogs.isEmpty {
                    self.catalogResults.merge(loadedTraktCatalogs) { _, trakt in trakt }
                }

                let finalLoadedCount = self.catalogResults.values.filter { !$0.isEmpty }.count
                    + self.widgetData.values.filter { !$0.isEmpty }.count
                self.applyHeroBannerSelection()
                self.isLoading = false
                let permitsEmptyResults = enabledCatalogSnapshot.allSatisfy { $0.source == .local }
                self.hasLoadedContent = finalLoadedCount > 0 || permitsEmptyResults
                if self.hasLoadedContent && self.pendingCatalogFilterRefresh {
                    self.pendingCatalogFilterRefresh = false
                    Task { @MainActor [weak self] in
                        await self?.reapplyCatalogFilters()
                    }
                }
                self.hasCompletedInitialLoad = true
                self.hasRenderableStartupContent = finalLoadedCount > 0
                self.errorMessage = finalLoadedCount == 0 && !permitsEmptyResults
                    ? "Unable to load home catalogs. Check your internet connection and API configuration, then try again."
                    : nil
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
            if !forYou.isEmpty {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    guard ProfileManager.shared.isStillActive(owner) else { return }
                    self.catalogResults["forYou"] = forYou
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
            if !bywResults.isEmpty {
                await MainActor.run {
                    guard self.loadGeneration == generation else { return }
                    guard ProfileManager.shared.isStillActive(owner) else { return }
                    self.catalogResults["becauseYouWatched"] = bywResults
                    self.becauseYouWatchedTitle = bywTitle
                    self.applyHeroBannerSelection()
                }
            }
        }
    }

    private func loadKidsCatalogs(
        tmdbService: TMDBService,
        contentFilter: TMDBContentFilter,
        catalogs: [Catalog]
    ) async -> [String: [TMDBSearchResult]] {
        let kinds = catalogs.compactMap { KidsHomeCatalog.from(catalogID: $0.id) }
        guard !kinds.isEmpty else { return [:] }

        var raw: [String: [TMDBSearchResult]] = [:]
        await withTaskGroup(of: (String, [TMDBSearchResult]).self) { group in
            for kind in kinds {
                group.addTask {
                    let items = (try? await tmdbService.discoverForKids(query: kind.query)) ?? []
                    return (kind.catalogID, items)
                }
            }
            for await (id, items) in group {
                raw[id] = items
            }
        }

        await contentFilter.prepareMaturityRatings(for: Array(raw.values.joined()))
        return raw.mapValues { contentFilter.filterSearchResults($0) }
    }

    private func loadHomeCatalog<T>(_ id: String, fetch: () async throws -> [T]) async -> [T] {
        do {
            let items = try await fetch()
            Logger.shared.log("HomeViewModel: catalog \(id) loaded count=\(items.count)", type: "TMDB")
            return items
        } catch {
            Logger.shared.log("HomeViewModel: catalog \(id) failed: \(error.localizedDescription)", type: "Error")
            return []
        }
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

    private func loadStremioCatalogs(
        enabledCatalogs: [Catalog],
        tmdbService: TMDBService,
        contentFilter: TMDBContentFilter
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
            await contentFilter.prepareMaturityRatings(for: items)
            let filtered = contentFilter.filterSearchResults(items)
            if !filtered.isEmpty {
                loaded[catalog.id] = filtered
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
        tmdbService: TMDBService,
        contentFilter: TMDBContentFilter
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
            await contentFilter.prepareMaturityRatings(for: items)
            let filtered = contentFilter.filterSearchResults(items)
            if !filtered.isEmpty {
                loaded[catalog.id] = filtered
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
        let rawCandidates = (usesCustomSelection ? selectedTitles : heroCandidates(for: catalogId))
            .filter { MyDubListDubFilter.shared.shouldInclude($0) }
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
