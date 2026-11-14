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
            let frame = geometry.frame(in: .global)
            let deltaY = frame.minY
            let height = headerHeight + max(0, deltaY)
            let offset = min(0, -deltaY)

            ZStack(alignment: .bottom) {
                Color.clear
                    .overlay {
                        if let imageURL = resolvedBackdropURL {
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
                        } else {
                            Rectangle().fill(placeholderColor)
                        }
                    }
                    .clipped()
                    .frame(height: height)
                    .offset(y: offset)

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: localAmbientColor.opacity(0.0), location: 0.0),
                        .init(color: localAmbientColor.opacity(0.1), location: 0.2),
                        .init(color: localAmbientColor.opacity(0.3), location: 0.7),
                        .init(color: localAmbientColor.opacity(0.6), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 0))
            }
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
