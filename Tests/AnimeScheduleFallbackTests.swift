import Foundation
import XCTest
@testable import Eclipse

private final class AnimeScheduleURLProtocol: URLProtocol {
    static let lock = NSLock()
    static var handler: ((URLRequest) -> (Int, Data, [String: String]))?
    static var paths: [String] = []

    static func configure(_ handler: @escaping (URLRequest) -> (Int, Data, [String: String])) {
        lock.lock()
        self.handler = handler
        paths = []
        lock.unlock()
    }

    static var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return paths.count
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.paths.append(request.url?.path ?? "")
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data, headers) = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class AnimeScheduleFallbackTests: XCTestCase {
    func testAniListScheduleEntryCarriesReleaseYearAndRuntimeIntoScheduleFilters() {
        let entry = AniListAiringScheduleEntry(
            id: 42,
            mediaId: 1234,
            title: "Example Anime",
            airingAt: Date(timeIntervalSince1970: 1_800_000_000),
            episode: 3,
            coverImage: nil,
            englishTitle: "Example Anime",
            romajiTitle: "Example Anime",
            nativeTitle: nil,
            format: "TV",
            hasKnownAiringTime: true,
            scheduleProvider: .aniList,
            malID: 5678,
            airingTimeWithdrawn: false,
            tags: ["Action"],
            releaseYear: 1993,
            runtimeMinutes: 19
        )

        let scheduleEntry = ScheduleEntry(animeEntry: entry)

        XCTAssertEqual(scheduleEntry.releaseYear, 1993)
        XCTAssertEqual(scheduleEntry.runtimeMinutes, 19)
        XCTAssertEqual(scheduleEntry.metadataTags, ["Action"])
    }

    func testScheduleMergeBridgesAniListAndMALIDsAndPrefersConfirmedDates() {
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        func entry(
            id: Int,
            mediaID: Int,
            malID: Int?,
            date: Date,
            knownTime: Bool,
            withdrawn: Bool = false
        ) -> ScheduleEntry {
            ScheduleEntry(animeEntry: AniListAiringScheduleEntry(
                id: id,
                mediaId: mediaID,
                title: "Shared Anime",
                airingAt: date,
                episode: 4,
                coverImage: nil,
                englishTitle: "Shared Anime",
                romajiTitle: "Shared Anime",
                nativeTitle: nil,
                format: "TV",
                hasKnownAiringTime: knownTime,
                scheduleProvider: .aniList,
                malID: malID,
                airingTimeWithdrawn: withdrawn,
                tags: [],
                releaseYear: 2026,
                runtimeMinutes: 24
            ))
        }

        let aniListOnly = entry(
            id: 1, mediaID: 1234, malID: nil,
            date: baseDate, knownTime: true
        )
        let malOnly = entry(
            id: 2, mediaID: -5678, malID: nil,
            date: baseDate.addingTimeInterval(3_600), knownTime: true
        )
        let unconfirmedBridge = entry(
            id: 3, mediaID: 1234, malID: 5678,
            date: baseDate.addingTimeInterval(-3_600), knownTime: false, withdrawn: true
        )

        let confirmedMerge = ScheduleEntryMergePolicy.earliestByEpisode([
            aniListOnly, malOnly, unconfirmedBridge
        ])
        XCTAssertEqual(confirmedMerge.count, 1)
        XCTAssertEqual(confirmedMerge.first?.airingAt, baseDate)

        let confirmedBridge = entry(
            id: 4, mediaID: 1234, malID: 5678,
            date: baseDate.addingTimeInterval(-1_800), knownTime: true
        )
        let earliestConfirmedMerge = ScheduleEntryMergePolicy.earliestByEpisode([
            aniListOnly, malOnly, confirmedBridge
        ])
        XCTAssertEqual(earliestConfirmedMerge.count, 1)
        XCTAssertEqual(earliestConfirmedMerge.first?.airingAt, confirmedBridge.airingAt)
    }

    func testSeaDubIsAnEnglishOnlyScheduleProvider() {
        XCTAssertEqual(
            AnimeScheduleProviderLanguagePolicy.includes(
                provider: .seaDub,
                originalLanguage: "ja",
                selectedLanguages: [MyDubListLanguage.english.rawValue]
            ),
            true
        )
        XCTAssertEqual(
            AnimeScheduleProviderLanguagePolicy.includes(
                provider: .seaDub,
                originalLanguage: "ja",
                selectedLanguages: [MyDubListLanguage.spanish.rawValue]
            ),
            false
        )
    }

    func testDubLanguagePickerOnlyExposesEnglishAndSpanish() {
        XCTAssertEqual(
            Set(MyDubListLanguage.allCases.map(\.rawValue)),
            Set([MyDubListLanguage.english.rawValue, MyDubListLanguage.spanish.rawValue])
        )
        XCTAssertEqual(
            MyDubListDubFilter.supportedLanguages,
            Set([MyDubListLanguage.english.rawValue, MyDubListLanguage.spanish.rawValue])
        )
        XCTAssertEqual(MyDubListLanguage.spanish.displayName, "Spanish (Castellano o Latino)")
    }

    func testDubbedEpisodeListShowsLoadingUntilSelectedLanguageCountsResolve() {
        XCTAssertTrue(AnimeDubEpisodeMetadataLoadingPolicy.shouldShowLoading(
            isAnime: true,
            hasSelectedLanguages: true,
            hasResolvedCounts: false
        ))
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.shouldShowLoading(
            isAnime: true,
            hasSelectedLanguages: true,
            hasResolvedCounts: true
        ), "An empty but resolved provider response should show the genuine no-dub state.")
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.shouldShowLoading(
            isAnime: true,
            hasSelectedLanguages: true,
            hasResolvedCounts: false,
            hasFailure: true
        ), "A failed provider request should show retry guidance, not spin forever.")
        XCTAssertTrue(AnimeDubEpisodeMetadataLoadingPolicy.shouldShowFailure(
            isAnime: true,
            hasSelectedLanguages: true,
            hasFailure: true
        ))
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.shouldShowFailure(
            isAnime: true,
            hasSelectedLanguages: true,
            hasFailure: false
        ))
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.hasUsableProviderResponse(
            taizenSucceeded: false,
            anidubSucceeded: false,
            selectedLanguages: [MyDubListLanguage.english.rawValue]
        ))
        XCTAssertTrue(AnimeDubEpisodeMetadataLoadingPolicy.hasUsableProviderResponse(
            taizenSucceeded: false,
            anidubSucceeded: true,
            selectedLanguages: [MyDubListLanguage.spanish.rawValue]
        ))
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.hasUsableProviderResponse(
            taizenSucceeded: false,
            anidubSucceeded: true,
            selectedLanguages: [MyDubListLanguage.english.rawValue, MyDubListLanguage.spanish.rawValue]
        ))
        XCTAssertTrue(AnimeDubEpisodeMetadataLoadingPolicy.hasUsableProviderResponse(
            taizenSucceeded: true,
            anidubSucceeded: false,
            selectedLanguages: [MyDubListLanguage.english.rawValue, MyDubListLanguage.spanish.rawValue]
        ))
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.shouldShowLoading(
            isAnime: true,
            hasSelectedLanguages: false,
            hasResolvedCounts: false
        ))
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.shouldShowLoading(
            isAnime: false,
            hasSelectedLanguages: true,
            hasResolvedCounts: false
        ))
        XCTAssertFalse(AnimeDubEpisodeMetadataLoadingPolicy.shouldLoadMetadata(
            isAnime: true,
            hasSelectedLanguages: true,
            hasProviderIdentity: false
        ), "Do not mark a season empty before its anime provider identity has resolved.")
        XCTAssertTrue(AnimeDubEpisodeMetadataLoadingPolicy.shouldLoadMetadata(
            isAnime: true,
            hasSelectedLanguages: true,
            hasProviderIdentity: true
        ))
    }

    func testGlobalAudioRequirementDoesNotBroadenAnExplicitDubLanguageSelection() {
        XCTAssertEqual(
            DubLanguageSelectionPolicy.effectiveLanguages(
                selectedLanguages: [MyDubListLanguage.spanish.rawValue],
                requiresEnglishSpanishAudio: true
            ),
            [MyDubListLanguage.spanish.rawValue]
        )
        XCTAssertEqual(
            DubLanguageSelectionPolicy.effectiveLanguages(
                selectedLanguages: [MyDubListLanguage.english.rawValue],
                requiresEnglishSpanishAudio: true
            ),
            [MyDubListLanguage.english.rawValue]
        )
        XCTAssertEqual(
            DubLanguageSelectionPolicy.effectiveLanguages(
                selectedLanguages: [],
                requiresEnglishSpanishAudio: true
            ),
            [MyDubListLanguage.english.rawValue, MyDubListLanguage.spanish.rawValue]
        )
        XCTAssertTrue(
            DubLanguageSelectionPolicy.effectiveLanguages(
                selectedLanguages: [],
                requiresEnglishSpanishAudio: false
            ).isEmpty
        )
    }



    private var now: Date { Date(timeIntervalSince1970: 1_788_998_400) }

    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AnimeScheduleURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func row(_ changes: [String: Any] = [:]) -> [String: Any] {
        var result: [String: Any] = [
            "title": "Example Season 2", "route": "example-2", "english": "Example Second Season",
            "romaji": "Example 2", "native": "例", "episodeDate": ISO8601DateFormatter().string(from: now.addingTimeInterval(3600)),
            "episodeNumber": 5, "airType": "dub", "airingStatus": "unaired",
            "delayedFrom": "0001-01-01T00:00:00Z", "delayedUntil": "0001-01-01T00:00:00Z",
            "mediaTypes": [["route": "tv", "name": "TV"]], "imageVersionRoute": "anime/jpg/example.jpg"
        ]
        for (key, value) in changes { result[key] = value }
        return result
    }

    private func anime(_ changes: [String: Any] = [:]) -> [String: Any] {
        var result: [String: Any] = [
            "route": "example-2", "websites": ["aniList": "anilist.co/anime/101/Example", "mal": "myanimelist.net/anime/202/Example"],
            "genres": [["route": "action", "name": "Action"]]
        ]
        for (key, value) in changes { result[key] = value }
        return result
    }

    private func data(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }

    private func mapped(_ changes: [String: Any] = [:], animeChanges: [String: Any] = [:], stale: Bool = false) throws -> [AniListAiringScheduleEntry] {
        let row = try JSONDecoder().decode(AnimeScheduleTimetableEntry.self, from: data(row(changes)))
        let anime = try JSONDecoder().decode(AnimeScheduleAnime.self, from: data(anime(animeChanges)))
        return AnimeScheduleEntryMapper.entries(from: row, anime: anime, window: ScheduleDateWindow.envelope(dayCount: 7, now: now), preferredLanguageCode: "en", stale: stale)
    }

    private func stub(
        rows: [[String: Any]]? = nil,
        missingWeek: Bool = false,
        catalogTotalAmount: Int = 1
    ) throws {
        let timetable = try data(rows ?? [row()])
        let catalog = try data(["page": 1, "totalAmount": catalogTotalAmount, "anime": [anime()]])
        let firstWeek = AnimeScheduleWeek.covering(ScheduleDateWindow.envelope(dayCount: 7, now: now)).first?.week
        AnimeScheduleURLProtocol.configure { request in
            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token" else { return (401, Data(), [:]) }
            if request.url?.path.contains("timetables") == true {
                guard request.url?.path.hasSuffix("/timetables/dub") == true else { return (404, Data(), [:]) }
                let week = URLComponents(url: request.url ?? URL(fileURLWithPath: "/"), resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "week" }?.value
                if missingWeek, week != firstWeek.map(String.init) { return (404, Data(), [:]) }
                return (200, timetable, [:])
            }
            return (200, catalog, [:])
        }
    }

    func testAnidubFallbackOnlyRunsWhenTaizenLacksEnglishAndSpanishCounts() {
        XCTAssertFalse(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(taizenCounts: ["es": 12]))
        XCTAssertFalse(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(taizenCounts: ["en": 12]))
        XCTAssertFalse(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(taizenCounts: ["es-419": 12]))
        XCTAssertTrue(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(taizenCounts: ["fr": 12]))
        XCTAssertTrue(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(taizenCounts: [:]))
    }

    func testAnidubFallbackChecksTheSelectedLanguageRatherThanAnyDub() {
        XCTAssertTrue(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(
            taizenCounts: ["en": 12],
            selectedLanguages: ["spanish"]
        ))
        XCTAssertFalse(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(
            taizenCounts: ["es-419": 12],
            selectedLanguages: ["spanish"]
        ))
        XCTAssertTrue(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(
            taizenCounts: ["es": 12],
            selectedLanguages: ["english"]
        ))
        XCTAssertFalse(AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(
            taizenCounts: ["en": 12],
            selectedLanguages: ["english"]
        ))
    }

    func testSpanishSelectionExplainsMissingSpanishEpisodeDatesWithoutSubstitutingBroadcasts() {
        let notice = AnimeScheduleLanguageNoticePolicy.notice(
            selectedLanguages: ["english", "spanish"],
            providerNotice: nil
        )
        XCTAssertTrue(notice?.contains("No confirmed Spanish-dub episode dates") == true)
        XCTAssertTrue(notice?.contains("Japanese broadcast dates are never substituted") == true)
    }

    func testSpanishSelectionReplacesGenericProviderOutageWithLanguageSpecificNotice() {
        let notice = AnimeScheduleLanguageNoticePolicy.notice(
            selectedLanguages: ["spanish"],
            providerNotice: "English dub timetable providers are temporarily unavailable."
        )
        XCTAssertTrue(notice?.contains("No confirmed Spanish-dub episode dates") == true)
        XCTAssertFalse(notice?.contains("providers are temporarily unavailable") == true)
    }

    func testEnglishOnlyAnimeSchedulePreservesProviderNotice() {
        let providerNotice = "DubOnly timetable is temporarily unavailable."
        XCTAssertEqual(
            AnimeScheduleLanguageNoticePolicy.notice(
                selectedLanguages: ["english"],
                providerNotice: providerNotice
            ),
            providerNotice
        )
    }

    func testLanguageFilterNeverAllowsUndubbedBroadcastFallback() {
        XCTAssertFalse(AnimeScheduleFallback.permitsBroadcastFallback(selectedDubLanguages: ["english"]))
        XCTAssertFalse(AnimeScheduleFallback.permitsBroadcastFallback(selectedDubLanguages: ["spanish"]))
        XCTAssertFalse(AnimeScheduleFallback.permitsBroadcastFallback(selectedDubLanguages: ["english", "spanish"]))
        XCTAssertTrue(AnimeScheduleFallback.permitsBroadcastFallback(selectedDubLanguages: []))
    }

    func testEnglishSpanishAudioFilterSuppressesBroadcastFallbackWhenDubPickerIsEmpty() {
        XCTAssertTrue(AnimeScheduleFallback.requiresDubSchedule(
            selectedDubLanguages: [],
            englishSpanishAudioFilterEnabled: true
        ))
        XCTAssertFalse(AnimeScheduleFallback.permitsEnglishDubSchedule(
            selectedDubLanguages: [],
            englishSpanishAudioFilterEnabled: false
        ))
        XCTAssertTrue(AnimeScheduleFallback.permitsEnglishDubSchedule(
            selectedDubLanguages: [],
            englishSpanishAudioFilterEnabled: true
        ))
    }

    func testSpanishOnlySelectionNeverUsesEnglishOrBroadcastDates() {
        let selected: Set<String> = [MyDubListLanguage.spanish.rawValue]
        XCTAssertTrue(AnimeScheduleFallback.requiresDubSchedule(
            selectedDubLanguages: selected,
            englishSpanishAudioFilterEnabled: false
        ))
        XCTAssertFalse(AnimeScheduleFallback.permitsEnglishDubSchedule(
            selectedDubLanguages: selected,
            englishSpanishAudioFilterEnabled: true
        ))
        XCTAssertFalse(AnimeScheduleFallback.permitsBroadcastFallback(selectedDubLanguages: selected))
    }

    func testFallbackUsesAnimeScheduleBeforeMAL() async throws {
        var usedMAL = false
        let entries = try mapped()
        let result = try await AnimeScheduleFallback.load(
            aniList: { throw AnimeScheduleError.http(503) },
            animeSchedule: { AnimeAiringScheduleResult(entries: entries, isAuthoritativeForNotifications: false) },
            mal: { usedMAL = true; throw AnimeScheduleError.unavailable },
            permitsFallback: { _ in true }
        )
        XCTAssertFalse(usedMAL)
        XCTAssertEqual(result.entries.first?.mediaId, 101)
        XCTAssertTrue(result.entries.first?.hasKnownAiringTime == true)
    }

    func testHealthyAniListDoesNotContactFallback() async throws {
        var usedFallback = false
        let result = try await AnimeScheduleFallback.load(
            aniList: { AnimeAiringScheduleResult(entries: [], isAuthoritativeForNotifications: true) },
            animeSchedule: { usedFallback = true; throw AnimeScheduleError.unavailable },
            mal: { usedFallback = true; throw AnimeScheduleError.unavailable },
            permitsFallback: { _ in true }
        )
        XCTAssertTrue(result.isAuthoritativeForNotifications)
        XCTAssertFalse(usedFallback)
    }

    func testBothProvidersFailThenMALIsUsed() async throws {
        var usedMAL = false
        let result = try await AnimeScheduleFallback.load(
            aniList: { throw AnimeScheduleError.http(503) },
            animeSchedule: { throw AnimeScheduleError.http(429) },
            mal: { usedMAL = true; return AnimeAiringScheduleResult(entries: [], isAuthoritativeForNotifications: false) },
            permitsFallback: { _ in true }
        )
        XCTAssertTrue(usedMAL)
        XCTAssertFalse(result.isAuthoritativeForNotifications)
    }

    func testCancellationNeverFallsThroughToAnotherProvider() async {
        for cancellationAtPrimary in [true, false] {
            var usedMAL = false
            do {
                _ = try await AnimeScheduleFallback.load(
                    aniList: {
                        if cancellationAtPrimary { throw CancellationError() }
                        throw AnimeScheduleError.http(503)
                    },
                    animeSchedule: { throw URLError(.cancelled) },
                    mal: { usedMAL = true; throw AnimeScheduleError.unavailable },
                    permitsFallback: { _ in true }
                )
                XCTFail("Cancellation must propagate")
            } catch { XCTAssertTrue(error is CancellationError) }
            XCTAssertFalse(usedMAL)
        }
    }

    func testOrdinaryForbiddenResponseDoesNotAuthorizeFallback() async {
        var usedFallback = false
        do {
            _ = try await AnimeScheduleFallback.load(
                aniList: { throw NSError(domain: "AniList", code: 403) },
                animeSchedule: { usedFallback = true; throw AnimeScheduleError.unavailable },
                mal: { usedFallback = true; throw AnimeScheduleError.unavailable },
                permitsFallback: { error in
                    let health = AnimeProviderHealthCenter.shared
                    return health.shouldUseMALFallback(for: health.classifyAniListFailure(error))
                }
            )
            XCTFail("Forbidden must remain a failure")
        } catch { XCTAssertEqual((error as NSError).code, 403) }
        XCTAssertFalse(usedFallback)
    }

    func testWeekWindowsCoverThirtyDaysAndISOYearBoundary() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-31T23:00:00Z"))
        let weeks = AnimeScheduleWeek.covering(ScheduleDateWindow.envelope(dayCount: 30, now: date))
        XCTAssertEqual(weeks.first, AnimeScheduleWeek(year: 2026, week: 53))
        XCTAssertTrue(weeks.contains(AnimeScheduleWeek(year: 2027, week: 1)))
        XCTAssertEqual(Set(weeks).count, weeks.count)
        XCTAssertGreaterThanOrEqual(weeks.count, 5)
    }

    func testBatchReleasesHaveDistinctEpisodeIdentities() throws {
        let entries = try mapped(["subtractedEpisodeNumber": 3]).map(ScheduleEntry.init(animeEntry:))
        XCTAssertEqual(entries.map(\.episode), [3, 4, 5])
        XCTAssertEqual(Set(entries.map(\.id)).count, 3)
        XCTAssertEqual(entries.first?.animeMediaIDs, [101, -202])
        XCTAssertEqual(entries.first?.format, "TV")
        XCTAssertTrue(entries.allSatisfy(\.hasKnownAiringTime))
    }

    func testMapsOnlyEnglishDubRowsAndMarksDubOnlyProvider() throws {
        let entry = try XCTUnwrap(mapped().first)
        XCTAssertEqual(entry.scheduleProvider, .dubOnly)
        XCTAssertEqual(entry.malID, 202)
        XCTAssertTrue(try mapped(["airType": "sub"]).isEmpty)
    }

    func testRejectsInvalidEpisodesWrongAirTypeAndAdultRows() throws {
        for change: [String: Any] in [
            ["episodeNumber": 0], ["episodeNumber": 100_001], ["subtractedEpisodeNumber": 0],
            ["subtractedEpisodeNumber": 6], ["episodeNumber": 500, "subtractedEpisodeNumber": 1],
            ["episodeDate": "0001-01-01T00:00:00Z"], ["airType": "raw"], ["route": "../example-2"]
        ] { XCTAssertTrue(try mapped(change).isEmpty) }
        XCTAssertTrue(try mapped(animeChanges: ["genres": [["route": "hentai"]]]).isEmpty)
        XCTAssertTrue(try mapped(animeChanges: ["websites": [:]]).isEmpty)
    }

    func testCrossReferencesRequireExactHostAndAnimePath() {
        XCTAssertEqual(AnimeScheduleAnime.identifier("anilist.co/anime/101/title", host: "anilist.co"), 101)
        for text in ["https://anilist.co.evil.test/anime/101", "https://evil.test/anilist.co/anime/101", "https://anilist.co/manga/101", "https://anilist.co/anime/-101", "https://user@anilist.co/anime/101", "https://anilist.co/anime/99999999999999999"] {
            XCTAssertNil(AnimeScheduleAnime.identifier(text, host: "anilist.co"))
        }
    }

    func testMALOnlyMappingUsesExistingNegativeNamespace() throws {
        let entry = try XCTUnwrap(mapped(animeChanges: ["websites": ["mal": "myanimelist.net/anime/202/title"]]).first)
        XCTAssertEqual(entry.mediaId, -202)
    }

    func testDelayWithdrawsAirtimeButNormalSentinelDoesNot() throws {
        XCTAssertTrue(try XCTUnwrap(mapped().first).hasKnownAiringTime)
        let delayed = try XCTUnwrap(mapped(["airingStatus": "delayed-air"]).first)
        XCTAssertFalse(delayed.hasKnownAiringTime)
        XCTAssertTrue(delayed.airingTimeWithdrawn == true)
        let stale = try XCTUnwrap(mapped(stale: true).first)
        XCTAssertFalse(stale.hasKnownAiringTime)
        XCTAssertFalse(stale.airingTimeWithdrawn == true)
    }

    func testMovieAndONAFormatsRemainDistinctForSpecialFiltering() throws {
        XCTAssertEqual(try mapped(["mediaTypes": [["route": "movie-chinese"]]]).first?.format, "MOVIE")
        XCTAssertEqual(try mapped(["mediaTypes": [["route": "ona-chinese"]]]).first?.format, "ONA")
    }

    func testFetchPaginatesWeeksAndCachesWithoutDuplicateEpisodes() async throws {
        try stub()
        let session = session()
        defer { session.invalidateAndCancel() }
        let service = AnimeScheduleService(session: session, token: "fixture-token", requestSpacing: 0)
        let first = try await service.fetchSchedule(daysAhead: 7, now: now)
        let count = AnimeScheduleURLProtocol.count
        let second = try await service.fetchSchedule(daysAhead: 7, now: now)
        XCTAssertEqual(first.entries.count, 1)
        XCTAssertEqual(second.entries.count, 1)
        XCTAssertGreaterThan(count, 1)
        XCTAssertEqual(AnimeScheduleURLProtocol.count, count)
        XCTAssertFalse(first.isAuthoritativeForNotifications)
    }

    func testOngoingCatalogStopsPagingAfterEveryRequestedAnimeRouteIsFound() async throws {
        try stub(catalogTotalAmount: 10_000)
        let session = session()
        defer { session.invalidateAndCancel() }
        let service = AnimeScheduleService(session: session, token: "fixture-token", requestSpacing: 0)

        let result = try await service.fetchSchedule(daysAhead: 7, now: now)

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(
            AnimeScheduleURLProtocol.paths.filter { $0 == "/api/v3/anime" }.count,
            1,
            "The ongoing catalog should not fetch later pages after finding every route in the schedule window."
        )
    }

    func testMissingWeekRetainsConfirmedEntriesWithoutDeletionAuthority() async throws {
        try stub(missingWeek: true)
        let session = session()
        defer { session.invalidateAndCancel() }
        let service = AnimeScheduleService(session: session, token: "fixture-token", requestSpacing: 0)
        let result = try await service.fetchSchedule(daysAhead: 7, now: now)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertTrue(result.entries.first?.hasKnownAiringTime == true)
        XCTAssertFalse(result.isAuthoritativeForNotifications)
        XCTAssertTrue(result.notice?.contains("unavailable") == true)
    }

    func testDiskCacheSurvivesRelaunchWithoutInventingFreshNotificationAuthority() async throws {
        try stub()
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: cache) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let initial = AnimeScheduleService(session: session, token: "fixture-token", cacheURL: cache, requestSpacing: 0)
        _ = try await initial.fetchSchedule(daysAhead: 7, now: now)
        AnimeScheduleURLProtocol.configure { _ in (503, Data(), [:]) }
        let restored = AnimeScheduleService(session: session, token: "fixture-token", cacheURL: cache, requestSpacing: 0)
        let result = try await restored.fetchSchedule(daysAhead: 7, now: now.addingTimeInterval(3600))
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertFalse(result.entries.first?.hasKnownAiringTime == true)
        XCTAssertFalse(result.entries.first?.airingTimeWithdrawn == true)
        XCTAssertTrue(result.notice?.contains("Saved") == true)
        XCTAssertFalse(String(decoding: try Data(contentsOf: cache), as: UTF8.self).contains("fixture-token"))
    }

    func testUnconfiguredBuildDoesNotSendRequests() async {
        AnimeScheduleURLProtocol.configure { _ in (200, Data(), [:]) }
        do {
            _ = try await AnimeScheduleService(token: "$(ANIMESCHEDULE_API_TOKEN)").fetchSchedule(daysAhead: 7, now: now)
            XCTFail("Missing token must fail")
        } catch {}
        XCTAssertEqual(AnimeScheduleURLProtocol.count, 0)
    }

    func testRecoveryKeepsCanonicalEpisodeIdentityDespiteProviderTitleChange() throws {
        let fallback = try XCTUnwrap(mapped().first)
        var primary = try XCTUnwrap(mapped(["english": "Different provider spelling"]).first)
        primary.scheduleProvider = .aniList
        let a = ScheduleEntry(animeEntry: primary)
        let b = ScheduleEntry(animeEntry: fallback)
        XCTAssertEqual(a.id, b.id)
        XCTAssertTrue(a.isSameEpisode(as: b))
        XCTAssertNotEqual(a.title, b.title)
        XCTAssertNotEqual(a.provider, b.provider)
#if os(iOS)
        XCTAssertTrue(AnimeScheduleNotificationPolicy.matches(b, knownIDs: [101], aliases: []))
        XCTAssertTrue(AnimeScheduleNotificationPolicy.matches(b, knownIDs: [-202], aliases: []))
        XCTAssertFalse(AnimeScheduleNotificationPolicy.matches(b, knownIDs: [102], aliases: ["example second season"]))
#endif
    }

#if os(iOS)
    func testExplicitLegacyReminderAndMutesSurviveProviderSwitch() throws {
        let entry = ScheduleEntry(animeEntry: try XCTUnwrap(mapped().first))
        let reminder = LocalEpisodeNotificationReminder(id: "anime:title:old spelling:e5", source: .anime, sourceMediaID: 101, tmdbID: 77, tmdbMediaType: .tv, title: "Old spelling", season: nil, episode: 5, airingAt: now, hasKnownAiringTime: true, isStreamingRelease: false, isAnimeSpecial: false)
        XCTAssertEqual(AnimeScheduleNotificationPolicy.explicitKey(entry, reminders: [reminder]), reminder.id)
        let legacyMute = "subscription:title:example 2:s0:e5"
        XCTAssertEqual(AnimeScheduleNotificationPolicy.subscriptionKey(entry, subscriptionID: "subscription", existingKeys: [legacyMute]), legacyMute)
        let canonical = "subscription:media:101:e5"
        XCTAssertEqual(AnimeScheduleNotificationPolicy.subscriptionKey(entry, subscriptionID: "subscription", existingKeys: [canonical]), canonical)
    }

    func testChangedOrWithdrawnAirtimeReplacesOnlyMatchingPendingRequests() throws {
        let fresh = ScheduleEntry(animeEntry: try XCTUnwrap(mapped().first))
        let delayed = ScheduleEntry(animeEntry: try XCTUnwrap(mapped(["airingStatus": "delayed-air"]).first))
        let stale = ScheduleEntry(animeEntry: try XCTUnwrap(mapped(stale: true).first))
        let info: [AnyHashable: Any] = ["source": "anime", "sourceMediaID": 101, "episodeNumber": 5]
        XCTAssertTrue(AnimeScheduleNotificationPolicy.supersedes(info, entries: [fresh]))
        XCTAssertTrue(AnimeScheduleNotificationPolicy.supersedes(info, entries: [delayed]))
        XCTAssertFalse(AnimeScheduleNotificationPolicy.supersedes(info, entries: [stale]))
        XCTAssertFalse(AnimeScheduleNotificationPolicy.supersedes(["source": "anime", "sourceMediaID": 999, "episodeNumber": 5], entries: [fresh]))
        XCTAssertFalse(AnimeScheduleNotificationPolicy.supersedes(["source": "western", "sourceMediaID": 101, "episodeNumber": 5], entries: [fresh]))
        let batch: [AnyHashable: Any] = ["source": "anime", "sourceMediaID": 101, "episodeNumbers": [3, 4, 5]]
        XCTAssertFalse(AnimeScheduleNotificationPolicy.supersedes(batch, entries: [fresh]))
        XCTAssertTrue(AnimeScheduleNotificationPolicy.supersedes(batch, entries: try mapped(["subtractedEpisodeNumber": 3]).map(ScheduleEntry.init(animeEntry:))))
    }

    func testDelayedReminderSurvivesOriginalAirtimeAndRelaunchUntilRescheduled() throws {
        var reminder = LocalEpisodeNotificationReminder(id: "anime:media:101:e5", source: .anime, sourceMediaID: 101, tmdbID: 77, tmdbMediaType: .tv, title: "Example", season: nil, episode: 5, airingAt: now.addingTimeInterval(-3600), hasKnownAiringTime: false, isStreamingRelease: false, isAnimeSpecial: false)
        let restored = try JSONDecoder().decode(LocalEpisodeNotificationReminder.self, from: JSONEncoder().encode(reminder))
        XCTAssertFalse(restored.hasExpired(at: now))
        reminder.airingAt = now.addingTimeInterval(86400)
        reminder.hasKnownAiringTime = true
        XCTAssertFalse(reminder.hasExpired(at: now))
        XCTAssertTrue(reminder.hasExpired(at: now.addingTimeInterval(86401)))
    }
#endif

    func testUnmappedTimetableDoesNotBlockLastResortFallback() async throws {
        let timetable = try data([row()])
        let catalog = try data(["page": 1, "totalAmount": 1, "anime": [anime(["websites": [:]])]])
        AnimeScheduleURLProtocol.configure { request in
            (200, request.url?.path.contains("timetables") == true ? timetable : catalog, [:])
        }
        let session = session()
        defer { session.invalidateAndCancel() }
        do {
            _ = try await AnimeScheduleService(session: session, token: "fixture-token", requestSpacing: 0).fetchSchedule(daysAhead: 7, now: now)
            XCTFail("An unusable timetable must allow the next provider")
        } catch { XCTAssertTrue(error is AnimeScheduleError) }
    }

    func testProviderOutageStopsFurtherRequestsAndInvalidRateLimitHeadersAreBounded() async {
        for status in [401, 429, 503] {
            AnimeScheduleURLProtocol.configure { _ in (status, Data(), ["Retry-After": "nan", "X-RateLimit-Reset": "inf"]) }
            let session = session()
            let service = AnimeScheduleService(session: session, token: "fixture-token", requestSpacing: 0)
            do {
                _ = try await service.fetchSchedule(daysAhead: 30, now: now)
                XCTFail("An unavailable provider must fail")
            } catch {}
            XCTAssertEqual(AnimeScheduleURLProtocol.count, 1)
            if status == 429 {
                do { _ = try await service.fetchSchedule(daysAhead: 30, now: now) } catch {}
                XCTAssertEqual(AnimeScheduleURLProtocol.count, 1)
            }
            session.invalidateAndCancel()
        }
    }

    @MainActor
    func testLiveScheduleThroughProductionClientAndOutageFallback() async throws {
        guard ProcessInfo.processInfo.environment["ECLIPSE_RUN_LIVE_SCHEDULE_TESTS"] == "1" else {
            throw XCTSkip("Live API validation is opt-in")
        }
        let service = AnimeScheduleService()
        for days in [7, 30] {
            let started = Date()
            let result = try await AnimeScheduleFallback.load(
                aniList: { throw NSError(domain: "AniList", code: 503) },
                animeSchedule: { try await service.fetchSchedule(daysAhead: days) },
                mal: { XCTFail("Live DubOnly English schedule should serve the primary feed"); throw AnimeScheduleError.unavailable },
                permitsFallback: { error in
                    let health = AnimeProviderHealthCenter.shared
                    return health.shouldUseMALFallback(for: health.classifyAniListFailure(error))
                }
            )
            XCTAssertFalse(result.entries.isEmpty)
            XCTAssertTrue(result.entries.allSatisfy { $0.scheduleProvider == .dubOnly && $0.mediaId != 0 })
            XCTAssertEqual(Set(result.entries.map(\.id)).count, result.entries.count)
            let entries = result.entries.map(ScheduleEntry.init(animeEntry:))
            XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
            XCTAssertTrue(entries.contains( where: \.hasKnownAiringTime))
#if os(iOS)
            let entry = try XCTUnwrap(entries.first)
            XCTAssertTrue(AnimeScheduleNotificationPolicy.matches(entry, knownIDs: entry.animeMediaIDs, aliases: []))
#endif
            print("DubOnly live: days=\(days) entries=\(entries.count) confirmed=\(entries.filter(\.hasKnownAiringTime).count) elapsed=\(Int(Date().timeIntervalSince(started)))s notice=\(result.notice ?? "")")
        }
        let result = try await AniListService.shared.fetchAiringScheduleResult(daysAhead: 7)
        XCTAssertFalse(result.entries.isEmpty)
        XCTAssertTrue(result.entries.contains( where: \.hasKnownAiringTime))
        print("AnimeSchedule live: shared schedule facade entries=\(result.entries.count) provider=\(result.entries.first?.scheduleProvider?.rawValue ?? "aniList")")
        let model = ScheduleViewModel()
        await model.loadSchedule(mode: .anime, localTimeZone: true)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.scheduleEntries.isEmpty)
        XCTAssertTrue(model.dayBuckets.contains { !$0.items.isEmpty })
        let snapshot = await model.notificationScheduleSnapshot(dayCount: 7, requiredSources: [.anime])
        XCTAssertTrue(snapshot.successfulSources.contains(.anime))
        XCTAssertFalse(snapshot.entries.isEmpty)
        if snapshot.entries.contains(where: { $0.provider == .dubOnly }) {
            XCTAssertFalse(snapshot.authoritativeSources.contains(.anime))
            XCTAssertNotNil(model.scheduleNotice)
        }
        let entry = try XCTUnwrap(model.scheduleEntries.first { $0.title.lowercased().contains("one piece") } ?? model.scheduleEntries.first)
        let detail = await model.lookupTMDBResult(for: entry)
        XCTAssertNotNil(detail)
        print("AnimeSchedule live: calendar buckets=\(model.dayBuckets.count) notification entries=\(snapshot.entries.count) title navigation=\(detail != nil)")
    }
}


final class AnimeDubEpisodeVisibilityTests: XCTestCase {
    func testSelectedLanguagesUseORLogicAndExposeOnlyReportedEpisodePrefix() {
        let selected: Set<String> = [
            MyDubListLanguage.english.rawValue,
            MyDubListLanguage.spanish.rawValue
        ]
        let counts = ["en": 3, "es": 7]

        XCTAssertEqual(
            AnimeDubEpisodeVisibilityPolicy.availableEpisodeLimit(
                selectedLanguages: selected,
                dubCountsByLanguage: counts
            ),
            7
        )
        XCTAssertTrue(AnimeDubEpisodeVisibilityPolicy.includes(
            episodeNumber: 7,
            selectedLanguages: selected,
            dubCountsByLanguage: counts
        ))
        XCTAssertFalse(AnimeDubEpisodeVisibilityPolicy.includes(
            episodeNumber: 8,
            selectedLanguages: selected,
            dubCountsByLanguage: counts
        ))
    }

    func testMissingDubMetadataFailsClosedWhenFilterIsEnabled() {
        let selected: Set<String> = [MyDubListLanguage.english.rawValue]

        XCTAssertEqual(
            AnimeDubEpisodeVisibilityPolicy.availableEpisodeLimit(
                selectedLanguages: selected,
                dubCountsByLanguage: [:]
            ),
            0
        )
        XCTAssertFalse(AnimeDubEpisodeVisibilityPolicy.includes(
            episodeNumber: 1,
            selectedLanguages: selected,
            dubCountsByLanguage: [:]
        ))
    }

    func testNoSelectedLanguagesLeavesEpisodeVisibilityUnfiltered() {
        XCTAssertNil(AnimeDubEpisodeVisibilityPolicy.availableEpisodeLimit(
            selectedLanguages: [],
            dubCountsByLanguage: [:]
        ))
        XCTAssertTrue(AnimeDubEpisodeVisibilityPolicy.includes(
            episodeNumber: 1,
            selectedLanguages: [],
            dubCountsByLanguage: [:]
        ))
    }

    func testSpanishOptionUsesRegionalAndGenericSpanishMetadataTags() {
        XCTAssertEqual(MyDubListLanguage.spanish.taizenLanguageCode, "es")
        XCTAssertEqual(
            MyDubListLanguage.spanish.episodeMetadataLanguageCodes,
            ["es-419", "es-es", "es"]
        )
        XCTAssertEqual(MyDubListLanguage.english.episodeMetadataLanguageCodes, ["en"])
    }

    func testAnidubParserKeepsRegionalCountsAndIgnoresStaleOrUnreleasedRows() throws {
        let payload: [String: Any] = [
            "anilistId": 101,
            "dubs": [
                ["language": "es-419", "status": "dubbed", "dubbedEpisodes": 8, "stale": false],
                ["language": "es-ES", "status": "dubbed", "dubbedEpisodes": 5, "stale": false],
                ["language": "en", "status": "in_production", "dubbedEpisodes": 2, "stale": false],
                ["language": "es", "status": "dubbed", "dubbedEpisodes": 12, "stale": true],
                ["language": "es-419", "status": "dubbed", "dubbedEpisodes": NSNull(), "stale": false]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let counts = try AnidubAnimeDubMetadataService.parseEpisodeDubCounts(
            from: data,
            anilistID: 101
        )

        XCTAssertEqual(counts["es-419"], 8)
        XCTAssertEqual(counts["es-es"], 5)
        XCTAssertNil(counts["en"])
        XCTAssertNil(counts["es"])
    }

    func testAnidubParserRejectsMismatchedAnimeIdentity() throws {
        let payload: [String: Any] = [
            "anilistId": 202,
            "dubs": [
                ["language": "es-419", "status": "dubbed", "dubbedEpisodes": 8, "stale": false]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        XCTAssertThrowsError(
            try AnidubAnimeDubMetadataService.parseEpisodeDubCounts(from: data, anilistID: 101)
        )
    }
}

final class StremioDownloadRefreshPolicyTests: XCTestCase {
    func testEmptyAddonResponseIsRetriedDuringDownloadRefresh() {
        XCTAssertTrue(
            StremioClient.shouldRetryNoPlayableResponse(
                allStreams: [],
                safeStreams: []
            )
        )
    }
}


final class AnimeSpecialDubFilterPolicyTests: XCTestCase {
    func testNoSelectedLanguagesLeavesSpecialsAndOVAsVisible() {
        XCTAssertTrue(AnimeSpecialDubFilterPolicy.shouldInclude(
            selectedLanguages: [],
            isVerifiedForSelection: false
        ))
    }

    func testSelectedLanguageHidesUnverifiedSpecialsAndOVAs() {
        XCTAssertFalse(AnimeSpecialDubFilterPolicy.shouldInclude(
            selectedLanguages: ["english"],
            isVerifiedForSelection: false
        ))
    }

    func testSelectedLanguageIncludesVerifiedSpecialsAndOVAs() {
        XCTAssertTrue(AnimeSpecialDubFilterPolicy.shouldInclude(
            selectedLanguages: ["english", "spanish"],
            isVerifiedForSelection: true
        ))
    }
}


final class UnifiedSpanishAndDubSchedulePolicyTests: XCTestCase {
    func testSpanishRegionalVariantsShareOneFilterLanguage() {
        for variant in ["es", "es-ES", "es-419", "es-MX", "Castellano", "Español latino", "Spanish"] {
            XCTAssertEqual(MediaLanguageCatalog.filterCanonicalID(for: variant), "es", "Expected \(variant) to normalize to Spanish")
        }
        XCTAssertTrue(MediaLanguageCatalog.matches(ruleID: "es", languageID: "es-419"))
        XCTAssertTrue(MediaLanguageCatalog.matches(ruleID: "es", languageID: "es-ES"))
    }

    func testDuplicateEpisodeKeepsEarlierDubRelease() {
        let earlier = AniListAiringScheduleEntry(
            id: 1, mediaId: 101, title: "Example", airingAt: Date(timeIntervalSince1970: 100),
            episode: 4, coverImage: nil, englishTitle: "Example", romajiTitle: nil,
            nativeTitle: nil, format: "TV", hasKnownAiringTime: true,
            scheduleProvider: .dubOnly, malID: nil, airingTimeWithdrawn: false
        )
        let later = AniListAiringScheduleEntry(
            id: 2, mediaId: 101, title: "Example", airingAt: Date(timeIntervalSince1970: 200),
            episode: 4, coverImage: nil, englishTitle: "Example", romajiTitle: nil,
            nativeTitle: nil, format: "TV", hasKnownAiringTime: true,
            scheduleProvider: .dubOnly, malID: nil, airingTimeWithdrawn: false
        )
        XCTAssertFalse(AnimeScheduleEntryMapper.shouldReplaceDuplicate(existing: earlier, candidate: later))
        XCTAssertTrue(AnimeScheduleEntryMapper.shouldReplaceDuplicate(existing: later, candidate: earlier))
    }

    func testConfirmedDuplicateWinsWhenAiringDatesMatch() {
        let withdrawn = AniListAiringScheduleEntry(
            id: 1, mediaId: 101, title: "Example", airingAt: Date(timeIntervalSince1970: 100),
            episode: 4, coverImage: nil, englishTitle: nil, romajiTitle: nil,
            nativeTitle: nil, format: "TV", hasKnownAiringTime: false,
            scheduleProvider: .dubOnly, malID: nil, airingTimeWithdrawn: true
        )
        let confirmed = AniListAiringScheduleEntry(
            id: 2, mediaId: 101, title: "Example", airingAt: Date(timeIntervalSince1970: 100),
            episode: 4, coverImage: nil, englishTitle: nil, romajiTitle: nil,
            nativeTitle: nil, format: "TV", hasKnownAiringTime: true,
            scheduleProvider: .dubOnly, malID: nil, airingTimeWithdrawn: false
        )
        XCTAssertTrue(AnimeScheduleEntryMapper.shouldReplaceDuplicate(existing: withdrawn, candidate: confirmed))
        XCTAssertFalse(AnimeScheduleEntryMapper.shouldReplaceDuplicate(existing: confirmed, candidate: withdrawn))
    }
}


final class AnimeScheduleLanguageLookupPolicyTests: XCTestCase {
    func testAniListOriginCountryMapsOnlyEnglishAndSpanishNativeLanguages() {
        XCTAssertEqual(AnimeOriginalLanguagePolicy.languageCode(forCountry: "US"), "en")
        XCTAssertEqual(AnimeOriginalLanguagePolicy.languageCode(forCountry: "ES"), "es")
        XCTAssertNil(AnimeOriginalLanguagePolicy.languageCode(forCountry: "JP"))
        XCTAssertNil(AnimeOriginalLanguagePolicy.languageCode(forCountry: "CA"))
        XCTAssertNil(AnimeOriginalLanguagePolicy.languageCode(forCountry: nil))
    }

    func testNativeLanguageScheduleOnlyIncludesMatchingLanguages() {
        XCTAssertTrue(ScheduleAudioLanguagePolicy.matches(originalLanguage: "en", selectedLanguages: ["english"]))
        XCTAssertTrue(ScheduleAudioLanguagePolicy.matches(originalLanguage: "es-MX", selectedLanguages: ["spanish"]))
        XCTAssertFalse(ScheduleAudioLanguagePolicy.matches(originalLanguage: "ja", selectedLanguages: ["english"]))
        XCTAssertFalse(ScheduleAudioLanguagePolicy.matches(originalLanguage: nil, selectedLanguages: ["spanish"]))
    }

    func testNoSelectedLanguageLeavesScheduleUnfiltered() {
        XCTAssertTrue(ScheduleAudioLanguagePolicy.matches(originalLanguage: "ja", selectedLanguages: []))
    }
}

final class ScheduleReleaseDatePolicyTests: XCTestCase {
    func testEarlierNativeReleaseWinsOverLaterDub() {
        let native = Date(timeIntervalSince1970: 100)
        let dubbed = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(ScheduleReleaseDatePolicy.earliest(native: native, dubbed: dubbed), native)
        XCTAssertFalse(ScheduleReleaseDatePolicy.usesDubbedDate(native: native, dubbed: dubbed))
    }

    func testEarlierDubReleaseWinsOverLaterNative() {
        let native = Date(timeIntervalSince1970: 200)
        let dubbed = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(ScheduleReleaseDatePolicy.earliest(native: native, dubbed: dubbed), dubbed)
        XCTAssertTrue(ScheduleReleaseDatePolicy.usesDubbedDate(native: native, dubbed: dubbed))
    }

    func testSingleAvailableLanguageDateIsKept() {
        let native = Date(timeIntervalSince1970: 100)
        let dubbed = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(ScheduleReleaseDatePolicy.earliest(native: native, dubbed: nil), native)
        XCTAssertEqual(ScheduleReleaseDatePolicy.earliest(native: nil, dubbed: dubbed), dubbed)
    }

    func testConfirmedDateBeatsEarlierWithdrawnOrEstimatedDate() {
        XCTAssertTrue(ScheduleReleaseDatePolicy.shouldPrefer(
            candidateDate: Date(timeIntervalSince1970: 200),
            candidateIsConfirmed: true,
            over: Date(timeIntervalSince1970: 100),
            existingIsConfirmed: false
        ))
        XCTAssertFalse(ScheduleReleaseDatePolicy.shouldPrefer(
            candidateDate: Date(timeIntervalSince1970: 100),
            candidateIsConfirmed: false,
            over: Date(timeIntervalSince1970: 200),
            existingIsConfirmed: true
        ))
    }

    func testEarlierDateWinsWhenBothScheduleDatesAreConfirmed() {
        XCTAssertTrue(ScheduleReleaseDatePolicy.shouldPrefer(
            candidateDate: Date(timeIntervalSince1970: 100),
            candidateIsConfirmed: true,
            over: Date(timeIntervalSince1970: 200),
            existingIsConfirmed: true
        ))
        XCTAssertFalse(ScheduleReleaseDatePolicy.shouldPrefer(
            candidateDate: Date(timeIntervalSince1970: 200),
            candidateIsConfirmed: true,
            over: Date(timeIntervalSince1970: 100),
            existingIsConfirmed: true
        ))
    }

    func testSpanishDubResearchConfirmsDateWithoutClaimingClockTime() {
        XCTAssertTrue(ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
            provider: .aiSpanishDub,
            hasKnownAiringTime: false,
            airingTimeWithdrawn: false
        ))
        XCTAssertFalse(ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
            provider: .aiSpanishDub,
            hasKnownAiringTime: false,
            airingTimeWithdrawn: true
        ))
        XCTAssertFalse(ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
            provider: .dubOnly,
            hasKnownAiringTime: false,
            airingTimeWithdrawn: false
        ))
        XCTAssertTrue(ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
            provider: .dubOnly,
            hasKnownAiringTime: true,
            airingTimeWithdrawn: false
        ))
    }

    func testNoQualifyingLanguageDateIsExcluded() {
        XCTAssertNil(ScheduleReleaseDatePolicy.earliest(native: nil, dubbed: nil))
        XCTAssertFalse(ScheduleReleaseDatePolicy.usesDubbedDate(native: nil, dubbed: nil))
    }

    func testNativeLanguageEntryIsAttributedToNativeLanguageProvider() {
        let airing = AniListAiringScheduleEntry(
            id: 1, mediaId: 101, title: "Example Anime",
            airingAt: Date(timeIntervalSince1970: 100), episode: 1,
            coverImage: nil, englishTitle: "Example Anime", romajiTitle: nil,
            nativeTitle: nil, format: "TV", hasKnownAiringTime: true,
            scheduleProvider: .aniList, malID: nil, airingTimeWithdrawn: false,
            originalLanguage: "en"
        )
        let entry = ScheduleEntry(animeEntry: airing).markedAsNativeLanguageMatch()
        XCTAssertEqual(entry.provider, .nativeLanguage)
        XCTAssertFalse(entry.isStreamingRelease)
    }
}


final class NonAnimeMovieSchedulePolicyTests: XCTestCase {

    func testMoviesIsASeparatePersistableScheduleMode() {
        XCTAssertEqual(ScheduleMode.sanitized("movies"), .movies)
        XCTAssertEqual(ScheduleMode.movies.displayName, "Movies")
    }
    func testJapaneseAnimationIsExcludedFromMovieSchedule() {
        XCTAssertTrue(MovieSchedulePolicy.isAnime(language: "ja", genres: ["animation"]))
    }

    func testAnimeGenreIsExcludedEvenWhenLanguageIsNotJapanese() {
        XCTAssertTrue(MovieSchedulePolicy.isAnime(language: "es", genres: ["anime"]))
    }

    func testWesternAnimationRemainsInMovieSchedule() {
        XCTAssertFalse(MovieSchedulePolicy.isAnime(language: "en", genres: ["animation"]))
    }

    func testLiveActionMoviesRemainInMovieSchedule() {
        XCTAssertFalse(MovieSchedulePolicy.isAnime(language: "ko", genres: ["drama", "thriller"]))
    }
}

final class CatalogNativeAudioPolicyTests: XCTestCase {
    func testNativeEnglishDoesNotNeedDubLookup() {
        XCTAssertTrue(CatalogNativeAudioPolicy.hasEnglishOrSpanishAudio("en"))
        XCTAssertTrue(CatalogNativeAudioPolicy.hasEnglishOrSpanishAudio("EN-US"))
    }

    func testNativeSpanishDoesNotNeedDubLookup() {
        XCTAssertTrue(CatalogNativeAudioPolicy.hasEnglishOrSpanishAudio("es"))
        XCTAssertTrue(CatalogNativeAudioPolicy.hasEnglishOrSpanishAudio("es-MX"))
    }

    func testJapaneseStillRequiresVerifiedDubEvidence() {
        XCTAssertFalse(CatalogNativeAudioPolicy.hasEnglishOrSpanishAudio("ja"))
    }

    func testUnknownAudioDoesNotQualifyAsNativeEnglishOrSpanish() {
        XCTAssertFalse(CatalogNativeAudioPolicy.hasEnglishOrSpanishAudio(nil))
        XCTAssertFalse(CatalogNativeAudioPolicy.hasEnglishOrSpanishAudio(""))
    }
}


final class ScheduleAllAgesFilterPolicyTests: XCTestCase {
    func testExplicitGeneralAudienceRatingIsExcludedWhenFilterIsEnabled() {
        XCTAssertTrue(ScheduleAllAgesPolicy.shouldExclude(rating: .general, enabled: true))
    }

    func testTeenAndOlderRatingsRemainVisible() {
        XCTAssertFalse(ScheduleAllAgesPolicy.shouldExclude(rating: .teen, enabled: true))
        XCTAssertFalse(ScheduleAllAgesPolicy.shouldExclude(rating: .mature, enabled: true))
        XCTAssertFalse(ScheduleAllAgesPolicy.shouldExclude(rating: .adult, enabled: true))
    }

    func testUnknownOrMissingRatingIsNotMisclassifiedAsAllAges() {
        XCTAssertFalse(ScheduleAllAgesPolicy.shouldExclude(rating: .unknown, enabled: true))
        XCTAssertFalse(ScheduleAllAgesPolicy.shouldExclude(rating: nil, enabled: true))
    }

    func testDisabledFilterKeepsGeneralAudienceTitles() {
        XCTAssertFalse(ScheduleAllAgesPolicy.shouldExclude(rating: .general, enabled: false))
    }
}


final class AnimeDubAudioSelectionPolicyTests: XCTestCase {
    func testSpanishOnlySelectionDoesNotAcceptEnglishOnlyDub() {
        XCTAssertFalse(AnimeDubAudioSelectionPolicy.hasSelectedAudio(
            selectedLanguages: ["spanish"],
            dubCountsByLanguage: ["en": 12]
        ))
    }

    func testEnglishOnlySelectionDoesNotAcceptSpanishOnlyDub() {
        XCTAssertFalse(AnimeDubAudioSelectionPolicy.hasSelectedAudio(
            selectedLanguages: ["english"],
            dubCountsByLanguage: ["es": 12]
        ))
    }

    func testCombinedSelectionUsesOrLogic() {
        XCTAssertTrue(AnimeDubAudioSelectionPolicy.hasSelectedAudio(
            selectedLanguages: ["english", "spanish"],
            dubCountsByLanguage: ["en": 1]
        ))
        XCTAssertTrue(AnimeDubAudioSelectionPolicy.hasSelectedAudio(
            selectedLanguages: ["english", "spanish"],
            dubCountsByLanguage: ["es-419": 1]
        ))
    }

    func testSpanishRegionalVariantsAreEquivalent() {
        XCTAssertTrue(AnimeDubAudioSelectionPolicy.hasSelectedAudio(
            selectedLanguages: ["spanish"],
            dubCountsByLanguage: ["es-es": 4]
        ))
    }
}

final class CatalogNativeAudioDubVerificationTests: XCTestCase {
    func testSpanishOriginalStillChecksForEnglishDubWhenEnglishIsSelected() {
        XCTAssertTrue(CatalogNativeAudioPolicy.requiresDubVerification(
            originalLanguage: "es-ES",
            selectedLanguages: ["english"]
        ))
    }

    func testEnglishOriginalStillChecksForSpanishDubWhenSpanishIsSelected() {
        XCTAssertTrue(CatalogNativeAudioPolicy.requiresDubVerification(
            originalLanguage: "en-US",
            selectedLanguages: ["spanish"]
        ))
    }

    func testNativeAudioSkipsDubLookupWhenItMatchesSelection() {
        XCTAssertFalse(CatalogNativeAudioPolicy.requiresDubVerification(
            originalLanguage: "en-GB",
            selectedLanguages: ["english"]
        ))
        XCTAssertFalse(CatalogNativeAudioPolicy.requiresDubVerification(
            originalLanguage: "es-MX",
            selectedLanguages: ["spanish"]
        ))
    }

    func testForeignOriginalAlwaysRequiresSelectedDubVerification() {
        XCTAssertTrue(CatalogNativeAudioPolicy.requiresDubVerification(
            originalLanguage: "ja",
            selectedLanguages: ["english", "spanish"]
        ))
    }
}

final class CatalogNativeAudioSelectionTests: XCTestCase {
    func testEnglishNativeAudioDoesNotSatisfySpanishOnlySelection() {
        XCTAssertFalse(ScheduleAudioLanguagePolicy.matches(
            originalLanguage: "en-US",
            selectedLanguages: ["spanish"]
        ))
    }

    func testSpanishNativeAudioDoesNotSatisfyEnglishOnlySelection() {
        XCTAssertFalse(ScheduleAudioLanguagePolicy.matches(
            originalLanguage: "es-ES",
            selectedLanguages: ["english"]
        ))
    }

    func testSpanishRegionalVariantsMatchCombinedSpanishSelection() {
        XCTAssertTrue(ScheduleAudioLanguagePolicy.matches(
            originalLanguage: "es-MX",
            selectedLanguages: ["spanish"]
        ))
    }

    func testEnglishNativeAudioMatchesEnglishSelection() {
        XCTAssertTrue(ScheduleAudioLanguagePolicy.matches(
            originalLanguage: "en-GB",
            selectedLanguages: ["english"]
        ))
    }
}


final class AnimeScheduleProviderLanguagePolicyTests: XCTestCase {
    func testNativeLanguageRowsMustMatchTheSelectedLanguage() {
        XCTAssertTrue(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .nativeLanguage,
            originalLanguage: "en",
            selectedLanguages: ["english"]
        ) == true)
        XCTAssertFalse(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .nativeLanguage,
            originalLanguage: "es-MX",
            selectedLanguages: ["english"]
        ) == true)
        XCTAssertTrue(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .nativeLanguage,
            originalLanguage: "es-ES",
            selectedLanguages: ["spanish"]
        ) == true)
    }

    func testSpanishAIResearchRowsNeverAppearInEnglishOnlySchedule() {
        XCTAssertTrue(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .aiSpanishDub,
            originalLanguage: nil,
            selectedLanguages: ["spanish"]
        ) == true)
        XCTAssertFalse(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .aiSpanishDub,
            originalLanguage: nil,
            selectedLanguages: ["english"]
        ) == true)
    }

    func testEnglishDubTimetablesNeverAppearInSpanishOnlySchedule() {
        XCTAssertTrue(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .dubOnly,
            originalLanguage: nil,
            selectedLanguages: ["english"]
        ) == true)
        XCTAssertFalse(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .tsuzuki,
            originalLanguage: nil,
            selectedLanguages: ["spanish"]
        ) == true)
    }

    func testUnverifiedProvidersFallThroughToTitleLevelVerification() {
        XCTAssertNil(AnimeScheduleProviderLanguagePolicy.includes(
            provider: .aniList,
            originalLanguage: "ja",
            selectedLanguages: ["english"]
        ))
    }
}


final class EnglishDubScheduleMergeTests: XCTestCase {
    private func entry(
        date: TimeInterval,
        known: Bool,
        provider: ScheduleProvider
    ) -> AniListAiringScheduleEntry {
        AniListAiringScheduleEntry(
            id: Int(date),
            mediaId: 101,
            title: "Example Anime",
            airingAt: Date(timeIntervalSince1970: date),
            episode: 4,
            coverImage: nil,
            englishTitle: "Example Anime",
            romajiTitle: nil,
            nativeTitle: nil,
            format: "TV",
            hasKnownAiringTime: known,
            scheduleProvider: provider,
            malID: nil,
            airingTimeWithdrawn: !known
        )
    }

    func testEarlierConfirmedFallbackDateReplacesLaterPrimaryDate() {
        let primary = entry(date: 200, known: true, provider: .dubOnly)
        let fallback = entry(date: 100, known: true, provider: .tsuzuki)
        let result = AnimeScheduleFallback.mergeEnglishDubSchedules(
            primary: AnimeAiringScheduleResult(entries: [primary], isAuthoritativeForNotifications: true),
            fallback: AnimeAiringScheduleResult(entries: [fallback], isAuthoritativeForNotifications: true)
        )
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries.first?.airingAt, fallback.airingAt)
        XCTAssertEqual(result.entries.first?.scheduleProvider, .tsuzuki)
    }

    func testLaterConfirmedFallbackDoesNotReplaceEarlierPrimaryDate() {
        let primary = entry(date: 100, known: true, provider: .dubOnly)
        let fallback = entry(date: 200, known: true, provider: .tsuzuki)
        let result = AnimeScheduleFallback.mergeEnglishDubSchedules(
            primary: AnimeAiringScheduleResult(entries: [primary], isAuthoritativeForNotifications: true),
            fallback: AnimeAiringScheduleResult(entries: [fallback], isAuthoritativeForNotifications: true)
        )
        XCTAssertEqual(result.entries.first?.airingAt, primary.airingAt)
        XCTAssertEqual(result.entries.first?.scheduleProvider, .dubOnly)
    }

    func testConfirmedPrimaryDateBeatsUnconfirmedFallback() {
        let primary = entry(date: 100, known: true, provider: .dubOnly)
        let fallback = entry(date: 50, known: false, provider: .tsuzuki)
        let result = AnimeScheduleFallback.mergeEnglishDubSchedules(
            primary: AnimeAiringScheduleResult(entries: [primary], isAuthoritativeForNotifications: true),
            fallback: AnimeAiringScheduleResult(entries: [fallback], isAuthoritativeForNotifications: true)
        )
        XCTAssertEqual(result.entries.first?.airingAt, primary.airingAt)
        XCTAssertEqual(result.entries.first?.scheduleProvider, .dubOnly)
    }

    func testConfirmedFallbackReplacesUnconfirmedPrimary() {
        let primary = entry(date: 200, known: false, provider: .dubOnly)
        let fallback = entry(date: 100, known: true, provider: .tsuzuki)
        let result = AnimeScheduleFallback.mergeEnglishDubSchedules(
            primary: AnimeAiringScheduleResult(entries: [primary], isAuthoritativeForNotifications: true),
            fallback: AnimeAiringScheduleResult(entries: [fallback], isAuthoritativeForNotifications: true)
        )
        XCTAssertEqual(result.entries.first?.airingAt, fallback.airingAt)
        XCTAssertEqual(result.entries.first?.scheduleProvider, .tsuzuki)
    }
}

final class AnimeScheduleCatalogScanPolicyTests: XCTestCase {
    func testGlobalCatalogWarmupStopsAfterFourPagesWhenRoutesAreStillMissing() {
        XCTAssertTrue(AnimeScheduleCatalogScanPolicy.shouldContinue(
            page: 1, totalAmount: 900, receivedCount: 18, allWantedRoutesResolved: false
        ))
        XCTAssertTrue(AnimeScheduleCatalogScanPolicy.shouldContinue(
            page: 3, totalAmount: 900, receivedCount: 18, allWantedRoutesResolved: false
        ))
        XCTAssertFalse(AnimeScheduleCatalogScanPolicy.shouldContinue(
            page: 4, totalAmount: 900, receivedCount: 18, allWantedRoutesResolved: false
        ))
    }

    func testGlobalCatalogWarmupStopsAsSoonAsAllRequestedRoutesAreResolved() {
        XCTAssertFalse(AnimeScheduleCatalogScanPolicy.shouldContinue(
            page: 1, totalAmount: 900, receivedCount: 18, allWantedRoutesResolved: true
        ))
    }

    func testGlobalCatalogWarmupStopsWhenTheProviderHasNoMorePages() {
        XCTAssertFalse(AnimeScheduleCatalogScanPolicy.shouldContinue(
            page: 1, totalAmount: 18, receivedCount: 18, allWantedRoutesResolved: false
        ))
        XCTAssertFalse(AnimeScheduleCatalogScanPolicy.shouldContinue(
            page: 1, totalAmount: 900, receivedCount: 0, allWantedRoutesResolved: false
        ))
        XCTAssertTrue(AnimeScheduleCatalogScanPolicy.catalogIsExhausted(
            page: 1, totalAmount: 18, receivedCount: 18
        ))
        XCTAssertTrue(AnimeScheduleCatalogScanPolicy.catalogIsExhausted(
            page: 1, totalAmount: 900, receivedCount: 0
        ))
        XCTAssertFalse(AnimeScheduleCatalogScanPolicy.catalogIsExhausted(
            page: 4, totalAmount: 900, receivedCount: 18
        ))
    }
}

