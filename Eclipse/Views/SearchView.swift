//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

enum SearchGridLayoutPolicy {
    static func columnCount(_ storedCount: Int) -> Int {
        min(max(storedCount, 1), 10)
    }
}

struct SearchView: View {
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 3
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 5
#if os(tvOS)
    @AppStorage("tvCardDensity") private var tvCardDensity = "standard"
#endif
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"
    @AppStorage("searchHistory") private var searchHistoryData: Data = Data()
    @AppStorage("searchHistorySavingEnabled") private var searchHistorySavingEnabled = false

    @State private var searchText = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var cachedCatalogResults: [TMDBSearchResult] = []
    @State private var filterRefreshRevision = 0
    @State private var lastContentFilterSettingsSignature = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchFilter: SearchFilter = .all
    @State private var searchHistory: [String] = []
    @State private var showingBrowse = false
    @State private var randomResult: TMDBSearchResult?
    @State private var isLoadingRandom = false
    @State private var randomErrorMessage: String?
    @State private var pendingSearchTask: Task<Void, Never>?
    @State private var activeSearchTask: Task<Void, Never>?
    @State private var lastSubmittedSearchQuery = ""
    @State private var searchRequestSerial = 0
#if os(tvOS)
    @FocusState private var tvFocusedResultID: String?
    @State private var tvSearchIsVisible = false
    @State private var tvSearchPresentationGeneration = UUID()
#endif

    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var contentFilter = TMDBContentFilter.shared
    @StateObject private var accentColorManager = AccentColorManager.shared
    @Environment(\.eclipseVerticalSizeClass) var verticalSizeClass

    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case movies = "Movies"
        case tvShows = "TV Shows"
        case anime = "Anime"
    }

    var filteredResults: [TMDBSearchResult] {
        // Keep the unfiltered search snapshot stable while catalog metadata
        // resolves. Replacing the backing array during scrolling resets the
        // LazyVGrid's layout and causes visible flashing/jumps to the top.
        _ = filterRefreshRevision
        let catalogResults = cachedCatalogResults
        switch searchFilter {
        case .all:
            return catalogResults
        case .movies:
            return catalogResults.filter { $0.isMovie }
        case .tvShows:
            return catalogResults.filter { $0.isTVShow && !isAnimeResult($0) }
        case .anime:
            return catalogResults.filter { isAnimeResult($0) }
        }
    }

    private func isAnimeResult(_ result: TMDBSearchResult) -> Bool {
        if result.animeIdentitySeed != nil || result.isAnimeHint == true {
            return true
        }
        guard result.genreIds?.contains(16) == true else { return false }
        let language = result.originalLanguage?.lowercased() ?? ""
        return ["ja", "zh", "ko"].contains(where: language.hasPrefix)
            || result.originCountry?.contains(where: { ["JP", "CN", "KR", "TW"].contains($0) }) == true
    }

    private var columnsCount: Int {
#if os(tvOS)
        switch tvCardDensity {
        case "spacious": return 4
        case "compact": return 6
        default: return 5
        }
#elseif os(macOS)
        max(2, Int((EclipseViewport.bounds.width - 280) / 190))
#else
        if UIDevice.current.userInterfaceIdiom == .pad {
            let screenWidth = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.screen })
                .first?.bounds.width ?? 1024

            let isLandscape = screenWidth > (UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.screen })
                .first?.bounds.height ?? 768)
            return isLandscape ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
#endif
    }

    private var searchGridColumns: [GridItem] {
#if os(tvOS)
        Array(repeating: GridItem(.flexible(), spacing: 16), count: SearchGridLayoutPolicy.columnCount(columnsCount))
#elseif os(macOS)
        [GridItem(.adaptive(minimum: 154, maximum: 210), spacing: 20)]
#else
        if isIPad {
            return [GridItem(.adaptive(minimum: 154, maximum: 190), spacing: 24)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: SearchGridLayoutPolicy.columnCount(columnsCount))
#endif
    }

    var body: some View {
        Group {
#if os(tvOS)
            searchContent
#else
            if #available(iOS 16.0, *) {
                NavigationStack {
                    searchContent
                }
            } else {
                NavigationView {
                    searchContent
                }
                .providerNavigationStyle()
            }
#endif
        }
    }

    private var searchContent: some View {
        ScrollView {
#if os(tvOS)
            if !searchResults.isEmpty {
                HStack {
                    Spacer()
                    searchFilterMenu
                }
                .padding()
            }
#else
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    randomButton
                }

                HStack(spacing: 8) {
                    SearchBarEclipse(text: $searchText) {
                        performSearch(force: true)
                    }

                    if !searchResults.isEmpty {
                        searchFilterMenu
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: searchResults.isEmpty)

                browseButton
            }
            .padding()
#endif

            if isLoading && searchResults.isEmpty {
                VStack {
                    EclipseLoadingIndicator()
                        .scaleEffect(1.2)

                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage, searchResults.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("Error")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(.top)

                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Try Again") {
                        performSearch(force: true)
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                if searchHistory.isEmpty {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Recent Searches")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                             Button("Clear") {
                                clearSearchHistory()
                            }
                            .font(isTvOS ? .system(size: 26) : .caption)
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        VStack(spacing: 0) {
                            ForEach(Array(searchHistory.enumerated()), id: \.offset) { index, historyItem in
                                HStack(spacing: 12) {
                                    Button(action: {
                                        searchText = historyItem
                                        performSearch(force: true)
                                    }) {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: isTvOS ? 24 : 16))

                                            Text(historyItem)
                                                .foregroundColor(.primary)
                                                .font(.body)
                                                .multilineTextAlignment(.leading)

                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
#if os(tvOS)
                                    .buttonStyle(.bordered)
#else
                                    .buttonStyle(PlainButtonStyle())
#endif

                                    Button(action: {
                                        removeFromSearchHistory(at: index)
                                    }) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: isTvOS ? 24 : 14))
                                    }
#if os(tvOS)
                                    .buttonStyle(.bordered)
#else
                                    .buttonStyle(PlainButtonStyle())
#endif
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)

                                if index < searchHistory.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .clipped()

                        Spacer()
                    }
                }
            } else if filteredResults.isEmpty && !searchResults.isEmpty {
                VStack(spacing: 12) {
                    if contentFilter.isResolvingSelectedAudio(for: searchResults) {
                        EclipseLoadingIndicator()
                            .scaleEffect(1.15)
                        Text("Checking selected audio languages…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "tv.and.hifispeaker.fill")
                            .imageScale(.large)
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No \(searchFilter.rawValue.lowercased()) found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding()

                        Text("Try adjusting your filter or search for something else")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack {
                    Image(systemName: "questionmark.circle")
                        .imageScale(.large)
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No results found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()

                    Text("Try searching for a different movie or TV show")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(
                    columns: searchGridColumns,
                    spacing: isIPad ? 24 : 16
                ) {
                    ForEach(filteredResults, id: \.stableIdentity) { result in
                        SearchResultCard(result: result)
#if os(tvOS)
                            .focused($tvFocusedResultID, equals: result.stableIdentity)
                            .accessibilityIdentifier("tv.search.result.\(result.stableIdentity)")
#endif
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }

#if os(tvOS)
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    randomButton
                }

                browseButton
            }
            .padding()
#endif
        }
        .overlay(alignment: .bottom) {
            if !searchText.isEmpty && !filteredResults.isEmpty {
                if isLoading {
                    HStack(spacing: 10) {
                        EclipseLoadingIndicator()
                        Text("Updating results")
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(24)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Updating search results")
                } else if errorMessage != nil {
                    Label("Could not refresh results", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(24)
                        .allowsHitTesting(false)
                }
            }
        }
        .navigationTitle("Search")
#if os(tvOS)
        .searchable(text: $searchText, prompt: "Movies & TV Shows")
        .onSubmit(of: .search) {
            performSearch(force: true)
        }
#endif
        .onChangeComp(of: searchText) { _, newValue in
            scheduleSearch(for: newValue)
        }
        .eclipseBackground()
        .background {
            browseNavigationLink
            randomNavigationLink
        }
        .alert("Couldn't Find a Random Title", isPresented: Binding(
            get: { randomErrorMessage != nil },
            set: { if !$0 { randomErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(randomErrorMessage ?? "Please try again.")
        }
        .onChangeComp(of: searchFilter) { _, newFilter in
            if newFilter == .anime && !searchText.isEmpty {
                performSearch(force: true)
            }
        }
        .onChangeComp(of: selectedLanguage) { _, _ in
            if !searchText.isEmpty && !searchResults.isEmpty {
                performSearch(force: true)
            }
        }
        .onChangeComp(of: contentFilter.filterHorror) { _, _ in
            if !searchText.isEmpty && !searchResults.isEmpty {
                performSearch(force: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: TMDBContentFilter.catalogFiltersDidChangeNotification)) { _ in
            refreshSearchResultsForFilterChange()
        }
        // Most filter switches are stored through AppStorage/UserDefaults and
        // do not emit catalogFiltersDidChangeNotification. Observe actual
        // defaults changes so Search cannot keep displaying its previous,
        // now-unfiltered result snapshot after returning from Settings.
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let signature = contentFilterSettingsSignature
            guard signature != lastContentFilterSettingsSignature else { return }
            lastContentFilterSettingsSignature = signature
            refreshSearchResultsForFilterChange()
        }
        .onAppear {
            lastContentFilterSettingsSignature = contentFilterSettingsSignature
#if os(tvOS)
            tvSearchIsVisible = true
            tvSearchPresentationGeneration = UUID()
#endif
            let settingsDomain = Bundle.main.bundleIdentifier ?? "app.Eclipse"
            let hasSavedHistoryPreference = UserDefaults.standard
                .persistentDomain(forName: settingsDomain)?["searchHistorySavingEnabled"] != nil
            if !hasSavedHistoryPreference, !searchHistoryData.isEmpty {
                searchHistorySavingEnabled = true
            }
            loadSearchHistory()
        }
        .onChangeComp(of: searchHistorySavingEnabled) { _, enabled in
            guard !enabled else { return }
            searchHistory.removeAll()
            searchHistoryData = Data()
        }

        .onReceive(NotificationCenter.default.publisher(for: .activeProfileDidChange)) { _ in
            reloadSearchResultsForProfileChange()
        }
        .onDisappear {
#if os(tvOS)
            tvSearchIsVisible = false
            tvSearchPresentationGeneration = UUID()
#endif
            pendingSearchTask?.cancel()
            activeSearchTask?.cancel()
            activeSearchTask = nil
        }
    }

    private var browseButton: some View {
        Group {
#if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                Button(action: { showingBrowse = true }) {
                    browseButtonContent
                }
            } else {
                NavigationLink(destination: BrowseMediaView()) {
                    browseButtonContent
                }
            }
#else
            NavigationLink(destination: BrowseMediaView()) {
                browseButtonContent
            }
#endif
        }
#if os(tvOS)
        .buttonStyle(TVMediaCardButtonStyle())
#else
        .buttonStyle(PlainButtonStyle())
#endif
    }

    private var randomButton: some View {
        Button(action: openRandomTitle) {
            HStack(spacing: 6) {
                if isLoadingRandom {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "dice.fill")
                }

                Text("Random")
            }
            .font(.subheadline.weight(.semibold))
#if !os(tvOS)

            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
#endif
        }
#if os(tvOS)

        .buttonStyle(.borderedProminent)
#else
        .buttonStyle(PlainButtonStyle())
#endif
        .disabled(isLoadingRandom)
        .accessibilityLabel("Open a random movie or TV show")
    }

    private var searchFilterMenu: some View {
        Menu {
            ForEach(SearchFilter.allCases, id: \.self) { filter in
                Button(action: {
                    searchFilter = filter
                }) {
                    HStack {
                        Text(filter.rawValue)
                        if searchFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
#if os(tvOS)
            HStack(spacing: 10) {
                Image(systemName: searchFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                Text(searchFilter == .all ? "Filter" : searchFilter.rawValue)
            }
            .font(.system(size: 28, weight: .semibold))
            .foregroundColor(.primary)
#else
            Image(systemName: searchFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.primary)
#endif
        }
    }

    private var browseNavigationLink: some View {
        NavigationLink(
            destination: BrowseMediaView(),
            isActive: $showingBrowse
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var randomNavigationLink: some View {
        NavigationLink(
            destination: randomDestination,
            isActive: Binding(
                get: { randomResult != nil },
                set: { isActive in
                    if !isActive {
                        randomResult = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var randomDestination: some View {
        if let randomResult {
            MediaDetailView(searchResult: randomResult)
        } else {
            EmptyView()
        }
    }

    private var browseButtonContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Browse")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Movies & TV Shows")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loadSearchHistory() {
        guard searchHistorySavingEnabled else {
            searchHistory.removeAll()
            searchHistoryData = Data()
            return
        }
        guard let decodedHistory = BackupSearchHistory.decodedQueries(from: searchHistoryData) else {
            searchHistory = []
            return
        }
        searchHistory = decodedHistory
        saveSearchHistory()
    }

    private func saveSearchHistory() {
        guard searchHistorySavingEnabled else {
            searchHistory.removeAll()
            searchHistoryData = Data()
            return
        }
#if DEBUG
        if ProcessInfo.processInfo.environment["ECLIPSE_UI_POSTER_AUDIT"] == "1" { return }
#endif
        searchHistory = BackupSearchHistory.sanitizedQueries(searchHistory)
        if let encodedHistory = try? JSONEncoder().encode(searchHistory),
           encodedHistory.count <= BackupSearchHistory.maximumEncodedBytes {
            searchHistoryData = encodedHistory
        }
    }

    private func addToSearchHistory(_ query: String) {
        guard searchHistorySavingEnabled else { return }
        guard let trimmedQuery = BackupSearchHistory.sanitizedQueries([query]).first else { return }

        searchHistory.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        searchHistory.insert(trimmedQuery, at: 0)

        saveSearchHistory()
    }

    private func removeFromSearchHistory(at index: Int) {
        guard index < searchHistory.count else { return }
        searchHistory.remove(at: index)
        saveSearchHistory()
    }

    private func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }

    private func openRandomTitle() {
        guard !isLoadingRandom else { return }

        isLoadingRandom = true
        randomErrorMessage = nil

        Task {
            do {
                let trendingResults = try await tmdbService.getTrending(mediaType: "all", timeWindow: "week")
                let eligibleResults = await contentFilter.filterSearchResultsResolvingRatings(trendingResults)

                await MainActor.run {
                    if let randomResult = eligibleResults.randomElement() {
                        self.randomResult = randomResult
                    } else {
                        self.randomErrorMessage = "No eligible movies or TV shows were available."
                    }
                    self.isLoadingRandom = false
                }
            } catch {
                await MainActor.run {
                    self.randomErrorMessage = error.localizedDescription
                    self.isLoadingRandom = false
                }
            }
        }
    }

    private var contentFilterSettingsSignature: String {
        let defaults = ProfileSettingsStore.active
        let keys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("catalog") || $0 == "filterHorror" }
            .sorted()
        return keys.map { key in
            "\(key)=\(String(describing: defaults.object(forKey: key) ?? "<unset>"))"
        }.joined(separator: "|")
    }

    private func refreshSearchResultsForFilterChange() {
        guard !searchResults.isEmpty else { return }
        // First apply the current cache-backed policy synchronously, then
        // resolve required metadata and apply it again. This avoids leaving
        // stale, unfiltered cards visible while a settings-triggered lookup runs.
        cachedCatalogResults = contentFilter.filterSearchResults(
            searchResults,
            resolveMetadataInBackground: false
        )
        filterRefreshRevision &+= 1
        let snapshot = searchResults
        let requestSerial = searchRequestSerial
        Task { @MainActor in
            await contentFilter.resolveBrowseFilterMetadata(for: snapshot)
            guard requestSerial == searchRequestSerial else { return }
            filterRefreshRevision &+= 1
            cachedCatalogResults = contentFilter.filterSearchResults(
                searchResults,
                resolveMetadataInBackground: false
            )
        }
    }

    private func reloadSearchResultsForProfileChange() {
        pendingSearchTask?.cancel()
        pendingSearchTask = nil
        activeSearchTask?.cancel()
        activeSearchTask = nil

        searchRequestSerial += 1
        searchResults = []
        cachedCatalogResults = []
#if os(tvOS)
        tvFocusedResultID = nil
#endif
        errorMessage = nil
        isLoading = false
        lastSubmittedSearchQuery = ""
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        performSearch(force: true)
    }

    private func scheduleSearch(for value: String) {
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Do not cancel a request that is already resolving this exact query.
        // Previously every SwiftUI text refresh cancelled the active task,
        // then the debounce callback short-circuited in performSearch because
        // lastSubmittedSearchQuery already matched. That left Search stuck in
        // its loading state with no request capable of completing.
        if !query.isEmpty,
           query.caseInsensitiveCompare(lastSubmittedSearchQuery) == .orderedSame {
            pendingSearchTask?.cancel()
            pendingSearchTask = nil
            isLoading = activeSearchTask != nil
            return
        }

        pendingSearchTask?.cancel()
        activeSearchTask?.cancel()
        activeSearchTask = nil
        searchRequestSerial += 1

        guard !query.isEmpty else {
            searchResults = []
            cachedCatalogResults = []
#if os(tvOS)
            tvFocusedResultID = nil
#endif
            errorMessage = nil
            isLoading = false
            searchFilter = .all
            lastSubmittedSearchQuery = ""
            return
        }

        // Keep the previous result snapshot interactive while the next
        // query is debounced and resolved. Clearing it on every keystroke
        // caused the grid, category controls and navigation targets to be
        // rebuilt repeatedly, making the browser feel frozen and untappable.
        isLoading = true
        errorMessage = nil

        pendingSearchTask = Task { [query] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                    return
                }
                performSearch()
            }
        }
    }

    private func resolveSearchAnimeIdentities(_ results: [TMDBSearchResult]) async -> [TMDBSearchResult] {
        let candidates = results.enumerated().filter { _, result in
            guard result.animeIdentitySeed == nil else { return false }
            // TMDB's country/original-language fields are incomplete on some
            // localized TV search payloads. Animation genre is therefore the
            // candidate signal; AniList's exact-title matcher below is the
            // authority that decides whether the result is actually anime.
            return result.isAnimeHint == true || result.genreIds?.contains(16) == true
        }
        guard !candidates.isEmpty else { return results }

        // Avoid downloading the full AniMap index during an interactive
        // search. Resolve only the few likely anime candidates directly by
        // title against AniList; this keeps search latency bounded and avoids
        // blocking every query on a global mapping refresh.
        return await withTaskGroup(of: (Int, TMDBSearchResult).self) { group in
            for (index, result) in candidates {
                group.addTask {
                    // Prefer the authoritative TMDB→AniList crosswalk. A title
                    // search alone can miss localized/alternate names even when
                    // TMDB already has a stable mapping for this exact show.
                    let mappings = await AniMapMappingService.shared.mappings(forTMDBShowId: result.id)
                    let mapping = mappings
                        .filter { $0.mediaType?.lowercased() != "movie" }
                        .first { $0.anilistId != nil }
                        ?? mappings.first { $0.anilistId != nil }
                    var identity: AnimeMediaIdentitySeed?
                    if let anilistID = mapping?.anilistId, anilistID > 0 {
                        identity = AnimeMediaIdentitySeed(
                            anilistId: anilistID,
                            malId: mapping?.malId,
                            kitsuId: mapping?.kitsuId,
                            format: mapping?.mediaType
                        ).sanitizedForPersistence
                    }
                    if identity == nil {
                        identity = await AniListService.shared.searchAnimeIdentity(title: result.displayTitle)
                    }
                    if identity == nil,
                       let originalName = result.originalName,
                       originalName.caseInsensitiveCompare(result.displayTitle) != .orderedSame {
                        identity = await AniListService.shared.searchAnimeIdentity(title: originalName)
                    }
                    guard let identity = identity?.sanitizedForPersistence else {
                        return (index, result)
                    }
                    let enriched = TMDBSearchResult(
                        id: result.id,
                        mediaType: result.mediaType,
                        title: result.title,
                        name: result.name,
                        originalName: result.originalName,
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
                        animeIdentitySeed: identity,
                        animeArtworkURL: result.animeArtworkURL,
                        animeLogoURL: result.animeLogoURL,
                        tvMazePosterURL: result.tvMazePosterURL,
                        fanartTVPosterURL: result.fanartTVPosterURL
                    )
                    return (index, enriched)
                }
            }

            var resolved = results
            for await (index, result) in group {
                resolved[index] = result
            }
            return resolved
        }
    }

    private func performSearch(force: Bool = false) {
        pendingSearchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        if !force && query.caseInsensitiveCompare(lastSubmittedSearchQuery) == .orderedSame {
            return
        }

        searchRequestSerial += 1
        let serial = searchRequestSerial
#if os(tvOS)
        let presentationGeneration = tvSearchPresentationGeneration
#endif
        lastSubmittedSearchQuery = query
        isLoading = true
        errorMessage = nil

        activeSearchTask?.cancel()
        activeSearchTask = Task {
            do {
                // Search localized and English TMDB indexes concurrently.
                // Structured child tasks are cancelled with this query when the
                // user changes text, and five pages keep the result window broad
                // without the old four ten-page serial wait.
                let shouldSearchTVEndpoint = searchFilter != .movies
                let shouldSearchEnglish = selectedLanguage.caseInsensitiveCompare("en-US") != .orderedSame
                async let localizedMultiResult: [TMDBSearchResult]? = try? await tmdbService.searchMulti(
                    query: query,
                    maxPages: 5
                )
                async let englishMultiResult: [TMDBSearchResult]? = shouldSearchEnglish
                    ? (try? await tmdbService.searchMulti(
                        query: query,
                        languageOverride: "en-US",
                        maxPages: 5
                    ))
                    : nil
                async let localizedTVResult: [TMDBTVShow]? = shouldSearchTVEndpoint
                    ? (try? await tmdbService.searchTVShows(query: query, maxPages: 5))
                    : nil
                async let englishTVResult: [TMDBTVShow]? = shouldSearchTVEndpoint && shouldSearchEnglish
                    ? (try? await tmdbService.searchTVShows(
                        query: query,
                        languageOverride: "en-US",
                        maxPages: 5
                    ))
                    : nil

                let (localizedMulti, englishMulti, localizedTV, englishTV) = await (
                    localizedMultiResult,
                    englishMultiResult,
                    localizedTVResult,
                    englishTVResult
                )
                var results = localizedMulti ?? []
                try Task.checkCancellation()
                if let englishMulti {
                    var seen = Set(results.map(\.stableIdentity))
                    results.append(contentsOf: englishMulti.filter {
                        seen.insert($0.stableIdentity).inserted
                    })
                }
                let selectedDubLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
                let requiresGlobalAnimeAgeRating = ProfileSettingsStore.active.bool(forKey: "catalogHideBelowPG13Anime")
                    || ProfileSettingsStore.active.bool(forKey: "catalogHideAllAgesAnime")
                if shouldSearchTVEndpoint {
                    var seen = Set(results.map(\.stableIdentity))
                    if let localizedTV {
                        try Task.checkCancellation()
                        results.append(contentsOf: localizedTV.map(\.asSearchResult)
                            .filter { seen.insert($0.stableIdentity).inserted })
                    }
                    if let englishTV {
                        try Task.checkCancellation()
                        results.append(contentsOf: englishTV.map(\.asSearchResult)
                            .filter { seen.insert($0.stableIdentity).inserted })
                    }

                    // If the full phrase is absent from both TV indexes, try
                    // a few meaningful title words independently. Keep only
                    // candidates whose title/original title contains every
                    // meaningful query token, so broad token searches cannot
                    // add unrelated shows to Search.
                    let foldedQuery = query.folding(
                        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                        locale: Locale(identifier: "en_US_POSIX")
                    ).lowercased()
                    let ignoredTitleWords: Set<String> = ["a", "an", "and", "of", "or", "the", "to", "in", "on", "no"]
                    let meaningfulQueryTokens = foldedQuery
                        .components(separatedBy: CharacterSet.alphanumerics.inverted)
                        .filter { $0.count >= 2 && !ignoredTitleWords.contains($0) }
                    let requiredTitleTokens = Set(meaningfulQueryTokens)
                    let hasStrongTVMatch = results.contains { result in
                        guard result.mediaType == "tv" else { return false }
                        let titleTokens = Set(
                            ([result.displayTitle, result.originalName ?? ""])
                                .joined(separator: " ")
                                .folding(
                                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                    locale: Locale(identifier: "en_US_POSIX")
                                )
                                .lowercased()
                                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                                .filter { !$0.isEmpty }
                        )
                        return !requiredTitleTokens.isEmpty
                            && requiredTitleTokens.isSubset(of: titleTokens)
                    }
                    if !hasStrongTVMatch, !requiredTitleTokens.isEmpty {
                        for token in meaningfulQueryTokens.filter({ $0.count >= 3 }).prefix(3) {
                            try Task.checkCancellation()
                            guard let tokenResults = try? await tmdbService.searchTVShows(
                                query: token,
                                maxPages: 5
                            ) else { continue }
                            for show in tokenResults {
                                let candidate = show.asSearchResult
                                let titleTokens = Set(
                                    ([candidate.displayTitle, candidate.originalName ?? ""])
                                        .joined(separator: " ")
                                        .folding(
                                            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                            locale: Locale(identifier: "en_US_POSIX")
                                        )
                                        .lowercased()
                                        .components(separatedBy: CharacterSet.alphanumerics.inverted)
                                        .filter { !$0.isEmpty }
                                )
                                guard requiredTitleTokens.isSubset(of: titleTokens),
                                      seen.insert(candidate.stableIdentity).inserted else { continue }
                                results.append(candidate)
                            }
                        }
                    }
                }

                // TMDB's multi-search index can omit anime or index it under
                // a translated title. Query AniList directly for the Anime
                // filter (and as a last resort when TMDB returns nothing).
                // Do not make every ordinary movie/TV query wait on AniList
                // merely because the user has dub or age filters enabled:
                // those filters are applied to anime candidates already found
                // in TMDB results, while the dedicated Anime filter performs
                // the broader AniList lookup.
                if searchFilter == .anime || searchFilter == .all || results.isEmpty {
                    // TMDB multi-search can return unrelated movie matches for
                    // an anime title, so a non-empty TMDB response must not
                    // suppress AniList lookup in the default All search.
                    let animeResults = await AniListService.shared.searchAnimeResults(
                        query: query,
                        tmdbService: tmdbService
                    )
                    try Task.checkCancellation()
                    var seen = Set(results.map(\.stableIdentity))
                    results.append(contentsOf: animeResults.filter {
                        seen.insert($0.stableIdentity).inserted
                    })
                }
                let needsAnimeIdentity = searchFilter == .anime
                    || !selectedDubLanguages.isEmpty
                    || requiresGlobalAnimeAgeRating
                // Anime identity resolution is network-backed. For broad
                // searches, resolve only likely anime candidates already
                // marked by TMDB's genre/origin/language metadata (the helper
                // performs that narrowing) and skip it for non-anime filters.
                let identityResolvedResults = needsAnimeIdentity
                    ? await resolveSearchAnimeIdentities(results)
                    : results
                try Task.checkCancellation()
                // Do not refresh the remote MyDubList index on each
                // keystroke. A missing cache is handled by the schedule/filter
                // refresh path; search must remain responsive and cancellable.
                try Task.checkCancellation()
                // Search must obey the same complete filter policy as Browse.
                // Resolve only metadata required by active filters before publishing
                // results; never expose a temporary unfiltered snapshot.
                await contentFilter.resolveBrowseFilterMetadata(
                    for: identityResolvedResults,
                    requiresAnimeAgeRating: requiresGlobalAnimeAgeRating
                )
                try Task.checkCancellation()

                await MainActor.run {
                    guard serial == searchRequestSerial,
                          searchText.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(query) == .orderedSame else {
                        return
                    }
                    let filteredResults = contentFilter.filterSearchResults(
                        identityResolvedResults,
                        resolveMetadataInBackground: false
                    )
#if os(tvOS)
                    let restoredFocus = restoredTVResultFocus(
                        previousID: tvFocusedResultID,
                        previousResults: self.filteredResults,
                        nextResults: filteredResultsForCurrentFilter(filteredResults)
                    )
#endif
                    self.searchResults = identityResolvedResults
                    self.cachedCatalogResults = filteredResults
                    self.isLoading = false
                    self.activeSearchTask = nil
#if os(tvOS)
                    if let restoredFocus {
                        DispatchQueue.main.async {
                            guard tvSearchIsVisible,
                                  tvSearchPresentationGeneration == presentationGeneration else { return }
                            tvFocusedResultID = restoredFocus
                        }
                    }
#endif
                    if !filteredResults.isEmpty {
                        self.addToSearchHistory(query)
                    }
                }
            } catch {
                await MainActor.run {
                    guard serial == searchRequestSerial,
                          searchText.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(query) == .orderedSame else {
                        return
                    }
                    self.activeSearchTask = nil
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

#if os(tvOS)
    private func filteredResultsForCurrentFilter(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        switch searchFilter {
        case .all: return results
        case .movies: return results.filter(\.isMovie)
        case .tvShows: return results.filter { $0.isTVShow && !isAnimeResult($0) }
        case .anime: return results.filter { isAnimeResult($0) }
        }
    }

    private func restoredTVResultFocus(
        previousID: String?,
        previousResults: [TMDBSearchResult],
        nextResults: [TMDBSearchResult]
    ) -> String? {
        guard let previousID else { return nil }
        if nextResults.contains(where: { $0.stableIdentity == previousID }) {
            return previousID
        }
        guard !nextResults.isEmpty else { return nil }
        let previousIndex = previousResults.firstIndex(where: { $0.stableIdentity == previousID }) ?? 0
        return nextResults[min(previousIndex, nextResults.count - 1)].stableIdentity
    }
#endif
}

private enum BrowseMediaType: String, CaseIterable, Identifiable {
    case movie = "Movies"
    case tv = "TV Shows"
    case anime = "Anime"

    var id: String { rawValue }

    var tmdbValue: String {
        switch self {
        case .movie:
            return "movie"
        case .tv, .anime:
            return "tv"
        }
    }

    var isAnime: Bool {
        self == .anime
    }

    var genres: [BrowseGenre] {
        switch self {
        case .movie:
            return BrowseGenre.movieGenres
        case .tv:
            return BrowseGenre.tvGenres
        case .anime:
            return BrowseGenre.animeGenres
        }
    }

    var countries: [BrowseCountry] {
        isAnime ? BrowseCountry.animeCountries : BrowseCountry.all
    }
}

private enum BrowseSort: String, CaseIterable, Identifiable {
    case popularity = "popularity.desc"
    case newest = "newest"
    case oldest = "oldest"
    case rank = "vote_average.desc"
    case title = "title.asc"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popularity:
            return "Most Popular"
        case .newest:
            return "Newest"
        case .oldest:
            return "Oldest"
        case .rank:
            return "Rank"
        case .title:
            return "Title A-Z"
        }
    }

    func tmdbValue(for mediaType: BrowseMediaType) -> String {
        switch self {
        case .popularity:
            return "popularity.desc"
        case .newest:
            return mediaType.tmdbValue == "tv" ? "first_air_date.desc" : "primary_release_date.desc"
        case .oldest:
            return mediaType.tmdbValue == "tv" ? "first_air_date.asc" : "primary_release_date.asc"
        case .rank:
            return "vote_average.desc"
        case .title:
            return mediaType.tmdbValue == "tv" ? "name.asc" : "original_title.asc"
        }
    }

}

enum BrowseDiscoverRatingPolicy {
    static func minimumVoteCount(isRankSort: Bool, minimumRating _: Double) -> Int? {
        isRankSort ? 100 : nil
    }
}

enum BrowseAgeRating: String, Codable, CaseIterable, Identifiable {
    case all
    case general
    case teen
    case mature
    case adult

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Any Age Rating"
        case .general:
            return "All Ages (G / U)"
        case .teen:
            return "Up to 14 (PG-13 / TV-14)"
        case .mature:
            return "Up to 17 (R / TV-MA)"
        case .adult:
            return "18+ Only"
        }
    }

    func includes(_ rating: MaturityRating?, hasExplicitContent: Bool = false) -> Bool {
        guard self != .all else { return true }
        if hasExplicitContent {
            guard rating == nil || rating == .unknown || rating == .adult else { return false }
            return self == .adult
        }
        guard let rating, rating != .unknown else { return false }

        switch self {
        case .all:
            return true
        case .general:
            return rating == .general
        case .teen:
            return rating <= .teen
        case .mature:
            return rating <= .mature
        case .adult:
            return rating == .adult
        }
    }
}

enum BrowseAnimeClassifier {
    private static let originCountries: Set<String> = ["JP", "CN", "KR", "TW"]
    private static let originalLanguages: Set<String> = ["ja", "zh", "ko"]

    private enum Classification: Equatable {
        case anime
        case nonAnime

        case unknownAnimation
    }

    static func isAnime(_ result: TMDBSearchResult) -> Bool {
        // Browse already queries TV animation with anime country/language
        // constraints. Some TMDB rows omit originCountry/originalLanguage;
        // classify those as unknown animation rather than silently dropping
        // every result from an otherwise valid Anime Browse page.
        classification(for: result) != .nonAnime
    }

    static func shouldIncludeInTV(_ result: TMDBSearchResult) -> Bool {
        // Do not discard animation rows from the TV catalog when TMDB omits
        // both originCountry and originalLanguage. Only exclude confirmed anime;
        // incomplete metadata must not collapse the TV catalog to a few titles.
        classification(for: result) != .anime
    }

    private static func classification(for result: TMDBSearchResult) -> Classification {
        if result.isAnimeHint == true {
            return .anime
        }
        guard result.mediaType == "tv" else { return .nonAnime }

        guard result.genreIds?.contains(16) == true else { return .nonAnime }

        if let origins = result.originCountry, !origins.isEmpty {
            return origins.contains(where: originCountries.contains) ? .anime : .nonAnime
        }

        if let language = result.originalLanguage?.lowercased(), !language.isEmpty {
            return originalLanguages.contains(language) ? .anime : .nonAnime
        }

        // TMDB often omits originCountry/originalLanguage. Keep the row
        // eligible for both browse surfaces until its origin is verified:
        // Anime Browse is already constrained to animation, while TV Browse
        // must not silently lose every metadata-incomplete animated series.
        return .unknownAnimation
    }
}

struct BrowseFilterConfiguration: Codable, Equatable {
    var selectedGenreKeys: [String]
    var excludedGenreKeys: [String]
    var selectedYears: [Int]
    var excludedYears: [Int]
    var selectedCountryCodes: [String]
    var sortRawValue: String
    var minimumRating: Double
    var ageRatingRawValue: String
    var showsUpcomingOnly: Bool? = nil

    func sanitized(
        validGenreKeys: Set<String>,
        validCountryCodes: Set<String>,
        validYearRange: ClosedRange<Int>
    ) -> BrowseFilterConfiguration {
        let selectedGenres = Set(selectedGenreKeys).intersection(validGenreKeys)
        let excludedGenres = Set(excludedGenreKeys)
            .intersection(validGenreKeys)
            .subtracting(selectedGenres)
        let selectedYearSet = Set(selectedYears.filter(validYearRange.contains))
        let excludedYearSet = Set(excludedYears.filter(validYearRange.contains))
            .subtracting(selectedYearSet)
        let countries = Set(selectedCountryCodes.map { $0.uppercased() })
            .intersection(validCountryCodes)
        let boundedMinimumRating = minimumRating.isFinite
            ? min(max(minimumRating, 0), 10)
            : 0

        return BrowseFilterConfiguration(
            selectedGenreKeys: selectedGenres.sorted(),
            excludedGenreKeys: excludedGenres.sorted(),
            selectedYears: selectedYearSet.sorted(),
            excludedYears: excludedYearSet.sorted(),
            selectedCountryCodes: countries.sorted(),
            sortRawValue: BrowseSort(rawValue: sortRawValue)?.rawValue ?? BrowseSort.popularity.rawValue,
            minimumRating: boundedMinimumRating,
            ageRatingRawValue: BrowseAgeRating(rawValue: ageRatingRawValue)?.rawValue ?? BrowseAgeRating.all.rawValue,
            showsUpcomingOnly: showsUpcomingOnly
        )
    }
}

struct BrowseFilterPreferences: Codable, Equatable {
    static let storageKey = "browseFilterPreferences"

    let mediaTypeRawValue: String
    let configurationsByMediaType: [String: BrowseFilterConfiguration]

    private enum CodingKeys: String, CodingKey {
        case mediaTypeRawValue
        case configurationsByMediaType
        case selectedGenreKeys
        case excludedGenreKeys
        case selectedYears
        case excludedYears
        case selectedCountryCode
        case sortRawValue
        case minimumRating
        case animeAgeRatingRawValue
    }

    init(
        mediaTypeRawValue: String,
        configurationsByMediaType: [String: BrowseFilterConfiguration]
    ) {
        self.mediaTypeRawValue = mediaTypeRawValue
        self.configurationsByMediaType = configurationsByMediaType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mediaTypeRawValue = try container.decodeIfPresent(String.self, forKey: .mediaTypeRawValue)
            ?? BrowseMediaType.movie.rawValue

        if let configurations = try container.decodeIfPresent(
            [String: BrowseFilterConfiguration].self,
            forKey: .configurationsByMediaType
        ) {
            configurationsByMediaType = configurations
            return
        }

        let legacyCountry = try container.decodeIfPresent(String.self, forKey: .selectedCountryCode) ?? ""
        let legacyAgeRating = try container.decodeIfPresent(String.self, forKey: .animeAgeRatingRawValue)
        let excludesAdultAnime = legacyAgeRating == "excludeAdults"
        var migrated: [String: BrowseFilterConfiguration] = [
            mediaTypeRawValue: BrowseFilterConfiguration(
                selectedGenreKeys: try container.decodeIfPresent([String].self, forKey: .selectedGenreKeys) ?? [],
                excludedGenreKeys: try container.decodeIfPresent([String].self, forKey: .excludedGenreKeys) ?? [],
                selectedYears: try container.decodeIfPresent([Int].self, forKey: .selectedYears) ?? [],
                excludedYears: try container.decodeIfPresent([Int].self, forKey: .excludedYears) ?? [],
                selectedCountryCodes: legacyCountry.isEmpty ? [] : [legacyCountry],
                sortRawValue: try container.decodeIfPresent(String.self, forKey: .sortRawValue)
                    ?? BrowseSort.popularity.rawValue,
                minimumRating: try container.decodeIfPresent(Double.self, forKey: .minimumRating) ?? 0,
                ageRatingRawValue: mediaTypeRawValue == BrowseMediaType.anime.rawValue && excludesAdultAnime
                    ? BrowseAgeRating.mature.rawValue
                    : BrowseAgeRating.all.rawValue
            )
        ]
        if excludesAdultAnime, mediaTypeRawValue != BrowseMediaType.anime.rawValue {
            migrated[BrowseMediaType.anime.rawValue] = BrowseFilterConfiguration(
                selectedGenreKeys: [],
                excludedGenreKeys: [],
                selectedYears: [],
                excludedYears: [],
                selectedCountryCodes: ["JP"],
                sortRawValue: BrowseSort.popularity.rawValue,
                minimumRating: 0,
                ageRatingRawValue: BrowseAgeRating.mature.rawValue
            )
        }
        configurationsByMediaType = migrated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mediaTypeRawValue, forKey: .mediaTypeRawValue)
        try container.encode(configurationsByMediaType, forKey: .configurationsByMediaType)
    }

    static func load(profile id: UUID) -> BrowseFilterPreferences? {
        guard let data = ProfileSettingsStore.shared.store(for: id).data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(BrowseFilterPreferences.self, from: data)
    }
}

private struct BrowseGenre: Identifiable, Hashable {
    let id: String
    let name: String
    let tmdbGenreID: Int?
    let keyword: String?

    init(id: Int, name: String) {
        self.id = "tmdb-\(id)"
        self.name = name
        self.tmdbGenreID = id
        self.keyword = nil
    }

    init(keyword: String, name: String) {
        self.id = "keyword-\(keyword)"
        self.name = name
        self.tmdbGenreID = nil
        self.keyword = keyword
    }

    static let movieGenres: [BrowseGenre] = [
        BrowseGenre(id: 28, name: "Action"),
        BrowseGenre(id: 12, name: "Adventure"),
        BrowseGenre(id: 16, name: "Animation"),
        BrowseGenre(id: 35, name: "Comedy"),
        BrowseGenre(id: 80, name: "Crime"),
        BrowseGenre(id: 99, name: "Documentary"),
        BrowseGenre(id: 18, name: "Drama"),
        BrowseGenre(id: 10751, name: "Family"),
        BrowseGenre(id: 14, name: "Fantasy"),
        BrowseGenre(id: 36, name: "History"),
        BrowseGenre(id: 27, name: "Horror"),
        BrowseGenre(id: 10402, name: "Music"),
        BrowseGenre(id: 9648, name: "Mystery"),
        BrowseGenre(id: 10749, name: "Romance"),
        BrowseGenre(id: 878, name: "Sci-Fi"),
        BrowseGenre(id: 10770, name: "TV Movie"),
        BrowseGenre(id: 53, name: "Thriller"),
        BrowseGenre(id: 10752, name: "War"),
        BrowseGenre(id: 37, name: "Western")
    ]

    static let tvGenres: [BrowseGenre] = [
        BrowseGenre(id: 10759, name: "Action & Adventure"),
        BrowseGenre(id: 16, name: "Animation"),
        BrowseGenre(id: 35, name: "Comedy"),
        BrowseGenre(id: 80, name: "Crime"),
        BrowseGenre(id: 99, name: "Documentary"),
        BrowseGenre(id: 18, name: "Drama"),
        BrowseGenre(id: 10751, name: "Family"),
        BrowseGenre(id: 10762, name: "Kids"),
        BrowseGenre(id: 9648, name: "Mystery"),
        BrowseGenre(id: 10763, name: "News"),
        BrowseGenre(id: 10764, name: "Reality"),
        BrowseGenre(id: 10765, name: "Sci-Fi & Fantasy"),
        BrowseGenre(id: 10766, name: "Soap"),
        BrowseGenre(id: 10767, name: "Talk"),
        BrowseGenre(id: 10768, name: "War & Politics"),
        BrowseGenre(id: 37, name: "Western")
    ]

    static let animeGenres: [BrowseGenre] = [
        BrowseGenre(id: 10759, name: "Action & Adventure"),
        BrowseGenre(id: 35, name: "Comedy"),
        // Keep Documentary available for exclusion as well as inclusion:
        // anime documentaries are valid catalogue entries, but users must be
        // able to exclude them without switching to the general TV filter set.
        BrowseGenre(id: 99, name: "Documentary"),
        BrowseGenre(id: 18, name: "Drama"),
        BrowseGenre(id: 10751, name: "Family"),
        BrowseGenre(id: 10762, name: "Kids"),
        BrowseGenre(id: 9648, name: "Mystery"),
        BrowseGenre(id: 10765, name: "Sci-Fi & Fantasy"),
        BrowseGenre(keyword: "isekai", name: "Isekai"),
        BrowseGenre(keyword: "reincarnation", name: "Reincarnation"),
        BrowseGenre(keyword: "slice of life", name: "Slice of Life"),
        BrowseGenre(keyword: "romance", name: "Romance"),
        BrowseGenre(keyword: "fantasy", name: "Fantasy"),
        BrowseGenre(keyword: "supernatural", name: "Supernatural"),
        BrowseGenre(keyword: "psychological", name: "Psychological"),
        BrowseGenre(keyword: "mecha", name: "Mecha"),
        BrowseGenre(keyword: "sports", name: "Sports"),
        BrowseGenre(keyword: "school", name: "School"),
        BrowseGenre(keyword: "historical", name: "Historical"),
        BrowseGenre(keyword: "harem", name: "Harem"),
        BrowseGenre(keyword: "magical girl", name: "Magical Girl"),
        BrowseGenre(keyword: "music", name: "Music"),
        BrowseGenre(keyword: "horror", name: "Horror"),
        BrowseGenre(keyword: "samurai", name: "Samurai"),
        BrowseGenre(keyword: "super power", name: "Super Power"),
        BrowseGenre(keyword: "time travel", name: "Time Travel"),
        BrowseGenre(keyword: "video game", name: "Video Game")
    ]
}

private struct BrowseCountry: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    static let all: [BrowseCountry] = [
        BrowseCountry(code: "US", name: "United States"),
        BrowseCountry(code: "JP", name: "Japan"),
        BrowseCountry(code: "KR", name: "South Korea"),
        BrowseCountry(code: "GB", name: "United Kingdom"),
        BrowseCountry(code: "CA", name: "Canada"),
        BrowseCountry(code: "FR", name: "France"),
        BrowseCountry(code: "DE", name: "Germany"),
        BrowseCountry(code: "CN", name: "China"),
        BrowseCountry(code: "IN", name: "India"),
        BrowseCountry(code: "ES", name: "Spain"),
        BrowseCountry(code: "MX", name: "Mexico"),
        BrowseCountry(code: "BR", name: "Brazil"),
        BrowseCountry(code: "AU", name: "Australia"),
        BrowseCountry(code: "TH", name: "Thailand")
    ]

    static let animeCountries: [BrowseCountry] = [
        BrowseCountry(code: "JP", name: "Japan"),
        BrowseCountry(code: "CN", name: "China"),
        BrowseCountry(code: "KR", name: "South Korea"),
        BrowseCountry(code: "TW", name: "Taiwan")
    ]
}

private struct BrowseMediaView: View {
    @AppStorage("mediaColumnsPortrait") private var mediaColumnsPortrait: Int = 3
    @AppStorage("mediaColumnsLandscape") private var mediaColumnsLandscape: Int = 5
#if os(tvOS)
    @AppStorage("tvCardDensity") private var tvCardDensity = "standard"
#endif
    @AppStorage("tmdbLanguage") private var selectedLanguage = "en-US"

    @State private var mediaType: BrowseMediaType
    @State private var filterConfigurations: [BrowseMediaType: BrowseFilterConfiguration]
    @State private var showingFilters = false
    @State private var expandedFilterMenu: String?
    @State private var results: [TMDBSearchResult] = []
    // Keep the provider snapshot separate from the visible filtered grid.
    // Metadata notifications should re-filter these rows, not restart the query.
    @State private var unfilteredResults: [TMDBSearchResult] = []
    @State private var filterRefreshTask: Task<Void, Never>?
    @State private var filterRefreshGeneration = 0
    @State private var filterRefreshPending = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var requestSerial = 0
    @State private var loadTask: Task<Void, Never>?
    @State private var activeBrowseLoadPage: Int?
    @State private var activeBrowseLoadReplacesResults = false
    @State private var interruptedBrowseLoad: (page: Int, replacing: Bool)?
    @State private var failedBrowseLoad: (page: Int, replacing: Bool)?
    @State private var browseQueryGeneration = UUID()

    @State private var filterOwner: UUID

    @State private var profileAppliedMediaType: BrowseMediaType?

    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var contentFilter = TMDBContentFilter.shared
    @StateObject private var glassAppearance = LiquidGlassAppearanceSettings.shared
    @StateObject private var accentColorManager = AccentColorManager.shared
    @Environment(\.eclipseVerticalSizeClass) private var verticalSizeClass

    private struct RestoredBrowseFilters {
        let mediaType: BrowseMediaType
        let configurations: [BrowseMediaType: BrowseFilterConfiguration]
    }

    private static func defaultConfiguration(for mediaType: BrowseMediaType) -> BrowseFilterConfiguration {
        let selectedGenres: [String]
        let excludedGenres: [String]
        switch mediaType {
        case .movie:
            selectedGenres = ["tmdb-14"] // Fantasy
            excludedGenres = ["tmdb-99", "tmdb-10402", "tmdb-37"] // Documentary, Music, Western
        case .tv:
            // Keep Browse broad by default. Genre constraints are user-selected
            // refinements, not mandatory defaults that hide most TMDB series.
            selectedGenres = []
            excludedGenres = []
        case .anime:
            // Do not silently hide whole anime genres in the default view.
            // Users can add genre/keyword exclusions from the Browse filters.
            selectedGenres = []
            excludedGenres = []
        }

        let defaultMinimumRating: Double
        switch mediaType {
        case .movie: defaultMinimumRating = 6
        case .tv, .anime: defaultMinimumRating = 0
        }

        return BrowseFilterConfiguration(
            selectedGenreKeys: selectedGenres,
            excludedGenreKeys: excludedGenres,
            selectedYears: [],
            excludedYears: [],
            selectedCountryCodes: [],
            sortRawValue: BrowseSort.newest.rawValue,
            minimumRating: defaultMinimumRating,
            ageRatingRawValue: BrowseAgeRating.all.rawValue
        )
    }

    private static func migratingPreviousDefault(
        _ configuration: BrowseFilterConfiguration,
        for mediaType: BrowseMediaType
    ) -> BrowseFilterConfiguration {
        let broadDefault = defaultConfiguration(for: mediaType)
        var previousDefault = broadDefault
        previousDefault.minimumRating = 6
        if mediaType == .tv {
            previousDefault.selectedGenreKeys = ["tmdb-10765"]
            previousDefault.excludedGenreKeys = [
                "tmdb-99", "tmdb-10762", "tmdb-10763",
                "tmdb-10764", "tmdb-10767", "tmdb-37"
            ]
        }
        if configuration == previousDefault { return broadDefault }

        // Migrate the restrictive defaults used by the previous Browse build.
        // They were automatically selected, not a user request to limit every
        // TV shelf to Fantasy+Sci-Fi or to hide Isekai/Slice-of-Life/Harem/Music.
        var migrated = configuration
        if mediaType == .tv,
           Set(configuration.selectedGenreKeys) == Set(["tmdb-14", "tmdb-878"]),
           Set(configuration.excludedGenreKeys) == Set(["tmdb-99", "tmdb-10762", "tmdb-10763"]) {
            // Preserve a user's year/country/rating/sort choices while removing
            // the old automatically-selected genre gates that hid most series.
            migrated.selectedGenreKeys = []
            migrated.excludedGenreKeys = []
        }
        if mediaType == .anime,
           configuration.selectedGenreKeys.isEmpty,
           Set(configuration.excludedGenreKeys) == Set([
               "tmdb-10762", "keyword-isekai", "keyword-slice of life",
               "keyword-harem", "keyword-music"
           ]) {
            // Remove the previous app-imposed exclusions without resetting
            // unrelated user filter choices.
            migrated.excludedGenreKeys = []
        }
        return migrated
    }

    private static func sanitizedConfiguration(
        _ configuration: BrowseFilterConfiguration,
        for mediaType: BrowseMediaType
    ) -> BrowseFilterConfiguration {
        return configuration.sanitized(
            validGenreKeys: Set(mediaType.genres.map(\.id)),
            validCountryCodes: Set(mediaType.countries.map(\.code)),
            validYearRange: AppCalendar.mediaYearRange()
        )
    }

    private static func restoredFilters(for profile: UUID) -> RestoredBrowseFilters {
        let preferences = BrowseFilterPreferences.load(profile: profile)
        let restoredMediaType = preferences
            .flatMap { BrowseMediaType(rawValue: $0.mediaTypeRawValue) }
            ?? .movie

        var configurations: [BrowseMediaType: BrowseFilterConfiguration] = [:]
        for mediaType in BrowseMediaType.allCases {
            let stored = preferences?.configurationsByMediaType[mediaType.rawValue]
                ?? defaultConfiguration(for: mediaType)
            let migrated = migratingPreviousDefault(stored, for: mediaType)
            configurations[mediaType] = sanitizedConfiguration(migrated, for: mediaType)
        }

        return RestoredBrowseFilters(
            mediaType: restoredMediaType,
            configurations: configurations
        )
    }

    init() {
        let owner = ProfileManager.shared.activeProfileID
        let restored = Self.restoredFilters(for: owner)

        _filterOwner = State(initialValue: owner)
        _mediaType = State(initialValue: restored.mediaType)
        _filterConfigurations = State(initialValue: restored.configurations)
    }

    private var currentFilters: BrowseFilterConfiguration {
        filterConfigurations[mediaType] ?? Self.defaultConfiguration(for: mediaType)
    }

    private var selectedGenreKeys: Set<String> { Set(currentFilters.selectedGenreKeys) }
    private var excludedGenreKeys: Set<String> { Set(currentFilters.excludedGenreKeys) }
    private var selectedYears: Set<Int> { Set(currentFilters.selectedYears) }
    private var excludedYears: Set<Int> { Set(currentFilters.excludedYears) }
    private var selectedCountryCodes: Set<String> { Set(currentFilters.selectedCountryCodes) }
    private var sort: BrowseSort { BrowseSort(rawValue: currentFilters.sortRawValue) ?? .popularity }
    private var minimumRating: Double { currentFilters.minimumRating }
    private var ageRating: BrowseAgeRating {
        BrowseAgeRating(rawValue: currentFilters.ageRatingRawValue) ?? .all
    }

    private var columnsCount: Int {
#if os(tvOS)
        switch tvCardDensity {
        case "spacious": return 4
        case "compact": return 6
        default: return 5
        }
#elseif os(macOS)
        max(2, Int((EclipseViewport.bounds.width - 280) / 190))
#else
        if UIDevice.current.userInterfaceIdiom == .pad {
            let screen = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.screen })
                .first
            let width = screen?.bounds.width ?? 1024
            let height = screen?.bounds.height ?? 768
            return width > height ? mediaColumnsLandscape : mediaColumnsPortrait
        } else {
            return verticalSizeClass == .compact ? mediaColumnsLandscape : mediaColumnsPortrait
        }
#endif
    }

    private var gridColumns: [GridItem] {
#if os(tvOS)
        Array(repeating: GridItem(.flexible(), spacing: 16), count: SearchGridLayoutPolicy.columnCount(columnsCount))
#elseif os(macOS)
        [GridItem(.adaptive(minimum: 154, maximum: 210), spacing: 20)]
#else
        if isIPad {
            return [GridItem(.adaptive(minimum: 154, maximum: 190), spacing: 24)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: SearchGridLayoutPolicy.columnCount(columnsCount))
#endif
    }

    private var availableYears: [Int] {
        Array(AppCalendar.mediaYearRange().reversed())
    }

    private var selectedGenreName: String {
        let selectedNames = mediaType.genres
            .filter { selectedGenreKeys.contains($0.id) }
            .map(\.name)
        return selectionSummary(values: selectedNames, emptyTitle: mediaType.isAnime ? "Any Anime Genre" : "Any Genre")
    }

    private var excludedGenreName: String {
        let excludedNames = mediaType.genres
            .filter { excludedGenreKeys.contains($0.id) }
            .map(\.name)
        return selectionSummary(values: excludedNames, emptyTitle: "None")
    }

    private var selectedYearName: String {
        let years = selectedYears
            .sorted(by: >)
            .map(String.init)
        let summary = selectionSummary(values: years, emptyTitle: "Any Year")
        return currentFilters.showsUpcomingOnly == true ? "Upcoming" : summary
    }

    private var excludedYearName: String {
        let years = excludedYears
            .sorted(by: >)
            .map(String.init)
        return selectionSummary(values: years, emptyTitle: "None")
    }

    private var selectedCountryName: String {
        let countryNames = mediaType.countries
            .filter { selectedCountryCodes.contains($0.code) }
            .map(\.name)
        return selectionSummary(values: countryNames, emptyTitle: "Any Country")
    }

    private var hasActiveFilters: Bool {
        !selectedGenreKeys.isEmpty
            || !excludedGenreKeys.isEmpty
            || !selectedYears.isEmpty
            || !excludedYears.isEmpty
            || !selectedCountryCodes.isEmpty
            || sort != .popularity
            || minimumRating > 0
            || ageRating != .all
            || currentFilters.showsUpcomingOnly == true
    }

    private var activeFilterCount: Int {
        var count = 0
        if !selectedGenreKeys.isEmpty { count += 1 }
        if !excludedGenreKeys.isEmpty { count += 1 }
        if !selectedYears.isEmpty { count += 1 }
        if !excludedYears.isEmpty { count += 1 }
        if !selectedCountryCodes.isEmpty { count += 1 }
        if sort != .popularity { count += 1 }
        if minimumRating > 0 { count += 1 }
        if ageRating != .all { count += 1 }
        if currentFilters.showsUpcomingOnly == true { count += 1 }
        return count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
#if os(tvOS)
                filterPanel
#else
                VStack(alignment: .leading, spacing: 12) {
                    mediaTypeSelector
                    filterButton
                }
#endif

                if isLoading && results.isEmpty {
                    loadingState
                } else if let errorMessage, results.isEmpty {
                    errorState(errorMessage)
                } else if results.isEmpty {
                    emptyState
                } else {
                    resultsGrid
                }
            }
            .padding()
        }
        .navigationTitle("Browse")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
#if !os(tvOS)
        .sheet(isPresented: $showingFilters) {
            filterSheet
        }
#endif
        .eclipseBackground()
        .onAppear {
            if let interrupted = interruptedBrowseLoad {
                interruptedBrowseLoad = nil
                loadPage(interrupted.page, replacing: interrupted.replacing)
            } else if results.isEmpty && !isLoading {
                reloadResults()
            } else if filterRefreshPending && !isLoading {
                filterRefreshPending = false
                reapplyCurrentFiltersToRetainedResults()
            }
        }
        .onDisappear {
            cancelBrowseLoad()
        }
        .onChangeComp(of: mediaType) { _, newMediaType in
            // A category change must never leave cards from the previous
            // category visible while the new discover request is running.
            loadTask?.cancel()
            filterRefreshTask?.cancel()
            filterRefreshTask = nil
            filterRefreshPending = false
            results.removeAll(keepingCapacity: true)
            unfilteredResults.removeAll(keepingCapacity: true)
            currentPage = 1
            hasMorePages = true
            errorMessage = nil
            // Never leave Movies/Series visible under the Anime selector (or
            // vice versa) while the replacement discover request is running.
            // The request serial still protects against late responses from the
            // category we just left.
            results.removeAll(keepingCapacity: true)
            unfilteredResults.removeAll(keepingCapacity: true)
            if profileAppliedMediaType == newMediaType {
                profileAppliedMediaType = nil
                reloadResults()
                return
            }
            persistFilters(filterConfigurations)
            reloadResults()
        }
        .onChangeComp(of: selectedLanguage) { _, _ in
            reloadResults()
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeProfileDidChange)) { _ in
            applyProfileChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: TMDBContentFilter.catalogFiltersDidChangeNotification)) { _ in
            reapplyCurrentFiltersToRetainedResults()
        }
    }

    private var mediaTypeSelector: some View {
        Picker("Type", selection: $mediaType) {
            ForEach(BrowseMediaType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .tint(accentColorManager.currentAccentColor)
        .padding(4)
        .background(
            glassAppearance.darkBarColor.opacity(0.42),
            in: Capsule()
        )
    }

    private var filterChipsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: isTvOS ? 420 : 132), spacing: isTvOS ? 20 : 10, alignment: .leading)],
                alignment: .leading,
                spacing: isTvOS ? 20 : 10
            ) {
                genreMenu
                excludedGenreMenu
                yearMenu
                excludedYearMenu
                countryMenu
                sortMenu
                ratingMenu
                ageRatingMenu

                if hasActiveFilters {
                    resetFiltersButton
                }
            }

            if let expandedFilterMenu {
                filterOptionsPanel(for: expandedFilterMenu)
                    .transition(
                        .opacity
                            .combined(with: .move(edge: .top))
                            .combined(with: .scale(scale: 0.98, anchor: .top))
                    )
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: expandedFilterMenu)
    }

    private func filterMenuButton(
        _ key: String,
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        Button {
            expandedFilterMenu = expandedFilterMenu == key ? nil : key
        } label: {
            filterChip(title: title, value: value, systemImage: systemImage)
                .overlay(alignment: .topTrailing) {
                    if expandedFilterMenu == key {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .padding(7)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(expandedFilterMenu == key ? .isSelected : [])
    }

    @ViewBuilder
    private func filterOptionsPanel(for key: String) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                switch key {
                case "genres":
                    filterOption("Any Genre", selected: selectedGenreKeys.isEmpty) {
                        updateCurrentFilters { $0.selectedGenreKeys = [] }
                    }
                    ForEach(mediaType.genres) { genre in
                        filterOption(genre.name, selected: selectedGenreKeys.contains(genre.id)) {
                            toggleGenre(genre)
                        }
                    }
                case "excludedGenres":
                    filterOption("Exclude None", selected: excludedGenreKeys.isEmpty) {
                        updateCurrentFilters { $0.excludedGenreKeys = [] }
                    }
                    ForEach(mediaType.genres) { genre in
                        filterOption(genre.name, selected: excludedGenreKeys.contains(genre.id)) {
                            toggleGenre(genre, excluded: true)
                        }
                    }
                case "years":
                    filterOption("Any Year", selected: selectedYears.isEmpty && currentFilters.showsUpcomingOnly != true) {
                        updateCurrentFilters {
                            $0.selectedYears = []
                            $0.showsUpcomingOnly = false
                        }
                    }
                    filterOption("Upcoming (announced date)", selected: currentFilters.showsUpcomingOnly == true) {
                        updateCurrentFilters {
                            $0.selectedYears = []
                            $0.showsUpcomingOnly = true
                        }
                    }
                    ForEach(availableYears, id: \.self) { year in
                        filterOption(String(year), selected: selectedYears.contains(year)) {
                            toggleYear(year)
                        }
                    }
                case "excludedYears":
                    filterOption("Exclude None", selected: excludedYears.isEmpty) {
                        updateCurrentFilters { $0.excludedYears = [] }
                    }
                    ForEach(availableYears, id: \.self) { year in
                        filterOption(String(year), selected: excludedYears.contains(year)) {
                            toggleYear(year, excluded: true)
                        }
                    }
                case "countries":
                    filterOption("Any Country", selected: selectedCountryCodes.isEmpty) {
                        updateCurrentFilters { $0.selectedCountryCodes = [] }
                    }
                    ForEach(mediaType.countries) { country in
                        filterOption(country.name, selected: selectedCountryCodes.contains(country.code)) {
                            toggleCountry(country)
                        }
                    }
                case "sort":
                    ForEach(BrowseSort.allCases) { option in
                        filterOption(option.title, selected: sort == option) {
                            updateCurrentFilters { $0.sortRawValue = option.rawValue }
                        }
                    }
                case "rating":
                    filterOption("Any Rating", selected: minimumRating == 0) {
                        updateCurrentFilters { $0.minimumRating = 0 }
                    }
                    ForEach([5, 6, 7, 8, 9], id: \.self) { star in
                        filterOption("\(star)+ Stars", selected: Int(minimumRating) == star) {
                            updateCurrentFilters { $0.minimumRating = Double(star) }
                        }
                    }
                case "ageRating":
                    ForEach(BrowseAgeRating.allCases) { option in
                        filterOption(option.title, selected: ageRating == option) {
                            updateCurrentFilters { $0.ageRatingRawValue = option.rawValue }
                        }
                    }
                default:
                    EmptyView()
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 280)
        .applyLiquidGlassBackground(
            cornerRadius: 14,
            fallbackFill: glassAppearance.browseFilterOptionsColor.opacity(0.48),
            glassTint: glassAppearance.browseFilterOptionsColor.opacity(0.34)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .accessibilityIdentifier("browse.filterOptions.\(key)")
    }

    private func filterOption(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .foregroundColor(.primary)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            mediaTypeSelector
            filterChipsGrid
        }
    }

    private var filterButton: some View {
        Button {
            showingFilters = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16, weight: .semibold))

                Text("Filters")
                    .font(.subheadline.weight(.semibold))

                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(glassAppearance.browseFilterButtonColor.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var filterSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterChipsGrid
                }
                .padding()
            }
            .navigationTitle("Filters")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingFilters = false }
                }
            }
            .eclipseBackground()
        }
#if os(iOS)
        .providerNavigationStyle()
#endif
    }

    private var genreMenu: some View {
        filterMenuButton("genres", title: mediaType.isAnime ? "Anime Genres" : "Genres", value: selectedGenreName, systemImage: "theatermasks.fill")
    }

    private var excludedGenreMenu: some View {
        filterMenuButton("excludedGenres", title: "Exclude Genres", value: excludedGenreName, systemImage: "theatermasks")
    }

    private var yearMenu: some View {
        filterMenuButton("years", title: "Year", value: selectedYearName, systemImage: "calendar")
    }

    private var excludedYearMenu: some View {
        filterMenuButton("excludedYears", title: "Exclude Years", value: excludedYearName, systemImage: "calendar.badge.minus")
    }

    private var countryMenu: some View {
        filterMenuButton("countries", title: "Countries", value: selectedCountryName, systemImage: "globe")
    }

    private var sortMenu: some View {
        filterMenuButton("sort", title: "Order", value: sort.title, systemImage: "arrow.up.arrow.down")
    }

    private var minimumRatingLabel: String {
        minimumRating > 0 ? "\(Int(minimumRating))+ Stars" : "Any Rating"
    }

    private var ratingMenu: some View {
        filterMenuButton("rating", title: "Rating", value: minimumRatingLabel, systemImage: "star.fill")
    }

    private var ageRatingMenu: some View {
        filterMenuButton("ageRating", title: "Age Rating", value: ageRating.title, systemImage: "18.circle")
    }

    private var resetFiltersButton: some View {
        Button(action: resetFilters) {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
#if !os(tvOS)
                .foregroundColor(.primary)
#endif
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
#if !os(tvOS)

                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
#endif
        }
#if os(tvOS)
        .buttonStyle(.bordered)
#else
        .buttonStyle(PlainButtonStyle())
#endif
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            EclipseLoadingIndicator()
                .scaleEffect(1.2)

            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.large)
                .font(.system(size: 52))
                .foregroundColor(.orange)

            Text("Unable to Load")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                retryBrowseLoad()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .imageScale(.large)
                .font(.system(size: 52))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(.title3.weight(.semibold))
                .foregroundColor(.secondary)

            if hasMorePages || isLoading {
                ProgressView("Searching for titles that match your filters…")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var resultsGrid: some View {
        // Keep the pagination sentinel eagerly laid out. A nested lazy stack
        // could leave it unrealized after the first TV/Anime page.
        VStack(spacing: 0) {
            LazyVGrid(columns: gridColumns, spacing: isIPad ? 24 : 16) {
                ForEach(results, id: \.stableIdentity) { result in
                    SearchResultCard(result: result)
                        .onAppear {
                            // Small filtered grids are filled automatically by loadPage.
                            // Once the grid is usable, this card and the trailing sentinel
                            // continue pagination only as the user approaches the bottom.
                            if results.count >= 12,
                               result.stableIdentity == results.last?.stableIdentity {
                                loadNextPage()
                            }
                        }
                }
            }
            // Appending a page or replacing a poster with provider artwork must
            // not animate the grid's layout. Stable card IDs plus fixed poster
            // geometry keep the visible rows anchored while images resolve.
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }

            // A trailing lazy sentinel is more reliable than relying only on
            // the final card's onAppear. SwiftUI can keep that card alive when
            // a page is appended, leaving Browse stuck until the user scrolls
            // away and back. The page-based identity re-arms the sentinel after
            // each successful append. Re-arm the sentinel after every append
            // so pagination remains
            // automatic at every depth without a manual "Load More" control.
            if hasMorePages {
                Color.clear
                    .frame(height: 24)
                    .accessibilityHidden(true)
                    .id("browse-search-pagination-\(currentPage)-\(results.count)")
                    .onAppear { loadNextPage() }
            }

            if let errorMessage {
                HStack(spacing: 10) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button("Retry") { retryBrowseLoad() }
                        .font(.caption.weight(.semibold))
                        .disabled(isLoading || !hasMorePages)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }

            if isLoading {
                EclipseLoadingIndicator()
                    .padding(.vertical, 18)
            }
        }
        .padding(.top, 4)
    }

    private func filterChip(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: isTvOS ? 14 : 8) {
            Image(systemName: systemImage)
                .font(.system(size: isTvOS ? 26 : 13, weight: .semibold))

            VStack(alignment: .leading, spacing: isTvOS ? 4 : 1) {
                Text(title)
                    .font(isTvOS ? .system(size: 26) : .caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(isTvOS ? .system(size: 30, weight: .semibold) : .subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: isTvOS ? 18 : 10, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, isTvOS ? 24 : 12)
        .frame(maxWidth: .infinity, minHeight: isTvOS ? 96 : 48, alignment: .leading)
        .background(glassAppearance.browseFilterChipColor.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: isTvOS ? 18 : 10, style: .continuous))
    }


    private func updateCurrentFilters(_ update: (inout BrowseFilterConfiguration) -> Void) {
        var updated = currentFilters
        update(&updated)
        updated = Self.sanitizedConfiguration(updated, for: mediaType)

        var nextConfigurations = filterConfigurations
        nextConfigurations[mediaType] = updated
        filterConfigurations = nextConfigurations
        persistFilters(nextConfigurations)
        reloadResults()
    }

    private func resetFilters() {
        var nextConfigurations = filterConfigurations
        nextConfigurations[mediaType] = Self.defaultConfiguration(for: mediaType)
        filterConfigurations = nextConfigurations
        persistFilters(nextConfigurations)
        reloadResults()
    }

    private func applyProfileChange() {
        let owner = ProfileManager.shared.activeProfileID
        guard owner != filterOwner else {
            reloadResults()
            return
        }
        filterOwner = owner
        let restored = Self.restoredFilters(for: owner)
        filterConfigurations = restored.configurations
        if mediaType != restored.mediaType {
            profileAppliedMediaType = restored.mediaType
            mediaType = restored.mediaType
        }
        reloadResults()
    }

    private func persistFilters(_ configurations: [BrowseMediaType: BrowseFilterConfiguration]) {
        let configurationsByMediaType = Dictionary(uniqueKeysWithValues: configurations.map {
            ($0.key.rawValue, $0.value)
        })
        let preferences = BrowseFilterPreferences(
            mediaTypeRawValue: mediaType.rawValue,
            configurationsByMediaType: configurationsByMediaType
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(preferences) else { return }
        let owner = filterOwner
        ProfileSettingsStore.shared
            .store(for: owner)
            .set(data, forKey: BrowseFilterPreferences.storageKey)
    }

    private func reloadResults() {
        interruptedBrowseLoad = nil
        failedBrowseLoad = nil
        requestSerial += 1
        browseQueryGeneration = UUID()
        filterRefreshGeneration += 1
        filterRefreshTask?.cancel()
        filterRefreshTask = nil
        filterRefreshPending = false
        currentPage = 1
        hasMorePages = true
        // Retain the last successful page while the new category/filter query
        // loads. Clearing both arrays here made category switches flash an
        // empty state and could make the segmented control feel unresponsive.
        // loadPage(replacing: true) replaces the retained content atomically
        // when the new response and filters are ready.
        errorMessage = nil
        loadPage(1, replacing: true)
    }

    private func cancelBrowseLoad() {
        if let page = activeBrowseLoadPage {
            // Browse cancels in-flight requests when navigating to a detail
            // page or another tab. Remember the exact page and whether it was
            // replacing the query so returning to Browse can resume without
            // silently leaving a partial/stale result set behind.
            interruptedBrowseLoad = (page, activeBrowseLoadReplacesResults)
        }
        activeBrowseLoadPage = nil
        requestSerial += 1
        browseQueryGeneration = UUID()
        filterRefreshGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        if filterRefreshTask != nil {
            filterRefreshPending = true
        }
        filterRefreshTask?.cancel()
        filterRefreshTask = nil
        isLoading = false
    }

    private func reapplyCurrentFiltersToRetainedResults() {
        guard !unfilteredResults.isEmpty else { return }
        guard !isLoading else {
            filterRefreshPending = true
            return
        }

        filterRefreshGeneration += 1
        let generation = filterRefreshGeneration
        let snapshot = unfilteredResults
        let selectedMediaType = mediaType
        let selectedAgeRating = ageRating
        let allowsUpcomingContent = currentFilters.showsUpcomingOnly == true
        let excludedGenreIDs = excludedGenreKeys.compactMap { key in
            selectedMediaType.genres.first(where: { $0.id == key })?.tmdbGenreID
        }
        let yearsToExclude = excludedYears
        let countries = Set(selectedCountryCodes)
        let selectedSort = sort

        filterRefreshTask?.cancel()
        filterRefreshTask = Task {
            let browseTypeFiltered = await filterResultsForBrowseType(
                snapshot,
                mediaType: selectedMediaType,
                ageRating: selectedAgeRating
            )
            guard !Task.isCancelled else { return }

            // Required metadata is scheduled by filterResultsForBrowseType.
            // Apply the current cache-backed predicate now; resolver notifications
            // re-filter retained rows as ratings arrive instead of holding Browse
            // behind optional network lookups on every refresh.
            let contentFiltered = contentFilter.filterSearchResults(
                filterExcludedResults(
                    browseTypeFiltered,
                    excludedGenreIds: excludedGenreIDs,
                    excludedYears: yearsToExclude
                ),
                allowUpcomingContent: allowsUpcomingContent,
                resolveMetadataInBackground: false
            )
            guard !Task.isCancelled else { return }
            let filtered = regionGuardedResults(contentFiltered, countries: countries)

            await MainActor.run {
                guard generation == filterRefreshGeneration,
                      selectedMediaType == mediaType else { return }
                results = sortedDeduplicatedResults(filtered, by: selectedSort)
                filterRefreshTask = nil
            }
        }
    }

    private func loadNextPage() {
        guard !isLoading, hasMorePages else { return }
        loadPage(currentPage + 1, replacing: false)
    }

    private func retryBrowseLoad() {
        guard !isLoading else { return }
        if let failedBrowseLoad {
            loadPage(failedBrowseLoad.page, replacing: failedBrowseLoad.replacing)
        } else {
            reloadResults()
        }
    }

    private func loadPage(_ page: Int, replacing: Bool) {
        requestSerial += 1
        let serial = requestSerial
        loadTask?.cancel()
        let browseMediaType = self.mediaType
        let mediaType = browseMediaType.tmdbValue
        let isAnime = browseMediaType.isAnime
        let selectedGenres = browseMediaType.genres.filter { selectedGenreKeys.contains($0.id) }
        let excludedGenres = browseMediaType.genres.filter { excludedGenreKeys.contains($0.id) }
        let years = selectedYears.sorted(by: >)
        let excludedYears = self.excludedYears
        let countries = selectedCountryCodes.sorted()
        let sort = self.sort
        let minimumRating = self.minimumRating
        let ageRating = self.ageRating
        let upcomingOnly = currentFilters.showsUpcomingOnly == true
        let existingRawResults = replacing ? [] : unfilteredResults
        activeBrowseLoadPage = page
        activeBrowseLoadReplacesResults = replacing
        failedBrowseLoad = nil
        if replacing { browseQueryGeneration = UUID() }
        let queryGeneration = browseQueryGeneration
        filterRefreshGeneration += 1
        filterRefreshTask?.cancel()
        filterRefreshTask = nil
        isLoading = true
        errorMessage = nil

        let task = Task {
            do {
                let pageResult = try await fetchDiscoverPage(
                    mediaType: mediaType,
                    isAnime: isAnime,
                    genres: selectedGenres,
                    excludedGenres: excludedGenres,
                    years: years,
                    upcomingOnly: upcomingOnly,
                    excludedYears: excludedYears,
                    originCountries: countries,
                    sort: sort,
                    minimumRating: minimumRating,
                    page: page
                )
                try Task.checkCancellation()
                // Dub/audio filters require resolved provider identity before
                // filtering. Without those filters, show the TMDB page immediately
                // and enrich posters/logos in the background so Anime Browse is not
                // blocked by AniList/AniMap artwork lookups.
                // Let the filtering pipeline resolve anime identity once.
                // Previously Browse performed the same provider lookup here
                // and again while applying the age/dub filters, delaying the
                // first usable Anime grid by a second round of network calls.
                // The browse-type filter owns anime identity resolution. Running
                // the resolver here as well repeated provider lookups on every page.
                // Resolve only the newly fetched page. Existing pages already carry
                // their anime identity seeds in unfilteredResults; resolving the
                // entire accumulated catalog on every pagination step caused the
                // same AniMap/AniList work to be repeated and made Browse appear
                // stuck as the result set grew.
                let fetchedPageBrowseResults = await filterResultsForBrowseType(
                    pageResult.results,
                    mediaType: browseMediaType,
                    ageRating: ageRating
                )
                try Task.checkCancellation()
                // A failed dub-index refresh is a terminal filter-data error for
                // this query, not an empty TMDB page. Stop automatic pagination
                // here; otherwise Browse can request up to 30 more pages while
                // showing the same spinner and repeating the failed lookup.
                let filterDataUnavailable = await MainActor.run { errorMessage != nil }
                let browseTypeFiltered = sortedDeduplicatedResults(
                    existingRawResults + fetchedPageBrowseResults,
                    by: sort
                )
                try Task.checkCancellation()
                let contentFiltered = contentFilter.filterSearchResults(
                    filterExcludedResults(
                        browseTypeFiltered,
                        excludedGenreIds: excludedGenres.compactMap(\.tmdbGenreID),
                        excludedYears: excludedYears
                    ),
                    allowUpcomingContent: upcomingOnly,
                    resolveMetadataInBackground: false
                )
                try Task.checkCancellation()
                let filtered = regionGuardedResults(
                    contentFiltered,
                    countries: Set(countries)
                )

                await MainActor.run {
                    guard serial == requestSerial else { return }
                    loadTask = nil
                    activeBrowseLoadPage = nil
                    failedBrowseLoad = nil

                    // Retain type/age-filtered rows with their resolved
                    // anime identities. Filter refreshes can now reuse the
                    // identity seed instead of repeating TMDB→AniList lookups.
                    unfilteredResults = sortedDeduplicatedResults(browseTypeFiltered, by: sort)
                    results = sortedDeduplicatedResults(filtered, by: sort)

                    // Warm the shared logo cache as soon as a page arrives.
                    // Visible cards can reuse in-flight/cached artwork rather
                    // than starting an independent lookup on appearance.
                    Task(priority: .utility) {
                        await SearchResultTitleLogoCache.shared.prefetch(results: pageResult.results)
                    }

                    currentPage = page
                    hasMorePages = pageResult.hasMore && !filterDataUnavailable
                    isLoading = false

                    if filterRefreshPending && !filterDataUnavailable {
                        filterRefreshPending = false
                        reapplyCurrentFiltersToRetainedResults()
                    }

                    // Automatically continue through filtered-out pages until the
                    // grid has enough content to scroll. There is deliberately no
                    // fixed page cap: Anime and TV filters can legitimately reject
                    // several consecutive provider pages. The provider's hasMore
                    // signal remains the hard stop.
                    if !filterDataUnavailable,
                       hasMorePages,
                       results.count < 12 {
                        loadNextPage()
                    }

                    if browseMediaType.isAnime {
                        // Identity resolution required by strict audio filters is
                        // completed before publishing, but artwork lookups are not.
                        // Resolve clean covers/logos after the filtered grid is
                        // interactive so the first page is not held behind image APIs.
                        Task {
                            let enriched = await resolveAnimeBrowseIdentities(fetchedPageBrowseResults, resolveArtwork: true)
                            guard queryGeneration == browseQueryGeneration,
                                  mediaType == browseMediaType.tmdbValue else { return }
                            var enrichedByID: [Int: TMDBSearchResult] = [:]
                            for result in enriched { enrichedByID[result.id] = result }
                            unfilteredResults = unfilteredResults.map { enrichedByID[$0.id] ?? $0 }
                            results = results.map { enrichedByID[$0.id] ?? $0 }
                        }
                    } else if !browseMediaType.isAnime {
                        // Browse used to resolve Fanart.tv/TVMaze artwork only
                        // from the anime enrichment path. Consequently movie and
                        // TV cards had no clean poster candidates and displayed
                        // generic gradient placeholders with logos on top.
                        Task {
                            let enriched = await resolveBrowsePosterArtwork(pageResult.results)
                            guard queryGeneration == browseQueryGeneration,
                                  mediaType == browseMediaType.tmdbValue else { return }
                            var enrichedByID: [Int: TMDBSearchResult] = [:]
                            for result in enriched { enrichedByID[result.id] = result }
                            unfilteredResults = unfilteredResults.map { enrichedByID[$0.id] ?? $0 }
                            results = results.map { enrichedByID[$0.id] ?? $0 }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    guard serial == requestSerial else { return }
                    loadTask = nil
                    activeBrowseLoadPage = nil
                    isLoading = false
                    guard !(error is CancellationError),
                          (error as? URLError)?.code != .cancelled else { return }
                    failedBrowseLoad = (page: page, replacing: replacing)
                    errorMessage = error.localizedDescription
                }
            }
        }
        loadTask = task
    }

    private func selectionSummary(values: [String], emptyTitle: String) -> String {
        guard let firstValue = values.first else {
            return emptyTitle
        }

        if values.count == 1 {
            return firstValue
        }

        if values.count == 2 {
            return "\(firstValue), \(values[1])"
        }

        return "\(firstValue) +\(values.count - 1)"
    }

    private func toggleGenre(_ genre: BrowseGenre) {
        toggleGenre(genre, excluded: false)
    }

    private func toggleGenre(_ genre: BrowseGenre, excluded: Bool) {
        let genreKey = genre.id
        updateCurrentFilters { filters in
            var selected = Set(filters.selectedGenreKeys)
            var excludedGenres = Set(filters.excludedGenreKeys)

            if excluded {
                if excludedGenres.contains(genreKey) {
                    excludedGenres.remove(genreKey)
                } else {
                    excludedGenres.insert(genreKey)
                    selected.remove(genreKey)
                }
            } else if selected.contains(genreKey) {
                selected.remove(genreKey)
            } else {
                selected.insert(genreKey)
                excludedGenres.remove(genreKey)
            }

            filters.selectedGenreKeys = selected.sorted()
            filters.excludedGenreKeys = excludedGenres.sorted()
        }
    }

    private func toggleYear(_ year: Int) {
        toggleYear(year, excluded: false)
    }

    private func toggleYear(_ year: Int, excluded: Bool) {
        updateCurrentFilters { filters in
            var selected = Set(filters.selectedYears)
            var excludedYearSet = Set(filters.excludedYears)

            if excluded {
                if excludedYearSet.contains(year) {
                    excludedYearSet.remove(year)
                } else {
                    excludedYearSet.insert(year)
                    selected.remove(year)
                }
            } else if selected.contains(year) {
                selected.remove(year)
            } else {
                selected.insert(year)
                excludedYearSet.remove(year)
            }

            filters.selectedYears = selected.sorted()
            filters.excludedYears = excludedYearSet.sorted()
            if !excluded {
                filters.showsUpcomingOnly = false
            }
        }
    }

    private func toggleCountry(_ country: BrowseCountry) {
        updateCurrentFilters { filters in
            var countries = Set(filters.selectedCountryCodes)
            if countries.contains(country.code) {
                countries.remove(country.code)
            } else {
                countries.insert(country.code)
            }
            filters.selectedCountryCodes = countries.sorted()
        }
    }

    private struct BrowsePageResult {
        let results: [TMDBSearchResult]
        let hasMore: Bool
    }

    private func fetchDiscoverPage(
        mediaType: String,
        isAnime: Bool,
        genres: [BrowseGenre],
        excludedGenres: [BrowseGenre],
        years: [Int],
        upcomingOnly: Bool,
        excludedYears: Set<Int>,
        originCountries: [String],
        sort: BrowseSort,
        minimumRating: Double,
        page: Int
    ) async throws -> BrowsePageResult {
        let selectedKeywordNames = genres.compactMap(\.keyword)
        let excludedKeywordNames = excludedGenres.compactMap(\.keyword)
        // TMDB exposes fan-made and unofficial productions as keywords more
        // reliably than it does in title/overview text. Exclude those at the
        // discovery query as well as in TMDBContentFilter so Upcoming-only
        // results cannot reintroduce tagged fan productions.
        let unofficialKeywordNames = ProfileSettingsStore.active.bool(forKey: "catalogHideUnofficialContent")
            ? ["fan film", "fan-made", "fan made", "fan fiction", "fanfiction", "unofficial"]
            : []
        let allKeywordNames = Array(Set(selectedKeywordNames + excludedKeywordNames + unofficialKeywordNames)).sorted()
        let keywordIDsByName = await tmdbService.keywordIDs(for: allKeywordNames)
        let selectedKeywordIDs = selectedKeywordNames.compactMap { keywordIDsByName[$0] }
        let excludedKeywordIDs = Array(Set(excludedKeywordNames + unofficialKeywordNames))
            .compactMap { keywordIDsByName[$0] }
        let effectiveGenreIds = Array(Set(genres.compactMap(\.tmdbGenreID))).sorted()
        // Anime always requires Animation. TV's two default required genres
        // are ANDed only while both remain selected; removing either in the
        // filter UI removes the mandatory pair instead of trapping the user.
        let selectedGenreIDs = Set(genres.compactMap(\.tmdbGenreID))
        let requiresFantasyAndSciFi = mediaType == "tv"
            && selectedGenreIDs.contains(14)
            && selectedGenreIDs.contains(878)
        let requiredGenreIds = isAnime ? [16] : (requiresFantasyAndSciFi ? [14, 878] : [])
        let excludedGenreIds = Array(Set(excludedGenres.compactMap(\.tmdbGenreID))).sorted()
        let effectiveCountries = Array(Set(originCountries)).sorted()
        let effectiveLanguage = isAnime ? animeLanguage(for: effectiveCountries) : nil
        let requestedYears = years.filter { !excludedYears.contains($0) }
        let tmdbSortValue = sort.tmdbValue(for: mediaType == "tv" ? .tv : .movie)

        let ratingFloor: Double? = minimumRating > 0 ? minimumRating : nil
        let voteCountFloor = BrowseDiscoverRatingPolicy.minimumVoteCount(
            isRankSort: sort == .rank,
            minimumRating: minimumRating
        )

        guard !requestedYears.isEmpty || years.isEmpty else {
            return BrowsePageResult(results: [], hasMore: false)
        }

        guard !requestedYears.isEmpty else {
            let fetched = try await tmdbService.discoverMedia(
                mediaType: mediaType,
                genreIds: effectiveGenreIds,
                requiredGenreIds: requiredGenreIds,
                excludedGenreIds: excludedGenreIds,
                keywordIds: selectedKeywordIDs,
                excludedKeywordIds: excludedKeywordIDs,
                dateGte: upcomingOnly ? Self.todayDateString() : nil,
                originCountries: effectiveCountries,
                originalLanguage: effectiveLanguage,
                sortBy: tmdbSortValue,
                minimumVoteCount: voteCountFloor,
                voteAverageGte: ratingFloor,
                page: page
            )
            var results = upcomingOnly
                ? fetched.results.filter { Self.hasOfficialUpcomingDate($0) }
                : fetched.results
            var hasMore = fetched.hasMore

            if isAnime {
                // TMDB's animation discover index is incomplete for anime and
                // often omits titles that AniList still catalogs. Merge a
                // paged AniList source into the same result pipeline so the
                // existing dub, age, runtime, and production filters still run.
                let catalogKind: AniListService.AniListCatalogKind =
                    sort == .rank ? .topRated : (sort == .newest ? .trending : .popular)
                if let aniListResults = try? await AniListService.shared.fetchAnimeCatalog(
                    catalogKind,
                    page: page,
                    limit: 20,
                    tmdbService: tmdbService
                ) {
                    let selectedGenreIDs = Set(effectiveGenreIds)
                    let selectedCountrySet = Set(effectiveCountries)
                    let aniListCandidates = aniListResults.compactMap { candidate -> TMDBSearchResult? in
                        let anime = candidate.withAnimeHint(true)
                        if let ids = anime.genreIds, !selectedGenreIDs.isEmpty,
                           !ids.contains(where: selectedGenreIDs.contains) {
                            return nil
                        }
                        if upcomingOnly && !Self.hasOfficialUpcomingDate(anime) { return nil }
                        if let year = Int(anime.displayDate.prefix(4)),
                           !requestedYears.isEmpty, !requestedYears.contains(year) {
                            return nil
                        }
                        if !selectedCountrySet.isEmpty,
                           let countries = anime.originCountry,
                           !countries.contains(where: selectedCountrySet.contains) {
                            return nil
                        }
                        if let effectiveLanguage,
                           let language = anime.originalLanguage?.lowercased(),
                           language != effectiveLanguage.lowercased() {
                            return nil
                        }
                        if let ratingFloor, (anime.voteAverage ?? 0) < ratingFloor { return nil }
                        return anime
                    }
                    results = sortedDeduplicatedResults(results + aniListCandidates, by: sort)
                    hasMore = hasMore || !aniListResults.isEmpty
                }
            }
            return BrowsePageResult(results: results, hasMore: hasMore)
        }

        return try await withThrowingTaskGroup(of: BrowsePageResult.self) { group in
            for year in requestedYears {
                group.addTask {
                    let fetched = try await tmdbService.discoverMedia(
                        mediaType: mediaType,
                        genreIds: effectiveGenreIds,
                        requiredGenreIds: requiredGenreIds,
                        excludedGenreIds: excludedGenreIds,
                        keywordIds: selectedKeywordIDs,
                        excludedKeywordIds: excludedKeywordIDs,
                        year: year,
                        dateGte: upcomingOnly ? Self.todayDateString() : nil,
                        originCountries: effectiveCountries,
                        originalLanguage: effectiveLanguage,
                        sortBy: tmdbSortValue,
                        minimumVoteCount: voteCountFloor,
                        voteAverageGte: ratingFloor,
                        page: page
                    )
                    let results = upcomingOnly
                        ? fetched.results.filter { Self.hasOfficialUpcomingDate($0) }
                        : fetched.results
                    return BrowsePageResult(results: results, hasMore: fetched.hasMore)
                }
            }

            var combined: [TMDBSearchResult] = []
            var hasMore = false

            for try await result in group {
                combined.append(contentsOf: result.results)
                hasMore = hasMore || result.hasMore
            }

            return BrowsePageResult(
                results: sortedDeduplicatedResults(combined, by: sort),
                hasMore: hasMore
            )
        }
    }

    private static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func hasOfficialUpcomingDate(_ result: TMDBSearchResult) -> Bool {
        let raw = result.isMovie ? result.releaseDate : (result.firstAirDate ?? result.releaseDate)
        guard let raw, raw.count >= 10, !raw.hasPrefix("0001-") else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let announcedDate = formatter.date(from: String(raw.prefix(10))),
              let today = formatter.date(from: todayDateString()) else { return false }
        return announcedDate >= today
    }

    private func filterExcludedResults(
        _ fetched: [TMDBSearchResult],
        excludedGenreIds: [Int],
        excludedYears: Set<Int>
    ) -> [TMDBSearchResult] {
        fetched.filter { result in
            if let year = Int(result.displayDate.prefix(4)), excludedYears.contains(year) {
                return false
            }

            if let genreIds = result.genreIds,
               genreIds.contains(where: excludedGenreIds.contains) {
                return false
            }

            return true
        }
    }

    private func resolveAnimeBrowseIdentities(
        _ results: [TMDBSearchResult],
        resolveArtwork: Bool = true
    ) async -> [TMDBSearchResult] {
        let selectedDubLanguageCodes = Set(MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement.compactMap {
            MyDubListLanguage(rawValue: $0)?.taizenLanguageCode
        })
        let originalAudioFilterEnabled = ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio")
        let globalAnimeAgeFilterEnabled =
            ProfileSettingsStore.active.bool(forKey: "catalogHideBelowPG13Anime")
            || ProfileSettingsStore.active.bool(forKey: "catalogHideAllAgesAnime")

        let candidates = results.enumerated().compactMap { index, result -> (Int, TMDBSearchResult, Bool)? in
            let hasTaizenPoster = result.animeArtworkURL?.contains("taizen.moe") == true

            let originalLanguage = result.originalLanguage?.lowercased() ?? ""
            let baseLanguage = originalLanguage.split(separator: "-").first.map(String.init) ?? originalLanguage
            let nativeAudioMatchesDubFilter = selectedDubLanguageCodes.contains {
                originalLanguage == $0 || originalLanguage.hasPrefix($0 + "-")
            }
            let needsDubIdentity = !selectedDubLanguageCodes.isEmpty && !nativeAudioMatchesDubFilter
            let needsAudioIdentity = originalAudioFilterEnabled && !["en", "es"].contains(baseLanguage)
            // Existing clean artwork must not short-circuit identity resolution
            // when a selected dub/audio filter still needs AniList metadata.
            // Otherwise an anime with a Taizen poster and logo is incorrectly
            // discarded before the strict language filter can inspect it.
            let needsAgeIdentity = globalAnimeAgeFilterEnabled
            if hasTaizenPoster, result.animeLogoURL != nil,
               !needsDubIdentity, !needsAudioIdentity, !needsAgeIdentity {
                return nil
            }
            let likelyAnime = result.isAnimeHint == true
                || (result.genreIds?.contains(16) == true
                    && (["ja", "zh", "ko"].contains(baseLanguage)
                        || result.originCountry?.contains(where: { ["JP", "CN", "KR", "TW"].contains($0) }) == true))
            // Taizen's fanart.tv poster is preferred for anime even when TMDB
            // already supplied an image. AniList remains the fallback.
            guard needsDubIdentity || needsAudioIdentity || needsAgeIdentity
                || likelyAnime || result.fullPosterURL == nil else {
                return nil
            }
            return (index, result, likelyAnime)
        }
        guard !candidates.isEmpty else { return results }

        if !selectedDubLanguageCodes.isEmpty || originalAudioFilterEnabled {
            // Load a previously persisted index before per-title lookups, but do
            // not block Browse on downloading the full global index on a cold
            // install. Keep the network refresh in the background.
            await AniMapMappingService.shared.prepareCachedGlobalIndexIfNeeded()
            guard !Task.isCancelled else { return results }
            Task(priority: .utility) {
                await AniMapMappingService.shared.prepareGlobalIndexIfNeeded()
            }
        }

        let resolvedResults = await withTaskGroup(of: (Int, TMDBSearchResult).self) { group in
            var iterator = candidates.makeIterator()
            // Cached mappings are cheap; modestly increase parallel resolution so
            // dub-filtered pages do not serialize behind a handful of slow lookups.
            let concurrencyLimit = 8
            for _ in 0..<min(concurrencyLimit, candidates.count) {
                guard let (index, result, likelyAnime) = iterator.next() else { continue }
                group.addTask {
                    let identity: AnimeMediaIdentitySeed?
                    if let existing = result.animeIdentitySeed?.sanitizedForPersistence {
                        // A previously resolved identity already satisfies the
                        // strict dub filter. Do not issue another mapping request.
                        identity = existing
                    } else {
                        let mappings = await AniMapMappingService.shared.mappings(forTMDBShowId: result.id)
                        let mapping = mappings
                            .filter { $0.mediaType?.lowercased() != "movie" }
                            .first { $0.anilistId != nil }
                            ?? mappings.first { $0.anilistId != nil }
                        if let anilistID = mapping?.anilistId, anilistID > 0 {
                            identity = AnimeMediaIdentitySeed(
                                anilistId: anilistID,
                                malId: mapping?.malId,
                                kitsuId: mapping?.kitsuId,
                                format: mapping?.mediaType
                            )
                        } else if likelyAnime {
                            let titleIdentity = await AniListService.shared.searchAnimeIdentity(title: result.displayTitle)
                            if let titleIdentity {
                                identity = titleIdentity
                            } else if let originalName = result.originalName,
                                      originalName.caseInsensitiveCompare(result.displayTitle) != .orderedSame {
                                identity = await AniListService.shared.searchAnimeIdentity(title: originalName)
                            } else {
                                identity = nil
                            }
                        } else {
                            identity = nil
                        }
                    }
                    guard let identity = identity?.sanitizedForPersistence else {
                        return (index, result)
                    }
                    let anilistID = identity.anilistId

                    let artworkURL: String?
                    if !resolveArtwork {
                        artworkURL = result.animeArtworkURL
                    } else if let existingArtwork = result.animeArtworkURL {
                        artworkURL = existingArtwork
                    } else {
                        let artworkIdentity = await AniListService.shared.fetchAnimeSeasonIdentity(
                            anilistId: anilistID,
                            tmdbShowId: result.id,
                            title: result.displayTitle
                        )
                        artworkURL = artworkIdentity?.posterURL
                    }
                    let enriched = TMDBSearchResult(
                        id: result.id,
                        mediaType: result.mediaType,
                        title: result.title,
                        name: result.name,
                        originalName: result.originalName,
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
                        animeIdentitySeed: identity,
                        animeArtworkURL: artworkURL,
                        animeLogoURL: result.animeLogoURL,
                        tvMazePosterURL: result.tvMazePosterURL,
                        fanartTVPosterURL: result.fanartTVPosterURL
                    )
                    return (index, enriched)
                }
            }

            var resolvedByIndex: [Int: TMDBSearchResult] = [:]
            while let (index, result) = await group.next() {
                resolvedByIndex[index] = result
                if let (nextIndex, nextResult, nextLikelyAnime) = iterator.next() {
                    group.addTask {
                        let identity: AnimeMediaIdentitySeed?
                        if let existing = nextResult.animeIdentitySeed?.sanitizedForPersistence {
                            // Reuse a resolved identity rather than repeating a
                            // TMDB-to-AniList mapping lookup for the same title.
                            identity = existing
                        } else {
                            let mappings = await AniMapMappingService.shared.mappings(forTMDBShowId: nextResult.id)
                            let mapping = mappings
                                .filter { $0.mediaType?.lowercased() != "movie" }
                                .first { $0.anilistId != nil }
                                ?? mappings.first { $0.anilistId != nil }
                            if let anilistID = mapping?.anilistId, anilistID > 0 {
                                identity = AnimeMediaIdentitySeed(
                                    anilistId: anilistID,
                                    malId: mapping?.malId,
                                    kitsuId: mapping?.kitsuId,
                                    format: mapping?.mediaType
                                )
                            } else if nextLikelyAnime {
                                let titleIdentity = await AniListService.shared.searchAnimeIdentity(title: nextResult.displayTitle)
                                if let titleIdentity {
                                    identity = titleIdentity
                                } else if let originalName = nextResult.originalName,
                                          originalName.caseInsensitiveCompare(nextResult.displayTitle) != .orderedSame {
                                    identity = await AniListService.shared.searchAnimeIdentity(title: originalName)
                                } else {
                                    identity = nil
                                }
                            } else {
                                identity = nil
                            }
                        }
                        guard let identity = identity?.sanitizedForPersistence else {
                            return (nextIndex, nextResult)
                        }
                        let anilistID = identity.anilistId
                        let artworkURL: String?
                        if !resolveArtwork {
                            artworkURL = nextResult.animeArtworkURL
                        } else if let existingArtwork = nextResult.animeArtworkURL {
                            artworkURL = existingArtwork
                        } else {
                            let artworkIdentity = await AniListService.shared.fetchAnimeSeasonIdentity(
                                anilistId: anilistID,
                                tmdbShowId: nextResult.id,
                                title: nextResult.displayTitle
                            )
                            artworkURL = artworkIdentity?.posterURL
                        }
                        return (nextIndex, TMDBSearchResult(
                            id: nextResult.id, mediaType: nextResult.mediaType,
                            title: nextResult.title, name: nextResult.name,
                            originalName: nextResult.originalName,
                            overview: nextResult.overview, posterPath: nextResult.posterPath,
                            backdropPath: nextResult.backdropPath, releaseDate: nextResult.releaseDate,
                            firstAirDate: nextResult.firstAirDate, voteAverage: nextResult.voteAverage,
                            popularity: nextResult.popularity, adult: nextResult.adult,
                            genreIds: nextResult.genreIds, originalLanguage: nextResult.originalLanguage,
                            originCountry: nextResult.originCountry, voteCount: nextResult.voteCount,
                            isAnimeHint: true,
                            animeIdentitySeed: identity,
                            animeArtworkURL: artworkURL,
                            animeLogoURL: nextResult.animeLogoURL,
                            tvMazePosterURL: nextResult.tvMazePosterURL,
                            fanartTVPosterURL: nextResult.fanartTVPosterURL
                        ))
                    }
                }
            }
            return results.enumerated().map { index, result in
                resolvedByIndex[index] ?? result
            }
        }

        guard resolveArtwork else { return resolvedResults }

        let taizenArtwork = await TaizenAnimeArtworkService.shared.artworks(
            forAniListIDs: resolvedResults.compactMap { $0.animeIdentitySeed?.anilistId }
        )
        let animeArtworkResults = resolvedResults.map { result in
            guard let anilistID = result.animeIdentitySeed?.anilistId,
                  let artwork = taizenArtwork[anilistID] else { return result }
            return result
                .withAnimeArtworkURL(artwork.posterURL ?? result.animeArtworkURL)
                .withAnimeLogoURL(artwork.logoURL ?? result.animeLogoURL)
        }

        let tvMazeRequests = animeArtworkResults.compactMap { result -> TVMazePosterRequest? in
            guard result.mediaType.lowercased() == "tv",
                  result.animeIdentitySeed == nil,
                  result.isAnimeHint != true else { return nil }
            let rawYear = result.firstAirDate ?? result.releaseDate
            return TVMazePosterRequest(
                id: result.id,
                title: result.displayTitle,
                year: rawYear.flatMap { Int($0.prefix(4)) }
            )
        }
        let fanartRequests = animeArtworkResults.compactMap { result -> FanartTVMoviePosterRequest? in
            guard result.mediaType.lowercased() == "movie",
                  result.animeIdentitySeed == nil,
                  result.isAnimeHint != true else { return nil }
            return FanartTVMoviePosterRequest(id: result.id)
        }

        async let tvMazePostersTask = TVMazeArtworkPosterService.shared.posters(for: tvMazeRequests)
        async let fanartPostersTask = FanartTVMovieArtworkService.shared.posters(for: fanartRequests)
        let (tvMazePosters, fanartPosters) = await (tvMazePostersTask, fanartPostersTask)

        return animeArtworkResults.map { result in
            if let posterURL = fanartPosters[result.id] {
                return result.withFanartTVPosterURL(posterURL)
            }
            if let posterURL = tvMazePosters[result.id] {
                return result.withTVMazePosterURL(posterURL)
            }
            return result
        }
    }

    private func resolveBrowsePosterArtwork(_ results: [TMDBSearchResult]) async -> [TMDBSearchResult] {
        let tvMazeRequests = results.compactMap { result -> TVMazePosterRequest? in
            guard result.mediaType.lowercased() == "tv",
                  result.animeIdentitySeed == nil,
                  result.isAnimeHint != true else { return nil }
            let rawYear = result.firstAirDate ?? result.releaseDate
            return TVMazePosterRequest(
                id: result.id,
                title: result.displayTitle,
                year: rawYear.flatMap { Int($0.prefix(4)) }
            )
        }
        let fanartRequests = results.compactMap { result -> FanartTVMoviePosterRequest? in
            guard result.mediaType.lowercased() == "movie",
                  result.animeIdentitySeed == nil,
                  result.isAnimeHint != true else { return nil }
            return FanartTVMoviePosterRequest(id: result.id)
        }
        async let tvMazeTask = TVMazeArtworkPosterService.shared.posters(for: tvMazeRequests)
        async let fanartTask = FanartTVMovieArtworkService.shared.posters(for: fanartRequests)
        let (tvMazePosters, fanartPosters) = await (tvMazeTask, fanartTask)
        return results.map { result in
            if let poster = fanartPosters[result.id] {
                return result.withFanartTVPosterURL(poster)
            }
            if let poster = tvMazePosters[result.id] {
                return result.withTVMazePosterURL(poster)
            }
            return result
        }
    }

    private func filterResultsForBrowseType(
        _ fetched: [TMDBSearchResult],
        mediaType: BrowseMediaType,
        ageRating: BrowseAgeRating
    ) async -> [TMDBSearchResult] {
        let typeFiltered = fetched.compactMap { result -> TMDBSearchResult? in
            switch mediaType {
            case .movie:
                return result
            case .tv:
                // Only remove results that carry explicit anime signals.
                // The previous classifier could reject ordinary TV titles
                // when provider identity metadata was incomplete.
                let language = result.originalLanguage?.lowercased() ?? ""
                let animeCountries: Set<String> = ["JP", "CN", "KR", "TW"]
                let hasAnimeSignals = result.animeIdentitySeed != nil
                    || result.isAnimeHint == true
                    || (result.genreIds?.contains(16) == true
                        && (["ja", "zh", "ko"].contains(language)
                            || result.originCountry?.contains(where: { animeCountries.contains($0) }) == true))
                return hasAnimeSignals ? nil : result
            case .anime:
                // AniList catalogue entries are authoritative anime even when
                // TMDB has incomplete or incorrect genre metadata for their
                // mapped TV record. Preserve those candidates; require TMDB's
                // Animation genre only for results discovered solely by TMDB.
                if result.isAnimeHint == true || result.animeIdentitySeed != nil {
                    return result.withAnimeHint(true)
                }
                if let genres = result.genreIds, !genres.contains(16) { return nil }
                return result.withAnimeHint(true)
            }
        }

        // Use the effective language set, not only the manually selected
        // languages. The global English/Spanish audio requirement implicitly
        // selects both languages and must warm the same dub index on cold Browse.
        let selectedDubLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
        let requiresGlobalAnimeAgeRating = ProfileSettingsStore.active.bool(forKey: "catalogHideBelowPG13Anime")
            || ProfileSettingsStore.active.bool(forKey: "catalogHideAllAgesAnime")
        let requiresAnimeIdentity = mediaType.isAnime
            && (!selectedDubLanguages.isEmpty || requiresGlobalAnimeAgeRating)

        // A cold launch can reach Browse before the asynchronous MyDubList
        // refresh in TMDBContentFilter.init has finished. The dub predicate
        // intentionally fails closed while its snapshot is unavailable, which
        // previously made the entire Anime page look empty. Hydrate the
        // persisted snapshot synchronously first; only wait for the network
        // when no matching cached language snapshot exists.
        if mediaType.isAnime, !selectedDubLanguages.isEmpty,
           !MyDubListDubFilter.shared.prepareCachedSnapshot() {
            // Keep the page in its loading state until the selected-language
            // identity snapshot is ready. Publishing an empty grid first and
            // replacing it after a background refresh caused a visible empty
            // state/flicker and repeated filtering work.
            // Do not hold the first Browse page on a slow global index request.
            // Per-title Taizen/audio checks below verify candidates immediately;
            // the refresh notification re-applies filters when the shared index arrives.
            Task(priority: .utility) {
                _ = await MyDubListDubFilter.shared.refresh()
            }
            guard !Task.isCancelled else { return [] }
        }
        let defaults = ProfileSettingsStore.active
        let requiresBrowseMetadata = defaults.bool(forKey: "catalogHideUnder20MinuteContent")
            || defaults.bool(forKey: "catalogHideUnofficialContent")
            || defaults.bool(forKey: "catalogHideBelowPG13Movies")
            || defaults.bool(forKey: "catalogHideBelowTV14Shows")
            || defaults.bool(forKey: "catalogHideBelowPG13Anime")
            || defaults.bool(forKey: "catalogHideAllAgesMovies")
            || defaults.bool(forKey: "catalogHideAllAgesSeries")
            || defaults.bool(forKey: "catalogHideAllAgesAnime")
            || defaults.bool(forKey: "catalogRequireEnglishSpanishAudio")
        guard ageRating != .all || requiresAnimeIdentity || requiresBrowseMetadata else {
            return typeFiltered
        }
        guard !Task.isCancelled else { return [] }

        // Resolve anime identity only when an anime-specific filter needs it.
        // Production-company/runtime filters also apply to ordinary TV and
        // movies, so they must still resolve metadata when Browse's age menu is
        // set to "Any Age Rating".
        let shouldResolveAnimeIdentity = mediaType.isAnime
            && (requiresAnimeIdentity || ageRating != .all)
        let ratingCandidates = shouldResolveAnimeIdentity
            ? await resolveAnimeBrowseIdentities(typeFiltered, resolveArtwork: false)
            : typeFiltered
        guard !Task.isCancelled else { return [] }

        // Resolve all metadata gates before the first filtered grid is published.
        // This avoids an empty first page when runtime, production, anime age, or
        // dub metadata is still in flight.
        await contentFilter.resolveBrowseFilterMetadata(
            for: ratingCandidates,
            requiresAnimeAgeRating: ageRating != .all
        )
        guard !Task.isCancelled else { return [] }

        if ageRating == .all {
            return ratingCandidates
        }

        // Resolve both sources concurrently: anime age classifications come
        // from Taizen/MAL, while TMDB supplies national movie/TV certifications.
        async let tmdbRatingResolution: Void = TMDBMaturityRatingStore.shared.resolve(
            ratingCandidates.map { (isMovie: $0.isMovie, id: $0.id) }
        )
        async let animeRatingResolution = resolveBrowseAnimeAgeRatings(
            ratingCandidates,
            mediaType: mediaType
        )
        await tmdbRatingResolution
        let animeRatingsByID = await animeRatingResolution
        guard !Task.isCancelled else { return [] }

        return ratingCandidates.filter { result in
            let hasExplicitContent = result.adult == true
                || (mediaType.isAnime && TMDBContentFilter.hasExplicitAnimeMetadata(result))
            let tmdbRating = TMDBMaturityRatingStore.shared.rating(isMovie: result.isMovie, id: result.id)
            let animeRating = result.animeIdentitySeed.flatMap { animeRatingsByID[$0.anilistId] }
            let verifiedAnimeRating = animeRating.flatMap { $0 == .unknown ? nil : $0 }
            let rating = mediaType.isAnime
                ? (verifiedAnimeRating ?? tmdbRating)
                : tmdbRating
            return ageRating.includes(rating, hasExplicitContent: hasExplicitContent)
        }
    }

    private func resolveBrowseAnimeAgeRatings(
        _ results: [TMDBSearchResult],
        mediaType: BrowseMediaType
    ) async -> [Int: MaturityRating] {
        guard mediaType.isAnime else { return [:] }
        let identities = results.compactMap(\.animeIdentitySeed)
        let identifiers = Array(Set(identities.map(\.anilistId)))
        guard !identifiers.isEmpty, !Task.isCancelled else { return [:] }
        var ratings = (try? await TaizenAnimeAgeRatingService.shared.ratings(anilistIDs: identifiers)) ?? [:]
        let missing = identities.filter { identity in
            identity.malId != nil
                && (ratings[identity.anilistId] == nil || ratings[identity.anilistId] == .unknown)
        }
        if MALMetadataService.shared.isConfigured {
            for identity in missing {
                guard !Task.isCancelled, let malID = identity.malId, malID > 0 else { continue }
                if let fallback = await MALMetadataService.shared.fetchMaturityRating(malID: malID),
                   fallback != .unknown {
                    ratings[identity.anilistId] = fallback
                }
            }
        }

        // Keep Browse's explicit age-rating gate on the same provider chain as
        // the shared content filter. Batch Jikan requests so larger pages do not
        // wait for one network round-trip per title.
        let jikanIdentities = missing.compactMap { identity -> (animeID: Int, malID: Int)? in
            guard (ratings[identity.anilistId] == nil || ratings[identity.anilistId] == .unknown),
                  let malID = identity.malId, malID > 0 else { return nil }
            return (identity.anilistId, malID)
        }
        let jikanRatings = await JikanAnimeAgeRatingService.shared.ratings(
            malIDs: Array(Set(jikanIdentities.map(\.malID)))
        )
        guard !Task.isCancelled else { return ratings }
        for identity in jikanIdentities {
            if let fallback = jikanRatings[identity.malID], fallback != .unknown {
                ratings[identity.animeID] = fallback
            }
        }
        return ratings
    }

    private func animeLanguage(for countries: [String]) -> String? {
        guard countries.count == 1 else { return nil }
        switch countries[0] {
        case "JP": return "ja"
        case "CN", "TW": return "zh"
        case "KR": return "ko"
        default: return nil
        }
    }

    private func expectedLanguages(for country: String) -> Set<String>? {
        switch country {
        case "US", "GB", "AU": return ["en"]
        case "CA": return ["en", "fr"]
        case "JP": return ["ja"]
        case "KR": return ["ko"]
        case "CN", "TW": return ["zh", "cn"]
        case "FR": return ["fr"]
        case "DE": return ["de"]
        case "ES": return ["es", "ca"]
        case "MX": return ["es"]
        case "BR": return ["pt"]
        case "TH": return ["th"]
        case "IN": return nil
        default: return nil
        }
    }

    private func regionGuardedResults(_ results: [TMDBSearchResult], countries: Set<String>) -> [TMDBSearchResult] {
        guard !countries.isEmpty else { return results }
        let languageSets = countries.compactMap(expectedLanguages)
        let acceptableLanguages = languageSets.reduce(into: Set<String>()) { result, languages in
            result.formUnion(languages)
        }
        let hasCountryWithoutLanguageFallback = languageSets.count != countries.count
        return results.filter { result in
            if let origins = result.originCountry, !origins.isEmpty {
                return !countries.isDisjoint(with: origins)
            }
            if !hasCountryWithoutLanguageFallback,
               let language = result.originalLanguage,
               !language.isEmpty {
                return acceptableLanguages.contains(language.lowercased())
            }
            return true
        }
    }

    private func sortedDeduplicatedResults(_ fetched: [TMDBSearchResult], by sort: BrowseSort) -> [TMDBSearchResult] {
        var seen = Set<String>()
        let uniqueResults = fetched.filter { result in
            seen.insert(result.stableIdentity).inserted
        }

        return uniqueResults.sorted { lhs, rhs in
            switch sort {
            case .newest, .oldest:
                if lhs.displayDate != rhs.displayDate {
                    if lhs.displayDate.isEmpty { return false }
                    if rhs.displayDate.isEmpty { return true }
                    return sort == .newest
                        ? lhs.displayDate > rhs.displayDate
                        : lhs.displayDate < rhs.displayDate
                }
            case .rank:
                if lhs.voteAverage != rhs.voteAverage {
                    return (lhs.voteAverage ?? 0) > (rhs.voteAverage ?? 0)
                }
            case .title:
                let comparison = lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            case .popularity:
                break
            }

            if lhs.popularity != rhs.popularity {
                return lhs.popularity > rhs.popularity
            }
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }
}

struct SearchBarEclipse: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    @StateObject private var glassAppearance = LiquidGlassAppearanceSettings.shared
#if os(macOS)
    @FocusState private var macSearchFocused: Bool
    @Environment(\.macSearchFocusRequest) private var macSearchFocusRequest
#endif

    var body: some View {
        HStack {
            TextField(LocalizedStringKey("Search Placeholder"), text: $text)
#if os(macOS)
                .focused($macSearchFocused)
                .accessibilityIdentifier("mac.media.search")
                .task(id: macSearchFocusRequest) {
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    macSearchFocused = macSearchFocusRequest != 0
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MacMediaFocusSearch"))) { _ in macSearchFocused = true }
#endif
                .submitLabel(.search)
                .onSubmit(onSearchButtonClicked)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color.clear)
                .contentShape(Rectangle())
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)

                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
#if !os(tvOS)
        // Tint only the actual pill surface. Applying glass to the TextField
        // itself let its expanding layout/background bleed into adjacent
        // search controls and the surrounding screen.
        .applyLiquidGlassBackground(
            cornerRadius: 12,
            fallbackFill: glassAppearance.lightBarColor.opacity(LiquidGlassAppearanceSettings.defaultLightBarOpacity),
            glassTint: glassAppearance.lightBarColor.opacity(LiquidGlassAppearanceSettings.defaultLightBarOpacity)
        )
#endif
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
