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
    /// path avoids the smaller w342/w500 derivatives used by many catalog APIs.
    static func bestPosterURL(for result: TMDBSearchResult) -> String? {
        if let fanart = result.fanartTVPosterURL, !fanart.isEmpty { return fanart }
        if let tvMaze = result.tvMazePosterURL, !tvMaze.isEmpty { return tvMaze }
        if let anime = result.animeArtworkURL,
           !anime.isEmpty,
           (anime.localizedCaseInsensitiveContains("taizen.moe")
                || anime.localizedCaseInsensitiveContains("fanart.tv")) {
            return anime
        }
        if let path = result.posterPath,
           path.hasPrefix("/"),
           !path.hasPrefix("//"),
           !path.contains(".."),
           let url = URL(string: "https://image.tmdb.org/t/p/original\(path)") {
            return url.absoluteString
        }
        if let anime = result.animeArtworkURL, !anime.isEmpty { return anime }
        return result.fullPosterURL
    }
}

struct CenteredPosterTitleOverlay: View {
    let title: String
    let logoURL: String?
    var fontSize: CGFloat = 16

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.58), location: 0.5),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if let logoURL, !logoURL.isEmpty {
                ResilientArtworkImage(
                    urls: [logoURL],
                    decodeSize: CGSize(width: 900, height: 260),
                    contentMode: .fit
                ) {
                    titleText
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
                urls: [
                    PosterArtworkURLResolver.bestPosterURL(for: result),
                    result.fullPosterURL,
                    result.animeArtworkURL
                ].compactMap { $0 },
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
