//
//  TMDBContentFilter.swift
//  Sora
//
//  Created by Francesco on 11/09/25.
//

import Combine
import Foundation

enum MyDubListLanguage: String, CaseIterable, Identifiable, Sendable {
    case english, spanish, german, french, italian, chinese, portuguese, korean
    case tagalog, arabic, polish, hindi, hungarian, hebrew, swedish, norwegian
    case dutch, thai, indonesian, russian, danish, finnish, turkish, catalan, vietnamese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish (Latino or Castellano)"
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
    private var allowedMALIDs: Set<Int> = []
    private var allowedAniListIDs: Set<Int> = []
    private var allowedEnglishMALIDs: Set<Int> = []
    private var allowedEnglishAniListIDs: Set<Int> = []
    private var loadedLanguages: Set<String> = []
    private var isLoaded = false

    var selectedLanguages: Set<String> {
        Set((ProfileSettingsStore.active.stringArray(forKey: Self.selectedLanguagesKey) ?? [])
            .filter { MyDubListLanguage(rawValue: $0) != nil })
    }

    var selectedLanguagesIncludingCatalogAudioRequirement: Set<String> {
        var languages = selectedLanguages
        if UserDefaults.standard.bool(forKey: "catalogRequireEnglishSpanishAudio") {
            languages.formUnion([
                MyDubListLanguage.english.rawValue,
                MyDubListLanguage.spanish.rawValue
            ])
        }
        return languages
    }

    private func notifyRefreshObservers() {
        NotificationCenter.default.post(name: Self.didRefreshNotification, object: nil)
        NotificationCenter.default.post(name: TMDBContentFilter.catalogFiltersDidChangeNotification, object: nil)
    }

    func setSelectedLanguages(_ languages: Set<String>) {
        let valid = languages.filter { MyDubListLanguage(rawValue: $0) != nil }
        ProfileSettingsStore.active.set(valid.sorted(), forKey: Self.selectedLanguagesKey)
        lock.lock()
        isLoaded = false
        lock.unlock()
    }

    func refresh() async -> Bool {
        let languages = selectedLanguages
        guard !languages.isEmpty else {
            clearSnapshot()
            notifyRefreshObservers()
            return true
        }

        loadCachedSnapshot(for: languages)

        do {
            var malIDs = Set<Int>()
            var englishMALIDs = Set<Int>()
            for language in languages.sorted() {
                let url = URL(string: "https://raw.githubusercontent.com/Joelis57/MyDubList/main/dubs/confidence/low/dubbed_\(language).json")!
                let data = try await Self.download(url, maximumBytes: 1_000_000)
                let dataset = try JSONDecoder().decode(DubDataset.self, from: data)
                guard dataset.dubbed.count <= 250_000 else { throw URLError(.dataLengthExceedsMaximum) }
                let validIDs = Set(dataset.dubbed.filter { $0 > 0 && $0 <= 100_000_000 })
                malIDs.formUnion(validIDs)
                if language == MyDubListLanguage.english.rawValue {
                    englishMALIDs = validIDs
                }
            }

            let mappingURL = URL(string: "https://raw.githubusercontent.com/Joelis57/MyDubList/main/dubs/mappings/mappings_anilist.jsonl")!
            let mappingData = try await Self.download(mappingURL, maximumBytes: 4_000_000)
            guard let mappingText = String(data: mappingData, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }

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

            guard languages == selectedLanguages else { return hasSnapshot(for: selectedLanguages) }
            publishSnapshot(
                malIDs: malIDs,
                aniListIDs: aniListIDs,
                englishMALIDs: englishMALIDs,
                englishAniListIDs: englishAniListIDs,
                languages: languages
            )
            let defaults = ProfileSettingsStore.active
            defaults.set(languages.sorted(), forKey: Self.cachedLanguagesKey)
            defaults.set(malIDs.sorted(), forKey: Self.cachedMALIDsKey)
            defaults.set(aniListIDs.sorted(), forKey: Self.cachedAniListIDsKey)
            defaults.set(englishMALIDs.sorted(), forKey: Self.cachedEnglishMALIDsKey)
            defaults.set(englishAniListIDs.sorted(), forKey: Self.cachedEnglishAniListIDsKey)
            notifyRefreshObservers()
            Logger.shared.log("MyDubList: loaded languages=\(languages.sorted().joined(separator: ",")) MAL=\(malIDs.count) AniList=\(aniListIDs.count)", type: "Anime")
            return true
        } catch {
            Logger.shared.log("MyDubList: dub filter refresh failed: \(error.localizedDescription)", type: "Anime")
            return hasSnapshot(for: languages)
        }
    }

    func shouldInclude(_ result: TMDBSearchResult) -> Bool {
        let languages = selectedLanguages
        guard !languages.isEmpty else { return true }
        let isLikelyAnime = result.animeIdentitySeed != nil
            || result.isAnimeHint == true
            || (result.genreIds?.contains(16) == true
                && (result.originalLanguage?.lowercased() == "ja"
                    || result.originCountry?.contains("JP") == true))
        guard isLikelyAnime else { return true }
        guard let seed = result.animeIdentitySeed else { return false }

        lock.lock()
        defer { lock.unlock() }
        // Keep existing anime visible while a newly selected dataset is loading.
        // The completion notification re-applies the filter against the verified snapshot.
        guard isLoaded, loadedLanguages == languages else { return true }
        if allowedAniListIDs.contains(seed.anilistId) { return true }
        if let malID = seed.malId, allowedMALIDs.contains(malID) { return true }
        return false
    }

    func shouldIncludeEnglishSchedule(anilistID: Int?, malID: Int?) -> Bool {
        let languages = selectedLanguages
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
        let languages = selectedLanguages
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
        request.timeoutInterval = 30
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
    private var animeAgeRatingsByID: [Int: MaturityRating] = [:]
    private var animeAudioEligibleIDs: Set<Int> = []

    private var cancellables = Set<AnyCancellable>()

    @Published var filterHorror: Bool {
        didSet {
            ProfileSettingsStore.active.set(filterHorror, forKey: "filterHorror")
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
        self.filterHorror = ProfileSettingsStore.active.bool(forKey: "filterHorror")
        Task { _ = await MyDubListDubFilter.shared.refresh() }
        TMDBMaturityRatingStore.shared.$revision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] revision in
                guard let self, self.isKidsProfileActive else { return }
                self.maturityRatingRevision = revision
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
        let defaults = UserDefaults.standard
        let needsTMDBRatings = kidsModeEnabled
            || defaults.bool(forKey: "catalogHideBelowPG13Movies")
            || defaults.bool(forKey: "catalogHideBelowTV14Shows")
        if needsTMDBRatings {
            let ratingResults = kidsModeEnabled ? results : results.filter { !Self.isAnimeResult($0) }
            await TMDBMaturityRatingStore.shared.resolve(
                ratingResults.map { (isMovie: $0.isMovie, id: $0.id) }
            )
        }

        let hideBelowAnime = defaults.bool(forKey: "catalogHideBelowPG13Anime")
        let requireVerifiedAudio = defaults.bool(forKey: "catalogRequireEnglishSpanishAudio")
        guard hideBelowAnime || requireVerifiedAudio else { return }

        var uniqueAnime: [Int: TMDBSearchResult] = [:]
        for result in results where Self.isAnimeResult(result) {
            guard let id = result.animeIdentitySeed?.anilistId, id > 0 else { continue }
            uniqueAnime[id] = result
        }
        let animeResults = Array(uniqueAnime.values)

        if hideBelowAnime {
            let identifiers = Array(uniqueAnime.keys)
            if let ratings = try? await TaizenAnimeAgeRatingService.shared.ratings(anilistIDs: identifiers) {
                for (id, rating) in ratings {
                    storeAnimeAgeRating(rating, for: id)
                }
            }
        }

        guard requireVerifiedAudio, !animeResults.isEmpty else { return }
        // Taizen exposes one title per request. Bound concurrency instead of
        // serially waiting for every anime in every home catalog.
        await withTaskGroup(of: (Int, Bool).self) { group in
            var iterator = animeResults.makeIterator()
            let concurrencyLimit = 6
            for _ in 0..<min(concurrencyLimit, animeResults.count) {
                guard let result = iterator.next(),
                      let id = result.animeIdentitySeed?.anilistId else { continue }
                group.addTask {
                    let counts = (try? await TaizenAnimeDubMetadataService.shared.episodeDubCounts(
                        anilistID: id,
                        malID: result.animeIdentitySeed?.malId
                    )) ?? [:]
                    let eligible = (counts["en"] ?? 0) > 0 || (counts["es"] ?? 0) > 0
                        || (counts["es-419"] ?? 0) > 0 || (counts["es-es"] ?? 0) > 0
                    return (id, eligible)
                }
            }
            while let (id, eligible) = await group.next() {
                storeAnimeAudioEligibility(eligible, for: id)
                if let result = iterator.next(),
                   let nextID = result.animeIdentitySeed?.anilistId {
                    group.addTask {
                        let counts = (try? await TaizenAnimeDubMetadataService.shared.episodeDubCounts(
                            anilistID: nextID,
                            malID: result.animeIdentitySeed?.malId
                        )) ?? [:]
                        let eligible = (counts["en"] ?? 0) > 0 || (counts["es"] ?? 0) > 0
                            || (counts["es-419"] ?? 0) > 0 || (counts["es-es"] ?? 0) > 0
                        return (nextID, eligible)
                    }
                }
            }
        }
    }

    func filterSearchResultsResolvingRatings(_ results: [TMDBSearchResult]) async -> [TMDBSearchResult] {
        await prepareMaturityRatings(for: results)
        return filterSearchResults(results)
    }

    func filterFastAnimeSearchResultsResolvingRatings(_ results: [TMDBSearchResult]) async -> [TMDBSearchResult] {
        await prepareMaturityRatings(for: results)
        return filterFastAnimeSearchResults(results)
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

    func filterSearchResults(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        return results.filter { result in
            shouldIncludeCatalogResult(result)
        }
    }

    func filterFastAnimeSearchResults(_ results: [TMDBSearchResult]) -> [TMDBSearchResult] {
        return results.filter { result in
            shouldIncludeCatalogResult(result) && shouldIncludeFastAnimeResult(result)
        }
    }

    func filterMovies(_ movies: [TMDBMovie]) -> [TMDBMovie] {
        return movies.filter { movie in
            guard movie.adult != true else { return false }
            guard shouldIncludeCatalogTitle(movie.title) else { return false }
            guard shouldIncludeTMDBAgeRating(
                isMovie: true,
                id: movie.id,
                enabled: UserDefaults.standard.bool(forKey: "catalogHideBelowPG13Movies")
            ) else { return false }
            guard shouldIncludeForKids(
                title: movie.title,
                overview: movie.overview,
                isMovie: true,
                tmdbID: movie.id
            ) else { return false }
            return shouldIncludeContent(genreIds: movie.genreIds)
        }
    }

    func filterTVShows(_ tvShows: [TMDBTVShow]) -> [TMDBTVShow] {
        return tvShows.filter { tvShow in
            guard tvShow.adult != true else { return false }
            guard shouldIncludeCatalogTitle(tvShow.name) else { return false }
            guard shouldIncludeTMDBAgeRating(
                isMovie: false,
                id: tvShow.id,
                enabled: UserDefaults.standard.bool(forKey: "catalogHideBelowTV14Shows")
            ) else { return false }
            guard shouldIncludeForKids(
                title: tvShow.name,
                overview: tvShow.overview,
                isMovie: false,
                tmdbID: tvShow.id
            ) else { return false }
            return shouldIncludeContent(genreIds: tvShow.genreIds)
        }
    }

    private func shouldIncludeCatalogResult(_ result: TMDBSearchResult) -> Bool {
        guard MyDubListDubFilter.shared.shouldInclude(result) else { return false }
        guard result.adult != true else { return false }
        guard shouldIncludeForConfiguredAgeAndAudio(result) else { return false }
        guard shouldIncludeCatalogTitle(result.displayTitle) else { return false }
        guard shouldIncludeForKids(
            title: result.displayTitle,
            overview: result.overview,
            isMovie: result.isMovie,
            tmdbID: result.id
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
        tmdbID: Int
    ) -> Bool {
        guard kidsModeEnabled else { return true }
        guard TMDBMaturityRatingStore.shared.isAllowedForKids(isMovie: isMovie, id: tmdbID) else {
            return false
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
        animeEligibilityLock.unlock()
    }

    private func storeAnimeAudioEligibility(_ isEligible: Bool, for id: Int) {
        animeEligibilityLock.lock()
        if isEligible {
            animeAudioEligibleIDs.insert(id)
        } else {
            animeAudioEligibleIDs.remove(id)
        }
        animeEligibilityLock.unlock()
    }

    private func shouldIncludeTMDBAgeRating(isMovie: Bool, id: Int, enabled: Bool) -> Bool {
        guard enabled else { return true }
        // Unknown certification is not proof that a title is below the threshold.
        guard let rating = TMDBMaturityRatingStore.shared.rating(isMovie: isMovie, id: id) else {
            return true
        }
        return rating == .unknown || rating >= .teen
    }

    private func shouldIncludeForConfiguredAgeAndAudio(_ result: TMDBSearchResult) -> Bool {
        let defaults = UserDefaults.standard
        let isAnime = Self.isAnimeResult(result)

        if isAnime, defaults.bool(forKey: "catalogHideBelowPG13Anime") {
            guard let anilistID = result.animeIdentitySeed?.anilistId else { return false }
            animeEligibilityLock.lock()
            let rating = animeAgeRatingsByID[anilistID]
            animeEligibilityLock.unlock()
            // Keep titles with unavailable age metadata; only hide a confirmed
            // rating below PG-13.
            guard rating == nil || rating == .unknown || rating! >= .teen else { return false }
        } else if !isAnime {
            let shouldCheckMovie = result.isMovie && defaults.bool(forKey: "catalogHideBelowPG13Movies")
            let shouldCheckTV = result.isTVShow && defaults.bool(forKey: "catalogHideBelowTV14Shows")
            if shouldCheckMovie || shouldCheckTV {
                guard let rating = TMDBMaturityRatingStore.shared.rating(
                    isMovie: result.isMovie,
                    id: result.id
                ), rating != .unknown, rating >= .teen else { return false }
            }
        }

        if Self.shouldHideForReleaseDate(result, defaults: defaults) { return false }

        if defaults.bool(forKey: "catalogRequireEnglishSpanishAudio") {
            let originalLanguage = result.originalLanguage?.lowercased()
            let hasNativeAudio = originalLanguage == "en" || originalLanguage == "es"
            if hasNativeAudio { return true }
            guard isAnime, let anilistID = result.animeIdentitySeed?.anilistId else {
                // TMDB does not publish dub-track availability for general
                // movies or TV episodes. Unknown audio must not be guessed.
                return false
            }
            animeEligibilityLock.lock()
            let hasVerifiedDub = animeAudioEligibleIDs.contains(anilistID)
            animeEligibilityLock.unlock()
            guard hasVerifiedDub else { return false }
        }
        return true
    }

    private static func isAnimeResult(_ result: TMDBSearchResult) -> Bool {
        result.animeIdentitySeed != nil
            || result.isAnimeHint == true
            || (result.genreIds?.contains(16) == true
                && (result.originalLanguage?.lowercased() == "ja"
                    || result.originCountry?.contains("JP") == true))
    }

    private static func announcedReleaseDate(for result: TMDBSearchResult) -> Date? {
        let raw = result.isMovie ? result.releaseDate : (result.firstAirDate ?? result.releaseDate)
        guard let raw, raw.count >= 10, !raw.hasPrefix("0001-") else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: String(raw.prefix(10)))
    }

    private static func shouldHideForReleaseDate(
        _ result: TMDBSearchResult,
        defaults: UserDefaults
    ) -> Bool {
        let isAnime = isAnimeResult(result)
        let isMovie = result.isMovie
        let before1994Key = isAnime ? "catalogHidePre1994Anime"
            : (isMovie ? "catalogHidePre1994Movies" : "catalogHidePre1994TVShows")
        let unreleasedKey = isAnime ? "catalogHideUnreleasedAnime"
            : (isMovie ? "catalogHideUnreleasedMovies" : "catalogHideUnreleasedTVShows")
        guard let releaseDate = announcedReleaseDate(for: result) else { return false }
        if defaults.bool(forKey: before1994Key),
           Calendar(identifier: .gregorian).component(.year, from: releaseDate) < 1994 {
            return true
        }
        return defaults.bool(forKey: unreleasedKey) && releaseDate > Date()
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
    }

    private var cache: [Int: CachedRating] = [:]
    private let cacheLifetime: TimeInterval = 24 * 60 * 60
    private let maximumResponseBytes = 1 * 1_024 * 1_024

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
                "a\(index): anime(id: \(id)) { id ageRating { rating } }"
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
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (root["errors"] as? [Any])?.isEmpty != false,
                  let payload = root["data"] as? [String: Any] else {
                throw TaizenAnimeAgeRatingError.invalidResponse
            }

            for (index, id) in batch.enumerated() {
                let rating: MaturityRating
                if let anime = payload["a\(index)"] as? [String: Any],
                   let returnedID = anime["id"] as? NSNumber,
                   returnedID.intValue == id,
                   let age = anime["ageRating"] as? [String: Any],
                   let raw = age["rating"] as? String {
                    rating = MaturityRating.classify(certification: raw)
                } else {
                    rating = .unknown
                }
                cache[id] = CachedRating(fetchedAt: now, rating: rating)
                resolved[id] = rating
            }
        }
        return resolved
    }
}
