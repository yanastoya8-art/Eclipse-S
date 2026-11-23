import Foundation
import Security

/// Selects the earliest confirmed release date among the user's qualifying
/// native-language and dubbed release dates. Missing dates never become
/// synthetic broadcast dates.
enum ScheduleReleaseDatePolicy {
    static func earliest(native: Date?, dubbed: Date?) -> Date? {
        [native, dubbed].compactMap { $0 }.min()
    }

    static func isConfirmedReleaseDate(
        provider: ScheduleProvider?,
        hasKnownAiringTime: Bool,
        airingTimeWithdrawn: Bool
    ) -> Bool {
        guard !airingTimeWithdrawn else { return false }
        // AI research confirms a calendar date from a cited announcement, but
        // intentionally has no clock time. Do not mistake that for an unknown date.
        if provider == .aiSpanishDub { return true }
        return hasKnownAiringTime
    }

    static func shouldPrefer(
        candidateDate: Date,
        candidateIsConfirmed: Bool,
        over existingDate: Date,
        existingIsConfirmed: Bool
    ) -> Bool {
        if candidateIsConfirmed != existingIsConfirmed {
            return candidateIsConfirmed
        }
        return candidateDate < existingDate
    }

    static func usesDubbedDate(native: Date?, dubbed: Date?) -> Bool {
        guard let dubbed else { return false }
        guard let native else { return true }
        return dubbed < native
    }
}

enum AnimeScheduleError: Error, LocalizedError {
    case unconfigured
    case invalidResponse
    case http(Int)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unconfigured: return "AnimeSchedule.net's public timetable API is not configured for this request."
        case .invalidResponse: return "The DubOnly English dub schedule returned an invalid response."
        case .http(let status): return "DubOnly English dub schedule request failed (HTTP \(status))."
        case .unavailable: return "DubOnly has no available English dub timetable for these dates."
        }
    }
}

enum AnimeScheduleCatalogScanPolicy {
    static let pageSize = 18
    static let maximumWarmupPages = 4

    static func catalogIsExhausted(page: Int, totalAmount: Int, receivedCount: Int) -> Bool {
        page >= 1 && (receivedCount == 0 || page * pageSize >= totalAmount)
    }

    static func shouldContinue(
        page: Int,
        totalAmount: Int,
        receivedCount: Int,
        allWantedRoutesResolved: Bool
    ) -> Bool {
        guard page >= 1,
              page < maximumWarmupPages,
              totalAmount > page * pageSize,
              receivedCount > 0,
              !allWantedRoutesResolved else { return false }
        return true
    }
}

struct AnimeScheduleWeek: Hashable, Codable {
    let year: Int
    let week: Int

    var key: String { "\(year)-\(week)" }

    static func covering(_ window: DateInterval) -> [AnimeScheduleWeek] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard var date = calendar.dateInterval(of: .weekOfYear, for: window.start)?.start else { return [] }
        var weeks: [AnimeScheduleWeek] = []
        while date < window.end, weeks.count < 7 {
            weeks.append(AnimeScheduleWeek(
                year: calendar.component(.yearForWeekOfYear, from: date),
                week: calendar.component(.weekOfYear, from: date)
            ))
            guard let next = calendar.date(byAdding: .day, value: 7, to: date), next > date else { break }
            date = next
        }
        return weeks
    }
}

struct AnimeScheduleCategory: Codable {
    let name: String?
    let route: String
}

struct AnimeScheduleTimetableEntry: Codable {
    let title: String
    let route: String
    let romaji: String?
    let english: String?
    let native: String?
    let episodeDate: String
    let episodeNumber: Int
    let subtractedEpisodeNumber: Int?
    let episodes: Int?
    let airType: String
    let airingStatus: String?
    let delayedFrom: String?
    let delayedUntil: String?
    let mediaTypes: [AnimeScheduleCategory]?
    let imageVersionRoute: String?
}

struct AnimeScheduleAnime: Codable {
    struct Websites: Codable {
        let aniList: String?
        let mal: String?
    }

    let route: String
    let websites: Websites?
    let genres: [AnimeScheduleCategory]?

    var aniListID: Int? { Self.identifier(websites?.aniList, host: "anilist.co") }
    var malID: Int? { Self.identifier(websites?.mal, host: "myanimelist.net") }

    var isAdult: Bool {
        genres?.contains { ["hentai", "adult", "erotica"].contains($0.route.lowercased()) } == true
    }

    static func identifier(_ text: String?, host: String) -> Int? {
        guard let text, text.utf8.count <= 2048,
              let url = URL(string: text.contains("://") ? text : "https://" + text),
              [host, "www." + host].contains(url.host?.lowercased() ?? ""),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.user == nil, url.password == nil else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "anime", let id = Int(parts[1]),
              id > 0, id <= 1_000_000_000 else { return nil }
        return id
    }
}

enum AnimeScheduleEntryMapper {
    static func shouldReplaceDuplicate(
        existing: AniListAiringScheduleEntry,
        candidate: AniListAiringScheduleEntry
    ) -> Bool {
        ScheduleReleaseDatePolicy.shouldPrefer(
            candidateDate: candidate.airingAt,
            candidateIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                provider: candidate.scheduleProvider,
                hasKnownAiringTime: candidate.hasKnownAiringTime,
                airingTimeWithdrawn: candidate.airingTimeWithdrawn == true
            ),
            over: existing.airingAt,
            existingIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                provider: existing.scheduleProvider,
                hasKnownAiringTime: existing.hasKnownAiringTime,
                airingTimeWithdrawn: existing.airingTimeWithdrawn == true
            )
        )
    }

    static func date(_ value: String?) -> Date? {
        guard let value, value.count <= 40, !value.hasPrefix("0001-") else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }

    static func validRoute(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 200
            && value.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-").contains($0) }
    }

    static func entries(
        from row: AnimeScheduleTimetableEntry,
        anime: AnimeScheduleAnime?,
        window: DateInterval,
        preferredLanguageCode: String,
        stale: Bool = false
    ) -> [AniListAiringScheduleEntry] {
        guard row.airType == "dub", validRoute(row.route), anime?.route == row.route,
              anime?.isAdult != true,
              !row.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              row.title.utf8.count <= 1024,
              row.episodeNumber > 0, row.episodeNumber <= 100_000,
              let date = date(row.episodeDate), date >= window.start, date < window.end else { return [] }
        let firstEpisode = row.subtractedEpisodeNumber ?? row.episodeNumber
        guard firstEpisode > 0, firstEpisode <= row.episodeNumber,
              row.episodeNumber - firstEpisode < 200 else { return [] }
        let mediaID = anime?.aniListID ?? anime?.malID.map { -$0 } ?? 0
        guard mediaID != 0 else { return [] }
        let formats = row.mediaTypes?.map(\.route) ?? []
        let format: String?
        if formats.contains(where: { $0.hasPrefix("movie") }) { format = "MOVIE" }
        else if formats.contains("tv-short") { format = "TV_SHORT" }
        else if formats.contains(where: { $0.hasPrefix("tv") }) { format = "TV" }
        else if formats.contains(where: { $0.hasPrefix("ona") }) { format = "ONA" }
        else if formats.contains("ova") { format = "OVA" }
        else if formats.contains("special") { format = "SPECIAL" }
        else if formats.contains("music") { format = "MUSIC" }
        else { format = nil }
        let names = AniListAnime.AniListTitle(romaji: row.romaji ?? row.title, english: row.english, native: row.native)
        let delayed = row.airingStatus?.lowercased().hasPrefix("delayed") == true
            || (Self.date(row.delayedFrom).map { start in
                date >= start && (Self.date(row.delayedUntil).map { date < $0 } ?? true)
            } ?? false)
        let knownTime = !delayed && !stale
        let image: String?
        if let route = row.imageVersionRoute, route.utf8.count <= 1024,
           !route.contains(".."), !route.contains("://"), !route.hasPrefix("/") {
            image = URL(string: "https://img.animeschedule.net/production/assets/public/img/" + route)?.absoluteString
        } else { image = nil }
        return (firstEpisode...row.episodeNumber).map { episode in
            AniListAiringScheduleEntry(
                id: -(abs(mediaID) * 100_001 + episode),
                mediaId: mediaID,
                title: AniListTitlePicker.title(from: names, preferredLanguageCode: preferredLanguageCode),
                airingAt: date,
                episode: episode,
                coverImage: image,
                englishTitle: row.english,
                romajiTitle: row.romaji ?? row.title,
                nativeTitle: row.native,
                format: format,
                hasKnownAiringTime: knownTime,
                scheduleProvider: .dubOnly,
                malID: anime?.malID,
                airingTimeWithdrawn: delayed && !stale
            )
        }
    }
}

enum AnimeScheduleAPIKeyStore {
    private static let service = "app.eclipse.animeschedule"
    private static let account = "application-api-token"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var hasToken: Bool {
        let keychainValue = load()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bundleValues = ["AnimeScheduleAPIToken", "DubsOnlyAPIKey"].compactMap {
            Bundle.main.object(forInfoDictionaryKey: $0) as? String
        }
        return !keychainValue.isEmpty || bundleValues.contains {
            let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && !value.contains("$(")
        }
    }

    static func save(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        guard !trimmed.isEmpty else {
            let status = SecItemDelete(lookup as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: Data(trimmed.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = lookup
            attributes.forEach { insert[$0.key] = $0.value }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

actor AnimeScheduleService {
    static let credentialsDidChangeNotification = Notification.Name("animeScheduleCredentialsDidChange")
    static let shared = AnimeScheduleService()

    private struct CachedWeek: Codable {
        let fetchedAt: Date
        let rows: [AnimeScheduleTimetableEntry]
    }

    private struct CachedAnime: Codable {
        let fetchedAt: Date
        let anime: AnimeScheduleAnime
    }

    private struct Cache: Codable {
        var weeks: [String: CachedWeek] = [:]
        var anime: [String: CachedAnime] = [:]
    }

    private struct AnimePage: Decodable {
        let page: Int
        let totalAmount: Int
        let anime: [AnimeScheduleAnime]
    }

    private let session: URLSession
    private var token: String
    private let cacheURL: URL?
    private let requestSpacing: TimeInterval
    private var nextRequestAt = Date.distantPast
    private var cache = Cache()
    private var didLoadCache = false
    private var catalogFetchedAt: Date?

    init(session: URLSession = .shared, token: String? = nil, cacheURL: URL? = nil, requestSpacing: TimeInterval = 0.55) {
        self.session = session
        let configured = token
            ?? AnimeScheduleAPIKeyStore.load()
            ?? (Bundle.main.object(forInfoDictionaryKey: "AnimeScheduleAPIToken") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "DubsOnlyAPIKey") as? String)
            ?? ""
        let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = trimmed.contains("$(") || trimmed.utf8.count > 512 ? "" : trimmed
        self.cacheURL = cacheURL ?? (token == nil ? FileManager.default.eclipseCachesDirectories.first?.appendingPathComponent("dubonly-english-schedule-v1.json") : nil)
        self.requestSpacing = requestSpacing
    }

    func updateToken(_ value: String?) {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        token = trimmed.contains("$(") || trimmed.utf8.count > 512 ? "" : trimmed
        cache = Cache()
        didLoadCache = false
        catalogFetchedAt = nil
    }

    func fetchSchedule(daysAhead: Int, now: Date = Date(), preferredLanguageCode: String = "en") async throws -> AnimeAiringScheduleResult {
        // The documented v3 API requires an application bearer token.
        // If it is not configured, fail fast and let the independent keyless
        // Tsuzuki and SeaDub providers supply the English-dub calendar.
        guard (1...30).contains(daysAhead) else { throw AnimeScheduleError.invalidResponse }
        try Task.checkCancellation()
        loadCache(now: now)
        let deadline = Date().addingTimeInterval(45)
        let window = ScheduleDateWindow.envelope(dayCount: daysAhead, now: now)
        let weeks = AnimeScheduleWeek.covering(window)
        var rows: [(AnimeScheduleTimetableEntry, Bool)] = []
        var complete = true
        var usedStale = false
        var loadedWeeks = 0
        var requestsUnavailable = false
        for week in weeks {
            try Task.checkCancellation()
            if let cached = cache.weeks[week.key], isFresh(cached.fetchedAt, now: now, age: 900) {
                rows += cached.rows.map { ($0, false) }
                loadedWeeks += 1
                continue
            }
            do {
                guard !requestsUnavailable else { throw AnimeScheduleError.unavailable }
                let data = try await request(path: "timetables/dub", query: [
                    URLQueryItem(name: "year", value: String(week.year)),
                    URLQueryItem(name: "week", value: String(week.week)),
                    URLQueryItem(name: "tz", value: "UTC")
                ], deadline: deadline)
                let entries = try JSONDecoder().decode([AnimeScheduleTimetableEntry].self, from: data)
                guard entries.count <= 2000 else { throw AnimeScheduleError.invalidResponse }
                cache.weeks[week.key] = CachedWeek(fetchedAt: now, rows: entries)
                rows += entries.map { ($0, false) }
                loadedWeeks += 1
            } catch {
                try Self.rethrowCancellation(error)
                complete = false
                if let cached = cache.weeks[week.key], isFresh(cached.fetchedAt, now: now, age: 48 * 3600) {
                    rows += cached.rows.map { ($0, true) }
                    loadedWeeks += 1
                    usedStale = true
                }
                if case AnimeScheduleError.http(404) = error {} else { requestsUnavailable = true }
            }
        }
        guard loadedWeeks > 0 else { throw AnimeScheduleError.unavailable }
        let wantedRoutes = Set(rows.compactMap { row, _ -> String? in
            guard AnimeScheduleEntryMapper.validRoute(row.route),
                  let date = AnimeScheduleEntryMapper.date(row.episodeDate),
                  date >= window.start, date < window.end else { return nil }
            return row.route
        })
        if !requestsUnavailable, wantedRoutes.contains(where: { cachedAnime($0, now: now) == nil }),
           !isFresh(catalogFetchedAt, now: now, age: 3600) {
            do { try await fetchOngoingAnime(now: now, wantedRoutes: wantedRoutes, deadline: deadline) }
            catch {
                try Self.rethrowCancellation(error)
                if case AnimeScheduleError.http(404) = error {} else { requestsUnavailable = true }
            }
        }
        var detailRequests = 0
        for route in wantedRoutes.sorted() where cachedAnime(route, now: now) == nil {
            guard !requestsUnavailable, detailRequests < 80 else { complete = false; break }
            detailRequests += 1
            do {
                let data = try await request(path: "anime/" + route, deadline: deadline)
                let anime = try JSONDecoder().decode(AnimeScheduleAnime.self, from: data)
                guard anime.route == route else { throw AnimeScheduleError.invalidResponse }
                cache.anime[route] = CachedAnime(fetchedAt: now, anime: anime)
            } catch {
                try Self.rethrowCancellation(error)
                complete = false
                if case AnimeScheduleError.http(404) = error {} else { break }
            }
        }
        var entriesByID: [String: AniListAiringScheduleEntry] = [:]
        for (row, stale) in rows {
            if row.airType != "dub" || !AnimeScheduleEntryMapper.validRoute(row.route) || AnimeScheduleEntryMapper.date(row.episodeDate) == nil {
                complete = false
            }
            let anime = cachedAnime(row.route, now: now)
            if wantedRoutes.contains(row.route), anime == nil || (anime?.aniListID == nil && anime?.malID == nil) {
                complete = false
            }
            let mapped = AnimeScheduleEntryMapper.entries(from: row, anime: anime, window: window, preferredLanguageCode: preferredLanguageCode, stale: stale)
            if wantedRoutes.contains(row.route), anime?.isAdult != true, mapped.isEmpty { complete = false }
            for entry in mapped {
                let key = "\(entry.mediaId)-\(entry.episode)"
                if let previous = entriesByID[key],
                   !AnimeScheduleEntryMapper.shouldReplaceDuplicate(existing: previous, candidate: entry) {
                    continue
                }
                entriesByID[key] = entry
            }
        }
        try Task.checkCancellation()
        persistCache(now: now)
        guard !entriesByID.isEmpty || complete else { throw AnimeScheduleError.unavailable }
        let notice = usedStale
            ? "DubOnly fallback · Saved English dub schedule; refresh unavailable."
            : complete ? "English dub schedule via DubOnly · Data credited to AnimeSchedule.net."
            : "DubOnly fallback · Some English dub dates or shows are unavailable."
        return AnimeAiringScheduleResult(
            entries: entriesByID.values.sorted { $0.airingAt == $1.airingAt ? $0.mediaId < $1.mediaId : $0.airingAt < $1.airingAt },
            isAuthoritativeForNotifications: false,
            notice: notice
        )
    }

    private func fetchOngoingAnime(now: Date, wantedRoutes: Set<String>, deadline: Date) async throws {
        for page in 1...AnimeScheduleCatalogScanPolicy.maximumWarmupPages {
            let data = try await request(path: "anime", query: [
                URLQueryItem(name: "airing-statuses", value: "ongoing"),
                URLQueryItem(name: "page", value: String(page))
            ], deadline: deadline)
            let result = try JSONDecoder().decode(AnimePage.self, from: data)
            guard result.page == page, result.anime.count <= AnimeScheduleCatalogScanPolicy.pageSize,
                  result.totalAmount >= 0, result.totalAmount <= 10_000 else { throw AnimeScheduleError.invalidResponse }
            for anime in result.anime where wantedRoutes.contains(anime.route) {
                cache.anime[anime.route] = CachedAnime(fetchedAt: now, anime: anime)
            }

            let allWantedRoutesResolved = wantedRoutes.allSatisfy {
                cachedAnime($0, now: now) != nil
            }
            let catalogExhausted = AnimeScheduleCatalogScanPolicy.catalogIsExhausted(
                page: page,
                totalAmount: result.totalAmount,
                receivedCount: result.anime.count
            )
            if catalogExhausted {
                catalogFetchedAt = now
                break
            }

            // This global catalog is only a cache warm-up. Exact route lookups
            // below resolve any remaining schedule rows, so scanning dozens of
            // unrelated pages only delays the useful per-show requests.
            guard AnimeScheduleCatalogScanPolicy.shouldContinue(
                page: page,
                totalAmount: result.totalAmount,
                receivedCount: result.anime.count,
                allWantedRoutesResolved: allWantedRoutesResolved
            ) else { break }
        }
    }

    private func request(path: String, query: [URLQueryItem] = [], deadline: Date) async throws -> Data {
        try Task.checkCancellation()
        let slot = max(Date(), nextRequestAt)
        guard slot < deadline else { throw AnimeScheduleError.unavailable }
        nextRequestAt = slot.addingTimeInterval(requestSpacing)
        let delay = slot.timeIntervalSinceNow
        guard delay < 30 else { throw AnimeScheduleError.http(429) }
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        guard var components = URLComponents(string: "https://animeschedule.net/api/v3/" + path) else { throw AnimeScheduleError.invalidResponse }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw AnimeScheduleError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = min(12, max(0.1, deadline.timeIntervalSinceNow))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Eclipse/AnimeSchedule", forHTTPHeaderField: "User-Agent")
        guard !token.isEmpty else { throw AnimeScheduleError.unconfigured }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.boundedData(for: request, maximumResponseBytes: 2 * 1024 * 1024)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw AnimeScheduleError.invalidResponse }
        if response.statusCode == 429 {
            let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init).flatMap { $0.isFinite ? $0 : nil }
            let retry = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init).flatMap { $0.isFinite ? $0 : nil }
            let delay = max(60, min(retry ?? reset.map { $0 - Date().timeIntervalSince1970 } ?? 60, 3600))
            nextRequestAt = Date().addingTimeInterval(delay)
        }
        guard response.statusCode == 200 else { throw AnimeScheduleError.http(response.statusCode) }
        return data
    }

    private func cachedAnime(_ route: String, now: Date) -> AnimeScheduleAnime? {
        guard let cached = cache.anime[route], isFresh(cached.fetchedAt, now: now, age: 7 * 86400) else { return nil }
        return cached.anime
    }

    private func isFresh(_ fetchedAt: Date?, now: Date, age: TimeInterval) -> Bool {
        guard let fetchedAt else { return false }
        let elapsed = now.timeIntervalSince(fetchedAt)
        return elapsed >= 0 && elapsed < age
    }

    private func loadCache(now: Date) {
        guard !didLoadCache else { return }
        didLoadCache = true
        guard let cacheURL,
              let size = try? cacheURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 4 * 1024 * 1024,
              let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode(Cache.self, from: data),
              decoded.weeks.count <= 7, decoded.anime.count <= 512,
              decoded.weeks.values.allSatisfy({ $0.rows.count <= 2000 }) else { return }
        cache = decoded
    }

    private func persistCache(now: Date) {
        cache.weeks = Dictionary(uniqueKeysWithValues: cache.weeks.filter { isFresh($0.value.fetchedAt, now: now, age: 48 * 3600) }
            .sorted { $0.value.fetchedAt > $1.value.fetchedAt }.prefix(7).map { ($0.key, $0.value) })
        cache.anime = Dictionary(uniqueKeysWithValues: cache.anime.filter { isFresh($0.value.fetchedAt, now: now, age: 7 * 86400) }
            .sorted { $0.value.fetchedAt > $1.value.fetchedAt }.prefix(512).map { ($0.key, $0.value) })
        guard let cacheURL, let data = try? JSONEncoder().encode(cache), data.count <= 4 * 1024 * 1024 else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    static func rethrowCancellation(_ error: Error) throws {
        if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
    }
}

enum AnimeScheduleLanguageNoticePolicy {
    static func notice(
        selectedLanguages: Set<String>,
        providerNotice: String?
    ) -> String? {
        guard selectedLanguages.contains(MyDubListLanguage.spanish.rawValue) else {
            return providerNotice
        }
        let clarification = "No confirmed Spanish-dub episode dates are available. Japanese broadcast dates are never substituted."
        guard let providerNotice,
              !providerNotice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return clarification
        }
        let normalized = providerNotice.lowercased()
        if normalized.contains("temporarily unavailable")
            || normalized.contains("providers are unavailable")
            || normalized.contains("no available") {
            return clarification
        }
        return "\(providerNotice) \(clarification)"
    }
}

actor TsuzukiAnimeDubScheduleService {
    static let shared = TsuzukiAnimeDubScheduleService()

    private struct Response: Decodable {
        let ok: Bool
        let episodes: [Episode]?
    }

    private struct Episode: Decodable {
        let mediaId: Int
        let episode: Int
        let airType: String
        let airingAt: Int?
        let exact: Bool
        let estimated: Bool
        let isBreak: Bool?
        let title: String
        let coverImage: String?
    }

    private var cached: [String: (fetchedAt: Date, result: AnimeAiringScheduleResult)] = [:]
    private let cacheLifetime: TimeInterval = 5 * 60

    func fetchSchedule(daysAhead: Int = 7) async throws -> AnimeAiringScheduleResult {
        let days = min(max(daysAhead, 1), 31)
        let now = Date()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // The Tsuzuki API interprets its start date in UTC.
        formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.string(from: now)
        let cacheKey = "\(start):\(days)"
        if let value = cached[cacheKey],
           now.timeIntervalSince(value.fetchedAt) < cacheLifetime {
            return value.result
        }

        var components = URLComponents(string: "https://tsuzuki.top/api/v1/schedule")
        components?.queryItems = [
            URLQueryItem(name: "start", value: start),
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "airType", value: "dub")
        ]
        guard let url = components?.url else { throw AnimeScheduleError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 18
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnimeScheduleError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw AnimeScheduleError.http(http.statusCode)
        }
        guard data.count <= 5 * 1_024 * 1_024,
              let payload = try? JSONDecoder().decode(Response.self, from: data),
              payload.ok else {
            throw AnimeScheduleError.invalidResponse
        }

        let entries = (payload.episodes ?? []).compactMap { episode -> AniListAiringScheduleEntry? in
            let title = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard episode.airType.lowercased() == "dub",
                  episode.isBreak != true,
                  episode.exact,
                  !episode.estimated,
                  episode.mediaId > 0,
                  episode.mediaId <= 1_000_000_000,
                  episode.episode > 0,
                  episode.episode <= 100_000,
                  !title.isEmpty,
                  title.utf8.count <= 1_024,
                  let timestamp = episode.airingAt,
                  timestamp > 0 else {
                return nil
            }

            let imageURL: String? = {
                guard let raw = episode.coverImage,
                      raw.utf8.count <= 2_048,
                      let url = URL(string: raw),
                      url.scheme?.lowercased() == "https",
                      let host = url.host?.lowercased(),
                      host == "anilist.co" || host.hasSuffix(".anilist.co") else {
                    return nil
                }
                return url.absoluteString
            }()

            return AniListAiringScheduleEntry(
                id: episode.mediaId * 100_001 + episode.episode,
                mediaId: episode.mediaId,
                title: title,
                airingAt: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                episode: episode.episode,
                coverImage: imageURL,
                englishTitle: title,
                romajiTitle: nil,
                nativeTitle: nil,
                format: nil,
                hasKnownAiringTime: true,
                scheduleProvider: .tsuzuki,
                malID: nil,
                airingTimeWithdrawn: false
            )
        }
        let result = AnimeAiringScheduleResult(
            entries: entries,
            isAuthoritativeForNotifications: true,
            notice: entries.isEmpty ? nil : "English dub dates supplemented by Tsuzuki's corrected schedule."
        )
        cached[cacheKey] = (Date(), result)
        return result
    }
}

actor SeaDubAnimeDubScheduleService {
    static let shared = SeaDubAnimeDubScheduleService()

    private struct Episode: Decodable {
        let mediaId: Int
        let idMal: Int?
        let title: String
        let episodeNumber: Int
        let episodeDate: String
        let format: String?
        let image: String?
        let delayed: Bool?
        let delayedIndefinitely: Bool?
        let verified: Bool?
        let dateType: String?
        let projected: Bool?
        let batchStartEpisode: Int?
        let batchEndEpisode: Int?
    }

    private var cached: [String: (fetchedAt: Date, result: AnimeAiringScheduleResult)] = [:]
    private let cacheLifetime: TimeInterval = 15 * 60
    private let feedURL = URL(string: "https://raw.githubusercontent.com/DefnoJae/SeaDub/main/raw/dub-schedule.json")!

    func fetchSchedule(daysAhead: Int = 7) async throws -> AnimeAiringScheduleResult {
        let days = min(max(daysAhead, 1), 31)
        let now = Date()
        let window = ScheduleDateWindow.envelope(dayCount: days, now: now)
        let cacheKey = "\(Int(window.start.timeIntervalSince1970 / 86_400)):\(days)"
        if let value = cached[cacheKey], now.timeIntervalSince(value.fetchedAt) < cacheLifetime {
            return value.result
        }

        var request = URLRequest(url: feedURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Eclipse/SeaDubSchedule", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnimeScheduleError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw AnimeScheduleError.http(http.statusCode)
        }
        guard data.count <= 10 * 1_024 * 1_024 else {
            throw AnimeScheduleError.invalidResponse
        }
        let episodes = try JSONDecoder().decode([Episode].self, from: data)
        guard episodes.count <= 20_000 else {
            throw AnimeScheduleError.invalidResponse
        }

        var entriesByEpisode: [String: AniListAiringScheduleEntry] = [:]
        for item in episodes {
            guard item.verified == true,
                  item.dateType?.lowercased() == "confirmed",
                  item.projected != true,
                  item.delayedIndefinitely != true,
                  item.mediaId > 0, item.mediaId <= 1_000_000_000,
                  item.episodeNumber > 0, item.episodeNumber <= 100_000,
                  let date = AnimeScheduleEntryMapper.date(item.episodeDate),
                  date >= window.start, date < window.end else { continue }

            let firstEpisode = item.batchStartEpisode ?? item.episodeNumber
            let lastEpisode = item.batchEndEpisode ?? item.episodeNumber
            guard firstEpisode > 0, firstEpisode <= lastEpisode,
                  lastEpisode <= 100_000, lastEpisode - firstEpisode < 200 else { continue }

            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.utf8.count <= 1_024 else { continue }

            let coverImage: String? = {
                guard let raw = item.image, raw.utf8.count <= 2_048,
                      let url = URL(string: raw),
                      url.scheme?.lowercased() == "https",
                      let host = url.host?.lowercased(),
                      host == "anilist.co" || host.hasSuffix(".anilist.co") else { return nil }
                return url.absoluteString
            }()
            let validMALID = item.idMal.flatMap { (1...1_000_000_000).contains($0) ? $0 : nil }
            let hasKnownTime = item.delayed != true

            for episode in firstEpisode...lastEpisode {
                let entry = AniListAiringScheduleEntry(
                    id: item.mediaId * 100_001 + episode,
                    mediaId: item.mediaId,
                    title: title,
                    airingAt: date,
                    episode: episode,
                    coverImage: coverImage,
                    englishTitle: title,
                    romajiTitle: nil,
                    nativeTitle: nil,
                    format: item.format,
                    hasKnownAiringTime: hasKnownTime,
                    scheduleProvider: .seaDub,
                    malID: validMALID,
                    airingTimeWithdrawn: !hasKnownTime
                )
                let key = "\(entry.mediaId):\(entry.episode)"
                if let previous = entriesByEpisode[key],
                   !ScheduleReleaseDatePolicy.shouldPrefer(
                    candidateDate: entry.airingAt,
                    candidateIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                        provider: entry.scheduleProvider,
                        hasKnownAiringTime: entry.hasKnownAiringTime,
                        airingTimeWithdrawn: entry.airingTimeWithdrawn == true
                    ),
                    over: previous.airingAt,
                    existingIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                        provider: previous.scheduleProvider,
                        hasKnownAiringTime: previous.hasKnownAiringTime,
                        airingTimeWithdrawn: previous.airingTimeWithdrawn == true
                    )
                   ) { continue }
                entriesByEpisode[key] = entry
            }
        }

        let entries = entriesByEpisode.values.sorted {
            if $0.airingAt != $1.airingAt { return $0.airingAt < $1.airingAt }
            if $0.title != $1.title { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return $0.episode < $1.episode
        }
        let result = AnimeAiringScheduleResult(
            entries: entries,
            isAuthoritativeForNotifications: false,
            notice: entries.isEmpty ? nil : "English dub dates supplemented by SeaDub's verified schedule feed."
        )
        cached[cacheKey] = (now, result)
        return result
    }
}

enum AnimeScheduleFallback {
    static func mergeEnglishDubSchedules(
        primary: AnimeAiringScheduleResult,
        fallback: AnimeAiringScheduleResult
    ) -> AnimeAiringScheduleResult {
        var entriesByEpisode: [String: AniListAiringScheduleEntry] = [:]
        for entry in primary.entries {
            entriesByEpisode["\(entry.mediaId):\(entry.episode)"] = entry
        }
        for candidate in fallback.entries {
            let key = "\(candidate.mediaId):\(candidate.episode)"
            if let existing = entriesByEpisode[key] {
                // Prefer a confirmed timetable over a withdrawn/estimated one.
                // When both providers have confirmed dates, keep the earliest
                // qualifying dub release instead of always trusting the primary.
                if ScheduleReleaseDatePolicy.shouldPrefer(
                    candidateDate: candidate.airingAt,
                    candidateIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                        provider: candidate.scheduleProvider,
                        hasKnownAiringTime: candidate.hasKnownAiringTime,
                        airingTimeWithdrawn: candidate.airingTimeWithdrawn == true
                    ),
                    over: existing.airingAt,
                    existingIsConfirmed: ScheduleReleaseDatePolicy.isConfirmedReleaseDate(
                        provider: existing.scheduleProvider,
                        hasKnownAiringTime: existing.hasKnownAiringTime,
                        airingTimeWithdrawn: existing.airingTimeWithdrawn == true
                    )
                ) {
                    entriesByEpisode[key] = candidate
                }
            } else {
                entriesByEpisode[key] = candidate
            }
        }
        let entries = entriesByEpisode.values.sorted {
            if $0.airingAt != $1.airingAt { return $0.airingAt < $1.airingAt }
            if $0.title != $1.title { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return $0.episode < $1.episode
        }
        let notices = [primary.notice, fallback.notice]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return AnimeAiringScheduleResult(
            entries: entries,
            isAuthoritativeForNotifications: primary.isAuthoritativeForNotifications
                && fallback.isAuthoritativeForNotifications,
            notice: notices.isEmpty ? nil : Array(Set(notices)).joined(separator: " · ")
        )
    }

    static func permitsBroadcastFallback(selectedDubLanguages: Set<String>) -> Bool {
        selectedDubLanguages.isEmpty
    }

    static func requiresDubSchedule(
        selectedDubLanguages: Set<String>,
        englishSpanishAudioFilterEnabled: Bool
    ) -> Bool {
        !selectedDubLanguages.isEmpty || englishSpanishAudioFilterEnabled
    }

    static func permitsEnglishDubSchedule(
        selectedDubLanguages: Set<String>,
        englishSpanishAudioFilterEnabled: Bool
    ) -> Bool {
        selectedDubLanguages.contains(MyDubListLanguage.english.rawValue)
            || (selectedDubLanguages.isEmpty && englishSpanishAudioFilterEnabled)
    }

    static func load(
        aniList: () async throws -> AnimeAiringScheduleResult,
        animeSchedule: () async throws -> AnimeAiringScheduleResult,
        mal: () async throws -> AnimeAiringScheduleResult,
        permitsFallback: (Error) -> Bool
    ) async throws -> AnimeAiringScheduleResult {
        do { return try await aniList() }
        catch {
            try AnimeScheduleService.rethrowCancellation(error)
            guard permitsFallback(error) else { throw error }
        }
        do { return try await animeSchedule() }
        catch { try AnimeScheduleService.rethrowCancellation(error) }
        return try await mal()
    }
}


// MARK: - Verified Spanish-dub release research

enum SpanishDubAIProvider: String, CaseIterable, Identifiable, Codable {
    case gemini
    case openAI

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openAI: return "OpenAI"
        }
    }
}

actor SpanishDubAIResearchService {
    static let shared = SpanishDubAIResearchService()
    static var hasConfiguredProvider: Bool {
        SpanishDubAIProvider.allCases.contains { proxyURL(for: $0) != nil }
    }

    private struct ResearchCandidate: Codable {
        let mediaId: Int
        let episode: Int
        let date: String
        let region: String
        let status: String
        let sources: [String]
    }

    private struct CachedDate: Codable {
        let fetchedAt: Date
        let date: Date
        let sourceURL: String
        let provider: SpanishDubAIProvider
    }

    private var cache: [String: CachedDate] = [:]
    private var negativeChecks: [String: Date] = [:]
    private var didLoadCache = false
    private let cacheKey = "spanishDubAIResearchCacheV1"
    private let cacheLifetime: TimeInterval = 12 * 60 * 60
    private let maximumCandidatesPerRefresh = 40

    /// Providers are deliberately sequential. A later provider only sees episodes
    /// that the earlier provider could not verify.
    func research(entries: [AniListAiringScheduleEntry]) async -> [AniListAiringScheduleEntry] {
        loadCache()
        let now = Date()
        let candidates = Array(entries.filter { $0.episode > 0 && $0.episode <= 100_000 }
            .sorted { $0.airingAt < $1.airingAt }
            .prefix(maximumCandidatesPerRefresh))
        guard !candidates.isEmpty else { return [] }

        var resolved: [String: CachedDate] = [:]
        for entry in candidates {
            let key = Self.cacheKey(for: entry)
            if let cached = cache[key],
               now.timeIntervalSince(cached.fetchedAt) >= 0,
               now.timeIntervalSince(cached.fetchedAt) < cacheLifetime {
                resolved[key] = cached
            }
        }

        var didAttemptProvider = false
        for provider in SpanishDubAIProvider.allCases {
            let apiKey = Self.apiKey(for: provider) ?? ""
            guard !apiKey.isEmpty else { continue }
            didAttemptProvider = true
            let unresolved = candidates.filter { entry in
                let key = Self.cacheKey(for: entry)
                if resolved[key] != nil { return false }
                if let checkedAt = negativeChecks[key], now.timeIntervalSince(checkedAt) >= 0, now.timeIntervalSince(checkedAt) < 21_600 { return false }
                return true
            }
            guard !unresolved.isEmpty else { break }
            do {
                let results = try await request(provider: provider, apiKey: apiKey, entries: unresolved)
                for (entry, result) in zip(unresolved, results) {
                    guard let result,
                          result.status.lowercased() == "confirmed",
                          result.region.lowercased().contains("spanish"),
                          let date = Self.parseDate(result.date),
                          date >= Calendar.current.startOfDay(for: now),
                          date <= now.addingTimeInterval(180 * 86400),
                          let source = result.sources.first(where: { Self.isUsableSource($0) }) else {
                        continue
                    }
                    let record = CachedDate(fetchedAt: now, date: date, sourceURL: source, provider: provider)
                    let key = Self.cacheKey(for: entry)
                    cache[key] = record
                    resolved[key] = record
                }
                persistCache()
            } catch {
                // Quota, authentication, network, malformed output and provider
                // outages all advance to the next configured provider.
                continue
            }
        }

        if didAttemptProvider {
            for entry in candidates {
                let key = Self.cacheKey(for: entry)
                if resolved[key] == nil { negativeChecks[key] = now }
            }
            persistCache()
        }
        let byEpisode = Dictionary(grouping: candidates, by: { Self.cacheKey(for: $0) })
        return resolved.compactMap { key, record in
            guard let original = byEpisode[key]?.first else { return nil }
            return AniListAiringScheduleEntry(
                id: original.id,
                mediaId: original.mediaId,
                title: original.title,
                airingAt: record.date,
                episode: original.episode,
                coverImage: original.coverImage,
                englishTitle: original.englishTitle,
                romajiTitle: original.romajiTitle,
                nativeTitle: original.nativeTitle,
                format: original.format,
                // The announcement confirms the calendar date, not a clock time.
                hasKnownAiringTime: false,
                scheduleProvider: .aiSpanishDub,
                malID: original.malID,
                airingTimeWithdrawn: false,
                tags: original.tags,
                releaseYear: original.releaseYear,
                runtimeMinutes: original.runtimeMinutes,
                sourceURL: record.sourceURL
            )
        }.sorted { $0.airingAt < $1.airingAt }
    }

    func clearNegativeCache() {
        negativeChecks.removeAll()
        persistCache()
    }

    private func request(
        provider: SpanishDubAIProvider,
        apiKey: String,
        entries: [AniListAiringScheduleEntry]
    ) async throws -> [ResearchCandidate?] {
        let grouped = Dictionary(grouping: entries, by: { $0.mediaId })
        let titles = grouped.values.compactMap(\.first).map { entry in
            let names = Array(Set([entry.englishTitle, entry.title, entry.romajiTitle, entry.nativeTitle]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }))
            let year = entry.releaseYear.map { " · year \($0)" } ?? ""
            let mal = entry.malID.map { " · MAL ID \($0)" } ?? ""
            let episodes = grouped[entry.mediaId, default: []].map(\.episode).sorted()
            return "\(names.joined(separator: " / "))\(year) (AniList ID \(entry.mediaId)\(mal)): episodes \(episodes.map(String.init).joined(separator: ", "))"
        }.joined(separator: "\n")
        let prompt = """
        Research upcoming Spanish-language anime dub release dates using live web search.
        Only return dates explicitly announced by an official distributor/platform or a reputable anime-news publication.
        Spanish includes Latin American Spanish and Castilian Spanish. Do not confuse Spanish with Portuguese.
        Do not use Japanese broadcast dates, English dub dates, fan predictions, or AI estimates.
        Only research the exact anime and episode numbers in this list:
        \(titles)

        Return ONLY valid JSON in this shape:
        {"results":[{"mediaId":123,"episode":1,"date":"YYYY-MM-DD","region":"Latin American Spanish or Castilian Spanish","status":"confirmed","sources":["https://..."]}]}
        Include only confirmed future dates. Every result must have at least one source URL that directly supports the Spanish dub episode/date. Omit anything uncertain.
        """
        let (_, body, _, _) = try Self.requestParts(provider: provider, apiKey: "", prompt: prompt)
        guard let proxyURL = Self.proxyURL(for: provider) else {
            throw AnimeScheduleError.unavailable
        }
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["payload": body])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnimeScheduleError.invalidResponse }
        guard (200..<300).contains(http.statusCode), data.count <= 2 * 1024 * 1024,
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnimeScheduleError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let text: String
        var citations = Set<String>()
        switch provider {
        case .gemini:
            guard let candidates = payload["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { throw AnimeScheduleError.invalidResponse }
            text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if let metadata = candidates.first?["groundingMetadata"] as? [String: Any],
               let chunks = metadata["groundingChunks"] as? [[String: Any]] {
                for chunk in chunks {
                    if let web = chunk["web"] as? [String: Any], let uri = web["uri"] as? String {
                        citations.insert(uri)
                    }
                }
            }
        case .openAI:
            guard let output = payload["output"] as? [[String: Any]] else { throw AnimeScheduleError.invalidResponse }
            var chunks: [String] = []
            for item in output where item["type"] as? String == "message" {
                for content in item["content"] as? [[String: Any]] ?? [] {
                    if let value = content["text"] as? String { chunks.append(value) }
                    for annotation in content["annotations"] as? [[String: Any]] ?? [] {
                        if let url = annotation["url"] as? String { citations.insert(url) }
                    }
                }
            }
            text = chunks.joined(separator: "\n")
        }

        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}"),
              jsonStart <= jsonEnd,
              let jsonData = String(text[jsonStart...jsonEnd]).data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ResearchEnvelope.self, from: jsonData) else {
            throw AnimeScheduleError.invalidResponse
        }
        let byEpisode = Dictionary(grouping: decoded.results, by: \.episode)
        return entries.map { entry in
            guard let result = byEpisode[entry.episode]?.first(where: { $0.mediaId == entry.mediaId }) else { return nil }
            let groundedSources = result.sources.filter { citations.contains($0) && Self.isUsableSource($0) }
            guard !groundedSources.isEmpty else { return nil }
            return ResearchCandidate(
                mediaId: result.mediaId,
                episode: result.episode,
                date: result.date,
                region: result.region,
                status: result.status,
                sources: groundedSources
            )
        }
    }

    private struct ResearchEnvelope: Decodable {
        struct Result: Decodable {
            let mediaId: Int
            let episode: Int
            let date: String
            let region: String
            let status: String
            let sources: [String]
        }
        let results: [Result]
    }

    private static func requestParts(
        provider: SpanishDubAIProvider,
        apiKey: String,
        prompt: String
    ) throws -> (URL, [String: Any], String, String) {
        switch provider {
        case .gemini:
            guard let components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent") else {
                throw AnimeScheduleError.invalidResponse
            }
            guard let url = components.url else { throw AnimeScheduleError.invalidResponse }
            return (url, [
                "contents": [["parts": [["text": prompt]]]],
                "tools": [["google_search": [:]]]
            ], "x-goog-api-key", apiKey)
        case .openAI:
            guard let url = URL(string: "https://api.openai.com/v1/responses") else {
                throw AnimeScheduleError.invalidResponse
            }
            return (url, [
                "model": "gpt-6.2-astra",
                "tools": [["type": "web_search"]],
                "input": prompt
            ], "Authorization", "Bearer " + apiKey)
        }
    }

    /// Provider credentials stay on the proxy. The only value shipped in the app
    /// is the public HTTPS base URL, which is not an API credential.
    private static func proxyURL(for provider: SpanishDubAIProvider) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SpanishDubResearchProxyURL") as? String else {
            return nil
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              var components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { return nil }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = (basePath.isEmpty ? "" : "/" + basePath) + "/api/ai-research/" + provider.rawValue
        return components.url
    }

    private static func apiKey(for provider: SpanishDubAIProvider) -> String? {
        proxyURL(for: provider) == nil ? nil : "server-proxy"
    }

    private static func cacheKey(for entry: AniListAiringScheduleEntry) -> String {
        "\(entry.mediaId):\(entry.episode)"
    }

    private static func parseDate(_ raw: String) -> Date? {
        guard raw.count == 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private static func isUsableSource(_ raw: String) -> Bool {
        guard raw.utf8.count <= 2048, let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil else { return false }
        let trusted = ["crunchyroll.com", "netflix.com", "hidive.com", "hulu.com", "disneyplus.com", "primevideo.com", "amazon.com", "aniplexusa.com", "aniplex.co.jp", "toei-animation.com", "viz.com", "selecta-vision.com", "animebox.net", "atresplayer.com", "pluto.tv", "movistarplus.es", "max.com", "animenewsnetwork.com", "animecorner.me", "comicbook.com", "ign.com", "variety.com", "deadline.com", "guianime.com", "doblaje.fandom.com", "doblaje-espana.fandom.com"]
        return trusted.contains(where: { host == $0 || host.hasSuffix("." + $0) })
    }

    private func loadCache() {
        guard !didLoadCache else { return }
        didLoadCache = true
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(CacheEnvelope.self, from: data),
              decoded.dates.count <= 500, decoded.negativeChecks.count <= 500 else { return }
        cache = decoded.dates
        negativeChecks = decoded.negativeChecks
    }

    private struct CacheEnvelope: Codable {
        let dates: [String: CachedDate]
        let negativeChecks: [String: Date]
    }

    private func persistCache() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.fetchedAt) >= 0 && now.timeIntervalSince($0.value.fetchedAt) < cacheLifetime }
        negativeChecks = negativeChecks.filter { now.timeIntervalSince($0.value) >= 0 && now.timeIntervalSince($0.value) < 21_600 }
        if let data = try? JSONEncoder().encode(CacheEnvelope(dates: cache, negativeChecks: negativeChecks)) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
