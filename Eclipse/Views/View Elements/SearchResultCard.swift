//
//  SearchResultCard.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher

enum PosterArtworkURLResolver {
    static func originalTMDBPosterURL(for result: TMDBSearchResult) -> String? {
        guard let path = result.posterPath else { return nil }
        if ImageDataSaverSettings.isEnabled() {
            return TMDBImageRequestPolicy.urlString(for: path, kind: .poster)
        }
        return TMDBImageRequestPolicy.originalURLString(for: path)
    }

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

        if isAnime, let anime = result.animeArtworkURL, !anime.isEmpty {
            candidates.append(anime)
        }
        if !isAnime, result.isMovie, let fanart = result.fanartTVPosterURL, !fanart.isEmpty {
            candidates.append(fanart)
        }
        if let original = originalTMDBPosterURL(for: result) {
            candidates.append(original)
        }
        if !isAnime, let fanart = result.fanartTVPosterURL, !fanart.isEmpty {
            candidates.append(fanart)
        }
        if !isAnime, let tvMaze = result.tvMazePosterURL, !tvMaze.isEmpty {
            candidates.append(tvMaze)
        }
        if !isAnime, let anime = result.animeArtworkURL, !anime.isEmpty {
            candidates.append(anime)
        }
        if let full = result.fullPosterURL, !full.isEmpty {
            candidates.append(full)
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

    var body: some View {
        ZStack {
            // Keep the source poster at its original brightness. A dark gradient
            // here was unintentionally tinting every browsing/search poster,
            // even when no title artwork was available.

            if let logoURL, !logoURL.isEmpty {
                ResilientArtworkImage(
                    urls: [logoURL],
                    decodeSize: CGSize(width: 900, height: 260),
                    contentMode: .fit
                ) {
                    Color.clear
                }
                .frame(maxWidth: 900, maxHeight: 260)
                .padding(.horizontal, 8)
            } else {
                titleText
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .allowsHitTesting(false)
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.72)
            .shadow(color: .black.opacity(0.85), radius: 7, x: 0, y: 3)
            .padding(.horizontal, 10)
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

    private var posterImage: some View {
        ZStack {
            ResilientArtworkImage(
                urls: PosterArtworkURLResolver.candidates(for: result),
                decodeSize: CGSize(width: posterDecodeWidth, height: posterDecodeWidth * 1.5),
                contentMode: .fill
            ) {
                FallbackImageView(
                    isMovie: result.isMovie,
                    size: CGSize(width: posterDecodeWidth, height: posterDecodeWidth * 1.5)
                )
            }

            CenteredPosterTitleOverlay(
                title: result.displayTitle,
                logoURL: result.animeLogoURL,
                fontSize: isTvOS ? 25 : (isIPad ? 18 : 14)
            )
        }
        .aspectRatio(2/3, contentMode: .fill)
    }
}
