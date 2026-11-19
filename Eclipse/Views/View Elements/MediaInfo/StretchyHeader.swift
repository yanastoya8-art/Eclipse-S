//
//  StretchyHeader.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Kingfisher
#if canImport(UIKit)
import UIKit
#endif

private enum StretchyHeaderAmbientColorCache {
    static let values = NSCache<NSString, UIColor>()
}

struct ResilientArtworkImage<Placeholder: View>: View {
    let urls: [String]
    let decodeSize: CGSize
    let contentMode: SwiftUI.ContentMode
    private let placeholder: () -> Placeholder
    private let onImageLoaded: ((Color) -> Void)?
    @State private var failedURLs: Set<String> = []

    init(
        urls: [String],
        decodeSize: CGSize,
        contentMode: SwiftUI.ContentMode = .fill,
        onImageLoaded: ((Color) -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urls = urls
        self.decodeSize = decodeSize
        self.contentMode = contentMode
        self.onImageLoaded = onImageLoaded
        self.placeholder = placeholder
    }

    private var currentURL: String? {
        urls.first { value in
            guard !failedURLs.contains(value),
                  let url = URL(string: value),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else { return false }
            return true
        }
    }

    var body: some View {
        Group {
            if let imageURL = currentURL {
                KFImage(URL(string: imageURL))
                    .setProcessor(DownsamplingImageProcessor(size: decodeSize))
                    .placeholder { placeholder() }
#if canImport(UIKit)
                    .onSuccess { result in
                        guard currentURL == imageURL else { return }
                        onImageLoaded?(Color.ambientColor(from: result.image))
                    }
#endif
                    .onFailure { _ in
                        guard currentURL == imageURL else { return }
                        failedURLs.insert(imageURL)
                    }
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .onChangeComp(of: urls) { _, _ in failedURLs.removeAll() }
    }
}

struct StretchyHeaderView: View {
    let backdropURL: String?
    let isMovie: Bool
    let headerHeight: CGFloat
    let minHeaderHeight: CGFloat
    let onAmbientColorExtracted: ((Color) -> Void)?
    var imageDecodeSize: CGSize? = nil
    var placeholderColor: Color = Color.gray.opacity(0.3)
    var fallbackImageURLs: [String] = []
    var preservesArtworkComposition: Bool = false
    var artworkScaleX: CGFloat = 1.0
    var artworkScaleY: CGFloat = 1.0
    // Landscape detail uses the extended hero-bleed compositor outside this
    // view. Suppress this local 100pt fade there to avoid a stacked gradient
    // that can read as a hard seam at the poster/content boundary.
    var showsBottomFade: Bool = true
    var bottomFadeHeight: CGFloat = 100
    var bottomFadeEndOpacity: Double = 0.6
    // Detail pages measure stretching relative to their ScrollView so the
    // safe-area origin and initial rotation layout do not shift the artwork.
    var scrollCoordinateSpaceName: String? = nil

    @State private var localAmbientColor: Color = Color.black
    @State private var failedImageURLs: Set<String> = []

    private var imageCandidates: [String] {
        var seen: Set<String> = []
        return ([backdropURL].compactMap { $0 } + fallbackImageURLs).filter { value in
            guard let url = URL(string: value),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else { return false }
            return seen.insert(value).inserted
        }
    }

    private var resolvedBackdropURL: String? {
        imageCandidates.first { !failedImageURLs.contains($0) }
    }

    private var resolvedImageDecodeSize: CGSize {
        imageDecodeSize ?? CGSize(
            width: max(EclipseViewport.bounds.width * EclipseViewport.scale, 1),
            height: max(headerHeight * EclipseViewport.scale, 1)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let frame = scrollCoordinateSpaceName.map {
                geometry.frame(in: .named($0))
            } ?? geometry.frame(in: .global)
            let deltaY = frame.minY
            let artworkWidth = max(geometry.size.width, EclipseViewport.bounds.width)
            let height = headerHeight + max(0, deltaY)
            // The detail ScrollView extends edge-to-edge, but SwiftUI can
            // still place its content origin inside the safe-area insets.
            // Pin the hero to the scroll viewport on both axes; the old
            // min(0, -deltaY) left a visible top strip whenever minY was positive.
            let offsetY = scrollCoordinateSpaceName == nil ? min(0, -deltaY) : -deltaY
            let offsetX = scrollCoordinateSpaceName == nil ? 0 : -frame.minX

            ZStack(alignment: .bottom) {
                // Fill the landscape side gutters with a restrained wash
                // of the poster's extracted colour. This is a colour field,
                // not a second/blurred copy of the artwork.
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: localAmbientColor.opacity(0.30), location: 0.0),
                                .init(color: localAmbientColor.opacity(0.58), location: 0.5),
                                .init(color: localAmbientColor.opacity(0.30), location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: artworkWidth, height: height)
                    .overlay {
                        if let imageURL = resolvedBackdropURL {
                            // Render the artwork exactly once. A previous version
                            // placed a blurred, enlarged copy behind the original
                            // poster, which made the detail hero look like Reader
                            // mode and obscured the intended colour-bleed treatment.
                            KFImage(URL(string: imageURL))
                                .setProcessor(DownsamplingImageProcessor(size: resolvedImageDecodeSize))
                                .placeholder { Rectangle().fill(placeholderColor) }
                                .onSuccess { result in
                                    guard resolvedBackdropURL == imageURL else { return }
                                    updateAmbientColor(from: result.image, url: imageURL)
                                }
                                .onFailure { _ in
                                    guard resolvedBackdropURL == imageURL else { return }
                                    failedImageURLs.insert(imageURL)
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: artworkWidth,
                                    height: height,
                                    alignment: .top
                                )
                                // Independent axes let landscape detail pages
                                // tune banner coverage without changing poster
                                // composition in portrait or other callers.
                                .scaleEffect(
                                    x: max(0.5, min(2.0, artworkScaleX)),
                                    y: max(0.5, min(2.0, artworkScaleY)),
                                    anchor: .center
                                )
                        } else {
                            Rectangle().fill(placeholderColor)
                        }
                    }
                    .clipped()
                    .frame(height: height)

                if showsBottomFade {
                    let endOpacity = min(max(bottomFadeEndOpacity, 0), 1)
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: localAmbientColor.opacity(0.0), location: 0.0),
                            .init(color: localAmbientColor.opacity(endOpacity / 6), location: 0.2),
                            .init(color: localAmbientColor.opacity(endOpacity * 0.5), location: 0.7),
                            .init(color: localAmbientColor.opacity(endOpacity), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: max(bottomFadeHeight, 0))
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                }
            }
            .offset(x: offsetX, y: offsetY)
        }
        .frame(height: headerHeight)
        .onChangeComp(of: imageCandidates) { _, _ in failedImageURLs.removeAll() }
    }

    private func updateAmbientColor(from image: UIImage, url: String) {
        let cacheKey = url as NSString?
        if let cacheKey,
           let cachedColor = StretchyHeaderAmbientColorCache.values.object(forKey: cacheKey) {
            applyAmbientColor(Color(cachedColor))
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let extractedColor = Color.ambientColor(from: image)
            if let cacheKey {
                StretchyHeaderAmbientColorCache.values.setObject(UIColor(extractedColor), forKey: cacheKey)
            }
            DispatchQueue.main.async {
                applyAmbientColor(extractedColor)
            }
        }
    }

    private func applyAmbientColor(_ color: Color) {
        localAmbientColor = color
        onAmbientColorExtracted?(color)
    }
}
