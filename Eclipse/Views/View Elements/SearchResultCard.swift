//
//  SearchResultCard.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

enum PosterArtworkURLResolver {
    /// Prefer provider artwork at its source resolution. TMDB's original-size
    /// path avoids smaller w342/w500 derivatives used by many catalog APIs.
    static func candidates(for result: TMDBSearchResult) -> [String] {
        var candidates: [String] = []

        // Anime cover services often provide sharper, cleaner source artwork
        // than TMDB's catalogue-sized poster. Prefer that artwork for anime,
        // while keeping Fanart.tv first for movies and TVMaze for live-action TV.
        let language = result.originalLanguage?.lowercased() ?? ""
        let asianAnimationCountries: Set<String> = ["JP", "CN", "KR", "TW"]
        let isAnime = result.animeIdentitySeed != nil
            || result.isAnimeHint == true
            || (result.genreIds?.contains(16) == true
                && (["ja", "zh", "ko"].contains(language)
                    || result.originCountry?.contains(where: { asianAnimationCountries.contains($0) }) == true))

        if isAnime, let fanart = result.fanartTVPosterURL, !fanart.isEmpty {
            candidates.append(fanart)
        }
        if isAnime, let anime = result.animeArtworkURL, !anime.isEmpty,
           let host = URL(string: anime)?.host?.lowercased(),
           (host == "taizen.moe" || host.hasSuffix(".taizen.moe")
                || host == "fanart.tv" || host.hasSuffix(".fanart.tv")) {
            // Do not use AniList/TMDB cover scans as a fallback here: many
            // have the series title baked into the image. Keep only the clean
            // Taizen/Fanart artwork so the transparent logo remains the sole
            // title treatment on Home and Browse poster cards.
            candidates.append(anime)
        }
        if !isAnime, result.isMovie, let fanart = result.fanartTVPosterURL, !fanart.isEmpty {
            candidates.append(fanart)
        }
        // TMDB poster artwork is deliberately excluded: it frequently
        // contains embedded title treatments. Keep only clean source artwork
        // from Fanart.tv, TVMaze and anime cover providers. The transparent
        // title-logo overlay is rendered separately by the card.
        if !isAnime, let fanart = result.fanartTVPosterURL, !fanart.isEmpty {
            candidates.append(fanart)
        }
        if !isAnime, let tvMaze = result.tvMazePosterURL, !tvMaze.isEmpty {
            candidates.append(tvMaze)
        }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    static func bestPosterURL(for result: TMDBSearchResult) -> String? {
        candidates(for: result).first
    }
}

struct CenteredPosterTitleOverlay: View {
    let title: String
    let logoURL: String?
    var fontSize: CGFloat = 16
    var verticalPosition: Double = MediaDetailTitleLogoPositionSettings.defaultVerticalPosition

    private let logoSize = MediaDetailTitleLogoAppearanceSettings.defaultSize
    private let logoWeight = MediaDetailTitleLogoAppearanceSettings.defaultWeight

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Never replace missing transparent artwork with ordinary text:
                // that creates a visibly different title treatment between cards.
                if let logoURL, !logoURL.isEmpty {
                    logoImage
                        .frame(
                            maxWidth: min(geometry.size.width * 0.9 * CGFloat(logoSize), 900),
                            maxHeight: min(geometry.size.height * 0.34 * CGFloat(logoSize), 260)
                        )
                        .padding(.horizontal, 8)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .offset(y: geometry.size.height * CGFloat(verticalPosition - 0.5))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var logoImage: some View {
        if let logoURL, !logoURL.isEmpty {
            ResilientArtworkImage(
                urls: [logoURL],
                decodeSize: CGSize(width: 1200, height: 360),
                contentMode: .fit
            ) {
                Color.clear
            }
            // A subtle second pass thickens thin logo strokes without adding
            // a text fallback or altering the source artwork.
            .overlay {
                if logoWeight > 0.01 {
                    ResilientArtworkImage(
                        urls: [logoURL],
                        decodeSize: CGSize(width: 1200, height: 360),
                        contentMode: .fit
                    ) {
                        Color.clear
                    }
                    .offset(x: 0.6, y: 0)
                    .opacity(min(max(logoWeight, 0), 1) * 0.65)
                }
            }
        }
    }
}

actor SearchResultTitleLogoCache {
    static let shared = SearchResultTitleLogoCache()

    private struct LookupResult {
        let url: String?
        let succeeded: Bool
    }

    private var resolved: [String: String] = [:]
    private var attempted = Set<String>()
    private var pending: [String: Task<LookupResult, Never>] = [:]

    func prefetch(results: [TMDBSearchResult], limit: Int = 48) async {
        var seen = Set<String>()
        let candidates = Array(results.filter { seen.insert($0.stableIdentity).inserted }.prefix(max(0, limit)))
        await withTaskGroup(of: Void.self) { group in
            var iterator = candidates.makeIterator()
            for _ in 0..<min(4, candidates.count) {
                guard let result = iterator.next() else { continue }
                group.addTask { await Self.shared.prefetchOne(result) }
            }
            while await group.next() != nil {
                if let result = iterator.next() {
                    group.addTask { await Self.shared.prefetchOne(result) }
                }
            }
        }
    }

    private func prefetchOne(_ result: TMDBSearchResult) async {
        // Provider-supplied anime logo URLs do not expose a dependable language
        // tag and can contain Japanese lettering. Resolve through the same
        // English-first TMDB policy used for movies and live-action TV instead.
        let candidate = await logoURL(
            mediaType: result.isMovie ? "movie" : "tv",
            id: result.id
        )
        guard let candidate, let url = URL(string: candidate), url.scheme == "https" else { return }
        KingfisherManager.shared.retrieveImage(with: url, options: [.backgroundDecode]) { _ in }
    }

    func logoURL(mediaType: String, id: Int) async -> String? {
        guard id > 0, mediaType == "movie" || mediaType == "tv" else { return nil }
        let key = "\(mediaType):\(id):en-es"
        if attempted.contains(key) { return resolved[key] }
        if let task = pending[key] { return await task.value.url }

        let task = Task<LookupResult, Never> {
            async let englishImages: TMDBImagesResponse? = {
                do {
                    return mediaType == "movie"
                        ? try await TMDBService.shared.getMovieImages(id: id, preferredLanguage: "en")
                        : try await TMDBService.shared.getTVShowImages(id: id, preferredLanguage: "en")
                } catch { return nil }
            }()
            async let spanishImages: TMDBImagesResponse? = {
                do {
                    return mediaType == "movie"
                        ? try await TMDBService.shared.getMovieImages(id: id, preferredLanguage: "es")
                        : try await TMDBService.shared.getTVShowImages(id: id, preferredLanguage: "es")
                } catch { return nil }
            }()
            let (english, spanish) = await (englishImages, spanishImages)
            let logos = (english?.logos ?? []) + (spanish?.logos ?? [])
            let ranked = logos.sorted { lhs, rhs in
                func languageRank(_ code: String?) -> Int {
                    switch code?.lowercased() {
                    case "en": return 0
                    case "es": return 1
                    case nil, "": return 2
                    default: return 3
                    }
                }
                let left = languageRank(lhs.iso6391)
                let right = languageRank(rhs.iso6391)
                if left != right { return left < right }
                if (lhs.voteCount ?? 0) != (rhs.voteCount ?? 0) {
                    return (lhs.voteCount ?? 0) > (rhs.voteCount ?? 0)
                }
                return (lhs.voteAverage ?? 0) > (rhs.voteAverage ?? 0)
            }
            // Never choose an unrelated-language logo merely to fill the slot.
            if let tmdbLogo = ranked.first(where: { $0.iso6391?.lowercased() == "en" })?.fullURL
                ?? ranked.first(where: { $0.iso6391?.lowercased() == "es" })?.fullURL
                ?? ranked.first(where: { $0.iso6391 == nil || $0.iso6391 == "" })?.fullURL {
                return LookupResult(url: tmdbLogo, succeeded: true)
            }

            // Some titles have no TMDB transparent logo. Use the same
            // language-filtered Fanart.tv fallback as Home and Detail rather
            // than leaving every Browse/Home poster without title artwork.
            if mediaType == "movie" {
                let details = try? await TMDBService.shared.getMovieDetails(id: id)
                let fanartLookup = await FanartTVLogoService.shared.lookup(
                    imdbID: details?.imdbId,
                    tvdbID: nil
                )
                return LookupResult(
                    url: fanartLookup.url,
                    succeeded: fanartLookup.url != nil
                        || (english != nil && spanish != nil && details != nil && fanartLookup.succeeded)
                )
            }

            let details = try? await TMDBService.shared.getTVShowWithSeasons(id: id)
            let fanartLookup = await FanartTVLogoService.shared.lookup(
                imdbID: nil,
                tvdbID: details?.externalIds?.tvdbId
            )
            return LookupResult(
                url: fanartLookup.url,
                succeeded: fanartLookup.url != nil
                    || (english != nil && spanish != nil && details != nil && fanartLookup.succeeded)
            )
        }
        pending[key] = task
        let lookup = await task.value
        pending[key] = nil
        // Cache successful no-logo responses, but allow a failed network lookup
        // to retry on a later appearance instead of hiding a logo permanently.
        if lookup.succeeded {
            attempted.insert(key)
            if let url = lookup.url, !url.isEmpty { resolved[key] = url }
        }
        return lookup.url
    }
}

struct SearchResultCard: View {
    let result: TMDBSearchResult
    @Environment(\.heroNamespace) private var heroNamespace
    private var heroID: String { "search-\(result.stableIdentity)" }

    var body: some View {
        NavigationLink(destination: MediaDetailView(searchResult: result)
            .heroDestination(id: heroID, namespace: heroNamespace)
        ) {
            VStack(spacing: 8) {
                posterArtwork
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .heroSource(id: heroID, namespace: heroNamespace)
                    .accessibilityLabel(result.displayTitle)
            }
            .frame(maxWidth: .infinity)
        }
#if os(tvOS)
        .buttonStyle(TVMediaCardButtonStyle())
#else
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("media.search.result.\(result.stableIdentity)")
#endif
    }

    @ViewBuilder
    private var posterArtwork: some View {
        if isTvOS || isIPad {
            Color.clear
                .aspectRatio(2/3, contentMode: .fit)
                .overlay {
                    posterImage
                }
                .clipped()
        } else {
            posterImage
                .frame(height: 180 * iPadScale)
        }
    }

    private var posterDecodeWidth: CGFloat {
        isTvOS ? 640 : (isIPad ? 480 : 320)
    }

    @State private var titleLogoURL: String?

    private var posterImage: some View {
        ZStack {
            ResilientArtworkImage(
                urls: PosterArtworkURLResolver.candidates(for: result),
                decodeSize: CGSize(width: posterDecodeWidth, height: posterDecodeWidth * 1.5),
                contentMode: .fill
            ) {
                FallbackImageView(
                    isMovie: result.isMovie,
                    size: CGSize(width: posterDecodeWidth, height: posterDecodeWidth * 1.5),
                    expandsToFillContainer: true
                )
            }

            CenteredPosterTitleOverlay(
                title: result.displayTitle,
                logoURL: titleLogoURL
            )
        }
        .aspectRatio(2/3, contentMode: .fill)
        .task(id: result.stableIdentity) {
            titleLogoURL = nil
            titleLogoURL = await SearchResultTitleLogoCache.shared.logoURL(
                mediaType: result.isMovie ? "movie" : "tv",
                id: result.id
            )
        }
    }
}
