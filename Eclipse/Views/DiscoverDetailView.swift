import SwiftUI
import Kingfisher

/// Tracks only successfully fetched pages. A failed request leaves the cursor
/// unchanged so Retry asks the provider for the same page again.
struct DiscoverPaginationCursor: Equatable {
    static let maximumConsecutiveEmptyPages = 4

    private(set) var currentPage = 1
    private(set) var consecutiveEmptyPages = 0
    private(set) var hasMorePages = true

    var nextPage: Int { currentPage + 1 }

    mutating func didLoadPage(hasUniqueItems: Bool) {
        currentPage = nextPage
        consecutiveEmptyPages = hasUniqueItems ? 0 : consecutiveEmptyPages + 1
        if consecutiveEmptyPages >= Self.maximumConsecutiveEmptyPages {
            hasMorePages = false
        }
    }

    mutating func reset() {
        currentPage = 1
        consecutiveEmptyPages = 0
        hasMorePages = true
    }

    mutating func refreshFirstPage() {
        consecutiveEmptyPages = 0
        hasMorePages = true
    }
}

struct DiscoverDetailView: View {
    let catalogID: String
    let title: String
    let initialItems: [TMDBSearchResult]
    var heroItem: TMDBSearchResult? = nil
    var loadMore: ((Int) async throws -> [TMDBSearchResult])? = nil
    var allowsUpcomingContent: Bool = false

    @State private var items: [TMDBSearchResult] = []
    @State private var initialPageItemCount = 0
    @State private var filterRefreshRevision = 0
    @State private var paginationCursor = DiscoverPaginationCursor()
    @State private var paginationError: String?
    @State private var isLoadingMore = false
    @State private var paginationSentinelVisible = false
    @State private var activePaginationSentinelID: String?
    @State private var loadGeneration = UUID()
    @StateObject private var contentFilter = TMDBContentFilter.shared
    @Environment(\.heroNamespace) private var heroNamespace

    private var filteredItems: [TMDBSearchResult] {
        _ = filterRefreshRevision
        return contentFilter.filterSearchResults(
            items,
            allowUpcomingContent: allowsUpcomingContent
        )
    }

    private var sectionIdentity: String {
        "\(catalogID)|\(title)"
    }

    // Start fetching before the user reaches the final card. Lazy grids do not
    // always re-fire the last visible card's onAppear after a page append,
    // which made Browse appear to stall until the user nudged the scroll view.
    private var paginationTriggerIdentity: String? {
        guard !filteredItems.isEmpty else { return nil }
        let triggerIndex = max(0, filteredItems.count - 6)
        return filteredItems[triggerIndex].stableIdentity
    }

    private var columns: [GridItem] {
#if os(tvOS)
        return [
            GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 44, alignment: .top)
        ]
#else
        if isIPad {
            return [
                GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 24, alignment: .top)
            ]
        }
        return [
            GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 16)
        ]
#endif
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if let hero = heroItem {
                    heroHeader(hero)
                }

                LazyVGrid(columns: columns, spacing: isTvOS ? 48 : (isIPad ? 30 : 20)) {
                    ForEach(filteredItems, id: \.stableIdentity) { item in
                        NavigationLink(destination: MediaDetailView(searchResult: item)
                            .heroDestination(id: "discover-\(item.stableIdentity)", namespace: heroNamespace)
                        ) {
                            discoverCard(item)
                        }
#if os(tvOS)
                        .buttonStyle(TVMediaCardButtonStyle())
#else
                        .buttonStyle(PlainButtonStyle())
#endif
                        .onAppear {
                            if item.stableIdentity == paginationTriggerIdentity {
                                loadNextPage()
                            }
                        }
                    }
                }
                .padding(.horizontal, isTvOS ? 60 : (isIPad ? 28 : 16))
                .padding(.top, heroItem != nil ? (isTvOS ? 40 : (isIPad ? 28 : 16)) : (isTvOS ? 24 : 8))

                // A dedicated sentinel keeps pagination moving when the last
                // card's onAppear is not re-fired after a page append.
                if loadMore != nil && paginationCursor.hasMorePages && paginationError == nil {
                    let sentinelID = "browse-pagination-\(items.count)-\(paginationCursor.currentPage)"
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                        .id(sentinelID)
                        .onAppear {
                            activePaginationSentinelID = sentinelID
                            paginationSentinelVisible = true
                            loadNextPage()
                        }
                        .onDisappear {
                            // The old sentinel can disappear after its replacement
                            // appears. Never let that stale callback clear the new
                            // sentinel's visibility and strand pagination.
                            if activePaginationSentinelID == sentinelID {
                                paginationSentinelVisible = false
                                activePaginationSentinelID = nil
                            }
                        }
                }

                if isLoadingMore {
                    EclipseLoadingIndicator()
                        .padding(.vertical, 20)
                }

                if let paginationError {
                    VStack(spacing: 10) {
                        Text(paginationError)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { loadNextPage() }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("discover.paginationRetryButton")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("discover.paginationRetry")
                } else if filteredItems.isEmpty && !paginationCursor.hasMorePages && !isLoadingMore {
                    Text("No results match the selected filters.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }

                Spacer(minLength: 80)
            }
        }
        .eclipseBackground()
        .navigationTitle(title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#elseif os(tvOS)
        .eclipseHideTabBar()
#endif
        .onAppear {
            if items.isEmpty {
                items = initialItems
                initialPageItemCount = initialItems.count
                if filteredItems.isEmpty {
                    loadNextPage()
                }
            }
            let snapshot = items.isEmpty ? initialItems : items
            Task { @MainActor in
                await contentFilter.resolveBrowseFilterMetadata(
                    for: snapshot
                )
                filterRefreshRevision &+= 1
            }
        }
        .onChangeComp(of: sectionIdentity) { _, _ in
            // The same navigation destination can be reused while switching
            // between Anime, Movies and Series. Invalidate any in-flight page
            // request and discard the previous catalog's tail before loading
            // the new category.
            loadGeneration = UUID()
            items = initialItems
            initialPageItemCount = initialItems.count
            paginationCursor.reset()
            paginationError = nil
            isLoadingMore = false
            filterRefreshRevision &+= 1
            let snapshot = items
            Task { @MainActor in
                await contentFilter.resolveBrowseFilterMetadata(
                    for: snapshot
                )
                filterRefreshRevision &+= 1
            }
            if filteredItems.isEmpty {
                loadNextPage()
            }
        }
        .onChangeComp(of: initialItems.map(\.stableIdentity)) { _, _ in
            // Home may refresh its first-page catalog snapshot after asynchronous
            // maturity metadata resolves. Replace only that first page and keep
            // already-loaded pages/currentPage so the visible grid does not jump
            // back to the top while the user is browsing.
            let existingTail = initialPageItemCount < items.count
                ? Array(items.dropFirst(initialPageItemCount))
                : []
            let firstPageIDs = Set(initialItems.map(\.stableIdentity))
            items = initialItems + existingTail.filter { !firstPageIDs.contains($0.stableIdentity) }
            initialPageItemCount = initialItems.count
            paginationCursor.refreshFirstPage()
            paginationError = nil
            let snapshot = items
            Task { @MainActor in
                await contentFilter.resolveBrowseFilterMetadata(
                    for: snapshot
                )
                filterRefreshRevision &+= 1
            }
            if filteredItems.isEmpty {
                loadNextPage()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: TMDBContentFilter.catalogFiltersDidChangeNotification)) { _ in
            let snapshot = items
            Task { @MainActor in
                await contentFilter.resolveBrowseFilterMetadata(
                    for: snapshot
                )
                // Keep the original page snapshot stable. Replacing the
                // backing array here invalidates LazyVGrid's scroll layout,
                // causing flashing and jumps back to the top.
                filterRefreshRevision &+= 1
                if filteredItems.isEmpty && paginationCursor.hasMorePages && paginationError == nil {
                    loadNextPage()
                }
            }
        }
    }

    @ViewBuilder
    private func heroHeader(_ hero: TMDBSearchResult) -> some View {
        Group {
            if isIPad {
                ZStack(alignment: .bottomLeading) {
                    KFImage(URL(string: hero.fullBackdropURL ?? hero.fullPosterURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(16/9, contentMode: .fit)
                        }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.12), EclipseTheme.shared.backgroundBase.opacity(0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    heroHeaderText(hero)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: 1080)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.30), radius: 20, x: 0, y: 12)
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .frame(maxWidth: .infinity)
            } else {
                ZStack(alignment: .bottomLeading) {
                    KFImage(URL(string: hero.fullBackdropURL ?? hero.fullPosterURL ?? ""))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        }
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 220)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, EclipseTheme.shared.backgroundBase],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)

                    heroHeaderText(hero)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private func heroHeaderText(_ hero: TMDBSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hero.displayTitle)
                .font(isIPad ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 8) {
                if !hero.displayDate.isEmpty {
                    Text(hero.displayDate)
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.white.opacity(0.72))
                }
                if let genres = hero.genreIds, let firstGenre = genres.first,
                   let genreName = WidgetGenre.active.first(where: { $0.id == firstGenre })?.name {
                    Text(genreName)
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.white.opacity(0.72))
                }
            }
        }
    }

    @ViewBuilder
    private func iPadDiscoverCard(_ item: TMDBSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            KFImage(item.fullPosterURL.flatMap(URL.init(string:)))
                .placeholder {
                    FallbackImageView(
                        isMovie: item.isMovie,
                        size: CGSize(width: 320, height: 180)
                    )
                }
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 9, x: 0, y: 5)
                .heroSource(id: "discover-\(item.stableIdentity)", namespace: heroNamespace)

            Text(item.displayTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 8) {
                if !item.displayDate.isEmpty {
                    Text(String(item.displayDate.prefix(4)))
                }

                if let vote = item.voteAverage, vote > 0 {
                    Label(String(format: "%.1f", vote), systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.58))
        }
    }

    @ViewBuilder
    private func phoneDiscoverCard(_ item: TMDBSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(item.fullPosterURL.flatMap(URL.init(string:)))
                .placeholder {
                    FallbackImageView(
                        isMovie: item.isMovie,
                        size: CGSize(width: 120, height: 180)
                    )
                }
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                .heroSource(id: "discover-\(item.stableIdentity)", namespace: heroNamespace)

            Text(item.displayTitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 4) {
                if !item.displayDate.isEmpty {
                    let date = item.displayDate
                    Text(String(date.prefix(4)))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }

                if let vote = item.voteAverage, vote > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", vote))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }

#if os(tvOS)
    @ViewBuilder
    private func tvDiscoverCard(_ item: TMDBSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            KFImage(URL(string: item.fullPosterURL ?? ""))
                .placeholder {
                    FallbackImageView(
                        isMovie: item.isMovie,
                        size: CGSize(width: 220, height: 330)
                    )
                }
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 220, height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(item.displayTitle)
                .font(.system(size: 25, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)

            HStack(spacing: 8) {
                if !item.displayDate.isEmpty {
                    Text(String(item.displayDate.prefix(4)))
                }

                if let vote = item.voteAverage, vote > 0 {
                    Label(String(format: "%.1f", vote), systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.system(size: 23))
            .foregroundColor(.white.opacity(0.6))
            .frame(width: 220, alignment: .leading)
        }
        .frame(width: 220)
        .padding(.vertical, 20)
    }
#endif

    @ViewBuilder
    private func discoverCard(_ item: TMDBSearchResult) -> some View {
#if os(tvOS)
        tvDiscoverCard(item)
#else
        if isIPad {
            iPadDiscoverCard(item)
        } else {
            phoneDiscoverCard(item)
        }
#endif
    }

    private func loadNextPage() {
        guard let loadMore = loadMore,
              !isLoadingMore,
              paginationCursor.hasMorePages else { return }
        isLoadingMore = true
        paginationError = nil
        let generation = UUID()
        loadGeneration = generation
        Task { @MainActor in
            // Skip a bounded number of pages removed by strict filters, but
            // never treat a network failure as an empty page.
            var scannedPages = 0
            // Bound each automatic pagination burst. If strict filters hide
            // several valid provider pages, retain those raw rows and let the
            // next sentinel appearance continue instead of scanning the entire
            // catalog in one main-actor task.
            while paginationCursor.hasMorePages,
                  paginationCursor.consecutiveEmptyPages < DiscoverPaginationCursor.maximumConsecutiveEmptyPages,
                  scannedPages < 6 {
                scannedPages += 1
                let requestedPage = paginationCursor.nextPage
                do {
                    let newItems = try await loadMore(requestedPage)
                    guard generation == loadGeneration else { return }
                    let existingIDs = Set(items.map { $0.stableIdentity })
                    let unique = newItems.filter { !existingIDs.contains($0.stableIdentity) }

                    if !unique.isEmpty {
                        // Resolve metadata while retaining the raw provider
                        // results. A dub/age lookup may complete after this page
                        // arrives; keeping the rows lets the filter notification
                        // reveal them later instead of losing the page forever.
                        await contentFilter.resolveBrowseFilterMetadata(for: unique)
                        guard generation == loadGeneration else { return }
                        let visibleIDs = Set(
                            contentFilter.filterSearchResults(
                                unique,
                                allowUpcomingContent: allowsUpcomingContent
                            ).map { $0.stableIdentity }
                        )
                        items.append(contentsOf: unique)
                        let addedVisibleItems = unique.contains { visibleIDs.contains($0.stableIdentity) }
                        // Empty-page detection must describe provider output,
                        // not the current filter result. A valid page containing
                        // titles that are still resolving dub/age metadata (or
                        // are excluded by the active filters) is not an empty
                        // provider page and must not consume the retry budget.
                        paginationCursor.didLoadPage(hasUniqueItems: true)
                        if addedVisibleItems { break }
                    } else {
                        paginationCursor.didLoadPage(hasUniqueItems: false)
                    }
                } catch {
                    guard generation == loadGeneration else { return }
                    Logger.shared.log("DiscoverDetailView: page \(requestedPage) failed: \(error.localizedDescription)", type: "Browse")
                    paginationError = "Couldn't load more results. Check your connection and try again."
                    isLoadingMore = false
                    return
                }
            }
            guard generation == loadGeneration else { return }
            isLoadingMore = false

            // The sentinel can be recreated while this page is still loading.
            // Its onAppear then sees isLoadingMore == true and is ignored. If it
            // remains in the viewport, explicitly request the next page now that
            // the current request has released the loading gate.
            if paginationSentinelVisible,
               paginationCursor.hasMorePages,
               paginationError == nil {
                DispatchQueue.main.async {
                    self.loadNextPage()
                }
            }
        }
    }
}
