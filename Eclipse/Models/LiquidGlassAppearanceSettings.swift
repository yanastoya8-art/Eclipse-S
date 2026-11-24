import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Shared, profile-persisted colors for the Liquid Glass controls and their containing bars.
@MainActor
final class LiquidGlassAppearanceSettings: ObservableObject {
    static let shared = LiquidGlassAppearanceSettings()

    static let darkBarColorKey = "liquidGlassDarkBarColor"
    static let lightBarColorKey = "liquidGlassLightBarColor"
    static let bottomBarColorKey = "liquidGlassBottomBarColor"

    @Published var darkBarColor: Color {
        didSet { Self.persist(darkBarColor, key: Self.darkBarColorKey) }
    }

    @Published var lightBarColor: Color {
        didSet { Self.persist(lightBarColor, key: Self.lightBarColorKey) }
    }

    @Published var bottomBarColor: Color {
        didSet { Self.persist(bottomBarColor, key: Self.bottomBarColorKey) }
    }

    var bottomBarTint: Color { bottomBarColor.opacity(0.42) }

    func searchFieldColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? lightBarColor : darkBarColor
    }

    private init() {
        darkBarColor = Self.restore(key: Self.darkBarColorKey, fallback: Color(red: 0.10, green: 0.10, blue: 0.15))
        lightBarColor = Self.restore(key: Self.lightBarColorKey, fallback: Color(red: 0.42, green: 0.42, blue: 0.48))
        bottomBarColor = Self.restore(key: Self.bottomBarColorKey, fallback: Color(red: 0.08, green: 0.08, blue: 0.13))
    }

    private static func restore(key: String, fallback: Color) -> Color {
        guard let value = ProfileSettingsStore.active.string(forKey: key),
              let color = color(fromHex: value) else { return fallback }
        return color
    }

    private static func persist(_ color: Color, key: String) {
        guard let value = hex(from: color) else { return }
        ProfileSettingsStore.active.set(value, forKey: key)
    }

    private static func color(fromHex value: String) -> Color? {
        let hex = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let number = UInt64(hex, radix: 16) else { return nil }
        return Color(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }

    private static func hex(from color: Color) -> String? {
#if os(macOS)
        guard let native = NSColor(color).usingColorSpace(.deviceRGB) else { return nil }
        let red = native.redComponent
        let green = native.greenComponent
        let blue = native.blueComponent
#else
        let native = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard native.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return nil }
#endif
        return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}
