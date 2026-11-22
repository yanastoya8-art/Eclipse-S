//
//  ScheduleViewModel.swift
//  Eclipse
//
//  Created by Soupy-dev
//

import Foundation

enum AnimeOriginalLanguagePolicy {
    // AniList exposes countryOfOrigin rather than an audio-language field.
    // Only map countries with a strong English/Spanish production-language signal.
    static func languageCode(forCountry country: String?) -> String? {
        switch country?.uppercased() {
        case "US", "GB", "AU", "NZ", "IE":
            return "en"
        case "ES", "MX", "AR", "CL", "CO", "PE", "VE", "UY", "BO", "PY",
             "CR", "PA", "GT", "HN", "SV", "NI", "DO", "CU", "EC", "PR":
            return "es"
        default:
            return nil
        }
    }
}

enum AnimeScheduleLanguageLookupPolicy {
    static func shouldFetchNativeLanguageSchedule(selectedLanguages: Set<String>) -> Bool {
        !selectedLanguages.isEmpty
    }

    static func nativeLanguageEntries(
        _ entries: [ScheduleEntry],
        selectedLanguages: Set<String>
    ) -> [ScheduleEntry] {
        entries.filter {
            ScheduleAudioLanguagePolicy.matches(
                originalLanguage: $0.originalLanguage,
                selectedLanguages: selectedLanguages
            )
        }.map { $0.markedAsNativeLanguageMatch() }
    }
}

enum AnimeScheduleProviderLanguagePolicy {
    /// Returns nil for providers whose eligibility is decided by the verified
    /// title-level dub index instead of a provider-specific language timetable.
    static func includes(
        provider: ScheduleProvider,
        originalLanguage: String?,
        selectedLanguages: Set<String>
    ) -> Bool? {
        switch provider {
        case .nativeLanguage:
            return ScheduleAudioLanguagePolicy.matches(
                originalLanguage: originalLanguage,
                selectedLanguages: selectedLanguages
            )
        case .aiSpanishDub:
            return selectedLanguages.contains(MyDubListLanguage.spanish.rawValue)
        case .dubOnly, .tsuzuki, .seaDub:
            return selectedLanguages.contains(MyDubListLanguage.english.rawValue)
        default:
            return nil
        }
    }
}

enum ScheduleMode: String, CaseIterable, Identifiable, Sendable {
    case anime
    case western
    case movies
    case combined

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anime:
            return "Anime"
        case .western:
            return "Series"
        case .movies:
            return "Movies"
        case .combined:
            return "Combined"
        }
    }

    var description: String? {
        switch self {
        case .anime:
            return nil
        case .western:
            return "Upcoming TV and streaming series episodes."
        case .movies:
            return "Upcoming non-anime movie releases, including selected dubbed-language dates."
        case .combined:
            return "Anime and series episodes together."
        }
    }

    static func sanitized(_ rawValue: String?) -> ScheduleMode {
        ScheduleMode(rawValue: rawValue ?? "") ?? .anime
    }

    static func sanitizedRawValue(_ rawValue: String?) -> String {
        sanitized(rawValue).rawValue
    }
}

enum ScheduleWindow: Int, CaseIterable, Identifiable, Sendable {
    case sevenDays = 7
    case fourteenDays = 14
    case twentyOneDays = 21
    case thirtyDays = 30

    static let storageKey = "scheduleWindowDays"
    static let defaultValue = ScheduleWindow.sevenDays

    var id: Int { rawValue }

    var displayName: String { "\(rawValue) Days" }

    var description: String {
        switch self {
        case .sevenDays:
            return "Default · Fastest loading"
        case .fourteenDays:
            return "Two weeks of upcoming episodes"
        case .twentyOneDays:
            return "Three weeks · More schedule data"
        case .thirtyDays:
            return "Longest range · Heaviest loading"
        }
    }

    static func sanitized(_ rawValue: Int?) -> ScheduleWindow {
        ScheduleWindow(rawValue: rawValue ?? 0) ?? defaultValue
    }

    static func sanitizedDays(_ rawValue: Int?) -> Int {
        sanitized(rawValue).rawValue
    }

    static var current: ScheduleWindow {
        sanitized(ProfileSettingsStore.active.object(forKey: storageKey) as? Int)
    }
}

enum ScheduleDateWindow {
    static func envelope(dayCount: Int, now: Date = Date(), localCalendar: Calendar = AppCalendar.current) -> DateInterval {
        let localCalendar = AppCalendar.gregorian(matching: localCalendar)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? localCalendar.timeZone
        let days = min(max(dayCount, 1), 366)
        let localStart = localCalendar.startOfDay(for: now)
        let utcStart = utc.startOfDay(for: now)
        let localEnd = localCalendar.date(byAdding: .day, value: days, to: localStart) ?? localStart
        let utcEnd = utc.date(byAdding: .day, value: days, to: utcStart) ?? utcStart
        return DateInterval(start: min(localStart, utcStart), end: max(localEnd, utcEnd))
    }
}

enum ScheduleProvider: String, Codable, Sendable {
    case aniList
    case animeSchedule
    case dubOnly
    case tsuzuki
    case seaDub
    case nativeLanguage
    case trakt
    case traktMovie
    case tvMaze
    case aiSpanishDub

    func metadataCacheKey(mediaID: Int, tmdbID: Int?, entryID: String) -> String {
        if let tmdbID, tmdbID > 0 {
            return rawValue == "traktMovie" ? "tmdb-movie-\(tmdbID)" : "tmdb-tv-\(tmdbID)"
        }
        return mediaID > 0 ? "\(rawValue)-\(mediaID)" : "\(rawValue)-entry-\(entryID)"
    }
}

enum ScheduleSource: Hashable, Sendable {
    case anime
    case western

    var displayName: String {
        switch self {
        case .anime:
            return "Anime"
        case .western:
            return "Series"
        }
    }
}

struct NotificationScheduleSnapshot {
    let entries: [ScheduleEntry]
    let dayCount: Int
    let successfulSources: Set<ScheduleSource>
    let authoritativeSources: Set<ScheduleSource>
}

private struct ScheduleLoadResult {
    let entries: [ScheduleEntry]
    let successfulSources: Set<ScheduleSource>
    let authoritativeSources: Set<ScheduleSource>
}

private struct AnimeScheduleLoadResult {
    let entries: [ScheduleEntry]
    let isAuthoritativeForNotifications: Bool
    var notice: String? = nil
}

private enum ScheduleSourceLoadError: LocalizedError {
    case retryDeferred(String)
    case languageMetadataUnavailable

    var errorDescription: String? {
        switch self {
        case .retryDeferred(let sourceName):
            return "\(sourceName) schedule refresh is waiting briefly after a provider failure."
        case .languageMetadataUnavailable:
            return "The selected dub-language data could not be verified. Check your connection and try again."
        }
    }
}

struct ScheduleEntry: Identifiable, Sendable {
    let id: String
    let source: ScheduleSource
    var provider: ScheduleProvider
    let sourceMediaId: Int
    let title: String
    var airingAt: Date
    let episode: Int
    let season: Int?
    var coverImage: String?
    let englishTitle: String?
    let romajiTitle: String?
    let nativeTitle: String?
    let format: String?
    let overview: String?
    let metadataTags: [String]
    var hasKnownAiringTime: Bool
    var isStreamingRelease: Bool
    let tmdbId: Int?
    var originalLanguage: String?
    var scheduleSourceURL: String? = nil
    let releaseYear: Int?
    var runtimeMinutes: Int?
    var productionCompanyNames: [String] = []
    var productionMetadataChecked = false
    let animeMALID: Int?
    let airingTimeWithdrawn: Bool
    let isMovie: Bool

    var animeMediaIDs: Set<Int> {
        guard source == .anime else { return [] }
        var ids: Set<Int> = sourceMediaId == 0 ? [] : [sourceMediaId]
        if let animeMALID, animeMALID > 0 { ids.insert(-animeMALID) }
        return ids
    }

    func isSameEpisode(as other: ScheduleEntry) -> Bool {
        guard source == other.source, episode == other.episode else { return false }
        if source == .anime { return !animeMediaIDs.isDisjoint(with: other.animeMediaIDs) }
        return id == other.id
    }

    init(animeEntry: AniListAiringScheduleEntry) {
        id = "anime-media-\(animeEntry.mediaId)-episode-\(animeEntry.episode)"
        source = .anime
        provider = animeEntry.scheduleProvider ?? .aniList
        sourceMediaId = animeEntry.mediaId
        title = animeEntry.title
        airingAt = animeEntry.airingAt
        episode = animeEntry.episode
        season = nil
        coverImage = animeEntry.coverImage
        englishTitle = animeEntry.englishTitle
        romajiTitle = animeEntry.romajiTitle
        nativeTitle = animeEntry.nativeTitle
        format = animeEntry.format
        overview = nil
        metadataTags = animeEntry.tags ?? []
        hasKnownAiringTime = animeEntry.hasKnownAiringTime
        isStreamingRelease = false
        tmdbId = nil
        animeMALID = animeEntry.malID
        airingTimeWithdrawn = animeEntry.airingTimeWithdrawn == true
        originalLanguage = animeEntry.originalLanguage
        releaseYear = animeEntry.releaseYear
        runtimeMinutes = animeEntry.runtimeMinutes
        scheduleSourceURL = animeEntry.sourceURL
        isMovie = false
    }

    fileprivate init(westernEpisode: TVMazeScheduleEpisode, airing: TVMazeAiringInfo) {
        animeMALID = nil
        airingTimeWithdrawn = false
        id = "western-\(westernEpisode.id)"
        source = .western
        provider = .tvMaze
        sourceMediaId = westernEpisode.show.id
        title = westernEpisode.show.name
        airingAt = airing.date
        episode = westernEpisode.number ?? 0
        season = westernEpisode.season
        coverImage = westernEpisode.show.image?.medium ?? westernEpisode.show.image?.original
        englishTitle = westernEpisode.show.name
        romajiTitle = nil
        nativeTitle = nil
        format = nil
        overview = westernEpisode.show.summary
        metadataTags = [westernEpisode.show.network?.name, westernEpisode.show.webChannel?.name]
            .compactMap { $0 }
        hasKnownAiringTime = airing.hasKnownAiringTime
        isStreamingRelease = westernEpisode.show.webChannel != nil
        tmdbId = nil
        originalLanguage = westernEpisode.show.isoLanguageCode
        releaseYear = westernEpisode.show.releaseYear
        runtimeMinutes = westernEpisode.runtime
        isMovie = false
    }

    fileprivate init(traktItem: TraktCalendarItem, airingAt: Date, tmdbDetail: TMDBTVShowDetail?) {
        animeMALID = nil
        airingTimeWithdrawn = false
        let showId = traktItem.show.ids.trakt ?? traktItem.show.ids.tmdb ?? 0
        let episodeId = traktItem.episode.ids?.trakt ?? 0
        let seasonNumber = traktItem.episode.season ?? 0
        let episodeNumber = traktItem.episode.number ?? 0
        id = "trakt-\(showId)-\(seasonNumber)-\(episodeNumber)-\(episodeId)-\(traktItem.firstAired)"
        source = .western
        provider = .trakt
        sourceMediaId = showId
        title = traktItem.show.title
        self.airingAt = airingAt
        episode = episodeNumber
        season = seasonNumber
        coverImage = tmdbDetail?.fullPosterURL
        englishTitle = traktItem.show.title
        romajiTitle = nil
        nativeTitle = nil
        format = nil
        overview = tmdbDetail?.overview
        metadataTags = tmdbDetail?.productionCompanies?.map(\.name) ?? []
        hasKnownAiringTime = true
        isStreamingRelease = false
        tmdbId = traktItem.show.ids.tmdb
        originalLanguage = traktItem.show.language?.lowercased()
        releaseYear = traktItem.show.year
        runtimeMinutes = traktItem.episode.runtime
        isMovie = false
    }

    fileprivate init(traktMovieItem: TraktMovieCalendarItem, releaseDate: Date) {
        animeMALID = nil
        airingTimeWithdrawn = false
        let movie = traktMovieItem.movie
        let stableID = movie.ids.tmdb ?? movie.ids.trakt ?? 0
        id = "trakt-movie-\(stableID)-\(movie.year ?? 0)"
        source = .western
        provider = .traktMovie
        sourceMediaId = stableID
        title = movie.title
        airingAt = releaseDate
        episode = 0
        season = nil
        coverImage = nil
        englishTitle = movie.title
        romajiTitle = nil
        nativeTitle = nil
        format = "MOVIE"
        overview = nil
        metadataTags = []
        hasKnownAiringTime = false
        isStreamingRelease = false
        tmdbId = movie.ids.tmdb
        originalLanguage = movie.primaryLanguageCode?.lowercased()
        releaseYear = movie.year
        runtimeMinutes = movie.runtime
        isMovie = true
    }

    fileprivate init(tmdbUpcomingMovie movie: TMDBMovie, releaseDate: Date) {
        animeMALID = nil
        airingTimeWithdrawn = false
        id = "tmdb-upcoming-movie-\(movie.id)-\(movie.releaseDate ?? "")"
        source = .western
        provider = .traktMovie
        sourceMediaId = movie.id
        title = movie.title
        airingAt = releaseDate
        episode = 0
        season = nil
        coverImage = movie.fullPosterURL
        englishTitle = movie.title
        romajiTitle = nil
        nativeTitle = nil
        format = "MOVIE"
        overview = movie.overview
        metadataTags = []
        hasKnownAiringTime = false
        isStreamingRelease = false
        tmdbId = movie.id
        originalLanguage = movie.originalLanguage?.lowercased()
        releaseYear = Calendar(identifier: .gregorian).component(.year, from: releaseDate)
        runtimeMinutes = nil
        isMovie = true
    }

    func withAiringAt(_ date: Date, isStreamingRelease: Bool) -> ScheduleEntry {
        var copy = self
        copy.airingAt = date
        copy.isStreamingRelease = isStreamingRelease
        if isStreamingRelease { copy.hasKnownAiringTime = false }
        return copy
    }

    func markedAsNativeLanguageMatch() -> ScheduleEntry {
        var copy = self
        copy.provider = .nativeLanguage
        return copy
    }
}

enum ScheduleEntryMergePolicy {
    static func earliestByEpisode(_ entries: [ScheduleEntry]) -> [ScheduleEntry] {
        var merged: [ScheduleEntry] = []
        var animeAliasIndices: [String: Int] = [:]
        var nonAnimeIndices: [String: Int] = [:]

        for entry in entries {
            if entry.source == .anime {
                let aliases = entry.animeMediaIDs.map { "anime|\($0)|\(entry.episode)" }
                let matchingIndices = Set(aliases.compactMap { animeAliasIndices[$0] })
                guard let targetIndex = matchingIndices.min() else {
                    let index = merged.count
                    merged.append(entry)
                    for alias in aliases { animeAliasIndices[alias] = index }
                    continue
                }

                var preferred = merged[targetIndex]
                if shouldPrefer(entry, over: preferred) { preferred = entry }

                // An entry carrying both AniList and MAL IDs can bridge two
                // earlier rows that were initially known under only one ID.
                // Collapse those rows too, preserving the best confirmed date.
                for removedIndex in matchingIndices.sorted(by: >) where removedIndex != targetIndex {
                    let existing = merged[removedIndex]
                    if shouldPrefer(existing, over: preferred) { preferred = existing }
                    merged.remove(at: removedIndex)

                    for key in Array(animeAliasIndices.keys) {
                        guard let index = animeAliasIndices[key] else { continue }
                        if index == removedIndex {
                            animeAliasIndices[key] = targetIndex
                        } else if index > removedIndex {
                            animeAliasIndices[key] = index - 1
                        }
                    }
                    for key in Array(nonAnimeIndices.keys) {
                        guard let index = nonAnimeIndices[key], index > removedIndex else { continue }
                        nonAnimeIndices[key] = index - 1
                    }
                }

                merged[targetIndex] = preferred
                for alias in aliases { animeAliasIndices[alias] = targetIndex }
            } else {
                let key = [
                    entry.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
                    String(entry.season ?? 0),
                    String(entry.episode)
                ].joined(separator: "|")
                if let index = nonAnimeIndices[key] {
                    if shouldPrefer(entry, over: merged[index]) { merged[index] = entry }
                } else {
                    let index = merged.count
                    merged.append(entry)
                    nonAnimeIndices[key] = index
                }
            }
        }

        return merged.sorted { $0.airingAt < $1.airingAt }
    }

    private static func shouldPrefer(_ candidate: ScheduleEntry, over existing: ScheduleEntry) -> Bool {
        ScheduleReleaseDatePolicy.shouldPrefer(
            candidateDate: candidate.airingAt,
            candidateIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                provider: candidate.provider,
                hasKnownAiringTime: candidate.hasKnownAiringTime,
                airingTimeWithdrawn: candidate.airingTimeWithdrawn
            ),
            over: existing.airingAt,
            existingIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                provider: existing.provider,
                hasKnownAiringTime: existing.hasKnownAiringTime,
                airingTimeWithdrawn: existing.airingTimeWithdrawn
            )
        )
    }
}

final class ScheduleViewModel: ObservableObject {
    static let shared = ScheduleViewModel()

    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published private(set) var scheduleNotice: String?
    @Published var scheduleEntries: [ScheduleEntry] = [] {
        didSet { scheduleEntriesRevision &+= 1 }
    }

    @Published private(set) var scheduleEntriesRevision = 0
    @Published var dayBuckets: [DayBucket] = []
    @Published var currentDayAnchor = Date()
    private(set) var loadedScheduleMode: ScheduleMode?
    private(set) var loadedScheduleDayCount: Int?

    private let scheduleCacheMaxAge: TimeInterval = 6 * 60 * 60
    private let animeAuthoritativeRetryInterval: TimeInterval = 15 * 60
    private let failedSourceRetryInterval: TimeInterval = 60
    private var animeScheduleResult: AnimeScheduleLoadResult?
    private var animeScheduleFetchedAt: Date?
    private var animeScheduleDayCount = 0
    private var animeScheduleLastAttemptAt: Date?
    private var animeScheduleLastFailureAt: Date?
    private var animeScheduleLoadTask: Task<AnimeScheduleLoadResult, Error>?
    private var spanishDubResearchTask: Task<Void, Never>?
    private var animeScheduleLoadID: UUID?
    private var animeScheduleCachedPolicyKey: String?
    private var animeScheduleLoadPolicyKey: String?
    private var animeScheduleLastFailurePolicyKey: String?
    private var westernScheduleEntries: [ScheduleEntry]?
    private var westernScheduleFetchedAt: Date?
    private var westernScheduleDayCount = 0
    private var westernScheduleLastAttemptAt: Date?
    private var westernScheduleLastFailureAt: Date?
    private var westernScheduleLoadTask: Task<[ScheduleEntry], Error>?
    private var westernScheduleLoadID: UUID?
    private var movieScheduleEntries: [ScheduleEntry]?
    private var movieScheduleFetchedAt: Date?
    private var movieScheduleDayCount = 0
    private var movieScheduleLastFailureAt: Date?
    private var activeLoadID: UUID?
    private var activeLoadMode: ScheduleMode?
    private var activeLoadDayCount: Int?
    private var activePosterHydrationID: UUID?
    private var posterHydrationTask: Task<Void, Never>?
    private var posterHydrationAttemptedTMDBIDs = Set<Int>()
    private var moviePosterHydrationAttemptedTMDBIDs = Set<Int>()
    private var currentLocalTimeZone = true
    private var dailyCalendarRefreshInProgress = false

    init() {}

    /// Refreshes the visible calendar once per local day, retrying failures
    /// after a cooldown. iOS may suspend background work, so execution time
    /// remains controlled by the operating system.
    @MainActor
    func refreshCalendarIfNeeded(now: Date = Date()) async -> Bool {
        guard !dailyCalendarRefreshInProgress else { return true }
        let defaults = UserDefaults.standard
        let successKey = "animeCalendarLastAutomaticRefreshSuccessV1"
        let attemptKey = "animeCalendarLastAutomaticRefreshAttemptV1"
        let lastSuccess = defaults.object(forKey: successKey) as? Date
        let lastAttempt = defaults.object(forKey: attemptKey) as? Date
        guard DailyScheduleRefreshPolicy.shouldRefresh(
            now: now,
            lastSuccessfulRefresh: lastSuccess,
            lastAttempt: lastAttempt
        ) else {
            return true
        }

        dailyCalendarRefreshInProgress = true
        defer { dailyCalendarRefreshInProgress = false }
        defaults.set(now, forKey: attemptKey)
        let revisionBeforeRefresh = scheduleEntriesRevision
        let mode = loadedScheduleMode ?? .anime
        let requiredSources: Set<ScheduleSource> = [.anime, .western]
        await MyDubListDubFilter.shared.refresh()
        let refreshedSnapshot = await notificationScheduleSnapshot(
            dayCount: ScheduleWindow.current.rawValue,
            requiredSources: requiredSources,
            forceRefreshSources: requiredSources
        )
        if mode == .movies {
            _ = try? await movieEntries(dayCount: ScheduleWindow.current.rawValue, forceRefresh: true)
        }
        await loadSchedule(
            mode: mode,
            localTimeZone: currentLocalTimeZone,
            forceRefresh: false
        )

        let allSourcesAvailable = refreshedSnapshot.successfulSources.isSuperset(of: requiredSources)
        let didPublishFreshSchedule = allSourcesAvailable
            && scheduleEntriesRevision != revisionBeforeRefresh
            && !isLoading
            && errorMessage == nil
        if didPublishFreshSchedule {
            defaults.set(now, forKey: successKey)
            Logger.shared.log(
                "Schedule calendar: completed daily automatic refresh for anime and western sources",
                type: "Anime"
            )
            return true
        }

        let missingSources = requiredSources.subtracting(refreshedSnapshot.successfulSources)
            .map(\.displayName)
            .sorted()
            .joined(separator: ", ")
        let reason = errorMessage
            ?? (missingSources.isEmpty ? "No fresh schedule was published." : "Unavailable sources: \(missingSources).")
        Logger.shared.log(
            "Schedule calendar: automatic refresh failed; it will retry after the cooldown. \(reason)",
            type: "Anime"
        )
        return false
    }

    func loadSchedule(
        mode: ScheduleMode,
        localTimeZone: Bool,
        forceRefresh: Bool = false
    ) async {
        let requestedDayCount = ScheduleWindow.current.rawValue
        let loadID = UUID()
        let shouldStart = await MainActor.run { () -> Bool in
            if !forceRefresh,
               activeLoadID != nil,
               activeLoadMode == mode,
               activeLoadDayCount == requestedDayCount {
                return false
            }
            posterHydrationTask?.cancel()
            posterHydrationTask = nil
            activePosterHydrationID = nil
            activeLoadID = loadID
            activeLoadMode = mode
            activeLoadDayCount = requestedDayCount
            currentLocalTimeZone = localTimeZone
            if mode == .anime || mode == .combined {
                let activeAnimePolicyKey = currentAnimeSchedulePolicyKey()
                if animeScheduleCachedPolicyKey != activeAnimePolicyKey {
                    // Do not leave an old AniList broadcast list visible while a
                    // newly selected dubbed-language policy is being resolved.
                    scheduleEntries.removeAll { $0.source == .anime }
                    updateBuckets(
                        with: scheduleEntries,
                        localTimeZone: localTimeZone,
                        dayCount: requestedDayCount
                    )
                }
            }
            if forceRefresh {
                posterHydrationAttemptedTMDBIDs.removeAll(keepingCapacity: true)
                moviePosterHydrationAttemptedTMDBIDs.removeAll(keepingCapacity: true)
                tmdbCache.removeAll(keepingCapacity: true)
                tmdbCacheGeneration = UUID()
            }
            isLoading = true
            errorMessage = nil
            scheduleNotice = nil
            return true
        }
        guard shouldStart else { return }

        do {
            let loadResult = try await entries(
                for: mode,
                dayCount: requestedDayCount,
                forceRefresh: forceRefresh
            )
            // Resolve the same runtime and production-company metadata used by
            // Home and Browse before publishing any schedule provider's rows.
            let preparedScheduleEntries = await applyShortRuntimeScheduleFilter(loadResult.entries)
            // Populate schedule-specific age metadata before evaluating the
            // exclusion predicate. Without this call the predicate only sees
            // cached ratings and silently misses MAL-only anime and TVMaze rows.
            await TMDBContentFilter.shared.prepareScheduleAgeRatings(for: preparedScheduleEntries)
            let hideUnofficialContent = UserDefaults.standard.bool(forKey: "catalogHideUnofficialContent")
            let entries = preparedScheduleEntries.filter { entry in
                // Enforce age exclusions before publishing the new schedule
                // snapshot. ScheduleView also refreshes its visible filter state,
                // but doing the policy here prevents a new page of all-ages or
                // below-minimum entries from appearing during that async refresh.
                guard !TMDBContentFilter.shared.scheduleEntryIsBlockedByConfiguredAgeFilter(entry) else {
                    return false
                }
                guard hideUnofficialContent else { return true }
                // Anime schedule providers include production/category tags.
                // Include them (and the episode's format/overview) in the same
                // policy used by Home and Browse; title-only checks miss fan
                // productions whose title does not identify their origin.
                if entry.tmdbId != nil && !entry.productionMetadataChecked { return false }
                let searchableMetadata = [
                    entry.title,
                    entry.englishTitle,
                    entry.romajiTitle,
                    entry.nativeTitle,
                    entry.format
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                    + " " + entry.metadataTags.joined(separator: " ")
                return !TMDBContentFilter.isUnofficialCreatorContent(
                    title: searchableMetadata,
                    overview: entry.overview,
                    productionCompanies: entry.productionCompanyNames
                )
            }
            let didPublish = await MainActor.run { () -> Bool in
                guard activeLoadID == loadID else { return false }
                activeLoadID = nil
                activeLoadMode = nil
                activeLoadDayCount = nil
                isLoading = false
                scheduleEntries = entries
                scheduleNotice = (mode == .western || mode == .movies) ? nil : animeScheduleResult?.notice
                loadedScheduleMode = mode
                loadedScheduleDayCount = requestedDayCount
                currentDayAnchor = Date()
                updateBuckets(
                    with: entries,
                    localTimeZone: localTimeZone,
                    dayCount: requestedDayCount
                )
                startPosterHydrationIfNeeded(for: entries, loadID: loadID)
                return true
            }
            guard didPublish else { return }
#if os(iOS) || os(macOS)
            if mode != .movies {
                await LocalNotificationManager.shared.reconcileScheduleEntries(
                    entries,
                    successfulSources: loadResult.successfulSources,
                    authoritativeSources: loadResult.authoritativeSources,
                    coveredDayCount: requestedDayCount
                )
            }
#endif
        } catch {
            if Self.isIntentionalCancellation(error) {
                await MainActor.run {
                    guard activeLoadID == loadID else { return }
                    activeLoadID = nil
                    activeLoadMode = nil
                    activeLoadDayCount = nil
                    isLoading = false
                }
                return
            }
            await MainActor.run {
                guard activeLoadID == loadID else { return }
                activeLoadID = nil
                activeLoadMode = nil
                activeLoadDayCount = nil
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    func notificationScheduleSnapshot(
        dayCount: Int,
        requiredSources: Set<ScheduleSource> = [.anime, .western],
        forceRefreshSources: Set<ScheduleSource> = [],
        requireAuthoritativeSources: Set<ScheduleSource> = []
    ) async -> NotificationScheduleSnapshot {

        let requestedDayCount = ScheduleWindow.sanitizedDays(dayCount)
        let needsAuthoritativeAnime = requireAuthoritativeSources.contains(.anime)
            && animeScheduleResult?.isAuthoritativeForNotifications != true
        let now = Date()
        let authoritativeRetryIsDue: Bool
        if animeScheduleResult == nil {
            authoritativeRetryIsDue = animeScheduleLastFailureAt.map {
                let elapsed = now.timeIntervalSince($0)
                return elapsed < 0 || elapsed >= failedSourceRetryInterval
            } ?? true
        } else {
            authoritativeRetryIsDue = animeScheduleLastAttemptAt.map {
                let elapsed = now.timeIntervalSince($0)
                return elapsed < 0 || elapsed >= animeAuthoritativeRetryInterval
            } ?? true
        }
        let forceAnime = forceRefreshSources.contains(.anime)
            || (needsAuthoritativeAnime && authoritativeRetryIsDue)

        async let animeLoad: Void = loadAnimeSnapshotSource(
            required: requiredSources.contains(.anime),
            dayCount: requestedDayCount,
            forceRefresh: forceAnime
        )
        async let westernLoad: Void = loadWesternSnapshotSource(
            required: requiredSources.contains(.western),
            dayCount: requestedDayCount,
            forceRefresh: forceRefreshSources.contains(.western)
        )
        _ = await (animeLoad, westernLoad)

        var entries: [ScheduleEntry] = []
        var successfulSources = Set<ScheduleSource>()
        var authoritativeSources = Set<ScheduleSource>()

        if scheduleCacheIsFresh(
            animeScheduleFetchedAt,
            cachedDayCount: animeScheduleDayCount,
            requiredDayCount: requestedDayCount
        ), let animeResult = cachedAnimeResult(for: requestedDayCount) {
            let filteredAnimeResult = filteredAnimeScheduleResult(animeResult)
            entries.append(contentsOf: filteredAnimeResult.entries)
            successfulSources.insert(.anime)
            if filteredAnimeResult.isAuthoritativeForNotifications {
                authoritativeSources.insert(.anime)
            }
        }
        if scheduleCacheIsFresh(
            westernScheduleFetchedAt,
            cachedDayCount: westernScheduleDayCount,
            requiredDayCount: requestedDayCount
        ), let westernEntries = cachedWesternEntries(for: requestedDayCount) {
            entries.append(contentsOf: westernEntries)
            successfulSources.insert(.western)
            authoritativeSources.insert(.western)
        }

        return NotificationScheduleSnapshot(
            entries: entries.sorted { $0.airingAt < $1.airingAt },
            dayCount: requestedDayCount,
            successfulSources: successfulSources,
            authoritativeSources: authoritativeSources
        )
    }

    @MainActor
    private func loadAnimeSnapshotSource(required: Bool, dayCount: Int, forceRefresh: Bool) async {
        guard required else { return }
        _ = try? await animeEntries(dayCount: dayCount, forceRefresh: forceRefresh)
    }

    @MainActor
    private func loadWesternSnapshotSource(required: Bool, dayCount: Int, forceRefresh: Bool) async {
        guard required else { return }
        _ = try? await westernEntries(dayCount: dayCount, forceRefresh: forceRefresh)
    }

    @MainActor
    private func entries(
        for mode: ScheduleMode,
        dayCount: Int,
        forceRefresh: Bool
    ) async throws -> ScheduleLoadResult {
        switch mode {
        case .anime:
            let result = try await animeEntries(dayCount: dayCount, forceRefresh: forceRefresh)
            return ScheduleLoadResult(
                entries: result.entries,
                successfulSources: [.anime],
                authoritativeSources: result.isAuthoritativeForNotifications ? [.anime] : []
            )
        case .western:
            return ScheduleLoadResult(
                entries: try await westernEntries(dayCount: dayCount, forceRefresh: forceRefresh),
                successfulSources: [.western],
                authoritativeSources: [.western]
            )
        case .movies:
            return ScheduleLoadResult(
                entries: try await movieEntries(dayCount: dayCount, forceRefresh: forceRefresh),
                successfulSources: [],
                authoritativeSources: []
            )
        case .combined:
            async let animeResult = scheduleSourceResult {
                try await self.animeEntries(dayCount: dayCount, forceRefresh: forceRefresh)
            }
            async let westernResult = scheduleSourceResult {
                try await self.westernEntries(dayCount: dayCount, forceRefresh: forceRefresh)
            }

            let sourceResults = await (animeResult, westernResult)
            var combinedEntries: [ScheduleEntry] = []
            var firstError: Error?
            var successfulSources = Set<ScheduleSource>()
            var authoritativeSources = Set<ScheduleSource>()
            var loadedAnySource = false

            switch sourceResults.0 {
            case .success(let result):
                combinedEntries += result.entries
                loadedAnySource = true
                successfulSources.insert(.anime)
                if result.isAuthoritativeForNotifications {
                    authoritativeSources.insert(.anime)
                }
            case .failure(let error):
                if Self.isIntentionalCancellation(error) {
                    throw CancellationError()
                }
                firstError = error
            }

            switch sourceResults.1 {
            case .success(let entries):
                combinedEntries += entries
                loadedAnySource = true
                successfulSources.insert(.western)
                authoritativeSources.insert(.western)
            case .failure(let error):
                if Self.isIntentionalCancellation(error) {
                    throw CancellationError()
                }
                firstError = firstError ?? error
            }

            if !loadedAnySource, let firstError {
                throw firstError
            }
            return ScheduleLoadResult(
                entries: combinedEntries,
                successfulSources: successfulSources,
                authoritativeSources: authoritativeSources
            )
        }
    }

    @MainActor
    private func scheduleSourceResult<Value>(
        operation: () async throws -> Value
    ) async -> Result<Value, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func preparedFilteredAnimeScheduleResult(
        _ result: AnimeScheduleLoadResult
    ) async -> AnimeScheduleLoadResult {
        // Resolve age metadata before the configured minimum-age gate runs.
        // Without this step, every dubbed-provider entry with an unknown age
        // rating was removed from Schedule even though its dub date was valid.
        await TMDBContentFilter.shared.prepareScheduleAgeRatings(for: result.entries)
        return filteredAnimeScheduleResult(result)
    }

    private func filteredAnimeScheduleResult(_ result: AnimeScheduleLoadResult) -> AnimeScheduleLoadResult {
        let selectedLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
        let hideAnimeSpecials = UserDefaults.standard.bool(forKey: "catalogHideAnimeSpecialsAndOVAs")

        let entries = result.entries.filter { entry in
            guard entry.source == .anime else { return true }
            guard !AnimeSpecialFormatPolicy.shouldExclude(format: entry.format, enabled: hideAnimeSpecials) else {
                return false
            }

            let searchableTitle = [
                entry.title, entry.englishTitle, entry.romajiTitle, entry.nativeTitle
            ].compactMap { $0 }.joined(separator: " ")
            // Apply the same anime category/runtime/era exclusions used by
            // Browse before publishing the calendar. Previously the schedule
            // only applied dub availability and special-format filters, so
            // enabling these catalog filters left incompatible anime visible.
            guard !TMDBContentFilter.shouldExcludeAnimeCategory(
                title: searchableTitle,
                overview: entry.overview,
                tags: entry.metadataTags
            ) else { return false }
            if UserDefaults.standard.bool(forKey: "catalogHidePre1994Anime"),
               let year = entry.releaseYear, year < 1994 {
                return false
            }
            if UserDefaults.standard.bool(forKey: "catalogHideUnder20MinuteContent") {
                guard CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: entry.runtimeMinutes) else { return false }
            }

            // With no dub-language filter selected, preserve the existing
            // schedule behavior while still applying the independent
            // specials/OVAs preference above.
            guard !selectedLanguages.isEmpty else { return true }
            // Provider-specific timetable rows must match the selected
            // language themselves. In particular, a Spanish AI/native row
            // must never leak into an English-only calendar (or vice versa).
            if let providerMatch = AnimeScheduleProviderLanguagePolicy.includes(
                provider: entry.provider,
                originalLanguage: entry.originalLanguage,
                selectedLanguages: selectedLanguages
            ) {
                return providerMatch
            }
            let anilistID = entry.sourceMediaId > 0 ? entry.sourceMediaId : nil
            let malID = entry.animeMALID ?? (entry.sourceMediaId < 0 ? -entry.sourceMediaId : nil)
            return MyDubListDubFilter.shared.shouldInclude(
                anilistID: anilistID,
                malID: malID
            )
        }
        return AnimeScheduleLoadResult(
            entries: entries,
            isAuthoritativeForNotifications: result.isAuthoritativeForNotifications,
            notice: result.notice
        )
    }

    @MainActor
    private func scheduleEntryPassesConfiguredFilters(_ entry: ScheduleEntry) -> Bool {
        guard !TMDBContentFilter.shared.scheduleEntryIsBlockedByConfiguredAgeFilter(entry) else {
            return false
        }
        guard UserDefaults.standard.bool(forKey: "catalogHideUnofficialContent") else {
            return true
        }
        if entry.tmdbId != nil && !entry.productionMetadataChecked { return false }
        let searchableMetadata = [
            entry.title,
            entry.englishTitle,
            entry.romajiTitle,
            entry.nativeTitle,
            entry.format
        ]
        .compactMap { $0 }
        .joined(separator: " ")
            + " " + entry.metadataTags.joined(separator: " ")
        return !TMDBContentFilter.isUnofficialCreatorContent(
            title: searchableMetadata,
            overview: entry.overview,
            productionCompanies: entry.productionCompanyNames
        )
    }

    @MainActor
    private func mergeSpanishDubResearchEntries(
        _ additions: [ScheduleEntry],
        into currentResult: AnimeScheduleLoadResult,
        dayCount: Int
    ) async {
        guard !additions.isEmpty else { return }

        // Merge by shared AniList/MAL identity so fallback rows cannot
        // duplicate an episode merely because the providers use different IDs.
        let mergedEntries = ScheduleEntryMergePolicy.earliestByEpisode(currentResult.entries + additions)

        // Spanish research runs after the first calendar paint. Re-run the
        // complete anime policy (language, specials/OVAs, categories, era and
        // runtime) against the merged raw snapshot, then resolve ratings and
        // reapply age/unofficial filters before publishing. Otherwise this
        // late merge can reintroduce entries excluded by the initial load.
        let mergedResult = AnimeScheduleLoadResult(
            entries: mergedEntries,
            isAuthoritativeForNotifications: currentResult.isAuthoritativeForNotifications,
            notice: currentResult.notice
        )
        let filteredResult = filteredAnimeScheduleResult(mergedResult)
        await TMDBContentFilter.shared.prepareScheduleAgeRatings(for: filteredResult.entries)
        let visibleAnimeEntries = filteredResult.entries.filter {
            scheduleEntryPassesConfiguredFilters($0)
        }
        animeScheduleResult = mergedResult

        guard loadedScheduleMode == .anime || loadedScheduleMode == .combined else { return }
        let nonAnimeEntries = scheduleEntries.filter {
            $0.source != .anime && scheduleEntryPassesConfiguredFilters($0)
        }
        scheduleEntries = (visibleAnimeEntries + nonAnimeEntries).sorted { $0.airingAt < $1.airingAt }
        updateBuckets(
            with: scheduleEntries,
            localTimeZone: currentLocalTimeZone,
            dayCount: dayCount
        )
    }

    private func dubOnlyUnavailable(_ result: AnimeAiringScheduleResult) -> Bool {
        result.entries.isEmpty
    }

    @MainActor
    private func currentAnimeSchedulePolicyKey() -> String {
        let languages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement.sorted().joined(separator: ",")
        let audioFilter = UserDefaults.standard.bool(forKey: "catalogRequireEnglishSpanishAudio")
        return "languages=\(languages)|englishSpanishAudio=\(audioFilter)"
    }

    @MainActor
    private func animeEntries(dayCount: Int, forceRefresh: Bool) async throws -> AnimeScheduleLoadResult {
        // Verified timetable/native-language rows do not depend on MyDubList.
        // Never block a cached calendar or healthy independent providers on an
        // unrelated title index. Unverified rows still fail the language filter.
        _ = MyDubListDubFilter.shared.prepareCachedSnapshot()
        let policyKey = currentAnimeSchedulePolicyKey()
        if animeScheduleLoadTask != nil, animeScheduleLoadPolicyKey != policyKey {
            // A language-filter change invalidates an in-flight request too;
            // never publish an AniList snapshot into a DubOnly-filtered view.
            animeScheduleLoadTask?.cancel()
            animeScheduleLoadTask = nil
            animeScheduleLoadID = nil
            animeScheduleLoadPolicyKey = nil
        }
        if !forceRefresh, animeScheduleCachedPolicyKey == policyKey,
           scheduleCacheIsFresh(
                animeScheduleFetchedAt,
                cachedDayCount: animeScheduleDayCount,
                requiredDayCount: dayCount
           ),
           let cached = cachedAnimeResult(for: dayCount) {
            return await preparedFilteredAnimeScheduleResult(cached)
        }
        if let animeScheduleLoadTask, animeScheduleLoadPolicyKey == policyKey {
            _ = try await animeScheduleLoadTask.value
            if animeScheduleCachedPolicyKey == policyKey,
               let cached = cachedAnimeResult(for: dayCount),
               scheduleCacheIsFresh(
                    animeScheduleFetchedAt,
                    cachedDayCount: animeScheduleDayCount,
                    requiredDayCount: dayCount
               ) {
                return filteredAnimeScheduleResult(cached)
            }

            return try await animeEntries(dayCount: dayCount, forceRefresh: forceRefresh)
        }

        if !forceRefresh,
           animeScheduleLastFailurePolicyKey == policyKey,
           retryIsCoolingDown(since: animeScheduleLastFailureAt) {
            throw ScheduleSourceLoadError.retryDeferred(ScheduleSource.anime.displayName)
        }

        let loadID = UUID()
        let fetchStartedAt = Date()
        animeScheduleLoadPolicyKey = policyKey
        animeScheduleLastAttemptAt = fetchStartedAt
        let loadTask = Task { @MainActor [weak self] () throws -> AnimeScheduleLoadResult in
            guard let self else { throw CancellationError() }
            do {
                let selectedDubLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
                let englishSpanishAudioFilterEnabled = UserDefaults.standard.bool(forKey: "catalogRequireEnglishSpanishAudio")
                let requiresDubSchedule = AnimeScheduleFallback.requiresDubSchedule(
                    selectedDubLanguages: selectedDubLanguages,
                    englishSpanishAudioFilterEnabled: englishSpanishAudioFilterEnabled
                )
                let result: AnimeAiringScheduleResult
                var verifiedNativeLanguageEntries: [ScheduleEntry] = []
                let permitsEnglishDubSchedule = AnimeScheduleFallback.permitsEnglishDubSchedule(
                    selectedDubLanguages: selectedDubLanguages,
                    englishSpanishAudioFilterEnabled: englishSpanishAudioFilterEnabled
                )
                if requiresDubSchedule {
                    if permitsEnglishDubSchedule {
                        // Independent, no-key English dub timetable providers.
                        async let dubOnlyResult: AnimeAiringScheduleResult? = try? await self.retryOnceAfterTransientCancellation(operationName: "DubOnly English-dub schedule") {
                            try await AnimeScheduleService.shared.fetchSchedule(daysAhead: dayCount)
                        }
                        async let tsuzukiResult: AnimeAiringScheduleResult? = try? await TsuzukiAnimeDubScheduleService.shared.fetchSchedule(daysAhead: dayCount)
                        async let seaDubResult: AnimeAiringScheduleResult? = try? await SeaDubAnimeDubScheduleService.shared.fetchSchedule(daysAhead: dayCount)
                        let (dubOnly, tsuzuki, seaDub) = await (dubOnlyResult, tsuzukiResult, seaDubResult)
                        try Task.checkCancellation()
                        let availableProviders = [dubOnly, tsuzuki, seaDub].compactMap { $0 }
                        if let first = availableProviders.first {
                            result = availableProviders.dropFirst().reduce(first) { merged, provider in
                                AnimeScheduleFallback.mergeEnglishDubSchedules(primary: merged, fallback: provider)
                            }
                        } else {
                            result = AnimeAiringScheduleResult(
                                entries: [],
                                isAuthoritativeForNotifications: false,
                                notice: "English dub timetable providers are temporarily unavailable."
                            )
                        }
                    } else {
                        result = AnimeAiringScheduleResult(
                            entries: [],
                            isAuthoritativeForNotifications: false,
                            notice: "Checking selected-language anime releases…"
                        )
                    }

                    if AnimeScheduleLanguageLookupPolicy.shouldFetchNativeLanguageSchedule(
                        selectedLanguages: selectedDubLanguages
                    ) {
                        let nativeSchedule = try? await self.retryOnceAfterTransientCancellation(
                            operationName: "AniList native-language airing identities"
                        ) {
                            try await AniListService.shared.fetchNativeAiringScheduleForLanguageVerification(daysAhead: dayCount)
                        }
                        if let nativeSchedule {
                            let nativeEntries = nativeSchedule.map(ScheduleEntry.init(animeEntry:))
                            verifiedNativeLanguageEntries = AnimeScheduleLanguageLookupPolicy.nativeLanguageEntries(
                                nativeEntries,
                                selectedLanguages: selectedDubLanguages
                            )

                            // Spanish dubbed dates are researched only from official/reputable
                            // web citations. If no configured research key succeeds, no
                            // Japanese broadcast date is substituted.
                            if selectedDubLanguages.contains(MyDubListLanguage.spanish.rawValue) {
                                self.spanishDubResearchTask?.cancel()
                                self.spanishDubResearchTask = Task(priority: .utility) { @MainActor [weak self] in
                                    let candidates = nativeSchedule
                                    let researched = await SpanishDubAIResearchService.shared.research(entries: candidates)
                                    guard !Task.isCancelled,
                                          let self,
                                          self.animeScheduleCachedPolicyKey == policyKey,
                                          self.animeScheduleDayCount == dayCount,
                                          self.animeScheduleResult != nil else { return }
                                    let scheduleWindow = ScheduleDateWindow.envelope(dayCount: dayCount)
                                    let confirmedEntries = researched
                                        .filter { $0.airingAt >= scheduleWindow.start && $0.airingAt < scheduleWindow.end }
                                        .map(ScheduleEntry.init(animeEntry:))
                                    guard let currentResult = self.animeScheduleResult else { return }
                                    await self.mergeSpanishDubResearchEntries(
                                        confirmedEntries,
                                        into: currentResult,
                                        dayCount: dayCount
                                    )
                                }
                            }
                        }
                    }
                } else {
                    result = try await self.retryOnceAfterTransientCancellation(operationName: "AniList schedule") {
                        try await AniListService.shared.fetchAiringScheduleResult(daysAhead: dayCount)
                    }
                }
                let entries = ScheduleEntryMergePolicy.earliestByEpisode(
                    result.entries.map(ScheduleEntry.init(animeEntry:)) + verifiedNativeLanguageEntries
                )
                try Task.checkCancellation()
                // Hide the routine language-verification explanation. Keep a
                // concise outage notice only when every selected-language source
                // failed and the calendar consequently has no entries.
                let hasProviderOutage = result.notice?
                    .localizedCaseInsensitiveContains("temporarily unavailable") == true
                let notice = requiresDubSchedule
                    ? (entries.isEmpty && hasProviderOutage ? result.notice : nil)
                    : result.notice
                let loadResult = AnimeScheduleLoadResult(
                    entries: entries,
                    isAuthoritativeForNotifications: result.isAuthoritativeForNotifications,
                    notice: notice
                )
                if self.animeScheduleLoadID == loadID {
                    self.animeScheduleResult = loadResult
                    self.animeScheduleCachedPolicyKey = policyKey
                    self.animeScheduleLoadPolicyKey = nil
                    self.animeScheduleDayCount = dayCount

                    self.animeScheduleFetchedAt = fetchStartedAt
                    self.animeScheduleLastFailureAt = nil
                    self.animeScheduleLastFailurePolicyKey = nil
                    self.animeScheduleLoadTask = nil
                    self.animeScheduleLoadID = nil
                }
                return await preparedFilteredAnimeScheduleResult(loadResult)
            } catch {
                if self.animeScheduleLoadID == loadID {
                    self.animeScheduleLastFailureAt = Date()
                    self.animeScheduleLastFailurePolicyKey = policyKey
                    self.animeScheduleLoadTask = nil
                    self.animeScheduleLoadID = nil
                    self.animeScheduleLoadPolicyKey = nil
                }
                throw error
            }
        }
        animeScheduleLoadID = loadID
        animeScheduleLoadTask = loadTask
        _ = try await loadTask.value
        if let cached = cachedAnimeResult(for: dayCount),
           scheduleCacheIsFresh(
                animeScheduleFetchedAt,
                cachedDayCount: animeScheduleDayCount,
                requiredDayCount: dayCount
           ) {
            return filteredAnimeScheduleResult(cached)
        }
        return try await animeEntries(dayCount: dayCount, forceRefresh: forceRefresh)
    }

    @MainActor
    private func westernEntries(dayCount: Int, forceRefresh: Bool) async throws -> [ScheduleEntry] {
        if !forceRefresh,
           scheduleCacheIsFresh(
                westernScheduleFetchedAt,
                cachedDayCount: westernScheduleDayCount,
                requiredDayCount: dayCount
           ),
           let cached = cachedWesternEntries(for: dayCount) {
            return cached
        }
        if let westernScheduleLoadTask {
            _ = try await westernScheduleLoadTask.value
            if let cached = cachedWesternEntries(for: dayCount),
               scheduleCacheIsFresh(
                    westernScheduleFetchedAt,
                    cachedDayCount: westernScheduleDayCount,
                    requiredDayCount: dayCount
               ) {
                return cached
            }
            return try await westernEntries(dayCount: dayCount, forceRefresh: forceRefresh)
        }

        if !forceRefresh, retryIsCoolingDown(since: westernScheduleLastFailureAt) {
            throw ScheduleSourceLoadError.retryDeferred(ScheduleSource.western.displayName)
        }

        let loadID = UUID()
        let fetchStartedAt = Date()
        westernScheduleLastAttemptAt = fetchStartedAt
        let loadTask = Task { @MainActor [weak self] () throws -> [ScheduleEntry] in
            guard let self else { throw CancellationError() }
            do {
                // TVMaze is the primary Series calendar. It provides episode
                // air dates without requiring a Trakt client ID or OAuth setup.
                let rawEntries = try await TVMazeService.shared.fetchSchedule(dayCount: dayCount)
                try Task.checkCancellation()
                let languageFiltered = ScheduleAudioLanguagePolicy.filter(
                    entries: rawEntries,
                    selectedLanguages: MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
                )
                let entries = await self.applyShortRuntimeScheduleFilter(languageFiltered)
                try Task.checkCancellation()
                if self.westernScheduleLoadID == loadID {
                    self.westernScheduleEntries = entries
                    self.westernScheduleDayCount = dayCount
                    self.westernScheduleFetchedAt = fetchStartedAt
                    self.westernScheduleLastFailureAt = nil
                    self.westernScheduleLoadTask = nil
                    self.westernScheduleLoadID = nil
                }
                return entries
            } catch {
                if self.westernScheduleLoadID == loadID {
                    self.westernScheduleLastFailureAt = Date()
                    self.westernScheduleLoadTask = nil
                    self.westernScheduleLoadID = nil
                }
                throw error
            }
        }
        westernScheduleLoadID = loadID
        westernScheduleLoadTask = loadTask
        _ = try await loadTask.value
        if let cached = cachedWesternEntries(for: dayCount),
           scheduleCacheIsFresh(
                westernScheduleFetchedAt,
                cachedDayCount: westernScheduleDayCount,
                requiredDayCount: dayCount
           ) {
            return cached
        }
        return try await westernEntries(dayCount: dayCount, forceRefresh: forceRefresh)
    }

    @MainActor
    private func movieEntries(dayCount: Int, forceRefresh: Bool) async throws -> [ScheduleEntry] {
        let window = ScheduleDateWindow.envelope(dayCount: dayCount)
        if !forceRefresh,
           scheduleCacheIsFresh(
                movieScheduleFetchedAt,
                cachedDayCount: movieScheduleDayCount,
                requiredDayCount: dayCount
           ),
           let cached = movieScheduleEntries {
            return cached.filter { $0.airingAt >= window.start && $0.airingAt < window.end }
        }
        if !forceRefresh, retryIsCoolingDown(since: movieScheduleLastFailureAt) {
            throw ScheduleSourceLoadError.retryDeferred("Movies")
        }
        do {
            // TMDB is the primary movie calendar provider. It requires no Trakt
            // client ID and is available with the app's existing TMDB configuration.
            let rawEntries = try await tmdbUpcomingMovieEntries(in: window)
            try Task.checkCancellation()
            let languageFiltered = ScheduleAudioLanguagePolicy.filter(
                entries: rawEntries,
                selectedLanguages: MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
            )
            let filteredEntries = await applyShortRuntimeScheduleFilter(languageFiltered)
            try Task.checkCancellation()
            movieScheduleEntries = filteredEntries
            movieScheduleDayCount = dayCount
            movieScheduleFetchedAt = Date()
            movieScheduleLastFailureAt = nil
            return filteredEntries.filter { $0.airingAt >= window.start && $0.airingAt < window.end }
        } catch {
            movieScheduleLastFailureAt = Date()
            throw error
        }
    }

    private func tmdbUpcomingMovieEntries(in window: DateInterval) async throws -> [ScheduleEntry] {
        async let firstPage = TMDBService.shared.getUpcomingMovies(page: 1)
        async let secondPage = TMDBService.shared.getUpcomingMovies(page: 2)
        let (pageOne, pageTwo) = try await (firstPage, secondPage)
        let movies = pageOne + pageTwo
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        return movies.compactMap { movie in
            guard let rawDate = movie.releaseDate,
                  let releaseDate = formatter.date(from: rawDate),
                  releaseDate >= window.start,
                  releaseDate < window.end,
                  !MovieSchedulePolicy.isAnime(
                    language: movie.originalLanguage,
                    genres: (movie.genreIds ?? []).map { $0 == 16 ? "animation" : String($0) }
                  ) else { return nil }
            return ScheduleEntry(tmdbUpcomingMovie: movie, releaseDate: releaseDate)
        }
        .sorted { $0.airingAt < $1.airingAt }
    }

    private func applyShortRuntimeScheduleFilter(_ entries: [ScheduleEntry]) async -> [ScheduleEntry] {
        let defaults = UserDefaults.standard
        let hideShortRuntime = defaults.bool(forKey: "catalogHideUnder20MinuteContent")
        let hideUnofficial = defaults.bool(forKey: "catalogHideUnofficialContent")
        guard hideShortRuntime || hideUnofficial else { return entries }

        var resolved = entries
        let titleKeys = Set(entries.compactMap { entry -> String? in
            guard let id = entry.tmdbId, id > 0 else { return nil }
            return "\(entry.isMovie ? "movie" : "tv")-\(id)"
        })

        for key in titleKeys {
            let parts = key.split(separator: "-")
            guard parts.count == 2, let id = Int(parts[1]) else { continue }
            if parts[0] == "movie" {
                guard let detail = try? await TMDBService.shared.getMovieDetails(id: id) else { continue }
                for index in resolved.indices where resolved[index].tmdbId == id && resolved[index].isMovie {
                    if hideShortRuntime && resolved[index].runtimeMinutes == nil {
                        resolved[index].runtimeMinutes = detail.runtime
                    }
                    if hideUnofficial {
                        resolved[index].productionCompanyNames = detail.productionCompanies?.map(\.name) ?? []
                        // A successful details response with no listed companies is still resolved metadata.
                        resolved[index].productionMetadataChecked = true
                    }
                }
            } else {
                guard let detail = try? await TMDBService.shared.getTVShowDetails(id: id) else { continue }
                for index in resolved.indices where resolved[index].tmdbId == id && !resolved[index].isMovie {
                    if hideShortRuntime && resolved[index].runtimeMinutes == nil {
                        if let season = resolved[index].season,
                           let seasonDetail = try? await TMDBService.shared.getSeasonDetails(
                            tvShowId: id,
                            seasonNumber: season
                           ) {
                            resolved[index].runtimeMinutes = seasonDetail.episodes.first {
                                $0.episodeNumber == resolved[index].episode
                            }?.runtime
                        } else {
                            resolved[index].runtimeMinutes = CatalogRuntimeFilterPolicy.shortestReportedRuntime(
                                detail.episodeRunTime
                            )
                        }
                    }
                    if hideUnofficial {
                        resolved[index].productionCompanyNames = detail.productionCompanies?.map(\.name) ?? []
                        // A successful details response with no listed companies is still resolved metadata.
                        resolved[index].productionMetadataChecked = true
                    }
                }
            }
        }

        return resolved.filter { entry in
            if hideShortRuntime,
               !CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: entry.runtimeMinutes) {
                return false
            }
            if hideUnofficial, entry.tmdbId != nil && !entry.productionMetadataChecked {
                return false
            }
            if hideUnofficial,
               TMDBContentFilter.isUnofficialCreatorContent(
                title: ([entry.title, entry.englishTitle, entry.romajiTitle, entry.nativeTitle, entry.format]
                    .compactMap { $0 } + entry.metadataTags).joined(separator: " "),
                overview: entry.overview,
                productionCompanies: entry.productionCompanyNames
               ) {
                return false
            }
            return true
        }
    }

    private func scheduleCacheIsFresh(
        _ fetchedAt: Date?,
        cachedDayCount: Int,
        requiredDayCount: Int
    ) -> Bool {
        guard let fetchedAt,
              cachedDayCount >= requiredDayCount,
              AppCalendar.current.isDate(fetchedAt, inSameDayAs: Date()) else {
            return false
        }
        let age = Date().timeIntervalSince(fetchedAt)
        return age >= 0 && age < scheduleCacheMaxAge
    }

    private func cachedAnimeResult(for dayCount: Int) -> AnimeScheduleLoadResult? {
        guard let animeScheduleResult else { return nil }
        return AnimeScheduleLoadResult(
            entries: entries(animeScheduleResult.entries, within: dayCount),
            isAuthoritativeForNotifications: animeScheduleResult.isAuthoritativeForNotifications,
            notice: animeScheduleResult.notice
        )
    }

    private func cachedWesternEntries(for dayCount: Int) -> [ScheduleEntry]? {
        guard let westernScheduleEntries else { return nil }
        return entries(westernScheduleEntries, within: dayCount)
    }

    private func entries(_ entries: [ScheduleEntry], within dayCount: Int) -> [ScheduleEntry] {
        let window = ScheduleDateWindow.envelope(dayCount: dayCount)
        return entries.filter { $0.airingAt >= window.start && $0.airingAt < window.end }
    }

    private func retryIsCoolingDown(since failureDate: Date?) -> Bool {
        guard let failureDate else { return false }
        let elapsed = Date().timeIntervalSince(failureDate)
        return elapsed >= 0 && elapsed < failedSourceRetryInterval
    }

    private func retryOnceAfterTransientCancellation<T>(
        operationName: String,
        operation: () async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        do {
            let result = try await operation()
            try Task.checkCancellation()
            return result
        } catch {
            if Self.isIntentionalCancellation(error) {
                throw CancellationError()
            }
            guard Self.isTransportCancellation(error) else {
                throw error
            }

            Logger.shared.log(
                "ScheduleViewModel: transient \(operationName) cancellation; retrying once after 1 second",
                type: "TMDB"
            )
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try Task.checkCancellation()
            let result = try await operation()
            try Task.checkCancellation()
            return result
        }
    }

    private static func isIntentionalCancellation(_ error: Error) -> Bool {
        Task.isCancelled || error is CancellationError
    }

    private static func isTransportCancellation(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    func updateBuckets(with entries: [ScheduleEntry], localTimeZone: Bool, dayCount: Int) {
        let calendar = makeCalendar(localTimeZone: localTimeZone)
        let startOfToday = calendar.startOfDay(for: Date())

        var buckets: [DayBucket] = []
        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else {
                continue
            }

            let dayItems = entries
                .filter { entry in
                    entry.airingAt >= calendar.startOfDay(for: day) && entry.airingAt < nextDay
                }
                .sorted { $0.airingAt < $1.airingAt }

            buckets.append(DayBucket(date: calendar.startOfDay(for: day), items: dayItems))
        }

        dayBuckets = buckets
    }

    func regroupBuckets(localTimeZone: Bool) {
        currentLocalTimeZone = localTimeZone
        updateBuckets(
            with: scheduleEntries,
            localTimeZone: localTimeZone,
            dayCount: loadedScheduleDayCount ?? ScheduleWindow.current.rawValue
        )
    }

    func handleDayChangeIfNeeded(mode: ScheduleMode, localTimeZone: Bool) async {
        let calendar = makeCalendar(localTimeZone: localTimeZone)
        let trackedDay = calendar.startOfDay(for: currentDayAnchor)
        let today = calendar.startOfDay(for: Date())

        if today != trackedDay {
            await loadSchedule(mode: mode, localTimeZone: localTimeZone, forceRefresh: true)
        } else {
            await MainActor.run {
                currentLocalTimeZone = localTimeZone
                currentDayAnchor = Date()
                updateBuckets(
                    with: scheduleEntries,
                    localTimeZone: localTimeZone,
                    dayCount: loadedScheduleDayCount ?? ScheduleWindow.current.rawValue
                )
            }
        }
    }

    @MainActor
    private func startPosterHydrationIfNeeded(for entries: [ScheduleEntry], loadID: UUID) {
        let tvEntries = entries.filter {
            guard $0.source == .western, !$0.isMovie,
                  let tmdbId = $0.tmdbId, $0.coverImage == nil else { return false }
            return !posterHydrationAttemptedTMDBIDs.contains(tmdbId)
        }
        let movieEntries = entries.filter {
            guard $0.isMovie, let tmdbId = $0.tmdbId, $0.coverImage == nil else { return false }
            return !moviePosterHydrationAttemptedTMDBIDs.contains(tmdbId)
        }
        guard !tvEntries.isEmpty || !movieEntries.isEmpty else { return }

        activePosterHydrationID = loadID
        posterHydrationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            async let tvDetailsTask = TraktScheduleService.shared.fetchTMDBDetails(for: tvEntries)
            async let moviePostersTask = TraktScheduleService.shared.fetchTMDBMoviePosters(for: movieEntries)
            let (details, moviePosters) = await (tvDetailsTask, moviePostersTask)
            guard !Task.isCancelled, self.activePosterHydrationID == loadID else { return }
            posterHydrationAttemptedTMDBIDs.formUnion(tvEntries.compactMap(\.tmdbId))
            moviePosterHydrationAttemptedTMDBIDs.formUnion(movieEntries.compactMap(\.tmdbId))

            var hydratedEntries = self.scheduleEntries
            for index in hydratedEntries.indices {
                guard let tmdbId = hydratedEntries[index].tmdbId else { continue }
                if hydratedEntries[index].isMovie, let poster = moviePosters[tmdbId] {
                    hydratedEntries[index].coverImage = poster
                } else if let detail = details[tmdbId] {
                    hydratedEntries[index].coverImage = detail.fullPosterURL
                }
            }
            scheduleEntries = hydratedEntries

            if var cachedWesternEntries = westernScheduleEntries {
                for index in cachedWesternEntries.indices {
                    guard let tmdbId = cachedWesternEntries[index].tmdbId,
                          let detail = details[tmdbId] else { continue }
                    cachedWesternEntries[index].coverImage = detail.fullPosterURL
                }
                westernScheduleEntries = cachedWesternEntries
            }
            if var cachedMovieEntries = movieScheduleEntries {
                for index in cachedMovieEntries.indices {
                    guard let tmdbId = cachedMovieEntries[index].tmdbId,
                          let poster = moviePosters[tmdbId] else { continue }
                    cachedMovieEntries[index].coverImage = poster
                }
                movieScheduleEntries = cachedMovieEntries
            }
            updateBuckets(
                with: hydratedEntries,
                localTimeZone: currentLocalTimeZone,
                dayCount: loadedScheduleDayCount ?? ScheduleWindow.current.rawValue
            )
            activePosterHydrationID = nil
            posterHydrationTask = nil
        }
    }

    private func makeCalendar(localTimeZone: Bool) -> Calendar {
        var calendar = AppCalendar.current
        calendar.timeZone = localTimeZone ? .current : (TimeZone(secondsFromGMT: 0) ?? calendar.timeZone)
        return calendar
    }

    private var tmdbCache: [String: TMDBSearchResult] = [:]
    private var tmdbCacheGeneration = UUID()

    @MainActor
    func lookupTMDBResult(for entry: ScheduleEntry) async -> TMDBSearchResult? {
        let cacheKey = entry.provider.metadataCacheKey(mediaID: entry.sourceMediaId, tmdbID: entry.tmdbId, entryID: entry.id)
        if let cached = tmdbCache[cacheKey] {
            return cached
        }

        let generation = tmdbCacheGeneration
        let result = await performTMDBLookup(for: entry)
        guard !Task.isCancelled, generation == tmdbCacheGeneration else { return nil }
        if let result {
            if tmdbCache.count >= 512 { tmdbCache.removeAll(keepingCapacity: true) }
            tmdbCache[cacheKey] = result
        }
        return result
    }

    private func performTMDBLookup(for entry: ScheduleEntry) async -> TMDBSearchResult? {
        if entry.isMovie {
            if let tmdbId = entry.tmdbId,
               let movies = try? await TMDBService.shared.searchMovies(query: entry.title),
               let exact = movies.first(where: { $0.id == tmdbId }) {
                return exact.asSearchResult
            }
        } else if let tmdbId = entry.tmdbId,
                  let detail = try? await TMDBService.shared.getTVShowDetails(id: tmdbId) {
            return tmdbSearchResult(from: detail)
        }

        func normalized(_ value: String) -> String {
            value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }

        var seen = Set<String>()
        let titleCandidates = [entry.englishTitle, entry.romajiTitle, entry.nativeTitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        let candidates = titleCandidates.isEmpty ? [entry.title] : titleCandidates
        let tmdbService = TMDBService.shared
        let preferAnimation = entry.source == .anime
        let isMovie = entry.isMovie || (preferAnimation && entry.format?.uppercased() == "MOVIE")

        for candidate in candidates {
            if isMovie {
                if let result = try? await tmdbService.searchMovies(query: candidate),
                   let best = bestMovieMatch(results: result, candidateKey: normalized(candidate)) {
                    return best.asSearchResult
                }
            } else {
                if let result = try? await tmdbService.searchTVShows(query: candidate),
                   let best = bestTVMatch(results: result, candidateKey: normalized(candidate), preferAnimation: preferAnimation) {
                    return best.asSearchResult
                }
            }
        }

        for candidate in candidates {
            if let results = try? await tmdbService.searchMulti(query: candidate, maxPages: 1),
               let best = bestMultiMatch(results: results, candidateKey: normalized(candidate), preferAnimation: preferAnimation) {
                return best
            }
        }

        guard entry.source == .anime, entry.sourceMediaId != 0 else {
            return nil
        }

        let parentCandidates = await AniListService.shared.fetchParentTitleCandidates(forMediaId: entry.sourceMediaId)
        for parent in parentCandidates {
            var parentSeen = Set<String>()
            let parentTitles = [parent.englishTitle, parent.romajiTitle, parent.nativeTitle]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && parentSeen.insert($0).inserted }

            for candidate in parentTitles {
                if let results = try? await tmdbService.searchTVShows(query: candidate),
                   let best = bestTVMatch(results: results, candidateKey: normalized(candidate), preferAnimation: true) {
                    return best.asSearchResult
                }
                if let results = try? await tmdbService.searchMulti(query: candidate, maxPages: 1),
                   let best = bestMultiMatch(results: results, candidateKey: normalized(candidate), preferAnimation: true) {
                    return best
                }
            }
        }

        return nil
    }

    private func tmdbSearchResult(from detail: TMDBTVShowDetail) -> TMDBSearchResult {
        TMDBSearchResult(
            id: detail.id,
            mediaType: "tv",
            title: nil,
            name: detail.name,
            overview: detail.overview,
            posterPath: detail.posterPath,
            backdropPath: detail.backdropPath,
            releaseDate: nil,
            firstAirDate: detail.firstAirDate,
            voteAverage: detail.voteAverage,
            popularity: detail.popularity,
            adult: detail.adult,
            genreIds: detail.genres.map(\.id)
        )
    }

    private func bestTVMatch(results: [TMDBTVShow], candidateKey: String, preferAnimation: Bool) -> TMDBTVShow? {
        func normalized(_ value: String) -> String {
            value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }
        guard !results.isEmpty else { return nil }

        let exactMatches = results.filter { normalized($0.name) == candidateKey }
        if !exactMatches.isEmpty {
            return bestTVResult(from: exactMatches, preferAnimation: preferAnimation)
        }

        let partialMatches = results.filter {
            let nameKey = normalized($0.name)
            return nameKey.contains(candidateKey) || candidateKey.contains(nameKey)
        }
        if !partialMatches.isEmpty {
            return bestTVResult(from: partialMatches, preferAnimation: preferAnimation)
        }

        return bestTVResult(from: results, preferAnimation: preferAnimation)
    }

    private func bestTVResult(from results: [TMDBTVShow], preferAnimation: Bool) -> TMDBTVShow? {
        results.min { a, b in
            let aAnim = a.genreIds?.contains(16) == true
            let bAnim = b.genreIds?.contains(16) == true
            if preferAnimation, aAnim != bAnim { return aAnim }
            return a.popularity > b.popularity
        }
    }

    private func bestMovieMatch(results: [TMDBMovie], candidateKey: String) -> TMDBMovie? {
        func normalized(_ value: String) -> String {
            value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }
        guard !results.isEmpty else { return nil }

        let exactMatches = results.filter { normalized($0.title) == candidateKey }
        if !exactMatches.isEmpty {
            return bestMovieResult(from: exactMatches)
        }

        let partialMatches = results.filter {
            let nameKey = normalized($0.title)
            return nameKey.contains(candidateKey) || candidateKey.contains(nameKey)
        }
        if !partialMatches.isEmpty {
            return bestMovieResult(from: partialMatches)
        }

        return bestMovieResult(from: results)
    }

    private func bestMovieResult(from results: [TMDBMovie]) -> TMDBMovie? {
        results.min { a, b in
            let aAnim = a.genreIds?.contains(16) == true
            let bAnim = b.genreIds?.contains(16) == true
            if aAnim != bAnim { return aAnim }
            return a.popularity > b.popularity
        }
    }

    private func bestMultiMatch(results: [TMDBSearchResult], candidateKey: String, preferAnimation: Bool) -> TMDBSearchResult? {
        guard !results.isEmpty else { return nil }
        let filtered = results.filter { result in
            let nameKey = result.displayTitle.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            return nameKey == candidateKey || nameKey.contains(candidateKey) || candidateKey.contains(nameKey)
        }
        let pool = filtered.isEmpty ? results : filtered
        return pool.min { a, b in
            let aAnim = a.genreIds?.contains(16) == true
            let bAnim = b.genreIds?.contains(16) == true
            if preferAnimation, aAnim != bAnim { return aAnim }
            return a.popularity > b.popularity
        }
    }
}

struct DayBucket: Identifiable {
    let id = UUID()
    let date: Date
    let items: [ScheduleEntry]
}

private func hasDailyScheduleDensity(_ dates: [Date]) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
    guard days.count >= 4 else { return false }

    var lowerBound = 0
    for upperBound in days.indices {
        while lowerBound < upperBound,
              let windowEnd = calendar.date(
                  byAdding: .day,
                  value: 7,
                  to: days[lowerBound]
              ),
              days[upperBound] >= windowEnd {
            lowerBound += 1
        }
        if upperBound - lowerBound + 1 >= 4 {
            return true
        }
    }
    return false
}

private final class TraktScheduleService {
    static let shared = TraktScheduleService()

    private let baseURL = URL(string: "https://api.trakt.tv")!

    private var clientId: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "TraktClientID") as? String ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.contains("$(") ? "" : trimmed
    }

    private init() {}

    func fetchSchedule(dayCount: Int) async throws -> [ScheduleEntry] {
        guard !clientId.isEmpty else {
            throw TraktScheduleError.missingClientId
        }

        let window = ScheduleDateWindow.envelope(dayCount: dayCount)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let formatter = AppCalendar.dateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var cursor = calendar.startOfDay(for: window.start)
        var items: [TraktCalendarItem] = []
        while cursor < window.end {
            try Task.checkCancellation()
            let remaining = calendar.dateComponents([.day], from: cursor, to: window.end).day ?? 0
            let chunkDays = min(30, max(1, remaining + 1))
            items += try await fetchCalendarItems(startDate: formatter.string(from: cursor), dayCount: chunkDays)
            guard let next = calendar.date(byAdding: .day, value: chunkDays, to: cursor), next > cursor else { break }
            cursor = next
        }
        let candidates = scheduleCandidates(from: items)
        let filtered = removeDailyShows(from: candidates)
            .sorted { $0.airingAt < $1.airingAt }

        return filtered.map { candidate in
            ScheduleEntry(
                traktItem: candidate.item,
                airingAt: candidate.airingAt,
                tmdbDetail: nil
            )
        }
    }

    private func fetchCalendarItems(startDate: String, dayCount: Int) async throws -> [TraktCalendarItem] {
        var components = URLComponents(string: "\(baseURL.absoluteString)/calendars/all/shows/\(startDate)/\(dayCount)")
        components?.queryItems = [
            URLQueryItem(name: "extended", value: "full")
        ]
        guard let url = components?.url else {
            throw TraktScheduleError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktScheduleError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TraktScheduleError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode([TraktCalendarItem].self, from: data)
    }

    private func scheduleCandidates(from items: [TraktCalendarItem]) -> [TraktScheduleCandidate] {
        var seenEpisodeIds = Set<String>()
        return items.compactMap { item in
            guard item.isWesternScheduleCandidate,
                  let airingAt = Self.parseDate(item.firstAired) else {
                return nil
            }

            let episodeKey = item.episode.ids?.trakt.map { "trakt-\($0)" }
                ?? item.episode.ids?.tmdb.map { "tmdb-\($0)" }
                ?? "\(item.showKey)-\(item.episode.season ?? 0)-\(item.episode.number ?? 0)-\(item.firstAired)"
            guard seenEpisodeIds.insert(episodeKey).inserted else {
                return nil
            }

            return TraktScheduleCandidate(
                item: item,
                airingAt: airingAt,
                showKey: item.showKey
            )
        }
    }

    private func removeDailyShows(from candidates: [TraktScheduleCandidate]) -> [TraktScheduleCandidate] {
        let dailyShowIds = Set(
            Dictionary(grouping: candidates, by: \.showKey)
                .compactMap { entry in
                    hasDailyScheduleDensity(entry.value.map(\.airingAt)) ? entry.key : nil
                }
        )
        return candidates.filter { !dailyShowIds.contains($0.showKey) }
    }

    func fetchTMDBMoviePosters(for entries: [ScheduleEntry]) async -> [Int: String] {
        let candidates = entries.compactMap { entry -> (Int, String)? in
            guard let id = entry.tmdbId else { return nil }
            return (id, entry.title)
        }
        return await withTaskGroup(of: (Int, String?).self) { group in
            for (id, title) in candidates.prefix(80) {
                group.addTask {
                    guard let movies = try? await TMDBService.shared.searchMovies(query: title),
                          let movie = movies.first(where: { $0.id == id }),
                          let path = movie.posterPath, !path.isEmpty else {
                        return (id, nil)
                    }
                    return (id, "https://image.tmdb.org/t/p/w500\(path)")
                }
            }
            var posters: [Int: String] = [:]
            for await (id, poster) in group {
                if let poster { posters[id] = poster }
            }
            return posters
        }
    }

    func fetchTMDBDetails(for entries: [ScheduleEntry]) async -> [Int: TMDBTVShowDetail] {
        var seen = Set<Int>()
        let ids = entries
            .compactMap(\.tmdbId)
            .filter { seen.insert($0).inserted }

        return await withTaskGroup(of: (Int, TMDBTVShowDetail?).self) { group in
            for id in ids.prefix(80) {
                group.addTask {
                    (id, try? await TMDBService.shared.getTVShowDetails(id: id))
                }
            }

            var details: [Int: TMDBTVShowDetail] = [:]
            for await (id, detail) in group {
                if let detail {
                    details[id] = detail
                }
            }
            return details
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    func fetchMovieSchedule(dayCount: Int) async throws -> [ScheduleEntry] {
        guard !clientId.isEmpty else { throw TraktScheduleError.missingClientId }
        let window = ScheduleDateWindow.envelope(dayCount: dayCount)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let formatter = AppCalendar.dateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var cursor = calendar.startOfDay(for: window.start)
        var items: [TraktMovieCalendarItem] = []
        while cursor < window.end {
            try Task.checkCancellation()
            let remaining = calendar.dateComponents([.day], from: cursor, to: window.end).day ?? 0
            let chunkDays = min(30, max(1, remaining + 1))
            items += try await fetchMovieCalendarItems(
                startDate: formatter.string(from: cursor),
                dayCount: chunkDays
            )
            guard let next = calendar.date(byAdding: .day, value: chunkDays, to: cursor), next > cursor else { break }
            cursor = next
        }

        let grouped = Dictionary(grouping: items.compactMap { item -> (TraktMovieCalendarItem, Date)? in
            guard item.isNonAnimeMovie, let date = Self.parseDate(item.released) else { return nil }
            return (item, date)
        }, by: { item, _ in item.movie.stableScheduleKey })
        let candidates = grouped.values.compactMap { group in
            group.min(by: { $0.1 < $1.1 })
        }

        let tmdbLookups = candidates.compactMap { candidate -> (Int, String)? in
            guard let tmdbID = candidate.0.movie.ids.tmdb else { return nil }
            return (tmdbID, candidate.0.movie.title)
        }
        let metadataByTMDBID = await withTaskGroup(
            of: (Int, String?, String?, Bool).self,
            returning: [Int: (String?, String?, Bool)].self
        ) { group in
            for (tmdbID, title) in tmdbLookups.prefix(80) {
                group.addTask {
                    guard let matches = try? await TMDBService.shared.searchMovies(query: title),
                          let movie = matches.first(where: { $0.id == tmdbID }) else {
                        return (tmdbID, nil, nil, false)
                    }
                    return (
                        tmdbID,
                        movie.originalLanguage,
                        movie.fullPosterURL,
                        movie.genreIds?.contains(16) == true
                    )
                }
            }
            var metadata: [Int: (String?, String?, Bool)] = [:]
            for await (id, language, poster, isAnimation) in group {
                metadata[id] = (language, poster, isAnimation)
            }
            return metadata
        }

        var result: [ScheduleEntry] = []
        for candidate in candidates {
            let movie = candidate.0.movie
            let metadata = movie.ids.tmdb.flatMap { metadataByTMDBID[$0] }
            let originalLanguage = metadata?.0 ?? movie.primaryLanguageCode
            let genres = (movie.genres ?? []) + (metadata?.2 == true ? ["animation"] : [])
            guard !MovieSchedulePolicy.isAnime(language: originalLanguage, genres: genres) else {
                continue
            }
            var entry = ScheduleEntry(traktMovieItem: candidate.0, releaseDate: candidate.1)
            entry.originalLanguage = originalLanguage?.lowercased()
            entry.coverImage = metadata?.1 ?? entry.coverImage
            result.append(entry)
        }
        return result.sorted { $0.airingAt < $1.airingAt }
    }

    private func fetchMovieCalendarItems(startDate: String, dayCount: Int) async throws -> [TraktMovieCalendarItem] {
        var components = URLComponents(
            string: "\(baseURL.absoluteString)/calendars/all/movies/\(startDate)/\(dayCount)"
        )
        components?.queryItems = [URLQueryItem(name: "extended", value: "full")]
        guard let url = components?.url else { throw TraktScheduleError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TraktScheduleError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw TraktScheduleError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode([TraktMovieCalendarItem].self, from: data)
    }
}

private struct TraktScheduleCandidate {
    let item: TraktCalendarItem
    let airingAt: Date
    let showKey: String
}

fileprivate struct TraktCalendarItem: Decodable {
    let firstAired: String
    let episode: TraktCalendarEpisode
    let show: TraktCalendarShow

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case episode, show
    }

    var showKey: String {
        show.ids.trakt.map { "trakt-\($0)" }
            ?? show.ids.tmdb.map { "tmdb-\($0)" }
            ?? show.title.lowercased()
    }

    var isWesternScheduleCandidate: Bool {
        let excludedGenres: Set<String> = [
            "anime",
            "documentary",
            "food",
            "game-show",
            "home-and-garden",
            "news",
            "reality",
            "soap",
            "special-interest",
            "sport",
            "talk-show"
        ]
        let genres = Set((show.genres ?? []).map { $0.lowercased() })
        let isLikelyAnime = genres.contains("anime")
            || (genres.contains("animation") && ["ja", "zh", "ko"].contains(show.language?.lowercased() ?? ""))
        return !isLikelyAnime && genres.isDisjoint(with: excludedGenres)
    }
}

enum MovieSchedulePolicy {
    static func isAnime(language: String?, genres: [String]?) -> Bool {
        let normalizedGenres = Set((genres ?? []).map { $0.lowercased() })
        let normalizedLanguage = language?.lowercased() ?? ""
        let baseLanguage = normalizedLanguage.split(separator: "-").first.map(String.init) ?? normalizedLanguage
        return normalizedGenres.contains("anime")
            || (normalizedGenres.contains("animation") && ["ja", "zh", "ko"].contains(baseLanguage))
    }
}

fileprivate struct TraktMovieCalendarItem: Decodable {
    let released: String
    let movie: TraktCalendarMovie

    var isNonAnimeMovie: Bool {
        !MovieSchedulePolicy.isAnime(language: movie.primaryLanguageCode, genres: movie.genres)
    }
}

fileprivate struct TraktCalendarMovie: Decodable {
    let title: String
    let year: Int?
    let ids: TraktCalendarIDs
    let language: String?
    let languages: [String]?
    let genres: [String]?
    let runtime: Int?

    var primaryLanguageCode: String? {
        language ?? languages?.first
    }

    var stableScheduleKey: String {
        if let tmdb = ids.tmdb { return "tmdb-\(tmdb)" }
        if let trakt = ids.trakt { return "trakt-\(trakt)" }
        return "\(title.lowercased())-\(year ?? 0)"
    }
}

fileprivate struct TraktCalendarEpisode: Decodable {
    let season: Int?
    let number: Int?
    let title: String?
    let ids: TraktCalendarIDs?
    let runtime: Int?
}

fileprivate struct TraktCalendarShow: Decodable {
    let title: String
    let year: Int?
    let ids: TraktCalendarIDs
    let language: String?
    let country: String?
    let network: String?
    let genres: [String]?
}

fileprivate struct TraktCalendarIDs: Decodable {
    let trakt: Int?
    let slug: String?
    let tvdb: Int?
    let imdb: String?
    let tmdb: Int?
}

private enum TraktScheduleError: LocalizedError {
    case missingClientId
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "TRAKT_CLIENT_ID is not configured."
        case .invalidURL:
            return "The Trakt schedule URL could not be created."
        case .invalidResponse:
            return "The Trakt schedule service returned an invalid response."
        case .httpStatus(let status):
            return "The Trakt schedule service returned HTTP \(status)."
        }
    }
}

private actor TVMazeService {
    static let shared = TVMazeService()

    private let baseURL = URL(string: "https://api.tvmaze.com")!
    private let extendedCacheMaxAge: TimeInterval = 6 * 60 * 60
    private var extendedScheduleCache: (fetchedAt: Date, entries: [ScheduleEntry])?

    private init() {}

    func fetchSchedule(dayCount: Int) async throws -> [ScheduleEntry] {
        if dayCount > ScheduleWindow.sevenDays.rawValue {
            return try await fetchExtendedSchedule(dayCount: dayCount)
        }

        let calendar = AppCalendar.current
        let window = ScheduleDateWindow.envelope(dayCount: dayCount)
        let startOfToday = calendar.startOfDay(for: window.start)
        let numberOfDays = (calendar.dateComponents([.day], from: startOfToday, to: window.end).day ?? dayCount) + 1
        let formatter = AppCalendar.dateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let regionCode = Locale.current.regionCode?.uppercased() ?? "US"
        var episodesById: [Int: TVMazeScheduleEpisode] = [:]

        for offset in 0..<numberOfDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }
            let dateString = formatter.string(from: date)
            let feeds = [
                (
                    path: "schedule",
                    requiresEnglishLanguage: false,
                    isOptional: false,
                    queryItems: [
                        URLQueryItem(name: "country", value: regionCode),
                        URLQueryItem(name: "date", value: dateString)
                    ]
                ),
                (
                    path: "schedule/web",
                    requiresEnglishLanguage: true,
                    isOptional: true,
                    queryItems: [
                        URLQueryItem(name: "country", value: ""),
                        URLQueryItem(name: "date", value: dateString)
                    ]
                )
            ]

            for feed in feeds {
                let episodes: [TVMazeScheduleEpisode]
                do {
                    episodes = try await fetchEpisodes(path: feed.path, queryItems: feed.queryItems)
                } catch {
                    guard feed.isOptional else {
                        throw error
                    }
                    Logger.shared.log(
                        "TVMazeService: optional feed failed path=\(feed.path) date=\(dateString) error=\(error.localizedDescription)",
                        type: "TMDB"
                    )
                    continue
                }
                for episode in episodes where episode.show.isWesternScheduleCandidate
                    {
                    episodesById[episode.id] = episode
                }
            }
        }

        return scheduleEntries(from: episodesById)
    }

    private func fetchExtendedSchedule(dayCount: Int) async throws -> [ScheduleEntry] {
        if let cached = extendedScheduleCache,
           AppCalendar.current.isDate(cached.fetchedAt, inSameDayAs: Date()) {
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age >= 0, age < extendedCacheMaxAge {
                return entries(cached.entries, within: dayCount)
            }
        }

        let episodes = try await fetchEpisodes(path: "schedule/full", queryItems: [])
        let window = ScheduleDateWindow.envelope(dayCount: ScheduleWindow.thirtyDays.rawValue)
        let start = window.start
        let end = window.end
        let regionCode = Locale.current.regionCode?.uppercased() ?? "US"
        var episodesById: [Int: TVMazeScheduleEpisode] = [:]

        for episode in episodes {
            guard episode.show.isWesternScheduleCandidate,
                  episode.show.isIncludedInFullSchedule(regionCode: regionCode),
                  let airing = episode.airing,
                  airing.date >= start,
                  airing.date < end else {
                continue
            }
            episodesById[episode.id] = episode
        }

        let extendedEntries = scheduleEntries(from: episodesById)
            .sorted { $0.airingAt < $1.airingAt }
        extendedScheduleCache = (Date(), extendedEntries)
        return entries(extendedEntries, within: dayCount)
    }

    private func scheduleEntries(
        from episodesById: [Int: TVMazeScheduleEpisode]
    ) -> [ScheduleEntry] {
        let dailyShowIds = Set(
            Dictionary(grouping: episodesById.values, by: { $0.show.id })
                .compactMap { entry in
                    hasDailyScheduleDensity(entry.value.compactMap { $0.airing?.date })
                        ? entry.key
                        : nil
                }
        )

        return episodesById.values.compactMap { episode in
            guard !dailyShowIds.contains(episode.show.id) else {
                return nil
            }
            guard let airing = episode.airing else {
                return nil
            }
            return ScheduleEntry(westernEpisode: episode, airing: airing)
        }
    }

    private func entries(_ entries: [ScheduleEntry], within dayCount: Int) -> [ScheduleEntry] {
        let window = ScheduleDateWindow.envelope(dayCount: dayCount)
        return entries.filter { $0.airingAt >= window.start && $0.airingAt < window.end }
    }

    private func fetchEpisodes(path: String, queryItems: [URLQueryItem], retryAfterRateLimit: Bool = true) async throws -> [TVMazeScheduleEpisode] {
        let data = try await fetchData(path: path, queryItems: queryItems, retryAfterRateLimit: retryAfterRateLimit)
        return try JSONDecoder().decode([TVMazeScheduleEpisode].self, from: data)
    }

    private func fetchData(
        path: String,
        queryItems: [URLQueryItem],
        retryAfterRateLimit: Bool = true
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw TVMazeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Eclipse iOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TVMazeError.invalidResponse
        }

        if httpResponse.statusCode == 429, retryAfterRateLimit {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return try await fetchData(
                path: path,
                queryItems: queryItems,
                retryAfterRateLimit: false
            )
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TVMazeError.httpStatus(httpResponse.statusCode)
        }

        return data
    }
}

private enum TVMazeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Western schedule URL could not be created."
        case .invalidResponse:
            return "The Western schedule service returned an invalid response."
        case .httpStatus(let status):
            return "The Western schedule service returned HTTP \(status)."
        }
    }
}

fileprivate struct TVMazeScheduleEpisode: Decodable {
    let id: Int
    let season: Int
    let number: Int?
    let runtime: Int?
    let airdate: String
    let airtime: String?
    let airstamp: String?
    let show: TVMazeShow

    private enum CodingKeys: String, CodingKey {
        case id, season, number, runtime, airdate, airtime, airstamp, show
        case embedded = "_embedded"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        season = try container.decode(Int.self, forKey: .season)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        airdate = try container.decode(String.self, forKey: .airdate)
        airtime = try container.decodeIfPresent(String.self, forKey: .airtime)
        airstamp = try container.decodeIfPresent(String.self, forKey: .airstamp)
        show = try container.decodeIfPresent(TVMazeShow.self, forKey: .show)
            ?? container.decode(TVMazeEmbedded.self, forKey: .embedded).show
    }

    var airing: TVMazeAiringInfo? {
        tvMazeAiringInfo(
            airdate: airdate,
            airtime: airtime,
            airstamp: airstamp,
            timeZoneIdentifier: show.network?.country?.timezone ?? show.webChannel?.country?.timezone
        )
    }
}

fileprivate struct TVMazeAiringInfo {
    let date: Date
    let hasKnownAiringTime: Bool
}

private func tvMazeAiringInfo(airdate: String, airtime: String?, airstamp: String?, timeZoneIdentifier: String?) -> TVMazeAiringInfo? {
    let normalizedAirtime = airtime?.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasKnownAiringTime = normalizedAirtime?.isEmpty == false

    if let airstamp, let date = ISO8601DateFormatter().date(from: airstamp) {
        return TVMazeAiringInfo(date: date, hasKnownAiringTime: hasKnownAiringTime)
    }

    let formatter = AppCalendar.dateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = hasKnownAiringTime ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
    if let timeZoneIdentifier {
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
    }
    let value = hasKnownAiringTime ? "\(airdate) \(normalizedAirtime ?? "")" : airdate
    guard let date = formatter.date(from: value) else {
        return nil
    }
    return TVMazeAiringInfo(date: date, hasKnownAiringTime: hasKnownAiringTime)
}

fileprivate struct TVMazeEmbedded: Decodable {
    let show: TVMazeShow
}

fileprivate struct TVMazeShow: Decodable {
    let id: Int
    let name: String
    let language: String?
    let premiered: String?
    let type: String?
    let genres: [String]
    let summary: String?
    let image: TVMazeImage?
    let network: TVMazeChannel?
    let webChannel: TVMazeChannel?
    let schedule: TVMazeShowSchedule?

    var isoLanguageCode: String? {
        guard let language else { return nil }
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let known: [String: String] = ["english": "en", "spanish": "es", "japanese": "ja", "french": "fr", "german": "de", "italian": "it", "portuguese": "pt", "korean": "ko", "chinese": "zh", "dutch": "nl", "russian": "ru", "turkish": "tr", "arabic": "ar", "hindi": "hi", "polish": "pl", "swedish": "sv", "danish": "da", "norwegian": "no", "finnish": "fi"]
        return known[normalized] ?? (normalized.count == 2 ? normalized : nil)
    }

    var releaseYear: Int? {
        guard let premiered, premiered.count >= 4 else { return nil }
        return Int(premiered.prefix(4))
    }

    var isLikelyAnime: Bool {
        let hasAnimeGenre = genres.contains { genre in
            let normalized = genre.lowercased()
            return normalized == "anime" || normalized == "animation"
        }
        return hasAnimeGenre
            && ["japanese", "chinese", "korean"].contains(language?.lowercased() ?? "")
    }

    var isWesternScheduleCandidate: Bool {
        guard !isLikelyAnime, (schedule?.days.count ?? 0) < 4 else { return false }
        switch type?.lowercased() {
        case "scripted", "animation":
            return true
        default:
            return false
        }
    }

    var isEnglishLanguage: Bool {
        language?.lowercased() == "english"
    }

    func isIncludedInFullSchedule(regionCode: String) -> Bool {
        let normalizedRegion = regionCode.uppercased()
        if network?.country?.code?.uppercased() == normalizedRegion {
            return true
        }
        if let webCountry = webChannel?.country {
            return webCountry.code?.uppercased() == normalizedRegion
        }

        return webChannel != nil
    }
}

fileprivate struct TVMazeShowSchedule: Decodable {
    let days: [String]
}

fileprivate struct TVMazeImage: Decodable {
    let medium: String?
    let original: String?
}

fileprivate struct TVMazeChannel: Decodable {
    let name: String?
    let country: TVMazeCountry?
}

fileprivate struct TVMazeCountry: Decodable {
    let code: String?
    let timezone: String?
}


enum ScheduleAudioLanguagePolicy {
    static func effectiveLanguageCodes(_ selectedLanguages: Set<String>) -> Set<String>? {
        let enabled = !selectedLanguages.isEmpty
            || UserDefaults.standard.bool(forKey: "catalogRequireEnglishSpanishAudio")
        guard enabled else { return nil }
        let effective = DubLanguageSelectionPolicy.effectiveLanguages(
            selectedLanguages: selectedLanguages,
            requiresEnglishSpanishAudio: UserDefaults.standard.bool(forKey: "catalogRequireEnglishSpanishAudio")
        )
        let codes = Set(effective.flatMap { raw in
            MyDubListLanguage(rawValue: raw)?.episodeMetadataLanguageCodes.map { $0.lowercased() } ?? []
        })
        return codes.isEmpty ? ["en", "es"] : codes
    }

    static func matches(originalLanguage: String?, selectedLanguages: Set<String>) -> Bool {
        guard let codes = effectiveLanguageCodes(selectedLanguages) else { return true }
        guard let raw = originalLanguage?.lowercased(), !raw.isEmpty else { return false }
        let code = raw.replacingOccurrences(of: "_", with: "-")
        return codes.contains(code)
            || codes.contains(where: { code.hasPrefix($0 + "-") })
            || ((code == "es" || code.hasPrefix("es-"))
                && codes.contains(where: { $0 == "es" || $0.hasPrefix("es-") }))
    }

    // No external audio-offer API is called. Unknown/non-native audio is
    // deliberately false so a missing provider never becomes a false positive.
    static func hasNativeLanguageMatch(
        originalLanguage: String?,
        selectedLanguages: Set<String>
    ) -> Bool? {
        matches(originalLanguage: originalLanguage, selectedLanguages: selectedLanguages)
    }

    static func filter(entries: [ScheduleEntry], selectedLanguages: Set<String>) -> [ScheduleEntry] {
        guard effectiveLanguageCodes(selectedLanguages) != nil else { return entries }
        return entries.filter {
            matches(originalLanguage: $0.originalLanguage, selectedLanguages: selectedLanguages)
        }.sorted { $0.airingAt < $1.airingAt }
    }
}
