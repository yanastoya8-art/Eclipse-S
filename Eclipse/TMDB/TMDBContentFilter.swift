//
//  TMDBContentFilter.swift
//  Sora
//
//  Created by Francesco on 11/09/25.
//

import Combine
import Foundation

enum CatalogRuntimeFilterPolicy {
    static func shortestReportedRuntime(_ values: [Int]?) -> Int? {
        values?.filter { $0 > 0 }.min()
    }

    static func shouldInclude(runtimeMinutes: Int?, minimumMinutes: Int = 20) -> Bool {
        guard let runtimeMinutes, runtimeMinutes > 0 else { return false }
        return runtimeMinutes >= minimumMinutes
    }
}

enum CatalogNativeAudioPolicy {
    /// Only skip a dub lookup when the title's native language already
    /// satisfies the user's selected audio languages. An English or Spanish
    /// original must still be checked for the other selected language's dub.
    static func requiresDubVerification(
        originalLanguage: String?,
        selectedLanguages: Set<String>
    ) -> Bool {
        !ScheduleAudioLanguagePolicy.matches(
            originalLanguage: originalLanguage,
            selectedLanguages: selectedLanguages
        )
    }

    /// Compatibility helper used by the schedule policy tests and any callers
    /// that need to check whether native audio is English or Spanish.
    static func hasEnglishOrSpanishAudio(_ originalLanguage: String?) -> Bool {
        ScheduleAudioLanguagePolicy.matches(
            originalLanguage: originalLanguage,
            selectedLanguages: [MyDubListLanguage.english.rawValue, MyDubListLanguage.spanish.rawValue]
        )
    }
}

enum DubLanguageSelectionPolicy {
    static func effectiveLanguages(
        selectedLanguages: Set<String>,
        requiresEnglishSpanishAudio: Bool
    ) -> Set<String> {
        guard selectedLanguages.isEmpty, requiresEnglishSpanishAudio else {
            return selectedLanguages
        }
        return [MyDubListLanguage.english.rawValue, MyDubListLanguage.spanish.rawValue]
    }
}

enum AnimeDubAudioSelectionPolicy {
    /// A title qualifies only when at least one of the user's selected
    /// languages has a confirmed dub. Spanish regional tags are one language.
    static func hasSelectedAudio(
        selectedLanguages: Set<String>,
        dubCountsByLanguage: [String: Int]
    ) -> Bool {
        if selectedLanguages.contains(MyDubListLanguage.english.rawValue),
           (dubCountsByLanguage["en"] ?? 0) > 0 {
            return true
        }
        if selectedLanguages.contains(MyDubListLanguage.spanish.rawValue),
           ["es", "es-419", "es-es"].contains(where: { (dubCountsByLanguage[$0] ?? 0) > 0 }) {
            return true
        }
        return false
    }
}

enum ScheduleAllAgesPolicy {
    /// Only an explicit general-audience classification is excluded. Missing
    /// or unknown ratings are not silently treated as All Ages.
    static func shouldExclude(rating: MaturityRating?, enabled: Bool) -> Bool {
        enabled && rating == .general
    }

    /// Exclude only entries with a known rating below the requested minimum.
    /// Missing/unknown certifications are not evidence that a title is too young;
    /// keeping them visible avoids emptying a schedule when a provider omits age data.
    static func shouldExclude(
        rating: MaturityRating?,
        minimum: MaturityRating?,
        hideAllAges: Bool
    ) -> Bool {
        if hideAllAges, rating == .general { return true }
        guard let minimum, let rating, rating != .unknown else { return false }
        return rating < minimum
    }
}

enum MyDubListLanguage: String, CaseIterable, Identifiable, Sendable {
    case english, spanish, german, french, italian, chinese, portuguese, korean
    case tagalog, arabic, polish, hindi, hungarian, hebrew, swedish, norwegian
    case dutch, thai, indonesian, russian, danish, finnish, turkish, catalan, vietnamese

    // Keep every language picker in sync with the two supported choices.
    static var allCases: [MyDubListLanguage] { [.english, .spanish] }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish (Castellano o Latino)"
        case .german: return "German"
        case .french: return "French"
        case .italian: return "Italian"
        case .chinese: return "Chinese"
        case .portuguese: return "Portuguese"
        case .korean: return "Korean"
        case .tagalog: return "Tagalog"
        case .arabic: return "Arabic"
        case .polish: return "Polish"
        case .hindi: return "Hindi"
        case .hungarian: return "Hungarian"
        case .hebrew: return "Hebrew"
        case .swedish: return "Swedish"
        case .norwegian: return "Norwegian"
        case .dutch: return "Dutch"
        case .thai: return "Thai"
        case .indonesian: return "Indonesian"
        case .russian: return "Russian"
        case .danish: return "Danish"
        case .finnish: return "Finnish"
        case .turkish: return "Turkish"
        case .catalan: return "Catalan"
        case .vietnamese: return "Vietnamese"
        }
    }

    /// Taizen uses primary BCP-47 language subtags. Its catalogue currently
    /// combines regional Spanish variants into the single "es" entry.
    var taizenLanguageCode: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .german: return "de"
        case .french: return "fr"
        case .italian: return "it"
        case .chinese: return "zh"
        case .portuguese: return "pt"
        case .korean: return "ko"
        case .tagalog: return "tl"
        case .arabic: return "ar"
        case .polish: return "pl"
        case .hindi: return "hi"
        case .hungarian: return "hu"
        case .hebrew: return "he"
        case .swedish: return "sv"
        case .norwegian: return "no"
        case .dutch: return "nl"
        case .thai: return "th"
        case .indonesian: return "id"
        case .russian: return "ru"
        case .danish: return "da"
        case .finnish: return "fi"
        case .turkish: return "tr"
        case .catalan: return "ca"
        case .vietnamese: return "vi"
        }
    }

    /// anidub exposes BCP-47 tags for regional Spanish when available.
    /// The generic "es" entry remains a fallback for Spanish records without
    /// a confirmed region.
    var episodeMetadataLanguageCodes: [String] {
        switch self {
        case .spanish: return ["es-419", "es-es", "es"]
        default: return [taizenLanguageCode]
        }
    }
}

final class MyDubListDubFilter: @unchecked Sendable {
    static let shared = MyDubListDubFilter()
    static let selectedLanguagesKey = "myDubListSelectedLanguagesV1"
    static let didRefreshNotification = Notification.Name("myDubListDubFilterDidRefresh")
    private static let cachedLanguagesKey = "myDubListCachedLanguagesV1"
    private static let cachedMALIDsKey = "myDubListCachedMALIDsV1"
    private static let cachedAniListIDsKey = "myDubListCachedAniListIDsV1"
    private static let cachedEnglishMALIDsKey = "myDubListCachedEnglishMALIDsV1"
    private static let cachedEnglishAniListIDsKey = "myDubListCachedEnglishAniListIDsV1"

    private struct DubDataset: Decodable {
        let dubbed: [Int]
    }

    private struct AniListMapping: Decodable {
        let malID: Int
        let aniListID: Int
        enum CodingKeys: String, CodingKey {
            case malID = "mal_id"
            case aniListID = "anilist_id"
        }
    }

    private let lock = NSLock()
    // Coalesce concurrent Home, Browse, and Schedule requests into one
    // language-index refresh instead of downloading the same datasets repeatedly.
    private var refreshTask: Task<Bool, Never>?
    private var refreshTaskLanguages: Set<String>?
    private var refreshTaskID: UUID?
    private var allowedMALIDs: Set<Int> = []
    private var allowedAniListIDs: Set<Int> = []
    private var allowedEnglishMALIDs: Set<Int> = []
    private var allowedEnglishAniListIDs: Set<Int> = []
    private var loadedLanguages: Set<String> = []
    private var isLoaded = false

    static let supportedLanguages: Set<String> = [
        MyDubListLanguage.english.rawValue,
        MyDubListLanguage.spanish.rawValue
    ]

    var selectedLanguages: Set<String> {
        let storedLanguages = ProfileSettingsStore.active.stringArray(forKey: Self.selectedLanguagesKey)
        let languages = storedLanguages ?? Array(Self.supportedLanguages)
        return Set(languages.filter { Self.supportedLanguages.contains($0) })
    }

    /// Loads the last verified language snapshot synchronously before a search or
    /// catalogue applies the dub gate. A cache miss is reported so callers can
    /// decide whether they need to await a network refresh.
    @discardableResult
    func prepareCachedSnapshot() -> Bool {
        let languages = selectedLanguagesIncludingCatalogAudioRequirement
        guard !languages.isEmpty else {
            clearSnapshot()
            return true
        }
        loadCachedSnapshot(for: languages)
        return hasSnapshot(for: languages)
    }

    var selectedLanguagesIncludingCatalogAudioRequirement: Set<String> {
        DubLanguageSelectionPolicy.effectiveLanguages(
            selectedLanguages: selectedLanguages,
            requiresEnglishSpanishAudio: ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio")
        )
    }

    private func notifyRefreshObservers() {
        NotificationCenter.default.post(name: Self.didRefreshNotification, object: nil)
        NotificationCenter.default.post(name: TMDBContentFilter.catalogFiltersDidChangeNotification, object: nil)
    }

    func setSelectedLanguages(_ languages: Set<String>) {
        let valid = languages.filter { Self.supportedLanguages.contains($0) }
        ProfileSettingsStore.active.set(valid.sorted(), forKey: Self.selectedLanguagesKey)
        lock.lock()
        refreshTask?.cancel()
        refreshTask = nil
        refreshTaskLanguages = nil
        refreshTaskID = nil
        isLoaded = false
        lock.unlock()
        notifyRefreshObservers()
    }

    private func cancelRefreshTask() {
        lock.lock()
        refreshTask?.cancel()
        refreshTask = nil
        refreshTaskLanguages = nil
        refreshTaskID = nil
        lock.unlock()
    }

    private func refreshTask(for languages: Set<String>) -> (Task<Bool, Never>, UUID) {
        lock.lock()
        defer { lock.unlock() }
        if let existingTask = refreshTask,
           refreshTaskLanguages == languages {
            return (existingTask, refreshTaskID ?? UUID())
        }

        refreshTask?.cancel()
        let taskID = UUID()
        refreshTaskLanguages = languages
        let createdTask = Task { await self.performRefresh(for: languages) }
        refreshTask = createdTask
        refreshTaskID = taskID
        return (createdTask, taskID)
    }

    private func finishRefreshTask(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard refreshTaskID == id else { return }
        refreshTask = nil
        refreshTaskLanguages = nil
        refreshTaskID = nil
    }

    func refresh() async -> Bool {
        let languages = selectedLanguagesIncludingCatalogAudioRequirement
        guard !languages.isEmpty else {
            cancelRefreshTask()
            clearSnapshot()
            notifyRefreshObservers()
            return true
        }

        let (task, taskID) = refreshTask(for: languages)
        let result = await task.value
        finishRefreshTask(id: taskID)
        return result
    }

    private func performRefresh(for languages: Set<String>) async -> Bool {
        loadCachedSnapshot(for: languages)

        do {
            var malIDs = Set<Int>()
            var englishMALIDs = Set<Int>()
            var downloadedLanguages = Set<String>()
            // English and Spanish are independent selections. A failure in one
            // mirror must not discard the other language's valid dataset: this
            // previously hid English-dubbed anime whenever the Spanish fetch
            // failed, even though English IDs had downloaded successfully.
            await withTaskGroup(of: (String, Data?).self) { group in
                for language in languages.sorted() {
                    group.addTask {
                        guard !Task.isCancelled else { return (language, nil) }
                        let url = URL(string: "https://raw.githubusercontent.com/Joelis57/MyDubList/main/dubs/confidence/low/dubbed_\(language).json")!
                        return (language, try? await Self.download(url, maximumBytes: 1_000_000))
                    }
                }
                for await (language, data) in group {
                    guard !Task.isCancelled,
                          let data,
                          let dataset = try? JSONDecoder().decode(DubDataset.self, from: data),
                          dataset.dubbed.count <= 250_000 else {
                        continue
                    }
                    let validIDs = Set(dataset.dubbed.filter { $0 > 0 && $0 <= 100_000_000 })
                    malIDs.formUnion(validIDs)
                    downloadedLanguages.insert(language)
                    if language == MyDubListLanguage.english.rawValue {
                        englishMALIDs = validIDs
                    }
                }
            }
            guard !downloadedLanguages.isEmpty else { throw URLError(.cannotLoadFromNetwork) }

            try Task.checkCancellation()
            let mappingURL = URL(string: "https://raw.githubusercontent.com/Joelis57/MyDubList/main/dubs/mappings/mappings_anilist.jsonl")!
            let mappingData = try? await Self.download(mappingURL, maximumBytes: 4_000_000)
            let didLoadMapping = mappingData != nil
            // MAL IDs remain usable even if the AniList mapping mirror is
            // temporarily unavailable; do not throw away a successfully loaded
            // English dataset because this optional mapping file failed.
            let mappingText = mappingData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            var aniListIDs = Set<Int>()
            var englishAniListIDs = Set<Int>()
            let decoder = JSONDecoder()
            for line in mappingText.split(whereSeparator: \.isNewline) {
                guard let row = try? decoder.decode(AniListMapping.self, from: Data(line.utf8)),
                      malIDs.contains(row.malID), row.aniListID > 0 else { continue }
                aniListIDs.insert(row.aniListID)
                if englishMALIDs.contains(row.malID) {
                    englishAniListIDs.insert(row.aniListID)
                }
            }

            guard !Task.isCancelled,
                  languages == selectedLanguagesIncludingCatalogAudioRequirement else {
                return hasSnapshot(for: selectedLanguagesIncludingCatalogAudioRequirement)
            }
            publishSnapshot(
                malIDs: malIDs,
                aniListIDs: aniListIDs,
                englishMALIDs: englishMALIDs,
                englishAniListIDs: englishAniListIDs,
                languages: languages
            )
            let defaults = ProfileSettingsStore.active
            // Persist only a complete selection snapshot. A partial success is
            // still useful in this session, but must be retried on next launch
            // so the missing language can recover without blocking the one that
            // did load.
            if downloadedLanguages == languages && didLoadMapping {
                defaults.set(languages.sorted(), forKey: Self.cachedLanguagesKey)
                defaults.set(malIDs.sorted(), forKey: Self.cachedMALIDsKey)
                defaults.set(aniListIDs.sorted(), forKey: Self.cachedAniListIDsKey)
                defaults.set(englishMALIDs.sorted(), forKey: Self.cachedEnglishMALIDsKey)
                defaults.set(englishAniListIDs.sorted(), forKey: Self.cachedEnglishAniListIDsKey)
            } else {
                defaults.removeObject(forKey: Self.cachedLanguagesKey)
                defaults.removeObject(forKey: Self.cachedMALIDsKey)
                defaults.removeObject(forKey: Self.cachedAniListIDsKey)
                defaults.removeObject(forKey: Self.cachedEnglishMALIDsKey)
                defaults.removeObject(forKey: Self.cachedEnglishAniListIDsKey)
            }
            notifyRefreshObservers()
            Logger.shared.log(
                "MyDubList: loaded languages=\(downloadedLanguages.sorted().joined(separator: ",")) requested=\(languages.sorted().joined(separator: ",")) MAL=\(malIDs.count) AniList=\(aniListIDs.count)",
                type: "Anime"
            )
            return true
        } catch {
            if !Task.isCancelled {
                Logger.shared.log("MyDubList: dub filter refresh failed: \(error.localizedDescription)", type: "Anime")
            }
            // A failed refresh has not changed the available snapshot. Do not
            // broadcast a filter-change event here: Browse and Schedule respond
            // to that event by retrying, which used to create a refresh loop.
            return hasSnapshot(for: languages)
        }
    }

    func shouldInclude(_ result: TMDBSearchResult) -> Bool {
        let languages = selectedLanguagesIncludingCatalogAudioRequirement
        guard !languages.isEmpty else { return true }
        let animeCountries: Set<String> = ["JP", "CN", "KR", "TW"]
        let animeLanguages: Set<String> = ["ja", "zh", "ko"]
        let isLikelyAnime = result.animeIdentitySeed != nil
            || result.isAnimeHint == true
            || (result.genreIds?.contains(16) == true
                && (animeLanguages.contains(result.originalLanguage?.lowercased() ?? "")
                    || result.originCountry?.contains(where: { animeCountries.contains($0) }) == true))
        guard isLikelyAnime else { return true }
        if let originalLanguage = result.originalLanguage?.lowercased(),
           languages.contains(where: { rawLanguage in
               guard let language = MyDubListLanguage(rawValue: rawLanguage) else { return false }
               let code = language.taizenLanguageCode
               return originalLanguage == code || originalLanguage.hasPrefix(code + "-")
           }) {
            return true
        }
        guard let seed = result.animeIdentitySeed else { return false }

        lock.lock()
        defer { lock.unlock() }
        guard isLoaded, loadedLanguages == languages else { return false }
        if allowedAniListIDs.contains(seed.anilistId) { return true }
        if let malID = seed.malId, allowedMALIDs.contains(malID) { return true }
        return false
    }

    func shouldIncludeEnglishSchedule(anilistID: Int?, malID: Int?) -> Bool {
        let languages = selectedLanguagesIncludingCatalogAudioRequirement
        if languages.isEmpty { return true }
        guard languages.contains(MyDubListLanguage.english.rawValue) else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard isLoaded, loadedLanguages == languages else { return false }
        if let anilistID, anilistID > 0, allowedEnglishAniListIDs.contains(anilistID) { return true }
        if let malID, malID > 0, allowedEnglishMALIDs.contains(malID) { return true }
        return false
    }

    func shouldInclude(anilistID: Int?, malID: Int?) -> Bool {
        let languages = selectedLanguagesIncludingCatalogAudioRequirement
        guard !languages.isEmpty else { return true }
        lock.lock()
        defer { lock.unlock() }
        guard isLoaded, loadedLanguages == languages else { return false }
        if let anilistID, anilistID > 0, allowedAniListIDs.contains(anilistID) { return true }
        if let malID, malID > 0, allowedMALIDs.contains(malID) { return true }
        return false
    }

    private func hasSnapshot(for languages: Set<String>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isLoaded && loadedLanguages == languages
    }

    private func clearSnapshot() {
        lock.lock()
        allowedMALIDs = []
        allowedAniListIDs = []
        allowedEnglishMALIDs = []
        allowedEnglishAniListIDs = []
        loadedLanguages = []
        isLoaded = true
        lock.unlock()
    }

    private func publishSnapshot(
        malIDs: Set<Int>,
        aniListIDs: Set<Int>,
        englishMALIDs: Set<Int>,
        englishAniListIDs: Set<Int>,
        languages: Set<String>
    ) {
        lock.lock()
        allowedMALIDs = malIDs
        allowedAniListIDs = aniListIDs
        allowedEnglishMALIDs = englishMALIDs
        allowedEnglishAniListIDs = englishAniListIDs
        loadedLanguages = languages
        isLoaded = true
        lock.unlock()
    }

    private func loadCachedSnapshot(for languages: Set<String>) {
        let defaults = ProfileSettingsStore.active
        let cachedLanguages = Set(defaults.stringArray(forKey: Self.cachedLanguagesKey) ?? [])
        guard cachedLanguages == languages else { return }
        let malIDs = Set((defaults.array(forKey: Self.cachedMALIDsKey) as? [Int] ?? []).filter { $0 > 0 })
        let aniListIDs = Set((defaults.array(forKey: Self.cachedAniListIDsKey) as? [Int] ?? []).filter { $0 > 0 })
        let englishMALIDs = Set((defaults.array(forKey: Self.cachedEnglishMALIDsKey) as? [Int] ?? []).filter { $0 > 0 })
        let englishAniListIDs = Set((defaults.array(forKey: Self.cachedEnglishAniListIDsKey) as? [Int] ?? []).filter { $0 > 0 })
        lock.lock()
        allowedMALIDs = malIDs
        allowedAniListIDs = aniListIDs
        allowedEnglishMALIDs = englishMALIDs
        allowedEnglishAniListIDs = englishAniListIDs
        loadedLanguages = languages
        isLoaded = true
        lock.unlock()
    }

    private static func download(_ url: URL, maximumBytes: Int) async throws -> Data {
        var request = URLRequest(url: url)
        // Dub metadata refresh is awaited only when no cached language
        // snapshot exists. Keep each download bounded so Browse cannot remain
        // in its loading state indefinitely on a slow mirror/network.
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              data.count <= maximumBytes else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

struct KidsPolicyDetails: Codable, Hashable {
    let isAdult: Bool
    let genreIds: [Int]
    let overview: String?
}

class TMDBContentFilter: ObservableObject {
    static let shared = TMDBContentFilter()
    static let catalogFiltersDidChangeNotification = Notification.Name("catalogFiltersDidChange")

    @Published private(set) var maturityRatingRevision = 0

    private let animeEligibilityLock = NSLock()
    func isResolvingSelectedAudio(for results: [TMDBSearchResult]) -> Bool {
        let animeIDs = Set(results.compactMap { result -> Int? in
            guard Self.isAnimeResult(result),
                  let id = result.animeIdentitySeed?.anilistId,
                  id > 0 else { return nil }
            return id
        })
        let catalogKeys = Set(results.compactMap { result -> String? in
            guard !Self.isAnimeResult(result),
                  result.isMovie || result.isTVShow else { return nil }
            return catalogAudioAvailabilityKey(for: result)
        })
        animeEligibilityLock.lock()
        defer { animeEligibilityLock.unlock() }
        return !animeIDs.isDisjoint(with: animeAudioLoadingIDs)
            || !catalogKeys.isDisjoint(with: catalogAudioLoadingKeys)
    }

    private var animeAgeRatingsByID: [Int: MaturityRating] = [:]
    // MAL-only schedule rows use a negative sourceMediaId, not an AniList ID.
    // Keep their resolved rating by stable schedule-entry ID so they still
    // participate in the All Ages calendar filter.
    private var scheduleAnimeAgeRatingsByEntryID: [String: MaturityRating] = [:]
    // TVMaze episode rows do not carry a TMDB ID. Resolve exact title matches
    // once per show so the Series All Ages filter can still use TMDB ratings.
    private var scheduleSeriesAgeRatingsByEntryID: [String: MaturityRating] = [:]
    private var scheduleSeriesTMDBIDsByTitle: [String: Int] = [:]
    private var animeAgeCheckedIDs: Set<Int> = []
    private var animeAgeLoadingIDs: Set<Int> = []
    private var animeAgeRetryAfterByID: [Int: Date] = [:]
    private var animeAudioEligibleIDs: Set<Int> = []
    private var animeAudioEligibilityLanguages: Set<String> = []
    private var animeAudioCheckedIDs: Set<Int> = []
    private var animeAudioLoadingIDs: Set<Int> = []
    private var animeAudioRetryAfterByID: [Int: Date] = [:]
    private var catalogAudioEligibleKeys: Set<String> = []
    private var catalogAudioCheckedKeys: Set<String> = []
    private var catalogAudioLoadingKeys: Set<String> = []
    private var catalogAudioRetryAfterByKey: [String: Date] = [:]
    @Published private(set) var catalogAudioRevision = 0
    private let runtimeMetadataLock = NSLock()
    private var runtimeMinutesByKey: [String: Int] = [:]
    private var runtimeCheckedKeys = Set<String>()
    private var runtimeLoadingKeys = Set<String>()
    private var productionCompaniesByKey: [String: [String]] = [:]
    private var productionMetadataCheckedKeys = Set<String>()
    private var productionMetadataLoadingKeys = Set<String>()
    private var productionMetadataRetryAfterByKey: [String: Date] = [:]

    private var cancellables = Set<AnyCancellable>()

    @Published var filterHorror: Bool {
        didSet {
            ProfileSettingsStore.active.set(filterHorror, forKey: "filterHorror")
            // Re-filter the already loaded catalog snapshot. Reloading the
            // catalog here replaces SwiftUI rows while the user is scrolling,
            // which can reset the scroll position and flash the whole screen.
            NotificationCenter.default.post(
                name: Self.catalogFiltersDidChangeNotification,
                object: nil
            )
        }
    }

    @Published private(set) var isKidsProfileActive: Bool = ProfileManager.shared.isKidsModeActive

    private let horrorGenreIds = [27]

    private static let kidsBlockedGenreIds: Set<Int> = [27, 53, 80, 10752, 9648, 10768]

    private let explicitCatalogTitleDenylist: Set<String> = [
        "overflow"
    ]

    private static let kidsMetadataDenylist: Set<String> = [
        "blood",
        "brutal",
        "cannibal",
        "carnage",
        "decapitation",
        "demonic",
        "disturbing",
        "drug abuse",
        "drug addiction",
        "gore",
        "graphic violence",
        "grisly",
        "gruesome",
        "hard drugs",
        "homicide",
        "horror",
        "massacre",
        "mutilation",
        "prostitution",
        "psychological horror",
        "rape",
        "sadistic",
        "satanic",
        "self harm",
        "serial killer",
        "sexual assault",
        "slasher",
        "snuff",
        "suicide",
        "torture",
        "violent"
    ]
    private static let adultAnimeMetadataDenylist: Set<String> = [
        "adult animation",
        "adult anime",
        "adult cartoon",
        "adult film",
        "adult video",
        "ecchi",
        "ero anime",
        "eroge",
        "erotica",
        "erotic",
        "erotic animation",
        "erotic anime",
        "explicit sex",
        "explicit sexual",
        "female nudity",
        "hentai",
        "mature anime",
        "mild nudity",
        "nudity",
        "ova hentai",
        "pornographic",
        "pornography",
        "r 18",
        "r18",
        "sex comedy",
        "sexual content",
        "sexually explicit",
        "softcore",
        "uncensored"
    ]

    private init() {
        ProfileSettingsStore.active.register(defaults: [
            "catalogHideBelowPG13Movies": true,
            "catalogHideBelowTV14Shows": true,
            "catalogHideBelowPG13Anime": true,
            "catalogHideAllAgesMovies": true,
            "catalogHideAllAgesSeries": true,
            "catalogHideAllAgesAnime": true,
            "catalogRequireEnglishSpanishAudio": true,
            "catalogHideHentai": true,
            "catalogHideYuri": true,
            "catalogHideYaoi": true,
            "catalogHideAnimeSpecialsAndOVAs": true,
            "catalogHidePre1994Anime": true,
            "catalogHidePre1994Movies": true,
            "catalogHidePre1994TVShows": true,
            "catalogHideUnreleasedAnime": true,
            "catalogHideUnreleasedMovies": true,
            "catalogHideUnreleasedTVShows": true,
            "catalogHideUnofficialContent": true,
            "catalogHideUnder20MinuteContent": true
        ])
        self.filterHorror = ProfileSettingsStore.active.bool(forKey: "filterHorror")
        Task { _ = await MyDubListDubFilter.shared.refresh() }
        TMDBMaturityRatingStore.shared.$revision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] revision in
                guard let self, self.isKidsProfileActive else { return }
                self.maturityRatingRevision = revision
                // Kids-profile ratings are resolved asynchronously. Reapply
                // the updated safety filter to the retained catalog snapshot
                // instead of forcing HomeView to reload and replace its rows.
                NotificationCenter.default.post(
                    name: Self.catalogFiltersDidChangeNotification,
                    object: nil
                )
            }
            .store(in: &cancellables)
    }

    func activeProfileDidChange() {
        Task { await MyDubListDubFilter.shared.refresh() }

        let storedFilterHorror = ProfileSettingsStore.active.bool(forKey: "filterHorror")
        if storedFilterHorror != filterHorror {
            if Thread.isMainThread {
                filterHorror = storedFilterHorror
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.filterHorror = storedFilterHorror
                }
            }
        }
        let isKids = ProfileManager.shared.isKidsModeActive
        guard isKids != isKidsProfileActive else { return }
        if Thread.isMainThread {
            isKidsProfileActive = isKids
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isKidsProfileActive = isKids
            }
        }
    }

    private var kidsModeEnabled: Bool { ProfileManager.shared.isKidsModeActive }

    func prepareMaturityRatings(for results: [TMDBSearchResult]) async {
        let defaults = ProfileSettingsStore.active
        if defaults.bool(forKey: "catalogHideUnder20MinuteContent") {
            Task(priority: .utility) { await self.resolveRuntimeMetadata(for: results) }
        }
        let needsTMDBRatings = kidsModeEnabled
            || Self.ageFilterEnabled("catalogHideBelowPG13Movies", defaults: defaults)
            || Self.ageFilterEnabled("catalogHideBelowTV14Shows", defaults: defaults)
            || defaults.bool(forKey: "catalogHideAllAgesMovies")
            || defaults.bool(forKey: "catalogHideAllAgesSeries")
        if needsTMDBRatings {
            // Anime maturity is sourced from anime-specific providers only.
            let ratingResults = results.filter { !Self.isAnimeResult($0) }
            let ratingLookups = ratingResults.map { (isMovie: $0.isMovie, id: $0.id) }
            if kidsModeEnabled {
                await TMDBMaturityRatingStore.shared.resolve(ratingLookups)
            } else {
                let revisionBeforeLookup = await MainActor.run { TMDBMaturityRatingStore.shared.revision }
                Task(priority: .utility) {
                    await TMDBMaturityRatingStore.shared.resolve(ratingLookups)
                    let didResolveNewRatings = await MainActor.run {
                        TMDBMaturityRatingStore.shared.revision != revisionBeforeLookup
                    }
                    if didResolveNewRatings {
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: TMDBContentFilter.catalogFiltersDidChangeNotification,
                                object: nil
                            )
                        }
                    }
                }
            }
        }

        let hideBelowAnime = defaults.bool(forKey: "catalogHideBelowPG13Anime")
        let hideAllAgesAnime = defaults.bool(forKey: "catalogHideAllAgesAnime")
        let requireVerifiedAudio = defaults.bool(forKey: "catalogRequireEnglishSpanishAudio")
        if requireVerifiedAudio {
            scheduleCatalogAudioAvailabilityResolutionIfNeeded(for: results)
        }
        let shouldResolveAnimeAgeRatings = kidsModeEnabled || hideBelowAnime || hideAllAgesAnime
        guard shouldResolveAnimeAgeRatings || requireVerifiedAudio else { return }

        var uniqueAnime: [Int: TMDBSearchResult] = [:]
        for result in results where Self.isAnimeResult(result) {
            guard let id = result.animeIdentitySeed?.anilistId, id > 0 else { continue }
            uniqueAnime[id] = result
        }
        let animeResults = Array(uniqueAnime.values)

        if shouldResolveAnimeAgeRatings {
            let identifiers = Array(uniqueAnime.keys)
            if kidsModeEnabled {
                await resolveAnimeAgeRatings(for: animeResults)
            } else {
                Task(priority: .utility) {
                    await TMDBContentFilter.shared.resolveAnimeAgeRatings(for: animeResults)
                }
            }
        }

        guard requireVerifiedAudio, !animeResults.isEmpty else { return }
        scheduleAnimeAudioMetadataResolutionIfNeeded(for: animeResults)
    }

    func prepareScheduleAgeRatings(for entries: [ScheduleEntry]) async {
        let defaults = ProfileSettingsStore.active
        let hideBelowAnime = defaults.bool(forKey: "catalogHideBelowPG13Anime")
        let hideAllAgesAnime = defaults.bool(forKey: "catalogHideAllAgesAnime")
        let animeEntries = (hideBelowAnime || hideAllAgesAnime)
            ? entries.filter { $0.source == .anime }
            : []
        if !animeEntries.isEmpty {
            await resolveAnimeAgeRatings(
                identities: animeEntries.map { ($0.sourceMediaId, $0.animeMALID) }
            )

            let malOnlyEntries = animeEntries.compactMap { entry -> (String, Int)? in
                guard entry.sourceMediaId <= 0 else { return nil }
                let malID = entry.animeMALID ?? (entry.sourceMediaId < 0 ? -entry.sourceMediaId : nil)
                guard let malID, malID > 0 else { return nil }
                return (entry.id, malID)
            }
            if MALMetadataService.shared.isConfigured, !malOnlyEntries.isEmpty {
                await withTaskGroup(of: (String, MaturityRating?).self) { group in
                    for (entryID, malID) in malOnlyEntries {
                        group.addTask {
                            (entryID, await MALMetadataService.shared.fetchMaturityRating(malID: malID))
                        }
                    }
                    for await (entryID, rating) in group {
                        animeEligibilityLock.lock()
                        if let rating, rating != .unknown {
                            scheduleAnimeAgeRatingsByEntryID[entryID] = rating
                        } else {
                            scheduleAnimeAgeRatingsByEntryID.removeValue(forKey: entryID)
                        }
                        animeEligibilityLock.unlock()
                    }
                }
            }
        }

        let tmdbEntries = entries.compactMap { entry -> (isMovie: Bool, id: Int)? in
            guard let id = entry.tmdbId, id > 0 else { return nil }
            let minimumAgeEnabled = Self.ageFilterEnabled(
                entry.isMovie ? "catalogHideBelowPG13Movies" : "catalogHideBelowTV14Shows",
                defaults: defaults
            )
            let allAgesEnabled = defaults.bool(
                forKey: entry.isMovie ? "catalogHideAllAgesMovies" : "catalogHideAllAgesSeries"
            )
            return minimumAgeEnabled || allAgesEnabled ? (entry.isMovie, id) : nil
        }
        if !tmdbEntries.isEmpty {
            await TMDBMaturityRatingStore.shared.resolve(tmdbEntries)
        }

        let seriesWithoutTMDBIDs = entries.filter {
            $0.source == .western && !$0.isMovie && $0.tmdbId == nil
                && (
                    Self.ageFilterEnabled("catalogHideBelowTV14Shows", defaults: defaults)
                        || defaults.bool(forKey: "catalogHideAllAgesSeries")
                )
        }
        if !seriesWithoutTMDBIDs.isEmpty {
            var uniqueShows: [String: ScheduleEntry] = [:]
            for entry in seriesWithoutTMDBIDs {
                let key = Self.normalizedScheduleTitle(entry.title)
                guard !key.isEmpty, uniqueShows[key] == nil else { continue }
                uniqueShows[key] = entry
            }

            animeEligibilityLock.lock()
            let cachedMatches = uniqueShows.keys.compactMap { key -> (String, Int)? in
                guard let id = scheduleSeriesTMDBIDsByTitle[key] else { return nil }
                return (key, id)
            }
            animeEligibilityLock.unlock()
            var matches = Dictionary(uniqueKeysWithValues: cachedMatches)

            let unresolvedShows = uniqueShows.filter { matches[$0.key] == nil }
            let newlyFound = await withTaskGroup(of: (String, Int?).self) { group in
                for (titleKey, entry) in unresolvedShows {
                    group.addTask {
                        guard !Task.isCancelled,
                              let candidates = try? await TMDBService.shared.searchTVShows(query: entry.title) else {
                            return (titleKey, nil)
                        }
                        let exactMatches = candidates.filter {
                            Self.normalizedScheduleTitle($0.name) == titleKey
                        }
                        guard !exactMatches.isEmpty else { return (titleKey, nil) }
                        let year = entry.releaseYear
                        let selected = exactMatches.first { candidate in
                            guard let year, let firstAirDate = candidate.firstAirDate,
                                  firstAirDate.count >= 4 else { return false }
                            return Int(firstAirDate.prefix(4)) == year
                        } ?? exactMatches.first
                        return (titleKey, selected?.id)
                    }
                }

                var values: [String: Int] = [:]
                for await (titleKey, tmdbID) in group {
                    if let tmdbID, tmdbID > 0 { values[titleKey] = tmdbID }
                }
                return values
            }
            matches.merge(newlyFound) { _, new in new }
            animeEligibilityLock.lock()
            for (titleKey, tmdbID) in newlyFound {
                scheduleSeriesTMDBIDsByTitle[titleKey] = tmdbID
            }
            animeEligibilityLock.unlock()

            let resolvedIDs = Array(Set(matches.values))
            if !resolvedIDs.isEmpty {
                await TMDBMaturityRatingStore.shared.resolve(
                    resolvedIDs.map { (isMovie: false, id: $0) }
                )
            }

            animeEligibilityLock.lock()
            for entry in seriesWithoutTMDBIDs {
                let key = Self.normalizedScheduleTitle(entry.title)
                guard let tmdbID = matches[key],
                      let rating = TMDBMaturityRatingStore.shared.rating(isMovie: false, id: tmdbID),
                      rating != .unknown else {
                    scheduleSeriesAgeRatingsByEntryID.removeValue(forKey: entry.id)
                    continue
                }
                scheduleSeriesAgeRatingsByEntryID[entry.id] = rating
            }
            animeEligibilityLock.unlock()
        }
    }

    private static func normalizedScheduleTitle(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func scheduleEntryIsAllAges(_ entry: ScheduleEntry) -> Bool {
        let defaults = ProfileSettingsStore.active
        if entry.source == .anime {
            guard defaults.bool(forKey: "catalogHideAllAgesAnime") else { return false }
            let id = entry.sourceMediaId
            animeEligibilityLock.lock()
            let rating = scheduleAnimeAgeRatingsByEntryID[entry.id]
                ?? (id > 0 ? animeAgeRatingsByID[id] : nil)
            animeEligibilityLock.unlock()
            return ScheduleAllAgesPolicy.shouldExclude(rating: rating, enabled: true)
        }

        let key = entry.isMovie ? "catalogHideAllAgesMovies" : "catalogHideAllAgesSeries"
        guard defaults.bool(forKey: key) else { return false }
        if let id = entry.tmdbId, id > 0 {
            return ScheduleAllAgesPolicy.shouldExclude(
                rating: TMDBMaturityRatingStore.shared.rating(isMovie: entry.isMovie, id: id),
                enabled: true
            )
        }
        animeEligibilityLock.lock()
        let rating = scheduleSeriesAgeRatingsByEntryID[entry.id]
        animeEligibilityLock.unlock()
        return ScheduleAllAgesPolicy.shouldExclude(rating: rating, enabled: true)
    }

    func scheduleEntryIsBlockedByConfiguredAgeFilter(_ entry: ScheduleEntry) -> Bool {
        let defaults = ProfileSettingsStore.active
        if entry.source == .anime {
            let hideBelowMinimum = defaults.bool(forKey: "catalogHideBelowPG13Anime")
            let hideAllAges = defaults.bool(forKey: "catalogHideAllAgesAnime")
            guard hideBelowMinimum || hideAllAges else { return false }
            let id = entry.sourceMediaId
            animeEligibilityLock.lock()
            let rating = scheduleAnimeAgeRatingsByEntryID[entry.id]
                ?? (id > 0 ? animeAgeRatingsByID[id] : nil)
            animeEligibilityLock.unlock()
            return ScheduleAllAgesPolicy.shouldExclude(
                rating: rating,
                minimum: hideBelowMinimum ? .teen : nil,
                hideAllAges: hideAllAges
            )
        }

        let hideBelowMinimum = Self.ageFilterEnabled(
            entry.isMovie ? "catalogHideBelowPG13Movies" : "catalogHideBelowTV14Shows",
            defaults: defaults
        )
        let hideAllAges = defaults.bool(
            forKey: entry.isMovie ? "catalogHideAllAgesMovies" : "catalogHideAllAgesSeries"
        )
        guard hideBelowMinimum || hideAllAges else { return false }

        let rating: MaturityRating?
        if let id = entry.tmdbId, id > 0 {
            rating = TMDBMaturityRatingStore.shared.rating(isMovie: entry.isMovie, id: id)
        } else if !entry.isMovie {
            animeEligibilityLock.lock()
            rating = scheduleSeriesAgeRatingsByEntryID[entry.id]
            animeEligibilityLock.unlock()
        } else {
            rating = nil
        }
        let minimum = hideBelowMinimum ? (entry.isMovie ? MaturityRating.teen : .age14) : nil
        return ScheduleAllAgesPolicy.shouldExclude(
            rating: rating,
            minimum: minimum,
            hideAllAges: hideAllAges
        )
    }

    func resolveAnimeAgeRatings(for results: [TMDBSearchResult]) async {
        let identities = results.compactMap { result -> (Int, Int?)? in
            guard let id = result.animeIdentitySeed?.anilistId, id > 0 else { return nil }
            return (id, result.animeIdentitySeed?.malId)
        }
        await resolveAnimeAgeRatings(identities: identities)
    }

    /// Browse must finish the metadata required by active filters before it
    /// publishes a page. The general catalogue path intentionally resolves some
    /// metadata in the background; doing that here caused a filtered Anime grid
    /// to publish as empty before its ratings/runtime/production data arrived.
    func resolveBrowseFilterMetadata(
        for results: [TMDBSearchResult],
        requiresAnimeAgeRating: Bool = false
    ) async {
        let defaults = ProfileSettingsStore.active
        let animeResults = results.filter { Self.isAnimeResult($0) }
        let nonAnimeResults = results.filter { !Self.isAnimeResult($0) }
        let dubFilter = MyDubListDubFilter.shared
        let selectedLanguages = dubFilter.selectedLanguagesIncludingCatalogAudioRequirement
        let needsAnimeAge = requiresAnimeAgeRating
            || defaults.bool(forKey: "catalogHideBelowPG13Anime")
            || defaults.bool(forKey: "catalogHideAllAgesAnime")
            || kidsModeEnabled
        let tmdbRatingResults = nonAnimeResults.filter { result in
            let minimumEnabled = result.isMovie
                ? Self.ageFilterEnabled("catalogHideBelowPG13Movies", defaults: defaults)
                : Self.ageFilterEnabled("catalogHideBelowTV14Shows", defaults: defaults)
            let allAgesEnabled = defaults.bool(
                forKey: result.isMovie ? "catalogHideAllAgesMovies" : "catalogHideAllAgesSeries"
            )
            return minimumEnabled || allAgesEnabled || kidsModeEnabled
        }

        // Browse must not filter against an uninitialised dub snapshot. In
        // particular, an English-only selection used to reject every Japanese
        // anime card before the language index had finished loading.
        if !selectedLanguages.isEmpty, !dubFilter.prepareCachedSnapshot() {
            // Verified per-title audio lookups can proceed while the shared index
            // refreshes. The catalogue observes the refresh notification and
            // re-filters retained results when the index becomes available.
            Task(priority: .utility) {
                _ = await dubFilter.refresh()
            }
        }

        if !selectedLanguages.isEmpty, !animeResults.isEmpty {
            prepareAnimeAudioEligibilitySelection(selectedLanguages)
        }

        // Resolve only the metadata requested by active filters, concurrently.
        // Awaiting this bounded batch before filtering prevents an entire page
        // from being discarded as "empty" while production/runtime/dub lookups
        // are still running in the background.
        await withTaskGroup(of: Void.self) { group in
            if defaults.bool(forKey: "catalogHideUnder20MinuteContent") {
                group.addTask { await self.resolveRuntimeMetadata(for: results) }
            }
            if defaults.bool(forKey: "catalogHideUnofficialContent") {
                group.addTask { await self.resolveProductionMetadata(for: results) }
            }
            if needsAnimeAge, !animeResults.isEmpty {
                group.addTask { await self.resolveAnimeAgeRatings(for: animeResults) }
            }
            if !selectedLanguages.isEmpty, !animeResults.isEmpty {
                group.addTask {
                    await self.resolveAnimeAudioMetadata(
                        for: animeResults,
                        selectedLanguages: selectedLanguages
                    )
                }
            }
            if defaults.bool(forKey: "catalogRequireEnglishSpanishAudio"),
               !nonAnimeResults.isEmpty {
                group.addTask {
                    await self.resolveCatalogAudioAvailability(for: nonAnimeResults)
                }
            }
            if !tmdbRatingResults.isEmpty {
                group.addTask {
                    await TMDBMaturityRatingStore.shared.resolve(
                        tmdbRatingResults.map { (isMovie: $0.isMovie, id: $0.id) }
                    )
                }
            }
        }
    }

    private func resolveAnimeAgeRatings(identities: [(Int, Int?)]) async {
        var malIDsByAnimeID: [Int: Int] = [:]
        var uniqueIDs = Set<Int>()
        for (id, malID) in identities where id > 0 {
            uniqueIDs.insert(id)
            if let malID, malID > 0, malIDsByAnimeID[id] == nil {
                malIDsByAnimeID[id] = malID
            }
        }
        let unresolvedIDs = uniqueIDs.filter { id in
            animeEligibilityLock.lock()
            defer { animeEligibilityLock.unlock() }
            guard !animeAgeCheckedIDs.contains(id),
                  !animeAgeLoadingIDs.contains(id),
                  Date() >= (animeAgeRetryAfterByID[id] ?? .distantPast) else { return false }
            animeAgeLoadingIDs.insert(id)
            return true
        }
        guard !unresolvedIDs.isEmpty else { return }

        var ratings = (try? await TaizenAnimeAgeRatingService.shared.ratings(anilistIDs: Array(unresolvedIDs))) ?? [:]
        let missingIDs = unresolvedIDs.filter { ratings[$0] == nil || ratings[$0] == .unknown }
        if MALMetadataService.shared.isConfigured, !missingIDs.isEmpty {
            await withTaskGroup(of: (Int, MaturityRating?).self) { group in
                for id in missingIDs {
                    guard let malID = malIDsByAnimeID[id], malID > 0 else { continue }
                    group.addTask {
                        (id, await MALMetadataService.shared.fetchMaturityRating(malID: malID))
                    }
                }
                while let (id, rating) = await group.next() {
                    if let rating, rating != .unknown { ratings[id] = rating }
                }
            }
        }

        // Jikan exposes MyAnimeList's official age classification without
        // requiring a user-supplied MAL client ID. Resolve missing titles as a
        // rate-limited concurrent batch instead of serial network round-trips.
        let jikanIDs = missingIDs.compactMap { id -> (animeID: Int, malID: Int)? in
            guard (ratings[id] == nil || ratings[id] == .unknown),
                  let malID = malIDsByAnimeID[id], malID > 0 else { return nil }
            return (id, malID)
        }
        let jikanRatings = await JikanAnimeAgeRatingService.shared.ratings(
            malIDs: Array(Set(jikanIDs.map(\.malID)))
        )
        for entry in jikanIDs {
            if let rating = jikanRatings[entry.malID], rating != .unknown {
                ratings[entry.animeID] = rating
            }
        }

        var didResolveAny = false
        for id in unresolvedIDs {
            if let rating = ratings[id], rating != .unknown {
                storeAnimeAgeRating(rating, for: id)
                didResolveAny = true
            } else {
                animeEligibilityLock.lock()
                animeAgeLoadingIDs.remove(id)
                animeAgeRetryAfterByID[id] = Date().addingTimeInterval(15 * 60)
                animeEligibilityLock.unlock()
            }
        }
        if didResolveAny {
            NotificationCenter.default.post(
                name: TMDBContentFilter.catalogFiltersDidChangeNotification,
                object: nil
            )
        }
    }

    private static func resolveAnimeDubEligibility(
        anilistID: Int,
        malID: Int?,
        selectedLanguages: Set<String>
    ) async -> Bool? {
        var counts = (try? await TaizenAnimeDubMetadataService.shared.episodeDubCounts(
            anilistID: anilistID,
            malID: malID
        )) ?? [:]

        // Taizen's positive "es" count already confirms Spanish audio for the
        // app's combined Latino/Castellano filter. Query Anidub only when that
        // confirmation is missing, avoiding one anonymous API request per title
        // when Taizen has already supplied the needed language metadata.
        if AnimeDubMetadataFallbackPolicy.shouldQueryAnidub(
            taizenCounts: counts,
            selectedLanguages: selectedLanguages
        ) {
            if let anidubCounts = try? await AnidubAnimeDubMetadataService.shared.episodeDubCounts(anilistID: anilistID) {
                for (language, count) in anidubCounts {
                    counts[language] = max(counts[language] ?? 0, count)
                }
            }
        }

        guard !counts.isEmpty else { return nil }
        return AnimeDubAudioSelectionPolicy.hasSelectedAudio(
            selectedLanguages: selectedLanguages,
            dubCountsByLanguage: counts
        )
    }

    private func resolveAnimeAudioMetadata(
        for results: [TMDBSearchResult],
        selectedLanguages: Set<String>
    ) async {
        let candidates = results.filter { result in
            guard !MyDubListDubFilter.shared.shouldInclude(result) else { return false }
            guard CatalogNativeAudioPolicy.requiresDubVerification(
                originalLanguage: result.originalLanguage,
                selectedLanguages: selectedLanguages
            ) else { return false }
            guard let id = result.animeIdentitySeed?.anilistId, id > 0 else { return false }
            animeEligibilityLock.lock()
            defer { animeEligibilityLock.unlock() }
            guard !animeAudioCheckedIDs.contains(id),
                  !animeAudioLoadingIDs.contains(id),
                  Date() >= (animeAudioRetryAfterByID[id] ?? .distantPast) else { return false }
            animeAudioLoadingIDs.insert(id)
            return true
        }
        guard !candidates.isEmpty else { return }

        await withTaskGroup(of: (Int, Bool?).self) { group in
            var iterator = candidates.makeIterator()
            let concurrencyLimit = 6
            for _ in 0..<min(concurrencyLimit, candidates.count) {
                guard let result = iterator.next(),
                      let id = result.animeIdentitySeed?.anilistId else { continue }
                group.addTask {
                    let eligible = await Self.resolveAnimeDubEligibility(
                        anilistID: id,
                        malID: result.animeIdentitySeed?.malId,
                        selectedLanguages: selectedLanguages
                    )
                    return (id, eligible)
                }
            }

            while let (id, eligible) = await group.next() {
                if let eligible {
                    storeAnimeAudioEligibility(eligible, for: id, selectedLanguages: selectedLanguages)
                    // Publish each completed lookup: a slow title must not hold
                    // already-verified rows behind the whole six-title batch.
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: TMDBContentFilter.catalogFiltersDidChangeNotification,
                            object: nil
                        )
                    }
                } else {
                    animeEligibilityLock.lock()
                    if animeAudioEligibilityLanguages == selectedLanguages {
                        animeAudioLoadingIDs.remove(id)
                        // Missing provider data is not evidence of a dub. Keep the
                        // result excluded, but retry later so temporary API outages
                        // do not permanently poison the in-memory eligibility cache.
                        animeAudioRetryAfterByID[id] = Date().addingTimeInterval(10 * 60)
                    }
                    animeEligibilityLock.unlock()
                    // Finish the transient verification state even when a
                    // provider lookup fails, so Search can render a final
                    // empty state rather than a permanent spinner.
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: TMDBContentFilter.catalogFiltersDidChangeNotification,
                            object: nil
                        )
                    }
                }

                if let result = iterator.next(),
                   let nextID = result.animeIdentitySeed?.anilistId {
                    group.addTask {
                        let eligible = await Self.resolveAnimeDubEligibility(
                            anilistID: nextID,
                            malID: result.animeIdentitySeed?.malId,
                            selectedLanguages: selectedLanguages
                        )
                        return (nextID, eligible)
                    }
                }
            }
        }
    }

    func filterSearchResultsResolvingRatings(
        _ results: [TMDBSearchResult],
        allowUpcomingContent: Bool = false
    ) async -> [TMDBSearchResult] {
        // prepareMaturityRatings starts background audio verification. Return
        // cached/native matches immediately; notification observers re-filter
        // the retained snapshot as each unknown title becomes verified.
        await prepareMaturityRatings(for: results)
        return filterSearchResults(results, allowUpcomingContent: allowUpcomingContent)
    }

    func filterFastAnimeSearchResultsResolvingRatings(_ results: [TMDBSearchResult]) async -> [TMDBSearchResult] {
        let animeResults = results.map { $0.withAnimeHint(true) }
        await prepareMaturityRatings(for: animeResults)
        return filterFastAnimeSearchResults(animeResults)
    }

    func filterContinueWatchingResolvingRatings(
        _ items: [ContinueWatchingItem]
    ) async -> [ContinueWatchingItem] {
        guard ProfileManager.shared.isKidsModeActive else { return items }
        await TMDBMaturityRatingStore.shared.resolve(
            items.map { (isMovie: $0.isMovie, id: $0.tmdbId) }
        )
        return items.filter { item in
            guard TMDBMaturityRatingStore.shared.isAllowedForKids(isMovie: item.isMovie, id: item.tmdbId) else {
                return false
            }
            guard TMDBMaturityRatingStore.shared.kidsDetailPolicyAllows(
                isMovie: item.isMovie,
                id: item.tmdbId
            ) == true else {
                return false
            }

            return Self.kidsTextHeuristicsAllow(title: item.title)
        }
    }

    func filterSearchResults(
        _ results: [TMDBSearchResult],
        allowUpcomingContent: Bool = false,
        resolveMetadataInBackground: Bool = true,
        allowUnresolvedOptionalMetadata: Bool = false
    ) -> [TMDBSearchResult] {
        // Browse explicitly awaits resolveBrowseFilterMetadata before applying
        // its predicate. Scheduling the same runtime, production and audio
        // lookups again here created duplicate per-page work and amplified
        // latency while users paged or changed filters.
        if resolveMetadataInBackground {
            if ProfileSettingsStore.active.bool(forKey: "catalogHideUnder20MinuteContent") {
                Task(priority: .utility) { await self.resolveRuntimeMetadata(for: results) }
            }
            if ProfileSettingsStore.active.bool(forKey: "catalogHideUnofficialContent") {
                Task(priority: .utility) { await self.resolveProductionMetadata(for: results) }
            }
            scheduleAnimeAudioMetadataResolutionIfNeeded(for: results)
            scheduleCatalogAudioAvailabilityResolutionIfNeeded(for: results)
        } else if allowUnresolvedOptionalMetadata {
            // Search keeps titles visible while canonical audio metadata is
            // resolved, then applies the strict language gate on refresh.
            scheduleAnimeAudioMetadataResolutionIfNeeded(for: results)
            scheduleCatalogAudioAvailabilityResolutionIfNeeded(for: results)
        }
        return results.filter { result in
            shouldIncludeCatalogResult(
                result,
                allowUpcomingContent: allowUpcomingContent,
                allowUnresolvedOptionalMetadata: allowUnresolvedOptionalMetadata
            )
        }
    }

    func filterFastAnimeSearchResults(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        let animeResults = results.map { $0.withAnimeHint(true) }
        if ProfileSettingsStore.active.bool(forKey: "catalogHideUnder20MinuteContent") {
            Task(priority: .utility) { await self.resolveRuntimeMetadata(for: animeResults) }
        }
        if ProfileSettingsStore.active.bool(forKey: "catalogHideUnofficialContent") {
            Task(priority: .utility) { await self.resolveProductionMetadata(for: animeResults) }
        }
        scheduleAnimeAudioMetadataResolutionIfNeeded(for: animeResults)
        return animeResults.filter { result in
            shouldIncludeCatalogResult(result) && shouldIncludeFastAnimeResult(result)
        }
    }

    private func scheduleAnimeAudioMetadataResolutionIfNeeded(for results: [TMDBSearchResult]) {
        let selectedLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
        guard !selectedLanguages.isEmpty else { return }
        let animeResults = results.filter { Self.isAnimeResult($0) }
        guard !animeResults.isEmpty else { return }
        // Selected-language filtering is also used outside the global
        // English/Spanish requirement toggle. Always run the verified Taizen /
        // Anidub fallback for those explicit selections, rather than relying
        // only on titles already present in the MyDubList index.
        prepareAnimeAudioEligibilitySelection(selectedLanguages)
        Task(priority: .utility) {
            await self.resolveAnimeAudioMetadata(for: animeResults, selectedLanguages: selectedLanguages)
        }
    }

    private func prepareAnimeAudioEligibilitySelection(_ selectedLanguages: Set<String>) {
        animeEligibilityLock.lock()
        defer { animeEligibilityLock.unlock() }
        guard animeAudioEligibilityLanguages != selectedLanguages else { return }
        animeAudioEligibilityLanguages = selectedLanguages
        animeAudioEligibleIDs.removeAll()
        animeAudioCheckedIDs.removeAll()
        animeAudioLoadingIDs.removeAll()
        animeAudioRetryAfterByID.removeAll()
    }

    func filterMovies(_ movies: [TMDBMovie]) -> [TMDBMovie] {
        let searchResults = movies.map(\.asSearchResult)
        Task(priority: .utility) { await self.prepareMaturityRatings(for: searchResults) }
        if ProfileSettingsStore.active.bool(forKey: "catalogHideUnofficialContent") {
            Task(priority: .utility) { await self.resolveProductionMetadata(for: searchResults) }
        }
        if ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio") {
            scheduleAnimeAudioMetadataResolutionIfNeeded(for: movies.map(\.asSearchResult))
        }
        return movies.filter { movie in
            guard shouldIncludeUnofficialProduction(
                title: movie.title,
                overview: movie.overview,
                result: movie.asSearchResult
            ) else { return false }
            guard movie.adult != true else { return false }
            guard shouldIncludeCatalogTitle(movie.title) else { return false }
            let movieResult = movie.asSearchResult
            let movieAnime = Self.isAnimeResult(movieResult)
            guard !shouldExcludeAnimeSpecialOrOVA(movieResult) else { return false }
            if ProfileSettingsStore.active.bool(forKey: "catalogHideAnime"), movieAnime { return false }
            if movieAnime, !shouldIncludeAnimeCategoryFilters(movie.asSearchResult) { return false }
            if ProfileSettingsStore.active.bool(forKey: "catalogHideUnder20MinuteContent") {
                guard CatalogRuntimeFilterPolicy.shouldInclude(
                    runtimeMinutes: cachedRuntimeMinutes(for: "movie-\(movie.id)")
                ) else { return false }
            }
            guard !Self.shouldHideForReleaseDate(
                rawDate: movie.releaseDate,
                isAnime: false,
                isMovie: true,
                defaults: ProfileSettingsStore.active
            ) else { return false }
            if ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio") {
                // Native audio only qualifies when it matches the user's selected
                // language(s); English must not satisfy a Spanish-only selection.
                guard shouldIncludeForConfiguredAgeAndAudio(movieResult) else { return false }
            }
            if movieAnime {
                guard shouldIncludeAnimeAgeRating(movie.asSearchResult) else { return false }
            } else {
                guard shouldIncludeTMDBAgeRating(
                    isMovie: true,
                    id: movie.id,
                    enabled: Self.ageFilterEnabled("catalogHideBelowPG13Movies")
                ) else { return false }
            }
            guard shouldIncludeForKids(
                title: movie.title,
                overview: movie.overview,
                isMovie: true,
                tmdbID: movie.id,
                animeResult: movieResult
            ) else { return false }
            return shouldIncludeContent(genreIds: movie.genreIds)
        }
    }

    func filterTVShows(_ tvShows: [TMDBTVShow]) -> [TMDBTVShow] {
        let searchResults = tvShows.map(\.asSearchResult)
        Task(priority: .utility) { await self.prepareMaturityRatings(for: searchResults) }
        if ProfileSettingsStore.active.bool(forKey: "catalogHideUnofficialContent") {
            Task(priority: .utility) { await self.resolveProductionMetadata(for: searchResults) }
        }
        if ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio") {
            scheduleAnimeAudioMetadataResolutionIfNeeded(for: tvShows.map(\.asSearchResult))
        }
        return tvShows.filter { tvShow in
            guard shouldIncludeUnofficialProduction(
                title: tvShow.name,
                overview: tvShow.overview,
                result: tvShow.asSearchResult
            ) else { return false }
            guard tvShow.adult != true else { return false }
            guard shouldIncludeCatalogTitle(tvShow.name) else { return false }
            let tvResult = tvShow.asSearchResult
            guard !shouldExcludeAnimeSpecialOrOVA(tvResult) else { return false }
            let animeCountries: Set<String> = ["JP", "CN", "KR", "TW"]
            let animeLanguages: Set<String> = ["ja", "zh", "ko"]
            let isAnime = tvShow.genreIds?.contains(16) == true
                && (animeLanguages.contains(tvShow.originalLanguage?.lowercased() ?? "")
                    || tvShow.originCountry?.contains(where: { animeCountries.contains($0) }) == true)
            if ProfileSettingsStore.active.bool(forKey: "catalogHideAnime"), isAnime { return false }
            if isAnime, !shouldIncludeAnimeCategoryFilters(tvShow.asSearchResult) { return false }
            if ProfileSettingsStore.active.bool(forKey: "catalogHideUnder20MinuteContent") {
                guard CatalogRuntimeFilterPolicy.shouldInclude(
                    runtimeMinutes: cachedRuntimeMinutes(for: "tv-\(tvShow.id)")
                ) else { return false }
            }
            guard !Self.shouldHideForReleaseDate(
                rawDate: tvShow.firstAirDate,
                isAnime: isAnime,
                isMovie: false,
                defaults: ProfileSettingsStore.active
            ) else { return false }
            if ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio") {
                // Apply the same selected-language check to native-language
                // titles and titles that need verified dub metadata.
                guard shouldIncludeForConfiguredAgeAndAudio(tvResult) else { return false }
            }
            if isAnime {
                guard shouldIncludeAnimeAgeRating(tvShow.asSearchResult) else { return false }
            } else {
                guard shouldIncludeTMDBAgeRating(
                    isMovie: false,
                    id: tvShow.id,
                    enabled: Self.ageFilterEnabled("catalogHideBelowTV14Shows")
                ) else { return false }
            }
            guard shouldIncludeForKids(
                title: tvShow.name,
                overview: tvShow.overview,
                isMovie: false,
                tmdbID: tvShow.id,
                animeResult: tvResult
            ) else { return false }
            return shouldIncludeContent(genreIds: tvShow.genreIds)
        }
    }

    private func shouldExcludeAnimeSpecialOrOVA(
        _ result: TMDBSearchResult,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard Self.isAnimeResult(result) else { return false }
        return AnimeSpecialFormatPolicy.shouldExclude(
            format: result.animeIdentitySeed?.format,
            enabled: defaults.bool(forKey: "catalogHideAnimeSpecialsAndOVAs")
        )
    }

    private func shouldIncludeSelectedAnimeDub(
        _ result: TMDBSearchResult,
        allowUnresolvedOptionalMetadata: Bool = false
    ) -> Bool {
        // Dub-language requirements apply only to anime.
        guard Self.isAnimeResult(result) else { return true }
        if MyDubListDubFilter.shared.shouldInclude(result) { return true }
        guard let anilistID = result.animeIdentitySeed?.anilistId, anilistID > 0 else { return false }
        let selectedLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
        guard !selectedLanguages.isEmpty else { return true }

        animeEligibilityLock.lock()
        defer { animeEligibilityLock.unlock() }
        guard animeAudioEligibilityLanguages == selectedLanguages,
              animeAudioCheckedIDs.contains(anilistID) else {
            // Search may display a title while its verified dub lookup is
            // pending. The resolver posts a filter-refresh notification when
            // it completes, at which point confirmed non-matches are removed.
            // Browse passes false and remains strict before publishing a page.
            return allowUnresolvedOptionalMetadata
        }
        return animeAudioEligibleIDs.contains(anilistID)
    }

    private func shouldIncludeCatalogResult(
        _ result: TMDBSearchResult,
        allowUpcomingContent: Bool = false,
        allowUnresolvedOptionalMetadata: Bool = false
    ) -> Bool {
        guard !shouldExcludeAnimeSpecialOrOVA(result) else { return false }
        guard shouldIncludeUnofficialProduction(
            title: result.displayTitle,
            overview: result.overview,
            result: result,
            allowUnresolvedMetadata: allowUnresolvedOptionalMetadata
        ) else { return false }
        guard shouldIncludeSelectedAnimeDub(
            result,
            allowUnresolvedOptionalMetadata: allowUnresolvedOptionalMetadata
        ) else { return false }
        guard result.adult != true else { return false }
        if Self.isAnimeResult(result), !shouldIncludeAnimeCategoryFilters(result) { return false }
        guard shouldIncludeForConfiguredAgeAndAudio(
            result,
            allowUpcomingContent: allowUpcomingContent,
            allowUnresolvedOptionalMetadata: allowUnresolvedOptionalMetadata
        ) else { return false }
        guard shouldIncludeCatalogTitle(result.displayTitle) else { return false }
        guard shouldIncludeForKids(
            title: result.displayTitle,
            overview: result.overview,
            isMovie: result.isMovie,
            tmdbID: result.id,
            animeResult: result
        ) else { return false }

        if kidsModeEnabled, Self.hasExplicitAnimeMetadata(result) { return false }

        if kidsModeEnabled,
           !Self.carriesFullKidsPolicySignals(result),
           TMDBMaturityRatingStore.shared.kidsDetailPolicyAllows(
            isMovie: result.isMovie,
            id: result.id
           ) == false {
            return false
        }
        return shouldIncludeContent(genreIds: result.genreIds)
    }

    private func shouldIncludeForKids(
        title: String,
        overview: String?,
        isMovie: Bool,
        tmdbID: Int,
        animeResult: TMDBSearchResult? = nil
    ) -> Bool {
        guard kidsModeEnabled else { return true }
        if let animeResult, Self.isAnimeResult(animeResult) {
            guard let anilistID = animeResult.animeIdentitySeed?.anilistId else { return false }
            animeEligibilityLock.lock()
            let animeRating = animeAgeRatingsByID[anilistID]
            animeEligibilityLock.unlock()
            guard let animeRating, !animeRating.isBlockedForKids else { return false }
        } else {
            guard TMDBMaturityRatingStore.shared.isAllowedForKids(isMovie: isMovie, id: tmdbID) else {
                return false
            }
        }
        let metadataText = [title, overview ?? ""].joined(separator: " ")
        if Self.containsBlockedCatalogText(metadataText, blockedTerms: Self.kidsMetadataDenylist) {
            return false
        }
        return !MaturityRating.containsMatureText(metadataText)
    }

    static func kidsDetailPolicyAllows(
        title: String,
        isAdult: Bool,
        genreIds: [Int],
        overview: String?
    ) -> Bool {
        if isAdult { return false }
        if genreIds.contains(where: kidsBlockedGenreIds.contains) { return false }
        return kidsTextHeuristicsAllow(title: title, overview: overview)
    }

    static func carriesFullKidsPolicySignals(_ result: TMDBSearchResult) -> Bool {
        result.adult != nil && result.genreIds != nil && result.overview != nil
    }

    static func kidsTextHeuristicsAllow(title: String, overview: String? = nil) -> Bool {
        let metadataText = [title, overview ?? ""].joined(separator: " ")
        if containsBlockedCatalogText(metadataText, blockedTerms: kidsMetadataDenylist) {
            return false
        }
        if containsBlockedCatalogText(metadataText, blockedTerms: adultAnimeMetadataDenylist) {
            return false
        }
        return !MaturityRating.containsMatureText(metadataText)
    }

    func kidsPolicyAllowsPlayback(
        isMovie: Bool,
        id: Int,
        title: String,
        persistedDetails: KidsPolicyDetails? = nil
    ) async -> Bool {
        guard kidsModeEnabled else { return true }
        await TMDBMaturityRatingStore.shared.resolve([(isMovie: isMovie, id: id)])
        guard TMDBMaturityRatingStore.shared.isAllowedForKids(isMovie: isMovie, id: id) else {
            return false
        }
        guard Self.kidsTextHeuristicsAllow(title: title) else { return false }

        var hasCompleteAllowedPolicy = false
        if let persistedDetails {
            guard Self.kidsDetailPolicyAllows(
                title: title,
                isAdult: persistedDetails.isAdult,
                genreIds: persistedDetails.genreIds,
                overview: persistedDetails.overview
            ) else { return false }
            hasCompleteAllowedPolicy = true
        }
        if let storedPolicy = TMDBMaturityRatingStore.shared.kidsDetailPolicyAllows(
            isMovie: isMovie,
            id: id
        ) {
            guard storedPolicy else { return false }
            hasCompleteAllowedPolicy = true
        }
        if hasCompleteAllowedPolicy { return true }

        let overview: String?
        let genreIds: [Int]
        let isAdult: Bool
        do {
            if isMovie {
                let detail = try await TMDBService.shared.getMovieDetails(id: id)
                overview = detail.overview
                genreIds = detail.genres.map(\.id)
                isAdult = detail.adult
            } else {
                let detail = try await TMDBService.shared.getTVShowDetails(id: id)
                overview = detail.overview
                genreIds = detail.genres.map(\.id)
                isAdult = detail.adult
            }
        } catch {

            if let persistedDetails {
                return Self.kidsDetailPolicyAllows(
                    title: title,
                    isAdult: persistedDetails.isAdult,
                    genreIds: persistedDetails.genreIds,
                    overview: persistedDetails.overview
                )
            }

            if let allowed = TMDBMaturityRatingStore.shared.kidsDetailPolicyAllows(isMovie: isMovie, id: id) {
                return allowed
            }

            if TMDBMaturityRatingStore.shared.rating(isMovie: isMovie, id: id) == .unknown {
                Logger.shared.log(
                    "Kids gate denied \(isMovie ? "movie" : "tv") \(id): unclassified with no stored policy and no details: \(error.localizedDescription)",
                    type: "Player"
                )
                return false
            }
            Logger.shared.log(
                "Kids gate could not fetch details for \(isMovie ? "movie" : "tv") \(id); the resolved certification stands: \(error.localizedDescription)",
                type: "Player"
            )
            return true
        }

        return Self.kidsDetailPolicyAllows(
            title: title,
            isAdult: isAdult,
            genreIds: genreIds,
            overview: overview
        )
    }

    private func shouldIncludeFastAnimeResult(_ result: TMDBSearchResult) -> Bool {
        !Self.hasExplicitAnimeMetadata(result)
    }

    static func hasExplicitAnimeMetadata(_ result: TMDBSearchResult) -> Bool {
        let metadataText = [result.displayTitle, result.overview ?? ""].joined(separator: " ")
        return containsBlockedCatalogText(metadataText, blockedTerms: adultAnimeMetadataDenylist)
    }

    private func storeAnimeAgeRating(_ rating: MaturityRating, for id: Int) {
        animeEligibilityLock.lock()
        animeAgeRatingsByID[id] = rating
        animeAgeLoadingIDs.remove(id)
        animeAgeRetryAfterByID.removeValue(forKey: id)
        animeAgeCheckedIDs.insert(id)
        animeEligibilityLock.unlock()
    }

    private func catalogAudioAvailabilityKey(for result: TMDBSearchResult) -> String {
        "\(result.isMovie ? "movie" : "tv")-\(result.id)"
    }

    private func hasVerifiedCatalogAudio(for result: TMDBSearchResult) -> Bool {
        let key = catalogAudioAvailabilityKey(for: result)
        animeEligibilityLock.lock()
        defer { animeEligibilityLock.unlock() }
        return catalogAudioEligibleKeys.contains(key)
    }

    private func hasResolvedCatalogAudio(for result: TMDBSearchResult) -> Bool {
        let key = catalogAudioAvailabilityKey(for: result)
        animeEligibilityLock.lock()
        defer { animeEligibilityLock.unlock() }
        return catalogAudioCheckedKeys.contains(key)
    }

    private func scheduleCatalogAudioAvailabilityResolutionIfNeeded(for results: [TMDBSearchResult]) {
        guard ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio") else { return }
        Task(priority: .utility) {
            await self.resolveCatalogAudioAvailability(for: results)
        }
    }

    /// Resolve non-anime native/dub audio eligibility before Browse publishes
    /// its filtered page. The normal catalogue path can schedule this work in
    /// the background, but Browse/Search use a cache-only predicate to avoid
    /// repeated task creation during SwiftUI redraws; without this awaited path,
    /// every non-native-language movie/TV result was rejected before its dub
    /// availability could ever be checked.
    private func resolveCatalogAudioAvailability(for results: [TMDBSearchResult]) async {
        guard ProfileSettingsStore.active.bool(forKey: "catalogRequireEnglishSpanishAudio") else { return }
        let candidates = results.filter { result in
            guard !Self.isAnimeResult(result),
                  (result.isMovie || result.isTVShow),
                  result.id > 0 else { return false }
            let language = result.originalLanguage?.lowercased() ?? ""
            guard !(language.hasPrefix("en") || language.hasPrefix("es")) else { return false }
            let key = catalogAudioAvailabilityKey(for: result)
            animeEligibilityLock.lock()
            defer { animeEligibilityLock.unlock() }
            guard !catalogAudioCheckedKeys.contains(key),
                  !catalogAudioLoadingKeys.contains(key),
                  Date() >= (catalogAudioRetryAfterByKey[key] ?? .distantPast) else { return false }
            catalogAudioLoadingKeys.insert(key)
            return true
        }
        guard !candidates.isEmpty else { return }

        let selectedLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
        await withTaskGroup(of: (String, Bool?).self) { group in
            var iterator = candidates.makeIterator()
            let concurrencyLimit = 4
            for _ in 0..<min(concurrencyLimit, candidates.count) {
                guard let result = iterator.next() else { continue }
                let key = self.catalogAudioAvailabilityKey(for: result)
                group.addTask {
                    let available = await self.catalogAudioMatch(
                        for: result,
                        selectedLanguages: selectedLanguages
                    )
                    return (key, available)
                }
            }

            var didResolveAny = false
            while let (key, available) = await group.next() {
                animeEligibilityLock.lock()
                catalogAudioLoadingKeys.remove(key)
                if let available {
                    catalogAudioCheckedKeys.insert(key)
                    catalogAudioRetryAfterByKey.removeValue(forKey: key)
                    if available {
                        catalogAudioEligibleKeys.insert(key)
                    } else {
                        catalogAudioEligibleKeys.remove(key)
                    }
                    didResolveAny = true
                } else {
                    catalogAudioRetryAfterByKey[key] = Date().addingTimeInterval(10 * 60)
                    didResolveAny = true
                }
                animeEligibilityLock.unlock()

                if let result = iterator.next() {
                    let nextKey = self.catalogAudioAvailabilityKey(for: result)
                    group.addTask {
                        let available = await self.catalogAudioMatch(
                            for: result,
                            selectedLanguages: selectedLanguages
                        )
                        return (nextKey, available)
                    }
                }
            }
        }

        await MainActor.run {
            self.catalogAudioRevision &+= 1
            NotificationCenter.default.post(
                name: Self.catalogFiltersDidChangeNotification,
                object: nil
            )
        }
    }

    private func catalogAudioMatch(
        for result: TMDBSearchResult,
        selectedLanguages: Set<String>
    ) async -> Bool? {
        let originalLanguage: String?
        if let language = result.originalLanguage, !language.isEmpty {
            originalLanguage = language
        } else {
            // Search/discover summaries occasionally omit original_language.
            // Fetch the canonical detail once rather than treating an unknown
            // language as proof that no selected-language audio exists.
            do {
                if result.isMovie {
                    let details = try await TMDBService.shared.getMovieDetails(id: result.id)
                    originalLanguage = details.originalLanguage
                } else {
                    let details = try await TMDBService.shared.getTVShowDetails(id: result.id)
                    originalLanguage = details.originalLanguage
                }
            } catch {
                return nil
            }
        }
        return ScheduleAudioLanguagePolicy.hasNativeLanguageMatch(
            originalLanguage: originalLanguage,
            selectedLanguages: selectedLanguages
        )
    }

    private func storeAnimeAudioEligibility(
        _ isEligible: Bool,
        for id: Int,
        selectedLanguages: Set<String>
    ) {
        animeEligibilityLock.lock()
        defer { animeEligibilityLock.unlock() }
        guard animeAudioEligibilityLanguages == selectedLanguages else { return }
        animeAudioLoadingIDs.remove(id)
        animeAudioRetryAfterByID.removeValue(forKey: id)
        animeAudioCheckedIDs.insert(id)
        if isEligible {
            animeAudioEligibleIDs.insert(id)
        } else {
            animeAudioEligibleIDs.remove(id)
        }
    }

    private func cachedAnimeAgeRating(for result: TMDBSearchResult) -> MaturityRating? {
        guard let anilistID = result.animeIdentitySeed?.anilistId, anilistID > 0 else { return nil }
        animeEligibilityLock.lock()
        defer { animeEligibilityLock.unlock() }
        return animeAgeRatingsByID[anilistID]
    }

    private func shouldIncludeAnimeAgeRating(
        _ result: TMDBSearchResult,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let hideBelowPG13 = defaults.bool(forKey: "catalogHideBelowPG13Anime")
        let hideAllAges = defaults.bool(forKey: "catalogHideAllAgesAnime")
        guard hideBelowPG13 || hideAllAges else { return true }
        // Anime uses its own AniList/Taizen age classification, never TMDB.
        guard let rating = cachedAnimeAgeRating(for: result), rating != .unknown else {
            // The existing minimum-age filter fails closed for missing ratings.
            return !hideBelowPG13
        }
        if hideAllAges && rating == .general { return false }
        return !hideBelowPG13 || rating >= .teen
    }

    private func shouldIncludeTMDBAgeRating(isMovie: Bool, id: Int, enabled: Bool) -> Bool {
        let hideAllAges = ProfileSettingsStore.active.bool(
            forKey: isMovie ? "catalogHideAllAgesMovies" : "catalogHideAllAgesSeries"
        )
        guard enabled || hideAllAges else { return true }
        guard let rating = TMDBMaturityRatingStore.shared.rating(isMovie: isMovie, id: id) else {
            // The setting hides titles with a known rating below the threshold;
            // an unavailable certificate must not collapse an entire Browse
            // category to the few titles whose regional rating happened to load.
            return true
        }
        if hideAllAges && rating == .general { return false }
        guard enabled, rating != .unknown else { return true }
        let minimum = isMovie ? MaturityRating.teen : .age14
        return rating >= minimum
    }

    private static func runtimeCacheKey(for result: TMDBSearchResult) -> String {
        "\(result.isMovie ? "movie" : "tv")-\(result.id)"
    }
    private func shouldIncludeUnofficialProduction(
        title: String,
        overview: String?,
        result: TMDBSearchResult,
        allowUnresolvedMetadata: Bool = false
    ) -> Bool {
        guard ProfileSettingsStore.active.bool(forKey: "catalogHideUnofficialContent") else { return true }
        if Self.isUnofficialCreatorContent(title: title, overview: overview) { return false }

        let key = Self.runtimeCacheKey(for: result)
        runtimeMetadataLock.lock()
        let isChecked = productionMetadataCheckedKeys.contains(key)
        let companyNames = productionCompaniesByKey[key] ?? []
        runtimeMetadataLock.unlock()

        // Browse waits for production-company metadata before admitting an
        // unknown item. Search is different: an optional metadata timeout must
        // not make a valid title disappear permanently from the user's query.
        // Once details resolve, the retained search snapshot is re-filtered.
        guard isChecked else { return allowUnresolvedMetadata }
        return !Self.isUnofficialCreatorContent(
            title: title,
            overview: overview,
            productionCompanies: companyNames
        )
    }

    private static func fetchTMDBProductionNames(for result: TMDBSearchResult) async throws -> [String] {
        if result.isMovie {
            let detail = try await TMDBService.shared.getMovieDetails(id: result.id)
            return detail.productionCompanies?.map(\.name) ?? []
        }
        let detail = try await TMDBService.shared.getTVShowDetails(id: result.id)
        return (detail.productionCompanies ?? []).map(\.name)
            + (detail.networks ?? []).map(\.name)
            + (detail.createdBy ?? []).map(\.name)
    }

    private static func fetchAniListStudioNames(for result: TMDBSearchResult) async -> [String]? {
        guard Self.isAnimeResult(result),
              let anilistID = result.animeIdentitySeed?.anilistId else { return nil }
        return await AniListService.shared.fetchAnimeStudioNames(anilistID: anilistID)
    }

    /// Combine independent production sources concurrently. Anime studio data
    /// falls back from AniList to Jikan/MyAnimeList, so a temporary failure in
    /// one catalogue does not silently mark the title as fully checked.
    private static func fetchProductionMetadata(for result: TMDBSearchResult) async throws -> (names: [String], complete: Bool) {
        async let tmdbNamesTask = Self.fetchTMDBProductionNames(for: result)
        async let aniListNamesTask = Self.fetchAniListStudioNames(for: result)
        var names = try await tmdbNamesTask
        var animeStudioMetadataResolved = false

        if let studios = await aniListNamesTask, !studios.isEmpty {
            names.append(contentsOf: studios)
            animeStudioMetadataResolved = true
        } else if Self.isAnimeResult(result),
                  let malID = result.animeIdentitySeed?.malId,
                  malID > 0,
                  let studios = await JikanAnimeAgeRatingService.shared.studioNames(malID: malID),
                  !studios.isEmpty {
            names.append(contentsOf: studios)
            animeStudioMetadataResolved = true
        }

        let complete = !Self.isAnimeResult(result) || animeStudioMetadataResolved
        return (Array(Set(names)).sorted(), complete)
    }

    private func resolveProductionMetadata(for results: [TMDBSearchResult]) async {
        let candidates = results.filter { $0.id > 0 && ($0.isMovie || $0.isTVShow) }
        var pending: [TMDBSearchResult] = []
        runtimeMetadataLock.lock()
        for result in candidates {
            let key = Self.runtimeCacheKey(for: result)
            if productionMetadataCheckedKeys.contains(key) || productionMetadataLoadingKeys.contains(key) {
                continue
            }
            if let retryAfter = productionMetadataRetryAfterByKey[key], retryAfter > Date() {
                continue
            }
            productionMetadataLoadingKeys.insert(key)
            pending.append(result)
        }
        runtimeMetadataLock.unlock()
        guard !pending.isEmpty else { return }

        await withTaskGroup(of: (String, [String]?, Bool).self) { group in
            var iterator = pending.makeIterator()
            for _ in 0..<min(6, pending.count) {
                guard let result = iterator.next() else { continue }
                group.addTask {
                    let key = Self.runtimeCacheKey(for: result)
                    do {
                        let metadata = try await Self.fetchProductionMetadata(for: result)
                        return (key, metadata.names, metadata.complete)
                    } catch {
                        return (key, nil, false)
                    }
                }
            }

            var didResolveAny = false
            while let (key, names, succeeded) = await group.next() {
                runtimeMetadataLock.lock()
                productionMetadataLoadingKeys.remove(key)
                if succeeded, let names {
                    productionCompaniesByKey[key] = names
                    productionMetadataCheckedKeys.insert(key)
                    productionMetadataRetryAfterByKey.removeValue(forKey: key)
                    didResolveAny = true
                } else {
                    productionMetadataRetryAfterByKey[key] = Date().addingTimeInterval(5 * 60)
                }
                runtimeMetadataLock.unlock()

                if let result = iterator.next() {
                    group.addTask {
                        let nextKey = Self.runtimeCacheKey(for: result)
                        do {
                            let metadata = try await self.fetchProductionMetadata(for: result)
                            return (nextKey, metadata.names, metadata.complete)
                        } catch {
                            return (nextKey, nil, false)
                        }
                    }
                }
            }
            if didResolveAny {
                NotificationCenter.default.post(
                    name: TMDBContentFilter.catalogFiltersDidChangeNotification,
                    object: nil
                )
            }
        }
    }


    private func cachedRuntimeMinutes(for key: String) -> Int? {
        runtimeMetadataLock.lock()
        defer { runtimeMetadataLock.unlock() }
        return runtimeMinutesByKey[key]
    }

    private func resolveRuntimeMetadata(for results: [TMDBSearchResult]) async {
        let candidates = results.filter { $0.id > 0 && ($0.isMovie || $0.isTVShow) }
        var pending: [(result: TMDBSearchResult, key: String)] = []
        runtimeMetadataLock.lock()
        for result in candidates {
            let key = Self.runtimeCacheKey(for: result)
            if runtimeCheckedKeys.contains(key) || runtimeLoadingKeys.contains(key) { continue }
            runtimeLoadingKeys.insert(key)
            pending.append((result, key))
        }
        runtimeMetadataLock.unlock()
        guard !pending.isEmpty else { return }

        await withTaskGroup(of: (String, Int?, Bool).self) { group in
            var iterator = pending.makeIterator()
            for _ in 0..<min(6, pending.count) {
                guard let item = iterator.next() else { continue }
                group.addTask {
                    await Self.fetchRuntimeMetadata(for: item.result, key: item.key)
                }
            }

            var didResolveAny = false
            while let (key, runtime, succeeded) = await group.next() {
                runtimeMetadataLock.lock()
                runtimeLoadingKeys.remove(key)
                if succeeded {
                    runtimeCheckedKeys.insert(key)
                    if let runtime, runtime > 0 {
                        runtimeMinutesByKey[key] = runtime
                    }
                    didResolveAny = true
                }
                runtimeMetadataLock.unlock()

                if let next = iterator.next() {
                    group.addTask {
                        await Self.fetchRuntimeMetadata(for: next.result, key: next.key)
                    }
                }
            }
            if didResolveAny {
                NotificationCenter.default.post(
                    name: TMDBContentFilter.catalogFiltersDidChangeNotification,
                    object: nil
                )
            }
        }
    }

    private static func fetchRuntimeMetadata(
        for result: TMDBSearchResult,
        key: String
    ) async -> (String, Int?, Bool) {
        if result.isMovie {
            do {
                let detail = try await TMDBService.shared.getMovieDetails(id: result.id)
                return (key, detail.runtime, true)
            } catch {
                return (key, nil, false)
            }
        }
        do {
            let detail = try await TMDBService.shared.getTVShowDetails(id: result.id)
            let shortestReportedEpisode = CatalogRuntimeFilterPolicy.shortestReportedRuntime(detail.episodeRunTime)
            guard let shortestReportedEpisode else { return (key, nil, true) }
            return (key, shortestReportedEpisode, true)
        } catch {
            return (key, nil, false)
        }
    }

    private static func ageFilterEnabled(_ key: String, defaults: UserDefaults = .standard) -> Bool {
        guard let storedValue = defaults.object(forKey: key) as? Bool else {
            // Keep the requested 13+ movie and TV baseline for fresh installs.
            return key == "catalogHideBelowPG13Movies" || key == "catalogHideBelowTV14Shows"
        }
        return storedValue
    }

    private func shouldIncludeForConfiguredAgeAndAudio(
        _ result: TMDBSearchResult,
        allowUpcomingContent: Bool = false,
        allowUnresolvedOptionalMetadata: Bool = false
    ) -> Bool {
        let defaults = ProfileSettingsStore.active
        let isAnime = Self.isAnimeResult(result)
        if defaults.bool(forKey: "catalogHideAnime"), isAnime { return false }
        if defaults.bool(forKey: "catalogHideUnder20MinuteContent") {
            // Do not show an item while its runtime is unknown. The async
            // metadata resolver will publish a filter-change notification
            // when the runtime is available, and the catalog will re-evaluate.
            let runtime = cachedRuntimeMinutes(for: Self.runtimeCacheKey(for: result))
            if let runtime {
                guard CatalogRuntimeFilterPolicy.shouldInclude(runtimeMinutes: runtime) else {
                    return false
                }
            } else if !allowUnresolvedOptionalMetadata {
                return false
            }
        }

        if isAnime {
            guard shouldIncludeAnimeAgeRating(result, defaults: defaults) else { return false }
        } else {
            let hideBelowMinimum = result.isMovie
                ? Self.ageFilterEnabled("catalogHideBelowPG13Movies", defaults: defaults)
                : Self.ageFilterEnabled("catalogHideBelowTV14Shows", defaults: defaults)
            let hideAllAges = result.isMovie
                ? defaults.bool(forKey: "catalogHideAllAgesMovies")
                : defaults.bool(forKey: "catalogHideAllAgesSeries")
            if let rating = TMDBMaturityRatingStore.shared.rating(isMovie: result.isMovie, id: result.id) {
                if hideAllAges && rating == .general { return false }
                let minimum = result.isMovie ? MaturityRating.teen : .age14
                // A missing/unknown certificate is not proof that a title is
                // below the configured minimum. Keep it visible and let a later
                // verified certification refine the decision.
                if hideBelowMinimum, rating != .unknown, rating < minimum { return false }
            }
        }

        if Self.shouldHideForReleaseDate(
            result,
            defaults: defaults,
            allowUpcomingContent: allowUpcomingContent
        ) { return false }

        if defaults.bool(forKey: "catalogRequireEnglishSpanishAudio") {
            let selectedLanguages = MyDubListDubFilter.shared.selectedLanguagesIncludingCatalogAudioRequirement
            // Search/discover payloads can omit original_language even when the
            // title has a verified English or Spanish dub. Treat missing native
            // language as "not confirmed native audio" and continue through the
            // provider-audio verification below instead of rejecting the title.
            let hasSelectedNativeAudio = result.originalLanguage.map {
                ScheduleAudioLanguagePolicy.matches(
                    originalLanguage: $0.lowercased(),
                    selectedLanguages: selectedLanguages
                )
            } ?? false
            if !hasSelectedNativeAudio {
                if isAnime {
                    guard let anilistID = result.animeIdentitySeed?.anilistId,
                          anilistID > 0 else { return false }
                    animeEligibilityLock.lock()
                    let hasVerifiedDub = animeAudioEligibleIDs.contains(anilistID)
                    animeEligibilityLock.unlock()
                    // Fail closed while anime dub metadata is loading or unavailable.
                    guard hasVerifiedDub else { return false }
                } else if !hasVerifiedCatalogAudio(for: result) {
                    // Preserve Search discoverability while canonical language
                    // metadata is being fetched or is temporarily unavailable.
                    // A confirmed negative result remains excluded.
                    guard allowUnresolvedOptionalMetadata && !hasResolvedCatalogAudio(for: result) else {
                        return false
                    }
                }
            }
        }
        return true
    }

    private func shouldIncludeAnimeCategoryFilters(_ result: TMDBSearchResult) -> Bool {
        !Self.shouldExcludeAnimeCategory(
            title: result.displayTitle,
            overview: result.overview
        )
    }

    static func shouldExcludeAnimeCategory(
        title: String,
        overview: String? = nil,
        tags: [String] = [],
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard defaults.bool(forKey: "catalogHideHentai")
                || defaults.bool(forKey: "catalogHideYuri")
                || defaults.bool(forKey: "catalogHideYaoi") else { return false }
        let metadata = ([title, overview ?? ""] + tags).joined(separator: " ")
        if defaults.bool(forKey: "catalogHideHentai"),
           containsBlockedCatalogText(metadata, blockedTerms: [
                "hentai", "ova hentai", "adult anime", "adult animation",
                "r18", "r 18", "pornographic", "pornography"
           ]) {
            return true
        }
        if defaults.bool(forKey: "catalogHideYuri"),
           containsBlockedCatalogText(metadata, blockedTerms: [
                "yuri", "girls love", "girl love", "shoujo ai", "shojo ai"
           ]) {
            return true
        }
        if defaults.bool(forKey: "catalogHideYaoi"),
           containsBlockedCatalogText(metadata, blockedTerms: [
                "yaoi", "boys love", "boy love", "shounen ai", "shonen ai"
           ]) {
            return true
        }
        return false
    }

    private static func isAnimeResult(_ result: TMDBSearchResult) -> Bool {
        result.animeIdentitySeed != nil
            || result.isAnimeHint == true
            || (result.genreIds?.contains(16) == true
                && (["ja", "zh", "ko"].contains(result.originalLanguage?.lowercased() ?? "")
                    || result.originCountry?.contains(where: { ["JP", "CN", "KR", "TW"].contains($0) }) == true))
    }

    private static func shouldHideForReleaseDate(
        _ result: TMDBSearchResult,
        defaults: UserDefaults,
        allowUpcomingContent: Bool = false
    ) -> Bool {
        shouldHideForReleaseDate(
            rawDate: result.isMovie ? result.releaseDate : (result.firstAirDate ?? result.releaseDate),
            isAnime: isAnimeResult(result),
            isMovie: result.isMovie,
            defaults: defaults,
            allowUpcomingContent: allowUpcomingContent
        )
    }

    private static func shouldHideForReleaseDate(
        rawDate: String?,
        isAnime: Bool,
        isMovie: Bool,
        defaults: UserDefaults,
        allowUpcomingContent: Bool = false
    ) -> Bool {
        guard let rawDate, rawDate.count >= 10, !rawDate.hasPrefix("0001-") else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let releaseDate = formatter.date(from: String(rawDate.prefix(10))) else { return false }
        let before1994Key = isAnime ? "catalogHidePre1994Anime"
            : (isMovie ? "catalogHidePre1994Movies" : "catalogHidePre1994TVShows")
        let unreleasedKey = isAnime ? "catalogHideUnreleasedAnime"
            : (isMovie ? "catalogHideUnreleasedMovies" : "catalogHideUnreleasedTVShows")
        if defaults.bool(forKey: before1994Key),
           Calendar(identifier: .gregorian).component(.year, from: releaseDate) < 1994 {
            return true
        }
        let calendar = Calendar.current
        return !allowUpcomingContent
            && defaults.bool(forKey: unreleasedKey)
            && calendar.startOfDay(for: releaseDate) > calendar.startOfDay(for: Date())
    }

    static func isUnofficialCreatorContent(
        title: String,
        overview: String?,
        productionCompanies: [String] = []
    ) -> Bool {
        let text = normalizedCatalogText([title, overview ?? ""].joined(separator: " "))
        let producerText = normalizedCatalogText(productionCompanies.joined(separator: " "))
        let producerPlatformIndicators = ["youtube", "youtube premium", "youtube red"]
        let indicators = [
            "fan made", "fanmade", "fan film", "fan films", "fan fiction", "fanfiction",
            "fan work", "fan works", "fan production", "fan productions", "fan project", "fan projects",
            "fan animation", "fan animations", "fan made anime", "fanmade anime", "fan made series",
            "fan made movie", "fan made film", "unofficial production", "unofficial creator",
            "unofficial series", "unofficial film", "unofficial movie", "youtube original",
            "youtube series", "youtuber", "youtubers", "made for youtube", "creator made",
            "creator made series", "independent web series", "independent web animation",
            "independent animation", "independent anime", "youtube channel", "youtube studio",
            "youtube studios", "content creator", "creator studio", "creator studios",
            "fan studio", "fan studios", "fanmade studio", "fanmade studios",
            "unofficial studio", "unofficial studios", "youtube originals",
            "youtuber studio", "youtuber studios", "youtuber production",
            "web creator", "video creator", "creator production",
            "dhar mann", "mrbeast", "smosh", "the try guys", "watcher entertainment",
            "markiplier", "jacksepticeye", "logan paul", "jake paul", "sidemen",
            "sssniperwolf", "the stokes twins", "ben azelart", "brent rivera",
            "prestonplayz", "unspeakable", "the royalty family", "zach king",
            "ryan trahan", "airrack", "lexi rivera", "vlad and niki",
            "like nastya", "kids diana show",
            "rooster teeth", "jubilee media", "dude perfect", "the soul publishing",
            "alan chikin chow", "studio71", "jellysmack", "mythical entertainment"
        ]
        func containsIndicator(_ indicator: String, in normalizedText: String) -> Bool {
            let token = normalizedCatalogText(indicator)
            return normalizedText.range(of: " " + token + " ") != nil
                || normalizedText.hasPrefix(token + " ")
                || normalizedText.hasSuffix(" " + token)
                || normalizedText == token
        }
        let hasTextIndicator = indicators.contains { containsIndicator($0, in: text) }
        // Production-company metadata must be checked against the complete
        // unofficial/creator vocabulary too, not only the YouTube platform
        // subset. Otherwise "Fan Made Studio", "Creator Studio" and
        // "Independent Web Animation" incorrectly pass the enabled filter.
        let hasUnofficialProducer = indicators.contains { containsIndicator($0, in: producerText) }
        let hasProducerPlatform = producerPlatformIndicators.contains {
            containsIndicator($0, in: producerText)
        }
        return hasTextIndicator || hasUnofficialProducer || hasProducerPlatform
    }

    private func shouldIncludeCatalogTitle(_ title: String) -> Bool {
        let normalized = Self.normalizedCatalogText(title)
        return !explicitCatalogTitleDenylist.contains(normalized)
    }

    private static func containsBlockedCatalogText(_ text: String, blockedTerms: Set<String>) -> Bool {
        let normalized = " \(normalizedCatalogText(text)) "
        return blockedTerms.contains { term in
            normalized.contains(" \(term) ")
        }
    }

    private static func normalizedCatalogText(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func shouldIncludeContent(genreIds: [Int]?) -> Bool {
        shouldIncludeContent(resolvedGenreIds: genreIds)
    }

    private func shouldIncludeContent(genres: [TMDBGenre]) -> Bool {
        shouldIncludeContent(resolvedGenreIds: genres.map(\.id))
    }

    private func shouldIncludeContent(resolvedGenreIds genreIds: [Int]?) -> Bool {
        let isKids = kidsModeEnabled
        guard let genreIds, !genreIds.isEmpty else { return true }

        if filterHorror || isKids {
            if genreIds.contains(where: horrorGenreIds.contains) {
                return false
            }
        }

        if isKids, genreIds.contains(where: Self.kidsBlockedGenreIds.contains) {
            return false
        }

        return true
    }
}

extension TMDBContentFilter {

    enum KidsAccessDecision {
        case allowed
        case denied
        case unresolved
    }

    static let kidsAccessResolveBudget: TimeInterval = 2

    func kidsAccessDecision(for result: TMDBSearchResult) -> KidsAccessDecision {
        guard kidsModeEnabled else { return .allowed }

        guard result.id > 0 else { return .denied }
        guard TMDBMaturityRatingStore.shared.rating(isMovie: result.isMovie, id: result.id) != nil else {
            return .unresolved
        }

        return shouldIncludeCatalogResult(result) ? .allowed : .denied
    }

    func resolveKidsAccess(for result: TMDBSearchResult) async -> KidsAccessDecision {
        let immediate = kidsAccessDecision(for: result)
        guard case .unresolved = immediate else { return immediate }

        Task {
            await TMDBMaturityRatingStore.shared.resolve([(isMovie: result.isMovie, id: result.id)])
        }

        let deadline = Date().addingTimeInterval(TMDBContentFilter.kidsAccessResolveBudget)
        while Date() < deadline, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 80_000_000)
            let decision = kidsAccessDecision(for: result)
            if decision != .unresolved { return decision }
        }

        Logger.shared.log(
            "Kids gate: denied \(result.isMovie ? "movie" : "tv")/\(result.id) — no certification within \(TMDBContentFilter.kidsAccessResolveBudget)s",
            type: "TMDB"
        )
        return .denied
    }
}


enum TaizenDubMetadataError: Error, LocalizedError {
    case missingIdentifier
    case invalidURL
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .missingIdentifier: return "No AniList or MyAnimeList identifier is available for this anime season."
        case .invalidURL: return "The Taizen metadata URL is invalid."
        case .invalidResponse: return "Taizen returned invalid episode dub metadata."
        case .http(let status): return "Taizen metadata request failed (HTTP \(status))."
        }
    }
}

/// Fetches episode-level dub counts for the exact AniList/MAL season identity.
/// Results are cached because Taizen refreshes its catalogue at most hourly.
/// TMDB-ID based movie artwork lookup. Missing artwork never blocks TMDB posters.
struct FanartTVMoviePosterRequest: Sendable {
    let id: Int
}

actor FanartTVMovieArtworkService {
    static let shared = FanartTVMovieArtworkService()

    private struct Response: Decodable {
        let movieposter: [Artwork]?
    }

    private struct Artwork: Decodable {
        let url: String
        let lang: String?
        let likes: String?
    }

    private struct CachedPoster {
        let fetchedAt: Date
        let url: String?
    }

    private var cache: [Int: CachedPoster] = [:]
    private let positiveCacheLifetime: TimeInterval = 24 * 60 * 60
    private let negativeCacheLifetime: TimeInterval = 2 * 60 * 60
    private let maximumResponseBytes = 2 * 1_024 * 1_024
    private let maximumBatchSize = 30

    private var apiKey: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "FanartTVAPIKey") as? String ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("$(") ? "" : trimmed
    }

    func posters(for requests: [FanartTVMoviePosterRequest]) async -> [Int: String] {
        let key = apiKey
        guard !key.isEmpty else { return [:] }
        let ids = Array(Set(requests.map(\.id).filter { (1...1_000_000_000).contains($0) }))
            .sorted()
            .prefix(maximumBatchSize)
        guard !ids.isEmpty else { return [:] }

        return await withTaskGroup(of: (Int, String?).self) { group in
            var iterator = ids.makeIterator()
            let concurrencyLimit = 4
            for _ in 0..<min(concurrencyLimit, ids.count) {
                guard let id = iterator.next() else { continue }
                group.addTask { (id, await self.posterURL(for: id, apiKey: key)) }
            }

            var output: [Int: String] = [:]
            while let (id, url) = await group.next() {
                if let url { output[id] = url }
                if let nextID = iterator.next() {
                    group.addTask { (nextID, await self.posterURL(for: nextID, apiKey: key)) }
                }
            }
            return output
        }
    }

    private func posterURL(for id: Int, apiKey: String) async -> String? {
        if let cached = cache[id] {
            let lifetime = cached.url == nil ? negativeCacheLifetime : positiveCacheLifetime
            if Date().timeIntervalSince(cached.fetchedAt) < lifetime {
                return cached.url
            }
        }

        guard var components = URLComponents(string: "https://webservice.fanart.tv/v3.2/movies/\(id)") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard data.count <= maximumResponseBytes,
                  let http = response as? HTTPURLResponse else { return nil }

            if http.statusCode == 404 {
                cache[id] = CachedPoster(fetchedAt: Date(), url: nil)
                return nil
            }
            guard http.statusCode == 200,
                  let payload = try? JSONDecoder().decode(Response.self, from: data) else {
                return nil
            }

            let poster = (payload.movieposter ?? [])
                .compactMap { item -> (String, Int, Int)? in
                    guard let safeURL = Self.trustedPosterURL(item.url) else { return nil }
                    let language = (item.lang ?? "").lowercased()
                    let languageRank: Int
                    switch language {
                    case "en": languageRank = 0
                    case "00": languageRank = 1
                    case "es": languageRank = 2
                    default: languageRank = 3
                    }
                    return (safeURL, languageRank, Int(item.likes ?? "") ?? 0)
                }
                .sorted {
                    if $0.1 != $1.1 { return $0.1 < $1.1 }
                    return $0.2 > $1.2
                }
                .first?.0

            cache[id] = CachedPoster(fetchedAt: Date(), url: poster)
            return poster
        } catch {
            return nil
        }
    }

    private static func trustedPosterURL(_ rawValue: String) -> String? {
        guard rawValue.utf8.count <= 2_048,
              let components = URLComponents(string: rawValue),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == "assets.fanart.tv",
              components.port == nil || components.port == 443,
              components.user == nil, components.password == nil,
              components.fragment == nil else { return nil }
        return components.url?.absoluteString
    }
}

struct TVMazePosterRequest: Sendable {
    let id: Int
    let title: String
    let year: Int?
}

actor TVMazeArtworkPosterService {
    static let shared = TVMazeArtworkPosterService()

    private struct SearchResult: Decodable {
        let score: Double
        let show: Show
    }

    private struct Show: Decodable {
        let name: String
        let premiered: String?
        let image: Image?
    }

    private struct Image: Decodable {
        let medium: String?
        let original: String?
    }

    private struct CachedPoster {
        let fetchedAt: Date
        let url: String?
    }

    private var cache: [String: CachedPoster] = [:]
    private let cacheLifetime: TimeInterval = 6 * 60 * 60
    private let maximumResponseBytes = 1_500_000
    private var nextRequestAt = Date.distantPast
    private let requestSpacing: TimeInterval = 0.55

    func posters(for requests: [TVMazePosterRequest]) async -> [Int: String] {
        let candidates = Array(requests.filter {
            (1...1_000_000_000).contains($0.id)
                && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.title.utf8.count <= 200
        }.prefix(12))
        guard !candidates.isEmpty else { return [:] }

        return await withTaskGroup(of: (Int, String?).self) { group in
            var iterator = candidates.makeIterator()
            let concurrencyLimit = 5
            for _ in 0..<min(concurrencyLimit, candidates.count) {
                guard let item = iterator.next() else { continue }
                group.addTask { (item.id, await self.posterURL(for: item.title, year: item.year)) }
            }

            var output: [Int: String] = [:]
            while let (id, url) = await group.next() {
                if let url { output[id] = url }
                if let item = iterator.next() {
                    group.addTask { (item.id, await self.posterURL(for: item.title, year: item.year)) }
                }
            }
            return output
        }
    }

    private func posterURL(for title: String, year: Int?) async -> String? {
        let normalizedTitle = Self.normalized(title)
        guard !normalizedTitle.isEmpty else { return nil }
        let cacheKey = "\(normalizedTitle):\(year ?? 0)"
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached.url
        }

        let wait = nextRequestAt.timeIntervalSinceNow
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        guard !Task.isCancelled else { return nil }
        nextRequestAt = Date().addingTimeInterval(requestSpacing)

        guard var components = URLComponents(string: "https://api.tvmaze.com/search/shows") else { return nil }
        components.queryItems = [URLQueryItem(name: "q", value: title)]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard data.count <= maximumResponseBytes,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let results = try? JSONDecoder().decode([SearchResult].self, from: data) else {
                return nil
            }

            let exactMatches = results.filter { Self.normalized($0.show.name) == normalizedTitle }
            let pool: [SearchResult]
            if let year, !exactMatches.isEmpty {
                let matchingYear = exactMatches.filter { candidate in
                    guard let premiered = candidate.show.premiered,
                          let premieredYear = Int(premiered.prefix(4)) else { return false }
                    return premieredYear == year
                }
                guard !matchingYear.isEmpty else {
                    cache[cacheKey] = CachedPoster(fetchedAt: Date(), url: nil)
                    return nil
                }
                pool = matchingYear
            } else {
                pool = exactMatches
            }
            let best = pool.max { $0.score < $1.score }
                ?? results.filter { $0.score >= 0.82 }.max { $0.score < $1.score }
            let poster = Self.trustedPosterURL(best?.show.image?.original)
                ?? Self.trustedPosterURL(best?.show.image?.medium)
            cache[cacheKey] = CachedPoster(fetchedAt: Date(), url: poster)
            return poster
        } catch {
            if Task.isCancelled { return nil }
            return nil
        }
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func trustedPosterURL(_ rawValue: String?) -> String? {
        guard let rawValue, rawValue.utf8.count <= 2_048,
              let components = URLComponents(string: rawValue),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == "static.tvmaze.com",
              components.user == nil, components.password == nil else { return nil }
        return components.url?.absoluteString
    }
}

struct TaizenAnimeArtwork: Sendable {
    let posterURL: String?
    let logoURL: String?
}

/// Batch artwork lookup for anime. Taizen mirrors fanart.tv TVPOSTER and
/// clear-logo artwork and falls back to its curated AniList cover when a
/// community poster is not available.
actor TaizenAnimeArtworkService {
    static let shared = TaizenAnimeArtworkService()

    private struct CachedArtwork {
        let fetchedAt: Date
        let artwork: TaizenAnimeArtwork
    }

    private var cache: [Int: CachedArtwork] = [:]
    private let cacheLifetime: TimeInterval = 60 * 60
    private let maximumResponseBytes = 3 * 1_024 * 1_024

    func artworks(forAniListIDs rawIDs: [Int]) async -> [Int: TaizenAnimeArtwork] {
        let ids = Array(Set(rawIDs.filter { (1...1_000_000_000).contains($0) })).sorted()
        guard !ids.isEmpty else { return [:] }

        let now = Date()
        let missing = ids.filter {
            guard let cached = cache[$0] else { return true }
            return now.timeIntervalSince(cached.fetchedAt) >= cacheLifetime
        }

        for start in stride(from: 0, to: missing.count, by: 40) {
            let batch = Array(missing[start..<min(start + 40, missing.count)])
            let idList = batch.map(String.init).joined(separator: ",")
            let query = "{ animePage(filter: { ids: [\(idList)] }, perPage: 40) { items { id logo coverImage { large } artwork(type: TVPOSTER, limit: 1) { url } } } }"
            guard var components = URLComponents(string: "https://taizen.moe/api/graphql") else { continue }
            components.queryItems = [URLQueryItem(name: "query", value: query)]
            guard let url = components.url else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 18
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                try Task.checkCancellation()
                guard data.count <= maximumResponseBytes,
                      let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      (root["errors"] as? [Any])?.isEmpty != false,
                      let payload = root["data"] as? [String: Any],
                      let page = payload["animePage"] as? [String: Any],
                      let items = page["items"] as? [[String: Any]] else {
                    continue
                }

                let returnedIDs = Set(items.compactMap { ($0["id"] as? NSNumber)?.intValue })
                for item in items {
                    guard let id = (item["id"] as? NSNumber)?.intValue,
                          (1...1_000_000_000).contains(id) else { continue }
                    let fanartPoster = (item["artwork"] as? [[String: Any]])?.first?["url"] as? String
                    let coverImage = (item["coverImage"] as? [String: Any])?["large"] as? String
                    let poster = Self.trustedArtworkURL(fanartPoster) ?? Self.trustedArtworkURL(coverImage)
                    let logo = Self.trustedArtworkURL(item["logo"] as? String)
                    cache[id] = CachedArtwork(
                        fetchedAt: Date(),
                        artwork: TaizenAnimeArtwork(posterURL: poster, logoURL: logo)
                    )
                }

                // A successful response with no item is a real negative result;
                // cache it briefly so a missing mapping does not cause repeat calls.
                for id in batch where !returnedIDs.contains(id) {
                    cache[id] = CachedArtwork(
                        fetchedAt: Date(),
                        artwork: TaizenAnimeArtwork(posterURL: nil, logoURL: nil)
                    )
                }
            } catch {
                if Task.isCancelled { return cachedArtwork(for: ids) }
            }
        }
        return cachedArtwork(for: ids)
    }

    private func cachedArtwork(for ids: [Int]) -> [Int: TaizenAnimeArtwork] {
        Dictionary(uniqueKeysWithValues: ids.compactMap { id in
            cache[id].map { (id, $0.artwork) }
        })
    }

    private static func trustedArtworkURL(_ rawValue: String?) -> String? {
        guard let rawValue, rawValue.utf8.count <= 2_048 else { return nil }
        let candidate = rawValue.hasPrefix("/")
            ? "https://taizen.moe" + rawValue
            : rawValue
        guard let components = URLComponents(string: candidate),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              host == "taizen.moe" || host.hasSuffix(".taizen.moe")
                || host == "anilist.co" || host.hasSuffix(".anilist.co"),
              components.user == nil, components.password == nil else {
            return nil
        }
        return components.url?.absoluteString
    }
}

actor TaizenAnimeDubMetadataService {
    static let shared = TaizenAnimeDubMetadataService()

    private struct CachedCounts {
        let fetchedAt: Date
        let counts: [String: Int]
    }

    private var cache: [String: CachedCounts] = [:]
    private let cacheLifetime: TimeInterval = 60 * 60
    private let maximumResponseBytes = 2 * 1_024 * 1_024

    func episodeDubCounts(anilistID: Int?, malID: Int?) async throws -> [String: Int] {
        let identity: String
        let lookup: String
        if let anilistID, (1...1_000_000_000).contains(anilistID) {
            identity = "anilist-\(anilistID)"
            lookup = "id: \(anilistID)"
        } else if let malID, (1...1_000_000_000).contains(malID) {
            identity = "mal-\(malID)"
            lookup = "idMal: \(malID)"
        } else {
            throw TaizenDubMetadataError.missingIdentifier
        }

        if let cached = cache[identity],
           Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached.counts
        }

        let query = "{ anime(\(lookup)) { episodes episodeLanguages { lang dubEpisodes dubSource } } }"
        guard var components = URLComponents(string: "https://taizen.moe/api/graphql") else {
            throw TaizenDubMetadataError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        guard let url = components.url else { throw TaizenDubMetadataError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()

        guard data.count <= maximumResponseBytes,
              let http = response as? HTTPURLResponse else {
            throw TaizenDubMetadataError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw TaizenDubMetadataError.http(http.statusCode)
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["errors"] as? [Any])?.isEmpty != false,
              let payload = root["data"] as? [String: Any],
              let anime = payload["anime"] as? [String: Any],
              let rows = anime["episodeLanguages"] as? [[String: Any]] else {
            throw TaizenDubMetadataError.invalidResponse
        }

        let totalEpisodes = (anime["episodes"] as? NSNumber)?.intValue
        var counts: [String: Int] = [:]
        for row in rows {
            guard let language = row["lang"] as? String,
                  language.count <= 16,
                  let rawCount = row["dubEpisodes"] as? NSNumber else { continue }
            let count = rawCount.intValue
            guard count >= 0, count <= 20_000 else { continue }
            let boundedCount = min(count, totalEpisodes ?? count)
            counts[language.lowercased()] = boundedCount
        }

        cache[identity] = CachedCounts(fetchedAt: Date(), counts: counts)
        return counts
    }
}

/// OR-based episode filtering: an episode is visible when its number is covered
/// by at least one selected language's reported dub count. Missing metadata is
/// deliberately fail-closed while a language filter is active.
enum AnimeDubEpisodeVisibilityPolicy {
    static func availableEpisodeLimit(
        selectedLanguages: Set<String>,
        dubCountsByLanguage: [String: Int]
    ) -> Int? {
        guard !selectedLanguages.isEmpty else { return nil }
        let selectedCodes = selectedLanguages.flatMap { rawValue in
            MyDubListLanguage(rawValue: rawValue)?.episodeMetadataLanguageCodes ?? []
        }
        return selectedCodes.compactMap { dubCountsByLanguage[$0] }.max() ?? 0
    }

    static func includes(
        episodeNumber: Int,
        selectedLanguages: Set<String>,
        dubCountsByLanguage: [String: Int]
    ) -> Bool {
        guard episodeNumber > 0 else { return false }
        guard let limit = availableEpisodeLimit(
            selectedLanguages: selectedLanguages,
            dubCountsByLanguage: dubCountsByLanguage
        ) else {
            return selectedLanguages.isEmpty
        }
        return episodeNumber <= limit
    }
}


enum AnimeDubMetadataFallbackPolicy {
    static func shouldQueryAnidub(
        taizenCounts: [String: Int],
        selectedLanguages: Set<String> = [
            MyDubListLanguage.english.rawValue,
            MyDubListLanguage.spanish.rawValue
        ]
    ) -> Bool {
        guard !selectedLanguages.isEmpty else { return false }
        return !AnimeDubAudioSelectionPolicy.hasSelectedAudio(
            selectedLanguages: selectedLanguages,
            dubCountsByLanguage: taizenCounts
        )
    }
}

enum AnidubAnimeDubMetadataError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The anidub metadata URL is invalid."
        case .invalidResponse: return "anidub returned invalid dub metadata."
        case .http(let status): return "anidub metadata request failed (HTTP \(status))."
        }
    }
}

/// Regional Spanish dub counts from anidub. Its API returns every language
/// known for a title in one request, including locale-tagged Spanish records.
actor AnidubAnimeDubMetadataService {
    static let shared = AnidubAnimeDubMetadataService()

    private struct CachedCounts: Codable {
        let fetchedAt: Date
        let counts: [String: Int]
    }

    private var cache: [Int: CachedCounts] = [:]
    private let cacheLifetime: TimeInterval = 6 * 60 * 60
    private let maximumResponseBytes = 1 * 1_024 * 1_024
    private let cacheKeyPrefix = "anidubEpisodeDubCountsV1."

    func episodeDubCounts(anilistID: Int) async throws -> [String: Int] {
        guard (1...1_000_000_000).contains(anilistID) else {
            throw AnidubAnimeDubMetadataError.invalidResponse
        }
        if let cached = cachedCounts(for: anilistID) {
            return cached
        }

        guard let url = URL(string: "https://api.anidub.moe/v1/anime/\(anilistID)") else {
            throw AnidubAnimeDubMetadataError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Eclipse", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard data.count <= maximumResponseBytes,
              let http = response as? HTTPURLResponse else {
            throw AnidubAnimeDubMetadataError.invalidResponse
        }
        if http.statusCode == 404 {
            // anidub imports new titles over time; cache "not indexed yet"
            // briefly so repeatedly opening the same season does not burn
            // the anonymous daily request allowance.
            let empty = CachedCounts(fetchedAt: Date(), counts: [:])
            cache[anilistID] = empty
            if let encoded = try? JSONEncoder().encode(empty) {
                UserDefaults.standard.set(encoded, forKey: cacheKeyPrefix + String(anilistID))
            }
            return [:]
        }
        guard http.statusCode == 200 else {
            throw AnidubAnimeDubMetadataError.http(http.statusCode)
        }

        let counts = try Self.parseEpisodeDubCounts(from: data, anilistID: anilistID)
        let cached = CachedCounts(fetchedAt: Date(), counts: counts)
        cache[anilistID] = cached
        if let encoded = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(encoded, forKey: cacheKeyPrefix + String(anilistID))
        }
        return counts
    }

    private func cachedCounts(for anilistID: Int) -> [String: Int]? {
        if let cached = cache[anilistID],
           Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached.counts
        }
        guard let data = UserDefaults.standard.data(forKey: cacheKeyPrefix + String(anilistID)),
              let cached = try? JSONDecoder().decode(CachedCounts.self, from: data),
              Date().timeIntervalSince(cached.fetchedAt) >= 0,
              Date().timeIntervalSince(cached.fetchedAt) < cacheLifetime else {
            return nil
        }
        cache[anilistID] = cached
        return cached.counts
    }

    static func parseEpisodeDubCounts(from data: Data, anilistID: Int) throws -> [String: Int] {
        guard data.count <= 1 * 1_024 * 1_024,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseID = root["anilistId"] as? NSNumber,
              responseID.intValue == anilistID,
              let rows = root["dubs"] as? [[String: Any]] else {
            throw AnidubAnimeDubMetadataError.invalidResponse
        }

        var counts: [String: Int] = [:]
        for row in rows {
            guard row["stale"] as? Bool == false,
                  let rawLanguage = row["language"] as? String,
                  rawLanguage.utf8.count <= 32,
                  let rawStatus = row["status"] as? String,
                  rawStatus == "dubbed",
                  let rawCount = row["dubbedEpisodes"] as? NSNumber else { continue }
            let count = rawCount.intValue
            guard count > 0, count <= 20_000 else { continue }
            let language = rawLanguage.lowercased()
            guard language == "en" || language == "es"
                    || language == "es-419" || language == "es-es" else { continue }
            counts[language] = max(counts[language] ?? 0, count)
        }
        return counts
    }
}


enum TaizenAnimeAgeRatingError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Taizen age-rating URL is invalid."
        case .invalidResponse: return "Taizen returned invalid anime age-rating metadata."
        case .http(let status): return "Taizen age-rating request failed (HTTP \(status))."
        }
    }
}

/// MyAnimeList age ratings are kept separate from TMDB national
/// certifications; the two rating systems are not interchangeable.
actor TaizenAnimeAgeRatingService {
    static let shared = TaizenAnimeAgeRatingService()

    private struct CachedRating {
        let fetchedAt: Date
        let rating: MaturityRating
        let studioNames: [String]?
    }

    private var cache: [Int: CachedRating] = [:]
    private let cacheLifetime: TimeInterval = 24 * 60 * 60
    private let maximumResponseBytes = 1 * 1_024 * 1_024

    static func parseRatings(from data: Data, identifiers: [Int]) throws -> [Int: MaturityRating] {
        guard data.count <= 1 * 1_024 * 1_024,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["errors"] as? [Any])?.isEmpty != false,
              let payload = root["data"] as? [String: Any] else {
            throw TaizenAnimeAgeRatingError.invalidResponse
        }

        var ratings: [Int: MaturityRating] = [:]
        for (index, id) in identifiers.enumerated() {
            guard (1...1_000_000_000).contains(id) else { continue }
            let rating: MaturityRating
            if let anime = payload["a\(index)"] as? [String: Any],
               let returnedID = anime["id"] as? NSNumber,
               returnedID.intValue == id,
               let age = anime["ageRating"] as? [String: Any] {
                if let raw = age["rating"] as? String {
                    let malRating = MaturityRating.ratingForFiltering(certification: raw)
                    if malRating != .unknown {
                        rating = malRating
                    } else {
                        rating = Self.certificationFallback(from: age)
                    }
                } else {
                    // MAL ratings are not imported for every anime. Taizen also
                    // exposes official regional TMDB certifications; use those
                    // only as a fallback so valid 13+/14+ titles do not vanish
                    // from Browse solely because the MAL field is null.
                    rating = Self.certificationFallback(from: age)
                }
            } else {
                rating = .unknown
            }
            ratings[id] = rating
        }
        return ratings
    }

    private static func certificationFallback(from age: [String: Any]) -> MaturityRating {
        let certifications = age["certifications"] as? [[String: Any]] ?? []
        var byRegion: [String: [String]] = [:]
        for certification in certifications {
            guard let region = certification["region"] as? String,
                  let value = certification["rating"] as? String,
                  !region.isEmpty, !value.isEmpty else { continue }
            byRegion[region, default: []].append(value)
        }
        return MaturityRating.classify(certificationsByRegion: byRegion)
    }

    func rating(anilistID: Int) async throws -> MaturityRating {
        try await ratings(anilistIDs: [anilistID])[anilistID] ?? .unknown
    }

    func ratings(anilistIDs: [Int]) async throws -> [Int: MaturityRating] {
        let identifiers = Array(Set(anilistIDs.filter { (1...1_000_000_000).contains($0) })).sorted()
        guard !identifiers.isEmpty else { return [:] }

        var resolved: [Int: MaturityRating] = [:]
        let now = Date()
        let missing = identifiers.filter { id in
            guard let cached = cache[id] else { return true }
            return now.timeIntervalSince(cached.fetchedAt) < 0
                || now.timeIntervalSince(cached.fetchedAt) >= cacheLifetime
        }
        for id in identifiers where !missing.contains(id) {
            resolved[id] = cache[id]?.rating
        }

        for offset in stride(from: 0, to: missing.count, by: 20) {
            let batch = Array(missing[offset..<min(offset + 20, missing.count)])
            let fields = batch.enumerated().map { index, id in
                "a\(index): anime(id: \(id)) { id ageRating { rating certifications { region rating } } }"
            }.joined(separator: " ")
            let query = "{ \(fields) }"
            guard var components = URLComponents(string: "https://taizen.moe/api/graphql") else {
                throw TaizenAnimeAgeRatingError.invalidURL
            }
            components.queryItems = [URLQueryItem(name: "query", value: query)]
            guard let url = components.url else { throw TaizenAnimeAgeRatingError.invalidURL }

            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard data.count <= maximumResponseBytes,
                  let http = response as? HTTPURLResponse else {
                throw TaizenAnimeAgeRatingError.invalidResponse
            }
            guard http.statusCode == 200 else {
                throw TaizenAnimeAgeRatingError.http(http.statusCode)
            }
            let parsedRatings = try Self.parseRatings(from: data, identifiers: batch)
            for (id, rating) in parsedRatings {
                cache[id] = CachedRating(fetchedAt: now, rating: rating)
                resolved[id] = rating
            }
        }
        return resolved
    }
}


/// Public Jikan fallback for MyAnimeList age classifications. Unlike the
/// authenticated MAL client this endpoint does not require an app client ID.
actor JikanAnimeAgeRatingService {
    static let shared = JikanAnimeAgeRatingService()

    private struct CachedRating {
        let fetchedAt: Date
        let rating: MaturityRating
    }

    private var cache: [Int: CachedRating] = [:]
    private var nextRequestAt = Date.distantPast
    private let cacheLifetime: TimeInterval = 24 * 60 * 60
    private let unknownCacheLifetime: TimeInterval = 15 * 60

    static func parseRating(from data: Data) -> MaturityRating {
        guard data.count <= 512 * 1_024,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let rawRating = payload["rating"] as? String else {
            return .unknown
        }
        let classification = rawRating
            .components(separatedBy: " - ")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? rawRating
        switch classification.uppercased() {
        case "R", "R+": return .age17
        case "RX": return .adult
        default: return MaturityRating.ratingForFiltering(certification: classification)
        }
    }

    static func parseStudioNames(from data: Data) -> [String]? {
        guard data.count <= 512 * 1_024,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let studios = payload["studios"] as? [[String: Any]] else {
            return nil
        }
        let names = Array(Set(studios.compactMap { studio -> String? in
            guard let rawName = studio["name"] as? String else { return nil }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        })).sorted()
        return names.isEmpty ? nil : names
    }

    func studioNames(malID: Int) async -> [String]? {
        if let cached = cache[malID], let names = cached.studioNames, !names.isEmpty {
            return names
        }
        _ = try? await rating(malID: malID)
        return cache[malID]?.studioNames
    }

    func ratings(malIDs: [Int]) async -> [Int: MaturityRating] {
        let identifiers = Array(Set(malIDs.filter { (1...1_000_000_000).contains($0) }))
        guard !identifiers.isEmpty else { return [:] }
        return await withTaskGroup(of: (Int, MaturityRating?).self) { group in
            for malID in identifiers {
                group.addTask {
                    do {
                        return (malID, try await self.rating(malID: malID))
                    } catch {
                        return (malID, nil)
                    }
                }
            }
            var resolved: [Int: MaturityRating] = [:]
            for await (malID, rating) in group {
                if let rating, rating != .unknown {
                    resolved[malID] = rating
                }
            }
            return resolved
        }
    }

    func rating(malID: Int) async throws -> MaturityRating {
        guard (1...1_000_000_000).contains(malID) else { return .unknown }
        if let cached = cache[malID] {
            let lifetime = cached.rating == .unknown ? unknownCacheLifetime : cacheLifetime
            if Date().timeIntervalSince(cached.fetchedAt) < lifetime {
                return cached.rating
            }
        }

        let now = Date()
        let scheduled = max(now, nextRequestAt)
        nextRequestAt = scheduled.addingTimeInterval(0.4)
        if scheduled > now {
            try await Task.sleep(nanoseconds: UInt64(scheduled.timeIntervalSince(now) * 1_000_000_000))
        }
        try Task.checkCancellation()

        guard let url = URL(string: "https://api.jikan.moe/v4/anime/\(malID)") else {
            return .unknown
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard data.count <= 512 * 1_024,
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return .unknown
        }
        let resolved = Self.parseRating(from: data)
        let studios = Self.parseStudioNames(from: data)
        cache[malID] = CachedRating(
            fetchedAt: Date(),
            rating: resolved,
            studioNames: studios
        )
        return resolved
    }
}


enum AnimeSpecialDubFilterPolicy {
    static func shouldInclude(
        selectedLanguages: Set<String>,
        isVerifiedForSelection: Bool
    ) -> Bool {
        selectedLanguages.isEmpty || isVerifiedForSelection
    }
}
