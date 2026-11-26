import SwiftUI
import UIKit
import Compression

/// Detailed, monochrome vector artwork traced from the approved Eclipse animation
/// concept sheet. The source illustrations are converted into tonal vector bands,
/// so every highlight and texture follows the user's selected animation tint.
enum HomeAnimatedShapeArtwork {
    private static let compressedAtlas = "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"

    private static let shapeIndexes: [String: Int] = [
        "dragon": 0, "bird": 1, "snake": 2, "fox": 3,
        "phoenix": 4, "wolf": 5, "cat": 6, "mermaid": 7,
        "paw": 8, "stars": 9, "crescentMoon": 10, "sun": 11
    ]

    private static let layerOpacity: [Double] = [0.24, 0.43, 0.67, 0.96]

    private static let decodedLayers: [[Path]] = {
        guard let compressed = Data(base64Encoded: compressedAtlas) else { return [] }
        var output = [UInt8](repeating: 0, count: 100_000)
        let decodedCount = compressed.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> Int in
            output.withUnsafeMutableBufferPointer { destination -> Int in
                guard let sourceBase = source.bindMemory(to: UInt8.self).baseAddress,
                      let destinationBase = destination.baseAddress else { return 0 }
                return compression_decode_buffer(
                    destinationBase,
                    destination.count,
                    sourceBase,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedCount > 0,
              let object = try? JSONSerialization.jsonObject(with: Data(output.prefix(decodedCount))),
              let rows = object as? [[String]] else { return [] }
        return rows.map { $0.map(makePath) }
    }()

    /// Draws a complete reference-derived motif while preserving the existing
    /// whole-shape drift, breathing, opacity, brightness and independent eye tint.
    @discardableResult
    static func draw(
        shape: HomeAnimatedBackgroundShape,
        in context: inout GraphicsContext,
        canvasSize: CGSize,
        color: Color,
        eyeColor: Color,
        opacity: Double,
        brightness: Double,
        phase: Double
    ) -> Bool {
        guard let index = shapeIndexes[shape.rawValue],
              decodedLayers.indices.contains(index) else { return false }

        let side = min(canvasSize.width, canvasSize.height) * 0.96
        let origin = CGPoint(
            x: (canvasSize.width - side) / 2,
            y: (canvasSize.height - side) / 2
        )
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let breathingScale = 1.0 + sin(phase * 1.15) * 0.012
        let globalAlpha = min(max(opacity * brightness, 0), 1)

        var artwork = context
        artwork.translateBy(x: center.x, y: center.y)
        artwork.rotate(by: .degrees(sin(phase * 0.55) * 1.4))
        artwork.scaleBy(x: breathingScale, y: breathingScale)
        artwork.translateBy(x: -center.x, y: -center.y)
        artwork.translateBy(x: origin.x, y: origin.y)
        artwork.scaleBy(x: side / 128, y: side / 128)

        for (layerIndex, path) in decodedLayers[index].enumerated() {
            guard layerIndex < layerOpacity.count else { continue }
            artwork.fill(
                path,
                with: .color(color.opacity(globalAlpha * layerOpacity[layerIndex])),
                style: FillStyle(eoFill: true)
            )
        }

        // Keep the existing per-creature eye-colour controls functional on the
        // new reference artwork: Toothless, Cobra and Hawk each retain a distinct eye.
        let eyeRect: CGRect?
        switch shape {
        case .dragon:
            eyeRect = CGRect(x: 88, y: 38, width: 7, height: 5)
        case .snake:
            eyeRect = CGRect(x: 84, y: 29, width: 5, height: 4)
        case .bird:
            eyeRect = CGRect(x: 85, y: 59, width: 5, height: 4)
        default:
            eyeRect = nil
        }
        if let eyeRect {
            var eye = Path()
            eye.addEllipse(in: eyeRect)
            artwork.fill(eye, with: .color(eyeColor.opacity(globalAlpha)))
            var pupil = Path()
            pupil.addEllipse(in: CGRect(
                x: eyeRect.midX - 1,
                y: eyeRect.minY + 0.8,
                width: 2,
                height: max(2, eyeRect.height - 1.4)
            ))
            artwork.fill(pupil, with: .color(Color.black.opacity(globalAlpha * 0.9)))
        }
        return true
    }

    private static func makePath(_ encoded: String) -> Path {
        var path = Path()
        for contour in encoded.split(separator: ";") {
            var firstPoint = true
            for coordinate in contour.split(separator: "|") {
                let pair = coordinate.split(separator: ",")
                guard pair.count == 2,
                      let x = Double(pair[0]),
                      let y = Double(pair[1]) else { continue }
                let point = CGPoint(x: x, y: y)
                if firstPoint {
                    path.move(to: point)
                    firstPoint = false
                } else {
                    path.addLine(to: point)
                }
            }
            if !firstPoint { path.closeSubpath() }
        }
        return path
    }
}
