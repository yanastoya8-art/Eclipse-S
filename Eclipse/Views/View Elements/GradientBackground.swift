import SwiftUI
import Compression
#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum ExperimentalMediaDesignPreset: String, CaseIterable, Identifiable {
    static let storageKey = "experimentalMediaDesignPreset"

    case cinematic
    case balanced
    case compact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cinematic: return "Cinematic"
        case .balanced: return "Balanced"
        case .compact: return "Compact"
        }
    }

    static var defaultValue: ExperimentalMediaDesignPreset { .cinematic }

    static var current: ExperimentalMediaDesignPreset {
        let rawValue = ProfileSettingsStore.active.string(forKey: storageKey)
        return ExperimentalMediaDesignPreset(rawValue: rawValue ?? "") ?? defaultValue
    }
}

enum ExperimentalHeroBleedLevel: String, CaseIterable, Identifiable {
    static let storageKey = "experimentalHeroBleedLevel"

    case soft
    case standard
    case strong

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soft: return "Soft"
        case .standard: return "Standard"
        case .strong: return "Strong"
        }
    }

    var strengthMultiplier: Double {
        switch self {
        case .soft: return 0.72
        case .standard: return 1.0
        case .strong: return 1.24
        }
    }

    static var defaultValue: ExperimentalHeroBleedLevel { .standard }

    static var current: ExperimentalHeroBleedLevel {
        let rawValue = ProfileSettingsStore.active.string(forKey: storageKey)
        return ExperimentalHeroBleedLevel(rawValue: rawValue ?? "") ?? defaultValue
    }
}

enum ExperimentalHomeCardShape: String, CaseIterable, Identifiable {
    static let storageKey = "experimentalHomeCardShape"

    case automatic
    case landscape
    case poster

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .landscape: return "Landscape"
        case .poster: return "Poster"
        }
    }

    static var defaultValue: ExperimentalHomeCardShape { .automatic }

    static var current: ExperimentalHomeCardShape {
        let rawValue = ProfileSettingsStore.active.string(forKey: storageKey)
        return ExperimentalHomeCardShape(rawValue: rawValue ?? "") ?? defaultValue
    }
}

enum ExperimentalMultiGradientPalette: String, CaseIterable, Identifiable {
    static let storageKey = "experimentalMultiGradientPalette"

    case eclipse
    case nocturne
    case velvet
    case auroraMuted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eclipse: return "Eclipse"
        case .nocturne: return "Nocturne"
        case .velvet: return "Velvet"
        case .auroraMuted: return "Muted Aurora"
        }
    }

    static var defaultValue: ExperimentalMultiGradientPalette { .eclipse }

    static var current: ExperimentalMultiGradientPalette {
        let rawValue = ProfileSettingsStore.active.string(forKey: storageKey)
        return ExperimentalMultiGradientPalette(rawValue: rawValue ?? "") ?? defaultValue
    }
}

struct ExperimentalVisualTuning {
    static let heroHeightScaleKey = "experimentalHeroHeightScale"
    static let heroBleedStrengthKey = "experimentalHeroBleedStrength"
    static let heroFadeDistanceScaleKey = "experimentalHeroFadeDistanceScale"
    static let sectionSpacingScaleKey = "experimentalSectionSpacingScale"
    static let cardRadiusScaleKey = "experimentalCardRadiusScale"
    static let mediaCardScaleKey = "experimentalMediaCardScale"
    static let glassStrengthKey = "experimentalGlassStrength"
    static let gradientBaseDarknessKey = "experimentalGradientBaseDarkness"
    static let gradientAccentIntensityKey = "experimentalGradientAccentIntensity"
    static let gradientScrollMotionKey = "experimentalGradientScrollMotion"
    static let gradientUseCustomColorsKey = "experimentalGradientUseCustomColors"
    static let gradientColorAKey = "experimentalGradientColorA"
    static let gradientColorBKey = "experimentalGradientColorB"
    static let gradientColorCKey = "experimentalGradientColorC"

    static let defaultHeroHeightScale = 1.0
    static let defaultHeroBleedStrength = 1.0
    static let defaultHeroFadeDistanceScale = 1.0
    static let defaultSectionSpacingScale = 1.0
    static let defaultCardRadiusScale = 1.0
    static let defaultMediaCardScale = 1.0
    static let defaultGlassStrength = 1.0
    static let defaultGradientBaseDarkness = 1.0
    static let defaultGradientAccentIntensity = 1.0
    static let defaultGradientScrollMotion = 1.0

    var heroHeightScale: Double
    var heroBleedStrength: Double
    var heroFadeDistanceScale: Double
    var sectionSpacingScale: Double
    var cardRadiusScale: Double
    var mediaCardScale: Double
    var glassStrength: Double
    var gradientBaseDarkness: Double
    var gradientAccentIntensity: Double
    var gradientScrollMotion: Double
    var gradientUseCustomColors: Bool
    var gradientColorA: Color?
    var gradientColorB: Color?
    var gradientColorC: Color?

    static var current: ExperimentalVisualTuning {
        let defaults = ProfileSettingsStore.active
#if os(tvOS)
        let mediaCardScale: Double
        switch defaults.string(forKey: "tvCardDensity") ?? "standard" {
        case "spacious": mediaCardScale = 1.12
        case "compact": mediaCardScale = 0.86
        default: mediaCardScale = 1.0
        }
#else
        let mediaCardScale = sanitizedMediaCardScale(
            defaults.doubleValue(forKey: mediaCardScaleKey, defaultValue: defaultMediaCardScale)
        )
#endif
        return ExperimentalVisualTuning(
            heroHeightScale: sanitizedHeroHeightScale(defaults.doubleValue(forKey: heroHeightScaleKey, defaultValue: defaultHeroHeightScale)),
            heroBleedStrength: sanitizedHeroBleedStrength(defaults.doubleValue(forKey: heroBleedStrengthKey, defaultValue: defaultHeroBleedStrength)),
            heroFadeDistanceScale: sanitizedHeroFadeDistanceScale(defaults.doubleValue(forKey: heroFadeDistanceScaleKey, defaultValue: defaultHeroFadeDistanceScale)),
            sectionSpacingScale: sanitizedSectionSpacingScale(defaults.doubleValue(forKey: sectionSpacingScaleKey, defaultValue: defaultSectionSpacingScale)),
            cardRadiusScale: sanitizedCardRadiusScale(defaults.doubleValue(forKey: cardRadiusScaleKey, defaultValue: defaultCardRadiusScale)),
            mediaCardScale: mediaCardScale,
            glassStrength: sanitizedGlassStrength(defaults.doubleValue(forKey: glassStrengthKey, defaultValue: defaultGlassStrength)),
            gradientBaseDarkness: sanitizedGradientBaseDarkness(defaults.doubleValue(forKey: gradientBaseDarknessKey, defaultValue: defaultGradientBaseDarkness)),
            gradientAccentIntensity: sanitizedGradientAccentIntensity(defaults.doubleValue(forKey: gradientAccentIntensityKey, defaultValue: defaultGradientAccentIntensity)),
            gradientScrollMotion: sanitizedGradientScrollMotion(defaults.doubleValue(forKey: gradientScrollMotionKey, defaultValue: defaultGradientScrollMotion)),
            gradientUseCustomColors: defaults.bool(forKey: gradientUseCustomColorsKey),
            gradientColorA: loadColor(key: gradientColorAKey),
            gradientColorB: loadColor(key: gradientColorBKey),
            gradientColorC: loadColor(key: gradientColorCKey)
        )
    }

    static func sanitizedHeroHeightScale(_ value: Double?) -> Double { clamp(value, defaultValue: defaultHeroHeightScale, range: 0.75...1.15) }
    static func sanitizedHeroBleedStrength(_ value: Double?) -> Double { clamp(value, defaultValue: defaultHeroBleedStrength, range: 0.0...1.5) }
    static func sanitizedHeroFadeDistanceScale(_ value: Double?) -> Double { clamp(value, defaultValue: defaultHeroFadeDistanceScale, range: 0.6...1.6) }
    static func sanitizedSectionSpacingScale(_ value: Double?) -> Double { clamp(value, defaultValue: defaultSectionSpacingScale, range: 0.75...1.35) }
    static func sanitizedCardRadiusScale(_ value: Double?) -> Double { clamp(value, defaultValue: defaultCardRadiusScale, range: 0.7...1.4) }
    static let mediaCardScaleRange: ClosedRange<Double> = 0.75...1.35
    static func sanitizedMediaCardScale(_ value: Double?) -> Double { clamp(value, defaultValue: defaultMediaCardScale, range: mediaCardScaleRange) }
    static func sanitizedGlassStrength(_ value: Double?) -> Double { clamp(value, defaultValue: defaultGlassStrength, range: 0.0...1.4) }
    static func sanitizedGradientBaseDarkness(_ value: Double?) -> Double { clamp(value, defaultValue: defaultGradientBaseDarkness, range: 0.7...1.3) }
    static func sanitizedGradientAccentIntensity(_ value: Double?) -> Double { clamp(value, defaultValue: defaultGradientAccentIntensity, range: 0.0...1.6) }
    static func sanitizedGradientScrollMotion(_ value: Double?) -> Double { clamp(value, defaultValue: defaultGradientScrollMotion, range: 0.0...1.4) }

    private static func clamp(_ value: Double?, defaultValue: Double, range: ClosedRange<Double>) -> Double {
        guard let value, value.isFinite else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    static func saveColor(_ color: Color, key: String) {
        do {
            let data = try PortableColorArchive.data(for: UIColor(color), requiringSecureCoding: true)
            ProfileSettingsStore.active.set(data, forKey: key)
        } catch { }
    }

    static func loadColor(key: String) -> Color? {
        guard let data = ProfileSettingsStore.active.data(forKey: key),
              let color = loadColor(data: data) else {
            return nil
        }
        return color
    }

    static func loadColor(data: Data) -> Color? {
        guard !data.isEmpty,
              let uiColor = try? PortableColorArchive.color(from: data) else {
            return nil
        }
        return Color(uiColor)
    }

    static func colorData(_ color: Color) -> Data? {
        try? PortableColorArchive.data(for: UIColor(color), requiringSecureCoding: true)
    }
}

private extension UserDefaults {
    func doubleValue(forKey key: String, defaultValue: Double) -> Double {
        object(forKey: key) == nil ? defaultValue : double(forKey: key)
    }
}

struct ExperimentalMediaDesignMetrics {
    let preset: ExperimentalMediaDesignPreset
    let heroBleedLevel: ExperimentalHeroBleedLevel
    let cardShape: ExperimentalHomeCardShape
    let tuning: ExperimentalVisualTuning

    init(
        preset: ExperimentalMediaDesignPreset,
        heroBleedLevel: ExperimentalHeroBleedLevel,
        cardShape: ExperimentalHomeCardShape,
        tuning: ExperimentalVisualTuning = .current
    ) {
        self.preset = preset
        self.heroBleedLevel = heroBleedLevel
        self.cardShape = cardShape
        self.tuning = tuning
    }

    var homeHeroHeightRatio: CGFloat {
        switch preset {
        case .cinematic: return 0.86
        case .balanced: return 0.78
        case .compact: return 0.68
        }
    }

    var detailHeroHeightRatio: CGFloat {
        switch preset {
        case .cinematic: return 0.90
        case .balanced: return 0.80
        case .compact: return 0.70
        }
    }

    var heroBleedDistance: CGFloat {
        let base: CGFloat
        switch preset {
        case .cinematic: base = 560
        case .balanced: base = 440
        case .compact: base = 320
        }
        return base * CGFloat(tuning.heroFadeDistanceScale)
    }

    var heroWashStrength: Double {
        let base: Double
        switch preset {
        case .cinematic: base = 0.94
        case .balanced: base = 0.76
        case .compact: base = 0.58
        }
        return base * heroBleedLevel.strengthMultiplier * tuning.heroBleedStrength
    }

    var contentTopOverlap: CGFloat {
        switch preset {
        case .cinematic: return 34
        case .balanced: return 22
        case .compact: return 10
        }
    }

    var sectionSpacing: CGFloat {
        let base: CGFloat
        switch preset {
        case .cinematic: base = 30
        case .balanced: base = 24
        case .compact: base = 18
        }
        return base * CGFloat(tuning.sectionSpacingScale)
    }

    var tvSectionSpacing: CGFloat { sectionSpacing * 4 / 3 }

    var cardRadius: CGFloat {
        let base: CGFloat
        switch preset {
        case .cinematic: base = 20
        case .balanced: base = 18
        case .compact: base = 16
        }
        return base * CGFloat(tuning.cardRadiusScale)
    }

    var glassOpacity: Double {
        let base: Double
        switch preset {
        case .cinematic: base = 0.72
        case .balanced: base = 0.64
        case .compact: base = 0.56
        }
        return min(max(base * tuning.glassStrength, 0), 0.95)
    }

    var heroBottomFadeHeight: CGFloat {
        let base: CGFloat
        switch preset {
        case .cinematic: base = 520
        case .balanced: base = 420
        case .compact: base = 320
        }
        return base * CGFloat(tuning.heroFadeDistanceScale)
    }

    var scrollOffsetThreshold: CGFloat {
        switch preset {
        case .cinematic: return 18
        case .balanced: return 20
        case .compact: return 24
        }
    }

    func homeHeroHeight(screenHeight: CGFloat, isIPad: Bool) -> CGFloat {
        if isIPad {
            let base: CGFloat
            switch preset {
            case .cinematic: base = 780
            case .balanced: base = 720
            case .compact: base = 640
            }
            return base * CGFloat(tuning.heroHeightScale)
        }
        let minimum: CGFloat = preset == .compact ? 560 : 640
        let maximum: CGFloat = preset == .cinematic ? 820 : 760
        return min(max(screenHeight * homeHeroHeightRatio * CGFloat(tuning.heroHeightScale), minimum), maximum)
    }

    func detailHeroHeight(screenHeight: CGFloat, isIPad: Bool) -> CGFloat {
        if isIPad {
            let base: CGFloat
            switch preset {
            case .cinematic: base = 760
            case .balanced: base = 700
            case .compact: base = 620
            }
            return base * CGFloat(tuning.heroHeightScale)
        }
        let minimum: CGFloat = preset == .compact ? 560 : 650
        let maximum: CGFloat = preset == .cinematic ? 850 : 780
        return min(max(screenHeight * detailHeroHeightRatio * CGFloat(tuning.heroHeightScale), minimum), maximum)
    }

    func landscapeCardSize(isIPad: Bool) -> CGSize {
        if isIPad {
            switch preset {
            case .cinematic: return scaled(CGSize(width: 330, height: 186))
            case .balanced: return scaled(CGSize(width: 300, height: 169))
            case .compact: return scaled(CGSize(width: 270, height: 152))
            }
        }
        switch preset {
        case .cinematic: return scaled(CGSize(width: 196, height: 110))
        case .balanced: return scaled(CGSize(width: 184, height: 104))
        case .compact: return scaled(CGSize(width: 168, height: 95))
        }
    }

    func posterCardSize(isIPad: Bool) -> CGSize {
        if isIPad {
            switch preset {
            case .cinematic: return scaled(CGSize(width: 156, height: 234))
            case .balanced: return scaled(CGSize(width: 142, height: 213))
            case .compact: return scaled(CGSize(width: 128, height: 192))
            }
        }
        switch preset {
        case .cinematic: return scaled(CGSize(width: 116, height: 174))
        case .balanced: return scaled(CGSize(width: 108, height: 162))
        case .compact: return scaled(CGSize(width: 100, height: 150))
        }
    }

    var mediaCardScale: CGFloat { CGFloat(tuning.mediaCardScale) }

    private func scaled(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width * CGFloat(tuning.mediaCardScale),
            height: size.height * CGFloat(tuning.mediaCardScale)
        )
    }

    static var current: ExperimentalMediaDesignMetrics {
        ExperimentalMediaDesignMetrics(
            preset: ExperimentalMediaDesignPreset.current,
            heroBleedLevel: ExperimentalHeroBleedLevel.current,
            cardShape: ExperimentalHomeCardShape.current,
            tuning: .current
        )
    }
}

struct SettingsGradientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var theme = EclipseTheme.shared
    @AppStorage(HomeAnimatedBackgroundSettings.enabledKey) private var animatedBackgroundEnabled = HomeAnimatedBackgroundSettings.defaultEnabled
    var allowsAnimatedBackground: Bool = true
    var allowsAnimatedShape: Bool = true

    @ViewBuilder
    var body: some View {
        baseBackground
            .overlay {
                if allowsAnimatedBackground
                    && animatedBackgroundEnabled
                    && theme.scopedAtmosphereStyle() != .aurora
                    && theme.scopedAtmosphereStyle() != .ember {
                    EclipseIsolatedAmbientMotionBackground(
                        topClearance: 0,
                        ambientColor: nil,
                        accentColor: theme.scopedGradientColor(),
                        motionEnabled: !reduceMotion && scenePhase == .active,
                        allowsAnimatedShape: allowsAnimatedShape
                    )
                }
            }
    }

    @ViewBuilder
    private var baseBackground: some View {
        AtmosphereBackdrop(
            input: theme.atmosphereInput(dominant: nil, hasHeroBleed: false, heroHeight: 0, fadeDistance: 1),
            scrollOffset: 0
        )
    }

    private var legacyBackground: some View {
        GeometryReader { geo in
            let h = geo.size.height * 2.5
            let gradientColor = theme.scopedGradientColor()
            if theme.scopedAtmosphereStyle() == .solid {
                theme.scopedAtmosphereColor(dominant: gradientColor)
                    .frame(height: h)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: theme.backgroundBase, location: 0.0),
                        .init(color: gradientColor.opacity(0.6), location: 0.15),
                        .init(color: gradientColor.opacity(0.3), location: 0.35),
                        .init(color: theme.backgroundBase, location: 0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: h)
            }
        }
        .clipped()
    }
}

struct EclipseScrollTracker: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ScrollOffsetPreferenceKey.self,
                value: -geo.frame(in: .named("eclipseGradientScroll")).origin.y
            )
        }
        .frame(height: 0)
    }
}

enum HomeAnimatedBackgroundParticleColor: String, CaseIterable, Identifiable {
    case accent
    case purple
    case blue
    case teal
    case pink
    case gold
    case white
    case custom

    static let storageKey = "homeAnimatedBackgroundParticleColor"
    static let customColorDataKey = "homeAnimatedBackgroundCustomParticleColorData"
    static let defaultValue: HomeAnimatedBackgroundParticleColor = .accent

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .accent: return "Accent Color"
        case .purple: return "Purple"
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .pink: return "Pink"
        case .gold: return "Gold"
        case .white: return "White"
        case .custom: return "Custom"
        }
    }

    func color(accent: Color, custom: Color = .purple) -> Color {
        switch self {
        case .accent: return accent
        case .purple: return Color(red: 0.66, green: 0.42, blue: 1.0)
        case .blue: return Color(red: 0.30, green: 0.62, blue: 1.0)
        case .teal: return Color(red: 0.20, green: 0.86, blue: 0.78)
        case .pink: return Color(red: 1.0, green: 0.38, blue: 0.70)
        case .gold: return Color(red: 1.0, green: 0.72, blue: 0.28)
        case .white: return .white
        case .custom: return custom
        }
    }

    static func resolved(_ rawValue: String?) -> HomeAnimatedBackgroundParticleColor {
        guard let rawValue, let value = Self(rawValue: rawValue) else { return defaultValue }
        return value
    }
}

enum HomeAnimatedBackgroundShape: String, CaseIterable, Identifiable {
    case wolf, fox, phoenix, paw, stars, crescentMoon, sun, spiral, cat, mermaid, bird, snake, dragon

    static let storageKey = "homeAnimatedBackgroundShape"
    static let defaultValue: HomeAnimatedBackgroundShape = .stars

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .wolf: return "Wolf"
        case .fox: return "Nine-Tailed Fox"
        case .phoenix: return "Phoenix"
        case .paw: return "Paw"
        case .stars: return "Star"
        case .crescentMoon: return "Moon"
        case .sun: return "Spiral Sun"
        case .spiral: return "Golden Spiral"
        case .cat: return "Cat"
        case .mermaid: return "Mermaid"
        case .bird: return "Hawk"
        case .snake: return "Cobra"
        case .dragon: return "Toothless"
        }
    }

    var glyph: String {
        switch self {
        case .wolf: return "\u{1F43A}\u{FE0E}"
        case .fox: return "\u{1F98A}\u{FE0E}"
        case .phoenix: return "\u{1F525}\u{FE0E}"
        case .paw: return "\u{1F43E}\u{FE0E}"
        case .stars: return "✦"
        case .crescentMoon: return "☾"
        case .sun: return "☀"
        case .spiral: return "✺"
        // Text-presentation glyphs honour foregroundColor, unlike multicolour emoji.
        case .cat: return "\u{1F408}\u{FE0E}"       // seated cat
        case .mermaid: return "\u{1F9DC}\u{FE0E}"
        case .bird: return "\u{1F985}\u{FE0E}"      // hawk/eagle
        case .snake: return "\u{1F40D}\u{FE0E}"     // cobra-like snake
        case .dragon: return "\u{1F409}\u{FE0E}"    // full dragon glyph
        }
    }

    static func resolved(_ rawValue: String?) -> HomeAnimatedBackgroundShape {
        guard let rawValue, let shape = Self(rawValue: rawValue) else { return defaultValue }
        return shape
    }
}

enum HomeAnimatedBackgroundSettings {
    static let enabledKey = "homeAnimatedBackgroundEnabled"
    static let shapeEnabledKey = "homeAnimatedBackgroundShapeEnabled"
    static let shapeOpacityKey = "homeAnimatedBackgroundShapeOpacity"
    static let shapeSizeKey = "homeAnimatedBackgroundShapeSize"
    static let shapeGlowKey = "homeAnimatedBackgroundShapeGlow"
    static let shapeBrightnessKey = "homeAnimatedBackgroundShapeBrightness"
    static let detailBackgroundKey = "detailAnimatedBackgroundEnabled"
    static let detailShapeKey = "detailAnimatedShapeEnabled"
    static let downloadsBackgroundKey = "downloadsAnimatedBackgroundEnabled"
    static let downloadsShapeKey = "downloadsAnimatedShapeEnabled"
    static let defaultEnabled = true
    static let defaultShapeEnabled = true
    static let defaultShapeOpacity = 0.82
    static let defaultShapeSize = 1.0
    static let defaultShapeGlow = 0.72
    static let defaultShapeBrightness = 1.2

    static func isEnabled(defaults: UserDefaults = ProfileSettingsStore.active) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? defaultEnabled : defaults.bool(forKey: enabledKey)
    }
}

enum HomeAnimatedBackgroundQuality: String, CaseIterable, Identifiable {
    static let storageKey = "homeAnimatedBackgroundQuality"

    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var layerOpacity: Double {
        switch self {
        case .low: return 0.96
        case .medium: return 1.0
        case .high: return 1.0
        }
    }

    static var defaultValue: HomeAnimatedBackgroundQuality { .low }

    static func resolved(_ rawValue: String?) -> HomeAnimatedBackgroundQuality {
        guard let rawValue,
              let quality = HomeAnimatedBackgroundQuality(rawValue: rawValue) else {
            return defaultValue
        }
        return quality
    }

    static func current(defaults: UserDefaults = ProfileSettingsStore.active) -> HomeAnimatedBackgroundQuality {
        resolved(defaults.string(forKey: storageKey))
    }
}

enum HomeAnimatedBackgroundFrameRate: String, CaseIterable, Identifiable {
    static let storageKey = "homeAnimatedBackgroundFrameRate"

    case fps20
    case fps30
    case fps60
    case fps120

    var id: String { rawValue }
    var framesPerSecond: Int {
        switch self {
        case .fps20: return 20
        case .fps30: return 30
        case .fps60: return 60
        case .fps120: return 120
        }
    }
    var displayName: String { "\(framesPerSecond) FPS" }
    var frameInterval: Double { 1.0 / Double(framesPerSecond) }

    static var defaultValue: HomeAnimatedBackgroundFrameRate { .fps20 }

    static func resolved(_ rawValue: String?) -> HomeAnimatedBackgroundFrameRate {

        if rawValue == "fps15" { return .fps20 }
        guard let rawValue, let value = HomeAnimatedBackgroundFrameRate(rawValue: rawValue) else {
            return defaultValue
        }
        return value
    }
}

enum ModeSwitchAnimationSettings {
    static let enabledKey = "modeSwitchAnimationEnabled"
    static let defaultEnabled = true

    static func isEnabled(defaults: UserDefaults = ProfileSettingsStore.active) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? defaultEnabled : defaults.bool(forKey: enabledKey)
    }
}

struct EclipseIsolatedAmbientMotionBackground: View {
    let topClearance: CGFloat
    let ambientColor: Color?
    let accentColor: Color
    let motionEnabled: Bool
    var allowsAnimatedShape: Bool = true

    var body: some View {
#if os(iOS)
        EclipseAmbientMotionHostingBoundary(
            topClearance: topClearance,
            ambientColor: ambientColor,
            accentColor: accentColor,
            motionEnabled: motionEnabled,
            allowsAnimatedShape: allowsAnimatedShape
        )
#else
        EclipseAmbientMotionBackground(
            topClearance: topClearance,
            ambientColor: ambientColor,
            accentColor: accentColor,
            motionEnabled: motionEnabled,
            allowsAnimatedShape: allowsAnimatedShape
        )
#endif
    }
}

#if os(iOS)
private struct EclipseAmbientMotionHostedRoot: View {
    let topClearance: CGFloat
    let ambientColor: Color?
    let accentColor: Color
    let motionEnabled: Bool
    var allowsAnimatedShape: Bool = true

    var body: some View {
        EclipseAmbientMotionBackground(
            topClearance: topClearance,
            ambientColor: ambientColor,
            accentColor: accentColor,
            motionEnabled: motionEnabled,
            allowsAnimatedShape: allowsAnimatedShape
        )
        .ignoresSafeArea(.all)
    }
}

private struct EclipseAmbientConfig: Equatable {
    let topClearance: CGFloat
    let ambientColor: Color?
    let accentColor: Color
    let motionEnabled: Bool
    let allowsAnimatedShape: Bool
}

private struct EclipseAmbientMotionHostingBoundary: UIViewControllerRepresentable {
    let topClearance: CGFloat
    let ambientColor: Color?
    let accentColor: Color
    let motionEnabled: Bool
    let allowsAnimatedShape: Bool

    private var hostedRoot: EclipseAmbientMotionHostedRoot {
        EclipseAmbientMotionHostedRoot(
            topClearance: topClearance,
            ambientColor: ambientColor,
            accentColor: accentColor,
            motionEnabled: motionEnabled,
            allowsAnimatedShape: allowsAnimatedShape
        )
    }

    private var currentConfig: EclipseAmbientConfig {
        EclipseAmbientConfig(
            topClearance: topClearance,
            ambientColor: ambientColor,
            accentColor: accentColor,
            motionEnabled: motionEnabled,
            allowsAnimatedShape: allowsAnimatedShape
        )
    }

    final class Coordinator {
        var last: EclipseAmbientConfig?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(
        context: Context
    ) -> UIHostingController<ProfileScopedAppStorage<EclipseAmbientMotionHostedRoot>> {
        let controller = UIHostingController(rootView: hostedRoot.profileScopedAppStorage())
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        controller.view.isUserInteractionEnabled = false
        context.coordinator.last = currentConfig
        return controller
    }

    func updateUIViewController(
        _ controller: UIHostingController<ProfileScopedAppStorage<EclipseAmbientMotionHostedRoot>>,
        context: Context
    ) {
        let config = currentConfig
        guard config != context.coordinator.last else { return }
        context.coordinator.last = config
        controller.rootView = hostedRoot.profileScopedAppStorage()
    }
}
#endif


/// Reference-derived animated artwork. Approved concept illustrations are
/// converted to layered vector paths so their fine detail, tonal depth and anatomy
/// remain crisp while following the selected animation tint.
private struct HomeAnimatedCreatureMotif: View {
    let shape: HomeAnimatedBackgroundShape
    let color: Color
    let eyeColor: Color
    let opacity: Double
    let brightness: Double
    let size: CGSize
    let phase: Double

    var body: some View {
        Canvas { context, canvasSize in
            var drawing = context
            draw(in: &drawing, canvasSize: canvasSize)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    /// Draw the creature directly into an existing Canvas context. This keeps
    /// the artwork reusable for both its normal pass and the blurred glow pass.
    func draw(in context: inout GraphicsContext, canvasSize: CGSize) {
        if HomeAnimatedShapeArtwork.draw(
            shape: shape,
            in: &context,
            canvasSize: canvasSize,
            color: color,
            eyeColor: eyeColor,
            opacity: opacity,
            brightness: brightness,
            phase: phase
        ) {
            return
        }

        let sx = canvasSize.width / 400
        let sy = canvasSize.height / 300
        var drawing = context
        drawing.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
        drawing.rotate(by: .degrees(sin(phase * 0.55) * 1.4))
        drawing.translateBy(x: -canvasSize.width / 2, y: -canvasSize.height / 2)
        let breathingScale = 1.0 + sin(phase * 1.15) * 0.012
        drawing.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
        drawing.scaleBy(x: breathingScale, y: breathingScale)
        drawing.translateBy(x: -canvasSize.width / 2, y: -canvasSize.height / 2)
        drawing.scaleBy(x: sx, y: sy)
        let fill = Path { path in
            switch shape {
            case .cat:
                // Seated cat: upright ears, chest, folded haunches and curled tail.
                path.move(to: CGPoint(x: 132, y: 252))
                path.addCurve(to: CGPoint(x: 104, y: 218), control1: CGPoint(x: 104, y: 250), control2: CGPoint(x: 96, y: 234))
                path.addCurve(to: CGPoint(x: 126, y: 184), control1: CGPoint(x: 105, y: 196), control2: CGPoint(x: 110, y: 184))
                path.addLine(to: CGPoint(x: 119, y: 105))
                path.addLine(to: CGPoint(x: 157, y: 130))
                path.addCurve(to: CGPoint(x: 239, y: 130), control1: CGPoint(x: 184, y: 111), control2: CGPoint(x: 213, y: 111))
                path.addLine(to: CGPoint(x: 277, y: 103))
                path.addLine(to: CGPoint(x: 269, y: 184))
                path.addCurve(to: CGPoint(x: 286, y: 229), control1: CGPoint(x: 286, y: 194), control2: CGPoint(x: 294, y: 211))
                path.addCurve(to: CGPoint(x: 241, y: 260), control1: CGPoint(x: 280, y: 258), control2: CGPoint(x: 258, y: 264))
                path.addLine(to: CGPoint(x: 155, y: 260))
                path.closeSubpath()
                path.move(to: CGPoint(x: 106, y: 222))
                path.addCurve(to: CGPoint(x: 65, y: 171), control1: CGPoint(x: 78, y: 227), control2: CGPoint(x: 56, y: 206))
                path.addCurve(to: CGPoint(x: 92, y: 136), control1: CGPoint(x: 69, y: 145), control2: CGPoint(x: 83, y: 134))
                path.addCurve(to: CGPoint(x: 105, y: 159), control1: CGPoint(x: 99, y: 139), control2: CGPoint(x: 106, y: 148))
                path.addCurve(to: CGPoint(x: 92, y: 194), control1: CGPoint(x: 105, y: 178), control2: CGPoint(x: 94, y: 184))
                path.addCurve(to: CGPoint(x: 132, y: 224), control1: CGPoint(x: 91, y: 213), control2: CGPoint(x: 111, y: 228))
            case .wolf:
                // Sitting wolf in profile, muzzle raised into a howl.
                path.move(to: CGPoint(x: 126, y: 257))
                path.addCurve(to: CGPoint(x: 105, y: 217), control1: CGPoint(x: 105, y: 249), control2: CGPoint(x: 98, y: 233))
                path.addCurve(to: CGPoint(x: 151, y: 175), control1: CGPoint(x: 111, y: 188), control2: CGPoint(x: 128, y: 178))
                path.addCurve(to: CGPoint(x: 172, y: 122), control1: CGPoint(x: 163, y: 157), control2: CGPoint(x: 166, y: 138))
                path.addLine(to: CGPoint(x: 151, y: 57))
                path.addLine(to: CGPoint(x: 205, y: 91))
                path.addCurve(to: CGPoint(x: 250, y: 83), control1: CGPoint(x: 223, y: 83), control2: CGPoint(x: 238, y: 82))
                path.addLine(to: CGPoint(x: 286, y: 49))
                path.addLine(to: CGPoint(x: 278, y: 112))
                path.addCurve(to: CGPoint(x: 328, y: 145), control1: CGPoint(x: 312, y: 111), control2: CGPoint(x: 333, y: 127))
                path.addCurve(to: CGPoint(x: 283, y: 165), control1: CGPoint(x: 324, y: 164), control2: CGPoint(x: 306, y: 169))
                path.addCurve(to: CGPoint(x: 245, y: 198), control1: CGPoint(x: 272, y: 184), control2: CGPoint(x: 256, y: 196))
                path.addLine(to: CGPoint(x: 255, y: 250))
                path.addLine(to: CGPoint(x: 218, y: 250))
                path.addLine(to: CGPoint(x: 199, y: 215))
                path.addLine(to: CGPoint(x: 172, y: 250))
                path.addLine(to: CGPoint(x: 137, y: 250))
                path.closeSubpath()
                path.move(to: CGPoint(x: 126, y: 204))
                path.addCurve(to: CGPoint(x: 77, y: 190), control1: CGPoint(x: 105, y: 201), control2: CGPoint(x: 87, y: 202))
                path.addCurve(to: CGPoint(x: 56, y: 225), control1: CGPoint(x: 54, y: 195), control2: CGPoint(x: 47, y: 215))
                path.addCurve(to: CGPoint(x: 126, y: 257), control1: CGPoint(x: 75, y: 254), control2: CGPoint(x: 102, y: 261))
            case .fox:
                // Nine-tailed fox: upright seated silhouette, pointed ears and
                // nine flowing tail ribbons in a balanced tattoo-emblem layout.
                path.move(to: CGPoint(x: 151, y: 112))
                path.addLine(to: CGPoint(x: 139, y: 36))
                path.addQuadCurve(to: CGPoint(x: 190, y: 78), control: CGPoint(x: 159, y: 54))
                path.addQuadCurve(to: CGPoint(x: 210, y: 78), control: CGPoint(x: 200, y: 72))
                path.addLine(to: CGPoint(x: 261, y: 36))
                path.addLine(to: CGPoint(x: 249, y: 112))
                path.addQuadCurve(to: CGPoint(x: 200, y: 156), control: CGPoint(x: 252, y: 151))
                path.addQuadCurve(to: CGPoint(x: 151, y: 112), control: CGPoint(x: 148, y: 151))
                path.closeSubpath()
                path.move(to: CGPoint(x: 160, y: 147))
                path.addCurve(to: CGPoint(x: 139, y: 251), control1: CGPoint(x: 142, y: 174), control2: CGPoint(x: 112, y: 223))
                path.addCurve(to: CGPoint(x: 200, y: 269), control1: CGPoint(x: 151, y: 278), control2: CGPoint(x: 180, y: 280))
                path.addCurve(to: CGPoint(x: 261, y: 251), control1: CGPoint(x: 220, y: 280), control2: CGPoint(x: 249, y: 278))
                path.addCurve(to: CGPoint(x: 240, y: 147), control1: CGPoint(x: 288, y: 223), control2: CGPoint(x: 258, y: 174))
                path.closeSubpath()
                for index in 0..<9 {
                    let t = CGFloat(index) - 4
                    let startX = CGFloat(200) + t * 9
                    let endX = CGFloat(200) + t * 37
                    let endY = CGFloat(80) + abs(t) * 15
                    path.move(to: CGPoint(x: startX, y: 219))
                    path.addCurve(to: CGPoint(x: endX, y: endY),
                                  control1: CGPoint(x: startX + t * 15, y: 169),
                                  control2: CGPoint(x: endX - t * 16, y: endY + 68))
                    path.addQuadCurve(to: CGPoint(x: endX + (t >= 0 ? -8 : 8), y: endY + 34),
                                      control: CGPoint(x: endX + t * 10, y: endY + 18))
                    path.addCurve(to: CGPoint(x: startX + 5, y: 224),
                                  control1: CGPoint(x: endX + t * 3, y: endY + 104),
                                  control2: CGPoint(x: startX + t * 4, y: 185))
                    path.closeSubpath()
                }
            case .phoenix:
                // Rising phoenix emblem with mirrored flame-feathers and tail plumes.
                path.move(to: CGPoint(x: 196, y: 117))
                path.addCurve(to: CGPoint(x: 63, y: 35), control1: CGPoint(x: 125, y: 92), control2: CGPoint(x: 85, y: 45))
                path.addCurve(to: CGPoint(x: 118, y: 119), control1: CGPoint(x: 72, y: 71), control2: CGPoint(x: 91, y: 104))
                path.addCurve(to: CGPoint(x: 38, y: 91), control1: CGPoint(x: 86, y: 108), control2: CGPoint(x: 55, y: 93))
                path.addCurve(to: CGPoint(x: 165, y: 173), control1: CGPoint(x: 82, y: 119), control2: CGPoint(x: 121, y: 161))
                path.addLine(to: CGPoint(x: 200, y: 151))
                path.addLine(to: CGPoint(x: 235, y: 173))
                path.addCurve(to: CGPoint(x: 362, y: 91), control1: CGPoint(x: 279, y: 161), control2: CGPoint(x: 318, y: 119))
                path.addCurve(to: CGPoint(x: 282, y: 119), control1: CGPoint(x: 345, y: 93), control2: CGPoint(x: 314, y: 108))
                path.addCurve(to: CGPoint(x: 337, y: 35), control1: CGPoint(x: 309, y: 104), control2: CGPoint(x: 328, y: 71))
                path.addCurve(to: CGPoint(x: 204, y: 117), control1: CGPoint(x: 315, y: 45), control2: CGPoint(x: 275, y: 92))
                path.closeSubpath()
                path.move(to: CGPoint(x: 184, y: 100))
                path.addCurve(to: CGPoint(x: 200, y: 57), control1: CGPoint(x: 179, y: 73), control2: CGPoint(x: 189, y: 58))
                path.addCurve(to: CGPoint(x: 216, y: 100), control1: CGPoint(x: 211, y: 58), control2: CGPoint(x: 221, y: 73))
                path.addLine(to: CGPoint(x: 200, y: 91))
                path.closeSubpath()
                path.move(to: CGPoint(x: 179, y: 139))
                path.addCurve(to: CGPoint(x: 200, y: 223), control1: CGPoint(x: 179, y: 177), control2: CGPoint(x: 185, y: 201))
                path.addCurve(to: CGPoint(x: 221, y: 139), control1: CGPoint(x: 215, y: 201), control2: CGPoint(x: 221, y: 177))
                path.closeSubpath()
                for index in 0..<5 {
                    let offset = CGFloat(index) * 15
                    path.move(to: CGPoint(x: 195 - offset * 0.25, y: 209))
                    path.addCurve(to: CGPoint(x: 124 + offset * 0.55, y: 282 - offset * 0.3),
                                  control1: CGPoint(x: 177 - offset * 0.2, y: 247),
                                  control2: CGPoint(x: 145 + offset * 0.25, y: 272))
                    path.addQuadCurve(to: CGPoint(x: 200, y: 235), control: CGPoint(x: 162 - offset * 0.2, y: 270))
                    path.closeSubpath()
                    path.move(to: CGPoint(x: 205 + offset * 0.25, y: 209))
                    path.addCurve(to: CGPoint(x: 276 - offset * 0.55, y: 282 - offset * 0.3),
                                  control1: CGPoint(x: 223 + offset * 0.2, y: 247),
                                  control2: CGPoint(x: 255 - offset * 0.25, y: 272))
                    path.addQuadCurve(to: CGPoint(x: 200, y: 235), control: CGPoint(x: 238 + offset * 0.2, y: 270))
                    path.closeSubpath()
                }
            case .bird:
                // Broad-winged hawk in a shallow banking glide.
                path.move(to: CGPoint(x: 194, y: 157))
                path.addCurve(to: CGPoint(x: 28, y: 75), control1: CGPoint(x: 112, y: 121), control2: CGPoint(x: 65, y: 56))
                path.addLine(to: CGPoint(x: 92, y: 154))
                path.addLine(to: CGPoint(x: 20, y: 132))
                path.addCurve(to: CGPoint(x: 169, y: 191), control1: CGPoint(x: 75, y: 151), control2: CGPoint(x: 122, y: 183))
                path.addLine(to: CGPoint(x: 200, y: 226))
                path.addLine(to: CGPoint(x: 231, y: 191))
                path.addCurve(to: CGPoint(x: 380, y: 132), control1: CGPoint(x: 278, y: 183), control2: CGPoint(x: 325, y: 151))
                path.addLine(to: CGPoint(x: 308, y: 154))
                path.addLine(to: CGPoint(x: 372, y: 75))
                path.addCurve(to: CGPoint(x: 206, y: 157), control1: CGPoint(x: 335, y: 56), control2: CGPoint(x: 288, y: 121))
                path.addCurve(to: CGPoint(x: 200, y: 142), control1: CGPoint(x: 207, y: 147), control2: CGPoint(x: 205, y: 143))
                path.addCurve(to: CGPoint(x: 194, y: 157), control1: CGPoint(x: 195, y: 143), control2: CGPoint(x: 193, y: 148))
                path.closeSubpath()
            case .snake:
                // Hooded cobra, flared hood, striking head and raised S-curve body.
                path.move(to: CGPoint(x: 183, y: 266))
                path.addCurve(to: CGPoint(x: 164, y: 215), control1: CGPoint(x: 174, y: 249), control2: CGPoint(x: 158, y: 239))
                path.addCurve(to: CGPoint(x: 194, y: 163), control1: CGPoint(x: 169, y: 188), control2: CGPoint(x: 194, y: 181))
                path.addCurve(to: CGPoint(x: 170, y: 110), control1: CGPoint(x: 194, y: 141), control2: CGPoint(x: 170, y: 130))
                path.addCurve(to: CGPoint(x: 119, y: 86), control1: CGPoint(x: 142, y: 93), control2: CGPoint(x: 125, y: 94))
                path.addCurve(to: CGPoint(x: 155, y: 38), control1: CGPoint(x: 110, y: 49), control2: CGPoint(x: 127, y: 34))
                path.addCurve(to: CGPoint(x: 245, y: 38), control1: CGPoint(x: 182, y: 25), control2: CGPoint(x: 219, y: 25))
                path.addCurve(to: CGPoint(x: 281, y: 86), control1: CGPoint(x: 273, y: 34), control2: CGPoint(x: 290, y: 49))
                path.addCurve(to: CGPoint(x: 230, y: 110), control1: CGPoint(x: 275, y: 94), control2: CGPoint(x: 258, y: 93))
                path.addCurve(to: CGPoint(x: 206, y: 163), control1: CGPoint(x: 230, y: 130), control2: CGPoint(x: 206, y: 141))
                path.addCurve(to: CGPoint(x: 236, y: 215), control1: CGPoint(x: 206, y: 181), control2: CGPoint(x: 231, y: 188))
                path.addCurve(to: CGPoint(x: 217, y: 266), control1: CGPoint(x: 242, y: 239), control2: CGPoint(x: 226, y: 249))
                path.closeSubpath()
                // Heavy lower coil gives the cobra a stable, tattoo-stencil base.
                path.move(to: CGPoint(x: 184, y: 239))
                path.addCurve(to: CGPoint(x: 112, y: 249), control1: CGPoint(x: 144, y: 222), control2: CGPoint(x: 108, y: 222))
                path.addCurve(to: CGPoint(x: 200, y: 281), control1: CGPoint(x: 116, y: 286), control2: CGPoint(x: 165, y: 290))
                path.addCurve(to: CGPoint(x: 288, y: 249), control1: CGPoint(x: 235, y: 290), control2: CGPoint(x: 284, y: 286))
                path.addCurve(to: CGPoint(x: 216, y: 239), control1: CGPoint(x: 292, y: 222), control2: CGPoint(x: 256, y: 222))
                path.closeSubpath()
            case .dragon:
                // New reference: an expressive, curled Night-Fury-like dragon in a
                // loose painterly pose, with a long body, dorsal spines and split fin.
                // Long curled body and haunch.
                path.move(to: CGPoint(x: 231, y: 132))
                path.addCurve(to: CGPoint(x: 149, y: 222), control1: CGPoint(x: 220, y: 188), control2: CGPoint(x: 173, y: 207))
                path.addCurve(to: CGPoint(x: 105, y: 176), control1: CGPoint(x: 119, y: 233), control2: CGPoint(x: 94, y: 207))
                path.addCurve(to: CGPoint(x: 146, y: 132), control1: CGPoint(x: 111, y: 151), control2: CGPoint(x: 126, y: 134))
                path.addCurve(to: CGPoint(x: 185, y: 157), control1: CGPoint(x: 164, y: 133), control2: CGPoint(x: 179, y: 145))
                path.addCurve(to: CGPoint(x: 222, y: 117), control1: CGPoint(x: 207, y: 147), control2: CGPoint(x: 225, y: 135))
                path.closeSubpath()
                // Raised shoulder and neck flowing into a broad, short muzzle.
                path.move(to: CGPoint(x: 192, y: 153))
                path.addCurve(to: CGPoint(x: 215, y: 91), control1: CGPoint(x: 205, y: 137), control2: CGPoint(x: 198, y: 108))
                path.addCurve(to: CGPoint(x: 265, y: 78), control1: CGPoint(x: 228, y: 67), control2: CGPoint(x: 249, y: 67))
                path.addCurve(to: CGPoint(x: 310, y: 111), control1: CGPoint(x: 296, y: 83), control2: CGPoint(x: 310, y: 95))
                path.addCurve(to: CGPoint(x: 275, y: 139), control1: CGPoint(x: 310, y: 132), control2: CGPoint(x: 295, y: 142))
                path.addCurve(to: CGPoint(x: 231, y: 132), control1: CGPoint(x: 258, y: 143), control2: CGPoint(x: 244, y: 139))
                path.closeSubpath()
                // Fin-like ears and swept-back head fins.
                path.move(to: CGPoint(x: 235, y: 88))
                path.addCurve(to: CGPoint(x: 207, y: 53), control1: CGPoint(x: 226, y: 69), control2: CGPoint(x: 214, y: 54))
                path.addCurve(to: CGPoint(x: 250, y: 76), control1: CGPoint(x: 224, y: 53), control2: CGPoint(x: 239, y: 64))
                path.closeSubpath()
                path.move(to: CGPoint(x: 272, y: 80))
                path.addCurve(to: CGPoint(x: 302, y: 51), control1: CGPoint(x: 282, y: 66), control2: CGPoint(x: 295, y: 53))
                path.addCurve(to: CGPoint(x: 291, y: 91), control1: CGPoint(x: 308, y: 68), control2: CGPoint(x: 302, y: 83))
                path.closeSubpath()
                // Folded wing with curved outer edge and a pointed trailing tip.
                path.move(to: CGPoint(x: 194, y: 151))
                path.addCurve(to: CGPoint(x: 258, y: 212), control1: CGPoint(x: 220, y: 153), control2: CGPoint(x: 259, y: 162))
                path.addCurve(to: CGPoint(x: 220, y: 195), control1: CGPoint(x: 248, y: 207), control2: CGPoint(x: 236, y: 198))
                path.addCurve(to: CGPoint(x: 187, y: 221), control1: CGPoint(x: 212, y: 206), control2: CGPoint(x: 199, y: 220))
                path.addCurve(to: CGPoint(x: 176, y: 178), control1: CGPoint(x: 175, y: 213), control2: CGPoint(x: 169, y: 194))
                path.closeSubpath()
                // Short foreleg and three soft clawed toes.
                path.move(to: CGPoint(x: 221, y: 150))
                path.addCurve(to: CGPoint(x: 250, y: 184), control1: CGPoint(x: 226, y: 164), control2: CGPoint(x: 245, y: 167))
                path.addCurve(to: CGPoint(x: 238, y: 197), control1: CGPoint(x: 257, y: 194), control2: CGPoint(x: 246, y: 201))
                path.addLine(to: CGPoint(x: 214, y: 181))
                path.closeSubpath()
                // Long tapered tail ending in the characteristic asymmetric fin.
                path.move(to: CGPoint(x: 133, y: 204))
                path.addCurve(to: CGPoint(x: 77, y: 151), control1: CGPoint(x: 101, y: 208), control2: CGPoint(x: 83, y: 185))
                path.addCurve(to: CGPoint(x: 69, y: 105), control1: CGPoint(x: 68, y: 129), control2: CGPoint(x: 61, y: 117))
                path.addCurve(to: CGPoint(x: 89, y: 91), control1: CGPoint(x: 72, y: 91), control2: CGPoint(x: 80, y: 87))
                path.addCurve(to: CGPoint(x: 103, y: 125), control1: CGPoint(x: 99, y: 99), control2: CGPoint(x: 104, y: 111))
                path.addCurve(to: CGPoint(x: 153, y: 177), control1: CGPoint(x: 115, y: 146), control2: CGPoint(x: 143, y: 158))
                path.closeSubpath()
                // Split prosthetic fin, kept in the selected animation tint.
                path.move(to: CGPoint(x: 76, y: 113))
                path.addCurve(to: CGPoint(x: 37, y: 78), control1: CGPoint(x: 62, y: 96), control2: CGPoint(x: 48, y: 80))
                path.addCurve(to: CGPoint(x: 80, y: 89), control1: CGPoint(x: 51, y: 67), control2: CGPoint(x: 69, y: 72))
                path.addCurve(to: CGPoint(x: 105, y: 111), control1: CGPoint(x: 94, y: 92), control2: CGPoint(x: 103, y: 101))
                path.addCurve(to: CGPoint(x: 76, y: 113), control1: CGPoint(x: 96, y: 116), control2: CGPoint(x: 86, y: 119))
                path.closeSubpath()
            case .mermaid:
                // Flowing-haired mermaid with torso, arms, scaled tail and split fin.
                path.move(to: CGPoint(x: 188, y: 46))
                path.addCurve(to: CGPoint(x: 239, y: 70), control1: CGPoint(x: 223, y: 39), control2: CGPoint(x: 245, y: 51))
                path.addCurve(to: CGPoint(x: 220, y: 119), control1: CGPoint(x: 241, y: 94), control2: CGPoint(x: 232, y: 111))
                path.addCurve(to: CGPoint(x: 247, y: 151), control1: CGPoint(x: 223, y: 130), control2: CGPoint(x: 238, y: 138))
                path.addLine(to: CGPoint(x: 281, y: 177))
                path.addCurve(to: CGPoint(x: 254, y: 184), control1: CGPoint(x: 273, y: 185), control2: CGPoint(x: 260, y: 190))
                path.addLine(to: CGPoint(x: 219, y: 161))
                path.addCurve(to: CGPoint(x: 202, y: 133), control1: CGPoint(x: 212, y: 146), control2: CGPoint(x: 204, y: 143))
                path.addCurve(to: CGPoint(x: 184, y: 165), control1: CGPoint(x: 198, y: 144), control2: CGPoint(x: 194, y: 156))
                path.addLine(to: CGPoint(x: 145, y: 186))
                path.addCurve(to: CGPoint(x: 126, y: 173), control1: CGPoint(x: 136, y: 188), control2: CGPoint(x: 122, y: 184))
                path.addLine(to: CGPoint(x: 170, y: 139))
                path.addCurve(to: CGPoint(x: 164, y: 107), control1: CGPoint(x: 171, y: 124), control2: CGPoint(x: 160, y: 119))
                path.addCurve(to: CGPoint(x: 163, y: 69), control1: CGPoint(x: 157, y: 94), control2: CGPoint(x: 151, y: 80))
                path.addCurve(to: CGPoint(x: 188, y: 46), control1: CGPoint(x: 169, y: 53), control2: CGPoint(x: 176, y: 45))
                path.closeSubpath()
                path.move(to: CGPoint(x: 207, y: 174))
                path.addCurve(to: CGPoint(x: 260, y: 228), control1: CGPoint(x: 215, y: 206), control2: CGPoint(x: 252, y: 209))
                path.addLine(to: CGPoint(x: 325, y: 250))
                path.addCurve(to: CGPoint(x: 277, y: 277), control1: CGPoint(x: 320, y: 274), control2: CGPoint(x: 298, y: 284))
                path.addCurve(to: CGPoint(x: 219, y: 255), control1: CGPoint(x: 252, y: 270), control2: CGPoint(x: 234, y: 268))
                path.addCurve(to: CGPoint(x: 159, y: 278), control1: CGPoint(x: 198, y: 264), control2: CGPoint(x: 178, y: 281))
                path.addCurve(to: CGPoint(x: 116, y: 251), control1: CGPoint(x: 137, y: 283), control2: CGPoint(x: 117, y: 272))
                path.addLine(to: CGPoint(x: 178, y: 229))
                path.addCurve(to: CGPoint(x: 207, y: 174), control1: CGPoint(x: 191, y: 210), control2: CGPoint(x: 196, y: 191))
                path.closeSubpath()
                // Long hair ribbon and face-framing locks.
                path.move(to: CGPoint(x: 175, y: 57))
                path.addCurve(to: CGPoint(x: 117, y: 117), control1: CGPoint(x: 144, y: 58), control2: CGPoint(x: 132, y: 99))
                path.addCurve(to: CGPoint(x: 148, y: 145), control1: CGPoint(x: 109, y: 144), control2: CGPoint(x: 130, y: 151))
                path.addCurve(to: CGPoint(x: 163, y: 112), control1: CGPoint(x: 153, y: 135), control2: CGPoint(x: 160, y: 126))
            case .paw:
                // Bear paw silhouette: broad heel pad, four naturally staggered toes.
                path.move(to: CGPoint(x: 151, y: 189))
                path.addCurve(to: CGPoint(x: 200, y: 161), control1: CGPoint(x: 153, y: 168), control2: CGPoint(x: 174, y: 157))
                path.addCurve(to: CGPoint(x: 249, y: 189), control1: CGPoint(x: 226, y: 157), control2: CGPoint(x: 247, y: 168))
                path.addCurve(to: CGPoint(x: 264, y: 226), control1: CGPoint(x: 271, y: 203), control2: CGPoint(x: 271, y: 216))
                path.addCurve(to: CGPoint(x: 235, y: 255), control1: CGPoint(x: 259, y: 248), control2: CGPoint(x: 249, y: 258))
                path.addCurve(to: CGPoint(x: 165, y: 255), control1: CGPoint(x: 216, y: 263), control2: CGPoint(x: 184, y: 263))
                path.addCurve(to: CGPoint(x: 136, y: 226), control1: CGPoint(x: 151, y: 258), control2: CGPoint(x: 141, y: 248))
                path.addCurve(to: CGPoint(x: 151, y: 189), control1: CGPoint(x: 129, y: 216), control2: CGPoint(x: 129, y: 203))
                path.closeSubpath()
                for (x, y, w, h) in [
                    (CGFloat(92), CGFloat(91), CGFloat(55), CGFloat(66)),
                    (CGFloat(157), CGFloat(54), CGFloat(49), CGFloat(67)),
                    (CGFloat(214), CGFloat(54), CGFloat(49), CGFloat(67)),
                    (CGFloat(253), CGFloat(91), CGFloat(55), CGFloat(66))
                ] {
                    path.addEllipse(in: CGRect(x: x, y: y, width: w, height: h))
                }
            case .stars:
                path.move(to: CGPoint(x: 200, y: 34))
                path.addLine(to: CGPoint(x: 221, y: 151))
                path.addLine(to: CGPoint(x: 338, y: 172))
                path.addLine(to: CGPoint(x: 221, y: 193))
                path.addLine(to: CGPoint(x: 200, y: 266))
                path.addLine(to: CGPoint(x: 179, y: 193))
                path.addLine(to: CGPoint(x: 62, y: 172))
                path.addLine(to: CGPoint(x: 179, y: 151))
                path.closeSubpath()
            case .crescentMoon:
                path.move(to: CGPoint(x: 260, y: 48))
                path.addCurve(to: CGPoint(x: 158, y: 256), control1: CGPoint(x: 330, y: 174), control2: CGPoint(x: 252, y: 284))
                path.addCurve(to: CGPoint(x: 260, y: 48), control1: CGPoint(x: 86, y: 233), control2: CGPoint(x: 104, y: 82))
                path.closeSubpath()
            case .spiral:
                // Calligraphic golden-spiral sun with eight tapered flame rays.
                for index in 0..<8 {
                    let angle = CGFloat(index) * .pi / 4
                    let cx = 200 + cos(angle) * 92
                    let cy = 150 + sin(angle) * 92
                    let tx = 200 + cos(angle + 0.34) * 145
                    let ty = 150 + sin(angle + 0.34) * 145
                    path.move(to: CGPoint(x: 200 + cos(angle - 0.16) * 34, y: 150 + sin(angle - 0.16) * 34))
                    path.addQuadCurve(to: CGPoint(x: tx, y: ty), control: CGPoint(x: cx + cos(angle + 0.8) * 30, y: cy + sin(angle + 0.8) * 30))
                    path.addQuadCurve(to: CGPoint(x: 200 + cos(angle + 0.16) * 34, y: 150 + sin(angle + 0.16) * 34), control: CGPoint(x: cx - cos(angle + 0.8) * 30, y: cy - sin(angle + 0.8) * 30))
                    path.closeSubpath()
                }
                path.move(to: CGPoint(x: 200, y: 150))
                path.addCurve(to: CGPoint(x: 218, y: 133), control1: CGPoint(x: 242, y: 160), control2: CGPoint(x: 232, y: 126))
                path.addCurve(to: CGPoint(x: 180, y: 137), control1: CGPoint(x: 201, y: 119), control2: CGPoint(x: 179, y: 122))
                path.addCurve(to: CGPoint(x: 203, y: 176), control1: CGPoint(x: 171, y: 158), control2: CGPoint(x: 190, y: 181))
                path.addCurve(to: CGPoint(x: 235, y: 153), control1: CGPoint(x: 225, y: 176), control2: CGPoint(x: 240, y: 165))
            case .sun:
                path.addEllipse(in: CGRect(x: 142, y: 92, width: 116, height: 116))
                for angle in stride(from: CGFloat(0), to: CGFloat(360), by: CGFloat(45)) {
                    let radians = angle * .pi / 180
                    let inner = CGPoint(x: 200 + cos(radians) * 78, y: 150 + sin(radians) * 78)
                    let outer = CGPoint(x: 200 + cos(radians) * 112, y: 150 + sin(radians) * 112)
                    path.move(to: inner)
                    path.addLine(to: outer)
                }
            }
        }
        // Keep every part of the selected creature tied to the animation
        // palette. Toothless must not retain a fixed black body or red tail:
        // the body, wings, tail fin, details and glow use this tint; eye irises
        // use the creature-specific custom eye colour.
        let motifTint = color
        let motifAlpha = min(1, opacity * brightness)
        // Use tonal depth from the selected animation hue rather than a flat,
        // heavy silhouette. The highlight and shadow stay in the same hue so
        // every motif continues to follow the user's animation-colour setting.
        drawing.fill(
            fill,
            with: .linearGradient(
                Gradient(colors: [
                    motifTint.opacity(motifAlpha * 0.62),
                    motifTint.opacity(motifAlpha),
                    motifTint.opacity(motifAlpha * 0.76)
                ]),
                startPoint: CGPoint(x: 150, y: 48),
                endPoint: CGPoint(x: 252, y: 282)
            )
        )
        // Volume pass: use closed, anatomy-shaped planes instead of relying
        // on decorative contour strokes alone. Every plane stays in the selected
        // animation hue, so the motifs remain fully recolourable.
        var volumePlanes = Path()
        switch shape {
        case .dragon:
            // Folded wing membrane, shoulder muscle, jaw plane and rear fin.
            volumePlanes.move(to: CGPoint(x: 218, y: 112))
            volumePlanes.addQuadCurve(to: CGPoint(x: 286, y: 101), control: CGPoint(x: 252, y: 82))
            volumePlanes.addQuadCurve(to: CGPoint(x: 266, y: 151), control: CGPoint(x: 294, y: 132))
            volumePlanes.addQuadCurve(to: CGPoint(x: 225, y: 157), control: CGPoint(x: 249, y: 143))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 147, y: 178))
            volumePlanes.addQuadCurve(to: CGPoint(x: 193, y: 151), control: CGPoint(x: 178, y: 166))
            volumePlanes.addQuadCurve(to: CGPoint(x: 178, y: 217), control: CGPoint(x: 166, y: 213))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 302, y: 195))
            volumePlanes.addQuadCurve(to: CGPoint(x: 351, y: 228), control: CGPoint(x: 338, y: 188))
            volumePlanes.addQuadCurve(to: CGPoint(x: 304, y: 244), control: CGPoint(x: 328, y: 248))
            volumePlanes.addQuadCurve(to: CGPoint(x: 317, y: 218), control: CGPoint(x: 304, y: 225))
            volumePlanes.closeSubpath()
        case .snake:
            // Hood lobes and a tapered belly highlight follow the cobra's S-curve.
            volumePlanes.move(to: CGPoint(x: 145, y: 53))
            volumePlanes.addQuadCurve(to: CGPoint(x: 184, y: 103), control: CGPoint(x: 151, y: 78))
            volumePlanes.addQuadCurve(to: CGPoint(x: 160, y: 92), control: CGPoint(x: 163, y: 104))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 255, y: 53))
            volumePlanes.addQuadCurve(to: CGPoint(x: 216, y: 103), control: CGPoint(x: 249, y: 78))
            volumePlanes.addQuadCurve(to: CGPoint(x: 240, y: 92), control: CGPoint(x: 237, y: 104))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 184, y: 171))
            volumePlanes.addQuadCurve(to: CGPoint(x: 196, y: 254), control: CGPoint(x: 176, y: 217))
            volumePlanes.addQuadCurve(to: CGPoint(x: 216, y: 171), control: CGPoint(x: 222, y: 216))
            volumePlanes.addQuadCurve(to: CGPoint(x: 207, y: 251), control: CGPoint(x: 205, y: 220))
            volumePlanes.closeSubpath()
        case .bird:
            // Layered primary and secondary flight-feather panels.
            for index in 0..<4 {
                let t = CGFloat(index)
                volumePlanes.move(to: CGPoint(x: 194, y: 157 + t * 7))
                volumePlanes.addQuadCurve(
                    to: CGPoint(x: 42 + t * 25, y: 83 + t * 20),
                    control: CGPoint(x: 105 + t * 16, y: 130 + t * 10)
                )
                volumePlanes.addQuadCurve(
                    to: CGPoint(x: 166 + t * 5, y: 190 + t * 2),
                    control: CGPoint(x: 116 + t * 15, y: 164 + t * 7)
                )
                volumePlanes.closeSubpath()
                volumePlanes.move(to: CGPoint(x: 206, y: 157 + t * 7))
                volumePlanes.addQuadCurve(
                    to: CGPoint(x: 358 - t * 25, y: 83 + t * 20),
                    control: CGPoint(x: 295 - t * 16, y: 130 + t * 10)
                )
                volumePlanes.addQuadCurve(
                    to: CGPoint(x: 234 - t * 5, y: 190 + t * 2),
                    control: CGPoint(x: 284 - t * 15, y: 164 + t * 7)
                )
                volumePlanes.closeSubpath()
            }
        case .fox:
            // Cheek mask, forehead blaze and separated tail-fan volumes.
            volumePlanes.move(to: CGPoint(x: 154, y: 105))
            volumePlanes.addQuadCurve(to: CGPoint(x: 199, y: 153), control: CGPoint(x: 157, y: 151))
            volumePlanes.addQuadCurve(to: CGPoint(x: 180, y: 126), control: CGPoint(x: 175, y: 141))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 246, y: 105))
            volumePlanes.addQuadCurve(to: CGPoint(x: 201, y: 153), control: CGPoint(x: 243, y: 151))
            volumePlanes.addQuadCurve(to: CGPoint(x: 220, y: 126), control: CGPoint(x: 225, y: 141))
            volumePlanes.closeSubpath()
            for index in 0..<5 {
                let t = CGFloat(index) - 2
                volumePlanes.move(to: CGPoint(x: 200 + t * 7, y: 219))
                volumePlanes.addQuadCurve(to: CGPoint(x: 200 + t * 38, y: 90 + abs(t) * 18), control: CGPoint(x: 200 + t * 30, y: 160))
                volumePlanes.addQuadCurve(to: CGPoint(x: 200 + t * 24, y: 205), control: CGPoint(x: 200 + t * 34, y: 160))
                volumePlanes.closeSubpath()
            }
        case .phoenix:
            // Individually layered wing feathers and flame-shaped tail panels.
            for index in 0..<6 {
                let t = CGFloat(index)
                volumePlanes.move(to: CGPoint(x: 196, y: 143 + t * 4))
                volumePlanes.addQuadCurve(to: CGPoint(x: 62 + t * 18, y: 44 + t * 17), control: CGPoint(x: 111 + t * 13, y: 101 + t * 9))
                volumePlanes.addQuadCurve(to: CGPoint(x: 167 + t * 4, y: 178 + t * 2), control: CGPoint(x: 113 + t * 15, y: 151 + t * 7))
                volumePlanes.closeSubpath()
                volumePlanes.move(to: CGPoint(x: 204, y: 143 + t * 4))
                volumePlanes.addQuadCurve(to: CGPoint(x: 338 - t * 18, y: 44 + t * 17), control: CGPoint(x: 289 - t * 13, y: 101 + t * 9))
                volumePlanes.addQuadCurve(to: CGPoint(x: 233 - t * 4, y: 178 + t * 2), control: CGPoint(x: 287 - t * 15, y: 151 + t * 7))
                volumePlanes.closeSubpath()
            }
        case .wolf:
            // Muzzle bridge, cheek planes and layered neck ruff.
            volumePlanes.move(to: CGPoint(x: 248, y: 91))
            volumePlanes.addQuadCurve(to: CGPoint(x: 324, y: 144), control: CGPoint(x: 304, y: 99))
            volumePlanes.addQuadCurve(to: CGPoint(x: 276, y: 155), control: CGPoint(x: 311, y: 162))
            volumePlanes.addQuadCurve(to: CGPoint(x: 258, y: 126), control: CGPoint(x: 261, y: 143))
            volumePlanes.closeSubpath()
            for index in 0..<4 {
                let t = CGFloat(index)
                volumePlanes.move(to: CGPoint(x: 153 + t * 13, y: 177 + t * 8))
                volumePlanes.addQuadCurve(to: CGPoint(x: 217 + t * 5, y: 249), control: CGPoint(x: 172 + t * 12, y: 224))
                volumePlanes.addQuadCurve(to: CGPoint(x: 180 + t * 7, y: 207), control: CGPoint(x: 196 + t * 8, y: 221))
                volumePlanes.closeSubpath()
            }
        case .cat:
            // Facial mask, shoulder/chest planes and the curled tail's inner volume.
            volumePlanes.move(to: CGPoint(x: 151, y: 132))
            volumePlanes.addQuadCurve(to: CGPoint(x: 198, y: 177), control: CGPoint(x: 153, y: 171))
            volumePlanes.addQuadCurve(to: CGPoint(x: 181, y: 150), control: CGPoint(x: 170, y: 165))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 249, y: 132))
            volumePlanes.addQuadCurve(to: CGPoint(x: 202, y: 177), control: CGPoint(x: 247, y: 171))
            volumePlanes.addQuadCurve(to: CGPoint(x: 219, y: 150), control: CGPoint(x: 230, y: 165))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 175, y: 181))
            volumePlanes.addQuadCurve(to: CGPoint(x: 225, y: 181), control: CGPoint(x: 200, y: 207))
            volumePlanes.addQuadCurve(to: CGPoint(x: 215, y: 246), control: CGPoint(x: 222, y: 224))
            volumePlanes.addQuadCurve(to: CGPoint(x: 185, y: 246), control: CGPoint(x: 178, y: 224))
            volumePlanes.closeSubpath()
        case .mermaid:
            // Flowing hair mass, shoulder highlights and layered tail-fin lobes.
            volumePlanes.move(to: CGPoint(x: 171, y: 48))
            volumePlanes.addCurve(to: CGPoint(x: 123, y: 157), control1: CGPoint(x: 138, y: 74), control2: CGPoint(x: 108, y: 119))
            volumePlanes.addQuadCurve(to: CGPoint(x: 153, y: 137), control: CGPoint(x: 142, y: 110))
            volumePlanes.addCurve(to: CGPoint(x: 171, y: 48), control1: CGPoint(x: 163, y: 93), control2: CGPoint(x: 175, y: 69))
            volumePlanes.closeSubpath()
            volumePlanes.move(to: CGPoint(x: 230, y: 48))
            volumePlanes.addCurve(to: CGPoint(x: 277, y: 157), control1: CGPoint(x: 262, y: 74), control2: CGPoint(x: 292, y: 119))
            volumePlanes.addQuadCurve(to: CGPoint(x: 247, y: 137), control: CGPoint(x: 258, y: 110))
            volumePlanes.addCurve(to: CGPoint(x: 230, y: 48), control1: CGPoint(x: 238, y: 93), control2: CGPoint(x: 225, y: 69))
            volumePlanes.closeSubpath()
            for index in 0..<4 {
                let t = CGFloat(index)
                volumePlanes.move(to: CGPoint(x: 200, y: 245 + t * 5))
                volumePlanes.addQuadCurve(to: CGPoint(x: 130 + t * 12, y: 279 - t * 4), control: CGPoint(x: 158 + t * 10, y: 253 + t * 6))
                volumePlanes.addQuadCurve(to: CGPoint(x: 200, y: 261 + t * 2), control: CGPoint(x: 164 + t * 8, y: 281))
                volumePlanes.closeSubpath()
                volumePlanes.move(to: CGPoint(x: 200, y: 245 + t * 5))
                volumePlanes.addQuadCurve(to: CGPoint(x: 270 - t * 12, y: 279 - t * 4), control: CGPoint(x: 242 - t * 10, y: 253 + t * 6))
                volumePlanes.addQuadCurve(to: CGPoint(x: 200, y: 261 + t * 2), control: CGPoint(x: 236 - t * 8, y: 281))
                volumePlanes.closeSubpath()
            }
        case .paw:
            // Raised central pad and four toe cushions; the central negative
            // space carries the forest motif rather than leaving a flat stamp.
            volumePlanes.addEllipse(in: CGRect(x: 164, y: 178, width: 72, height: 65))
            for (x, y, w, h) in [
                (CGFloat(94), CGFloat(77), CGFloat(54), CGFloat(64)),
                (CGFloat(157), CGFloat(48), CGFloat(48), CGFloat(66)),
                (CGFloat(195), CGFloat(48), CGFloat(48), CGFloat(66)),
                (CGFloat(252), CGFloat(77), CGFloat(54), CGFloat(64))
            ] {
                volumePlanes.addEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            }
        case .stars:
            // Nested star facets create a crystalline, dimensional centre.
            volumePlanes.move(to: CGPoint(x: 200, y: 49))
            volumePlanes.addLine(to: CGPoint(x: 217, y: 153))
            volumePlanes.addLine(to: CGPoint(x: 306, y: 172))
            volumePlanes.addLine(to: CGPoint(x: 217, y: 189))
            volumePlanes.addLine(to: CGPoint(x: 200, y: 245))
            volumePlanes.addLine(to: CGPoint(x: 183, y: 189))
            volumePlanes.addLine(to: CGPoint(x: 94, y: 172))
            volumePlanes.addLine(to: CGPoint(x: 183, y: 153))
            volumePlanes.closeSubpath()
        case .crescentMoon:
            // Curved inner lunar plane and crater basins.
            volumePlanes.move(to: CGPoint(x: 250, y: 67))
            volumePlanes.addCurve(to: CGPoint(x: 178, y: 231), control1: CGPoint(x: 278, y: 140), control2: CGPoint(x: 226, y: 223))
            volumePlanes.addCurve(to: CGPoint(x: 206, y: 192), control1: CGPoint(x: 191, y: 226), control2: CGPoint(x: 195, y: 209))
            volumePlanes.addCurve(to: CGPoint(x: 250, y: 67), control1: CGPoint(x: 271, y: 170), control2: CGPoint(x: 267, y: 104))
            volumePlanes.closeSubpath()
            for (x, y, d) in [(CGFloat(215), CGFloat(91), CGFloat(22)), (CGFloat(185), CGFloat(151), CGFloat(16)), (CGFloat(198), CGFloat(195), CGFloat(12))] {
                volumePlanes.addEllipse(in: CGRect(x: x, y: y, width: d, height: d * 0.72))
            }
        case .spiral:
            // Broad spiral bands and a stepped ray corona.
            for index in 0..<3 {
                let t = CGFloat(index)
                volumePlanes.move(to: CGPoint(x: 200 + t * 5, y: 150 + t * 5))
                volumePlanes.addCurve(to: CGPoint(x: 231 - t * 8, y: 135 + t * 7), control1: CGPoint(x: 252 - t * 5, y: 173 + t * 4), control2: CGPoint(x: 244 - t * 8, y: 119 + t * 7))
                volumePlanes.addQuadCurve(to: CGPoint(x: 220 - t * 5, y: 160 + t * 6), control: CGPoint(x: 233 - t * 6, y: 154 + t * 5))
                volumePlanes.closeSubpath()
            }
        case .sun:
            // Solar disc, inner corona and alternating broad rays.
            volumePlanes.addEllipse(in: CGRect(x: 158, y: 108, width: 84, height: 84))
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let inner = CGPoint(x: 200 + cos(angle) * 84, y: 150 + sin(angle) * 84)
                let outer = CGPoint(x: 200 + cos(angle) * 111, y: 150 + sin(angle) * 111)
                let side = CGPoint(x: 200 + cos(angle + 0.12) * 98, y: 150 + sin(angle + 0.12) * 98)
                volumePlanes.move(to: inner)
                volumePlanes.addQuadCurve(to: outer, control: side)
                volumePlanes.addQuadCurve(to: inner, control: CGPoint(x: 200 + cos(angle - 0.12) * 98, y: 150 + sin(angle - 0.12) * 98))
                volumePlanes.closeSubpath()
            }
        }
        var volumeDrawing = drawing
        volumeDrawing.clip(to: fill)
        volumeDrawing.fill(
            volumePlanes,
            with: .color(motifTint.opacity(min(1, motifAlpha * 0.22)))
        )
        volumeDrawing.stroke(
            volumePlanes,
            with: .color(motifTint.opacity(min(1, motifAlpha * 0.56))),
            style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round)
        )
        drawing.stroke(
            fill,
            with: .color(motifTint.opacity(min(1, motifAlpha * 0.9))),
            style: StrokeStyle(lineWidth: 2.15, lineCap: .round, lineJoin: .round)
        )
        if shape == .dragon {
            // Toothless's almond-shaped irises use the independent eye-colour setting;
            // the dark pupils remain separate for contrast.
            var eyes = Path()
            eyes.move(to: CGPoint(x: 244, y: 98))
            eyes.addQuadCurve(to: CGPoint(x: 276, y: 104), control: CGPoint(x: 263, y: 88))
            eyes.addQuadCurve(to: CGPoint(x: 269, y: 117), control: CGPoint(x: 278, y: 114))
            eyes.addQuadCurve(to: CGPoint(x: 243, y: 110), control: CGPoint(x: 256, y: 121))
            eyes.addQuadCurve(to: CGPoint(x: 244, y: 98), control: CGPoint(x: 237, y: 104))
            drawing.fill(eyes, with: .color(eyeColor.opacity(min(1, opacity * 1.25))))
            var pupils = Path()
            pupils.addEllipse(in: CGRect(x: 256, y: 100, width: 5, height: 11))
            drawing.fill(pupils, with: .color(Color.black.opacity(min(1, opacity * 0.72))))
        }
        var details = Path()
        let detailColor = motifTint.opacity(min(1, opacity * 0.85 * brightness))
        switch shape {
        case .fox:
            for index in 0..<9 {
                let t = CGFloat(index) - 4
                let startX = CGFloat(200) + t * 8
                let endX = CGFloat(200) + t * 35
                details.move(to: CGPoint(x: startX, y: 224))
                details.addQuadCurve(to: CGPoint(x: endX, y: 91 + abs(t) * 15), control: CGPoint(x: startX + t * 13, y: 161))
            }
            details.move(to: CGPoint(x: 164, y: 141))
            details.addQuadCurve(to: CGPoint(x: 236, y: 141), control: CGPoint(x: 200, y: 169))
        case .phoenix:
            for index in 0..<6 {
                let offset = CGFloat(index) * 14
                details.move(to: CGPoint(x: 192, y: 137))
                details.addQuadCurve(to: CGPoint(x: 63 + offset, y: 43 + offset * 1.5), control: CGPoint(x: 114 + offset * 0.35, y: 84 + offset))
                details.move(to: CGPoint(x: 208, y: 137))
                details.addQuadCurve(to: CGPoint(x: 337 - offset, y: 43 + offset * 1.5), control: CGPoint(x: 286 - offset * 0.35, y: 84 + offset))
            }
            details.move(to: CGPoint(x: 200, y: 157))
            details.addQuadCurve(to: CGPoint(x: 200, y: 222), control: CGPoint(x: 220, y: 190))
        case .spiral:
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                details.move(to: CGPoint(x: 200 + cos(angle) * 48, y: 150 + sin(angle) * 48))
                details.addLine(to: CGPoint(x: 200 + cos(angle) * 116, y: 150 + sin(angle) * 116))
            }
            details.move(to: CGPoint(x: 200, y: 150))
            details.addCurve(to: CGPoint(x: 220, y: 138), control1: CGPoint(x: 241, y: 162), control2: CGPoint(x: 228, y: 127))
        case .wolf:
            details.move(to: CGPoint(x: 274, y: 111))
            details.addQuadCurve(to: CGPoint(x: 306, y: 143), control: CGPoint(x: 299, y: 111))
            details.move(to: CGPoint(x: 250, y: 101))
            details.addQuadCurve(to: CGPoint(x: 277, y: 112), control: CGPoint(x: 266, y: 97))
            details.move(to: CGPoint(x: 177, y: 149))
            details.addQuadCurve(to: CGPoint(x: 205, y: 160), control: CGPoint(x: 192, y: 146))
        case .cat:
            details.move(to: CGPoint(x: 151, y: 139))
            details.addQuadCurve(to: CGPoint(x: 239, y: 139), control: CGPoint(x: 195, y: 161))
            details.move(to: CGPoint(x: 165, y: 222))
            details.addQuadCurve(to: CGPoint(x: 244, y: 222), control: CGPoint(x: 204, y: 239))
        case .bird:
            details.move(to: CGPoint(x: 199, y: 159))
            details.addQuadCurve(to: CGPoint(x: 85, y: 91), control: CGPoint(x: 127, y: 108))
            details.move(to: CGPoint(x: 201, y: 159))
            details.addQuadCurve(to: CGPoint(x: 315, y: 91), control: CGPoint(x: 273, y: 108))
        case .snake:
            // Hood ribs, jaw split, fangs and forked striking tongue.
            for index in 0..<7 {
                let x = CGFloat(145 + index * 18)
                details.move(to: CGPoint(x: x, y: 52))
                details.addQuadCurve(to: CGPoint(x: 200 + (x - 200) * 0.62, y: 105), control: CGPoint(x: 200, y: 61))
            }
            details.move(to: CGPoint(x: 174, y: 91))
            details.addQuadCurve(to: CGPoint(x: 226, y: 91), control: CGPoint(x: 200, y: 108))
            details.move(to: CGPoint(x: 181, y: 100))
            details.addLine(to: CGPoint(x: 187, y: 119))
            details.move(to: CGPoint(x: 219, y: 100))
            details.addLine(to: CGPoint(x: 213, y: 119))
            details.move(to: CGPoint(x: 200, y: 105))
            details.addLine(to: CGPoint(x: 200, y: 132))
            details.move(to: CGPoint(x: 200, y: 132))
            details.addLine(to: CGPoint(x: 190, y: 145))
            details.move(to: CGPoint(x: 200, y: 132))
            details.addLine(to: CGPoint(x: 210, y: 145))
            details.move(to: CGPoint(x: 185, y: 183))
            details.addCurve(to: CGPoint(x: 214, y: 237), control1: CGPoint(x: 167, y: 215), control2: CGPoint(x: 235, y: 211))
        case .dragon:
            // Flowing wing bones, soft muzzle, expressive cheek and tail-fin straps.
            details.move(to: CGPoint(x: 195, y: 153))
            details.addQuadCurve(to: CGPoint(x: 250, y: 202), control: CGPoint(x: 246, y: 153))
            details.move(to: CGPoint(x: 196, y: 164))
            details.addQuadCurve(to: CGPoint(x: 219, y: 207), control: CGPoint(x: 199, y: 190))
            details.move(to: CGPoint(x: 216, y: 104))
            details.addQuadCurve(to: CGPoint(x: 299, y: 116), control: CGPoint(x: 253, y: 142))
            details.move(to: CGPoint(x: 277, y: 130))
            details.addQuadCurve(to: CGPoint(x: 300, y: 124), control: CGPoint(x: 290, y: 135))
            details.move(to: CGPoint(x: 88, y: 111))
            details.addLine(to: CGPoint(x: 98, y: 103))
            details.move(to: CGPoint(x: 82, y: 103))
            details.addLine(to: CGPoint(x: 92, y: 95))
            // Short dorsal spines along the curved neck and back.
            for index in 0..<6 {
                let x = CGFloat(155 + index * 12)
                let y = CGFloat(146 - index * 7)
                details.move(to: CGPoint(x: x, y: y))
                details.addLine(to: CGPoint(x: x + 3, y: y - 12))
                details.addLine(to: CGPoint(x: x + 10, y: y - 4))
            }
            // Small claw marks on the forepaw.
            details.move(to: CGPoint(x: 239, y: 185))
            details.addLine(to: CGPoint(x: 247, y: 191))
            details.move(to: CGPoint(x: 230, y: 190))
            details.addLine(to: CGPoint(x: 237, y: 197))
        case .mermaid:
            for y in stride(from: CGFloat(220), through: CGFloat(252), by: CGFloat(10)) {
                details.move(to: CGPoint(x: 175, y: y))
                details.addQuadCurve(to: CGPoint(x: 238, y: y), control: CGPoint(x: 206, y: y + 12))
            }
            details.move(to: CGPoint(x: 189, y: 62))
            details.addQuadCurve(to: CGPoint(x: 224, y: 67), control: CGPoint(x: 208, y: 55))
        default:
            break
        }
        drawing.stroke(details, with: .color(detailColor), style: StrokeStyle(lineWidth: 2.15, lineCap: .round, lineJoin: .round))

        // Fine anime-illustration linework adds recognizable anatomy and surface
        // texture while retaining a single palette hue. These strokes deliberately
        // use the selected animation tint (not neutral grey), so changing the
        // animation colour recolours the entire creature consistently.
        var fineDetails = Path()
        switch shape {
        case .fox:
            // Tribal negative-space tufts, ear insets and nine flowing tail cuts.
            fineDetails.move(to: CGPoint(x: 151, y: 63))
            fineDetails.addQuadCurve(to: CGPoint(x: 183, y: 102), control: CGPoint(x: 157, y: 92))
            fineDetails.move(to: CGPoint(x: 249, y: 63))
            fineDetails.addQuadCurve(to: CGPoint(x: 217, y: 102), control: CGPoint(x: 243, y: 92))
            fineDetails.move(to: CGPoint(x: 177, y: 127))
            fineDetails.addQuadCurve(to: CGPoint(x: 223, y: 127), control: CGPoint(x: 200, y: 147))
            for index in 0..<9 {
                let t = CGFloat(index) - 4
                fineDetails.move(to: CGPoint(x: 200 + t * 9, y: 232))
                fineDetails.addQuadCurve(to: CGPoint(x: 200 + t * 30, y: 111 + abs(t) * 14), control: CGPoint(x: 200 + t * 18, y: 179))
            }
        case .phoenix:
            // Flame-cut feather shafts and engraved tail barbs.
            for index in 0..<7 {
                let offset = CGFloat(index) * 13
                fineDetails.move(to: CGPoint(x: 190, y: 143))
                fineDetails.addQuadCurve(to: CGPoint(x: 56 + offset * 1.8, y: 55 + offset), control: CGPoint(x: 114 + offset, y: 98))
                fineDetails.move(to: CGPoint(x: 210, y: 143))
                fineDetails.addQuadCurve(to: CGPoint(x: 344 - offset * 1.8, y: 55 + offset), control: CGPoint(x: 286 - offset, y: 98))
            }
            for index in 0..<5 {
                let y = CGFloat(229 + index * 8)
                fineDetails.move(to: CGPoint(x: 200, y: y))
                fineDetails.addLine(to: CGPoint(x: 200 - CGFloat(12 + index * 4), y: y + 22))
                fineDetails.move(to: CGPoint(x: 200, y: y))
                fineDetails.addLine(to: CGPoint(x: 200 + CGFloat(12 + index * 4), y: y + 22))
            }
        case .spiral:
            for radius in [CGFloat(24), 31, 38] {
                fineDetails.addEllipse(in: CGRect(x: 200 - radius, y: 150 - radius, width: radius * 2, height: radius * 2))
            }
            for index in 0..<24 {
                let angle = CGFloat(index) * .pi / 12
                fineDetails.move(to: CGPoint(x: 200 + cos(angle) * 120, y: 150 + sin(angle) * 120))
                fineDetails.addLine(to: CGPoint(x: 200 + cos(angle) * 130, y: 150 + sin(angle) * 130))
            }
        case .cat:
            // Inner ears, paired eyes, nose, whiskers and chest/fur contours.
            fineDetails.move(to: CGPoint(x: 132, y: 121))
            fineDetails.addLine(to: CGPoint(x: 151, y: 143))
            fineDetails.move(to: CGPoint(x: 265, y: 142))
            fineDetails.addLine(to: CGPoint(x: 278, y: 121))
            fineDetails.addEllipse(in: CGRect(x: 184, y: 151, width: 10, height: 7))
            fineDetails.addEllipse(in: CGRect(x: 222, y: 151, width: 10, height: 7))
            fineDetails.move(to: CGPoint(x: 203, y: 165))
            fineDetails.addLine(to: CGPoint(x: 211, y: 165))
            for offset in [CGFloat(-1), CGFloat(0), CGFloat(1)] {
                fineDetails.move(to: CGPoint(x: 192, y: 171 + offset * 4))
                fineDetails.addLine(to: CGPoint(x: 145, y: 163 + offset * 7))
                fineDetails.move(to: CGPoint(x: 224, y: 171 + offset * 4))
                fineDetails.addLine(to: CGPoint(x: 270, y: 163 + offset * 7))
            }
            fineDetails.move(to: CGPoint(x: 178, y: 190))
            fineDetails.addQuadCurve(to: CGPoint(x: 225, y: 190), control: CGPoint(x: 201, y: 211))
        case .wolf:
            // Layered cheek fur, neck ruff, muzzle, nose and shoulder fur.
            for index in 0..<5 {
                let x = CGFloat(169 + index * 10)
                fineDetails.move(to: CGPoint(x: x, y: 164 + CGFloat(index % 2) * 5))
                fineDetails.addQuadCurve(to: CGPoint(x: x + 17, y: 196 + CGFloat(index % 2) * 4), control: CGPoint(x: x - 2, y: 185))
            }
            fineDetails.move(to: CGPoint(x: 284, y: 143))
            fineDetails.addQuadCurve(to: CGPoint(x: 318, y: 145), control: CGPoint(x: 301, y: 157))
            fineDetails.addEllipse(in: CGRect(x: 316, y: 139, width: 8, height: 5))
            fineDetails.move(to: CGPoint(x: 191, y: 213))
            fineDetails.addLine(to: CGPoint(x: 181, y: 240))
            fineDetails.move(to: CGPoint(x: 207, y: 216))
            fineDetails.addLine(to: CGPoint(x: 207, y: 245))
        case .bird:
            // Individual flight feathers, layered covert feathers and tail quills.
            for index in 0..<6 {
                let offset = CGFloat(index) * 13
                fineDetails.move(to: CGPoint(x: 190, y: 161))
                fineDetails.addQuadCurve(to: CGPoint(x: 35 + offset, y: 79 + offset * 0.18), control: CGPoint(x: 104 + offset * 0.45, y: 117 + offset * 0.12))
                fineDetails.move(to: CGPoint(x: 210, y: 161))
                fineDetails.addQuadCurve(to: CGPoint(x: 365 - offset, y: 79 + offset * 0.18), control: CGPoint(x: 296 - offset * 0.45, y: 117 + offset * 0.12))
            }
            fineDetails.move(to: CGPoint(x: 194, y: 165))
            fineDetails.addLine(to: CGPoint(x: 200, y: 205))
            fineDetails.addLine(to: CGPoint(x: 206, y: 165))
            fineDetails.move(to: CGPoint(x: 205, y: 157))
            fineDetails.addLine(to: CGPoint(x: 226, y: 163))
        case .snake:
            // Hood eye-spots, scale rows following the S-shaped body and jaw line.
            for y in stride(from: CGFloat(58), through: CGFloat(91), by: CGFloat(11)) {
                fineDetails.addEllipse(in: CGRect(x: 143, y: y, width: 15, height: 8))
                fineDetails.addEllipse(in: CGRect(x: 242, y: y, width: 15, height: 8))
            }
            for index in 0..<7 {
                let y = CGFloat(157 + index * 13)
                let x = CGFloat(177 + (index % 2) * 8)
                fineDetails.move(to: CGPoint(x: x, y: y))
                fineDetails.addQuadCurve(to: CGPoint(x: x + 36, y: y + 3), control: CGPoint(x: x + 18, y: y + 10))
            }
            fineDetails.move(to: CGPoint(x: 178, y: 105))
            fineDetails.addQuadCurve(to: CGPoint(x: 222, y: 105), control: CGPoint(x: 200, y: 119))
        case .dragon:
            // Painterly scale texture following the curled torso and soft facial planes.
            for row in 0..<4 {
                let y = CGFloat(164 + row * 10)
                for col in 0..<4 {
                    let x = CGFloat(142 + col * 12)
                    fineDetails.move(to: CGPoint(x: x, y: y))
                    fineDetails.addQuadCurve(to: CGPoint(x: x + 8, y: y + 4), control: CGPoint(x: x + 4, y: y + 7))
                }
            }
            for index in 0..<5 {
                let x = CGFloat(225 + index * 12)
                fineDetails.move(to: CGPoint(x: x, y: 83 + CGFloat(index % 2) * 5))
                fineDetails.addQuadCurve(to: CGPoint(x: x + 8, y: 89 + CGFloat(index % 2) * 5), control: CGPoint(x: x + 4, y: 98))
            }
            // Delicate membrane striations in the folded wing.
            for index in 0..<4 {
                let offset = CGFloat(index) * 10
                fineDetails.move(to: CGPoint(x: 199 + offset, y: 160 + offset * 0.35))
                fineDetails.addQuadCurve(to: CGPoint(x: 246 - offset * 0.4, y: 195 + offset * 0.25), control: CGPoint(x: 233 + offset * 0.3, y: 169 + offset))
            }
            // Tiny pale spots on the prosthetic fin are represented in the shared tint.
            for dot in [CGPoint(x: 52, y: 83), CGPoint(x: 64, y: 91), CGPoint(x: 76, y: 99)] {
                fineDetails.addEllipse(in: CGRect(x: dot.x, y: dot.y, width: 4, height: 4))
            }
            fineDetails.move(to: CGPoint(x: 174, y: 146))
            fineDetails.addEllipse(in: CGRect(x: 174, y: 145, width: 3, height: 3))
            fineDetails.addEllipse(in: CGRect(x: 226, y: 145, width: 3, height: 3))
        case .mermaid:
            // Flowing hair strands, face, collarbone, fin rays and tail scales.
            for index in 0..<5 {
                let offset = CGFloat(index) * 8
                fineDetails.move(to: CGPoint(x: 177 + offset, y: 57))
                fineDetails.addCurve(to: CGPoint(x: 119 + offset * 0.55, y: 132), control1: CGPoint(x: 144 + offset, y: 76), control2: CGPoint(x: 127 + offset, y: 111))
            }
            fineDetails.addEllipse(in: CGRect(x: 194, y: 73, width: 5, height: 5))
            fineDetails.addEllipse(in: CGRect(x: 216, y: 73, width: 5, height: 5))
            fineDetails.move(to: CGPoint(x: 197, y: 91))
            fineDetails.addQuadCurve(to: CGPoint(x: 215, y: 91), control: CGPoint(x: 206, y: 98))
            for index in 0..<5 {
                let offset = CGFloat(index) * 11
                fineDetails.move(to: CGPoint(x: 219 + offset, y: 254 - offset * 0.12))
                fineDetails.addQuadCurve(to: CGPoint(x: 280 + offset * 0.25, y: 270 - offset * 0.1), control: CGPoint(x: 248 + offset * 0.45, y: 278))
            }
            for index in 0..<4 {
                let y = CGFloat(220 + index * 8)
                fineDetails.move(to: CGPoint(x: 183, y: y))
                fineDetails.addQuadCurve(to: CGPoint(x: 230, y: y + 2), control: CGPoint(x: 206, y: y + 8))
            }
            // Seaweed-like fronds, drifting bubbles and finer scale cross-lines.
            for index in 0..<4 {
                let x = CGFloat(120 + index * 15)
                fineDetails.move(to: CGPoint(x: x, y: 190))
                fineDetails.addCurve(to: CGPoint(x: x - 20, y: 252), control1: CGPoint(x: x - 28, y: 210), control2: CGPoint(x: x - 6, y: 237))
                fineDetails.move(to: CGPoint(x: x + 5, y: 198))
                fineDetails.addCurve(to: CGPoint(x: x + 28, y: 248), control1: CGPoint(x: x + 30, y: 217), control2: CGPoint(x: x + 12, y: 237))
            }
            for bubble in [CGPoint(x: 92, y: 118), CGPoint(x: 108, y: 92), CGPoint(x: 294, y: 181), CGPoint(x: 314, y: 158)] {
                fineDetails.addEllipse(in: CGRect(x: bubble.x, y: bubble.y, width: 5, height: 5))
            }
        case .paw:
            // Engraved bear-paw detail with a tiny woodland scene inside the heel pad.
            fineDetails.move(to: CGPoint(x: 157, y: 210))
            fineDetails.addQuadCurve(to: CGPoint(x: 243, y: 210), control: CGPoint(x: 200, y: 181))
            fineDetails.move(to: CGPoint(x: 157, y: 210))
            fineDetails.addQuadCurve(to: CGPoint(x: 169, y: 239), control: CGPoint(x: 155, y: 231))
            fineDetails.move(to: CGPoint(x: 243, y: 210))
            fineDetails.addQuadCurve(to: CGPoint(x: 231, y: 239), control: CGPoint(x: 245, y: 231))
            // Ground line and three layered pine silhouettes.
            fineDetails.move(to: CGPoint(x: 163, y: 238))
            fineDetails.addQuadCurve(to: CGPoint(x: 237, y: 238), control: CGPoint(x: 200, y: 243))
            for tree in [(CGFloat(178), CGFloat(226), CGFloat(13)), (CGFloat(200), CGFloat(215), CGFloat(20)), (CGFloat(222), CGFloat(226), CGFloat(13))] {
                let (x, base, height) = tree
                fineDetails.move(to: CGPoint(x: x, y: base))
                fineDetails.addLine(to: CGPoint(x: x, y: base - height))
                fineDetails.move(to: CGPoint(x: x, y: base - height * 0.88))
                fineDetails.addLine(to: CGPoint(x: x - height * 0.42, y: base - height * 0.38))
                fineDetails.addLine(to: CGPoint(x: x + height * 0.42, y: base - height * 0.38))
                fineDetails.move(to: CGPoint(x: x, y: base - height * 0.62))
                fineDetails.addLine(to: CGPoint(x: x - height * 0.34, y: base - height * 0.16))
                fineDetails.addLine(to: CGPoint(x: x + height * 0.34, y: base - height * 0.16))
            }
            // Fine toe-pad rims and curved crease marks.
            for (x, y, w, h) in [
                (CGFloat(101), CGFloat(101), CGFloat(37), CGFloat(45)),
                (CGFloat(163), CGFloat(67), CGFloat(36), CGFloat(45)),
                (CGFloat(221), CGFloat(67), CGFloat(36), CGFloat(45)),
                (CGFloat(264), CGFloat(101), CGFloat(37), CGFloat(45))
            ] {
                fineDetails.addEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            }
            fineDetails.move(to: CGPoint(x: 177, y: 194))
            fineDetails.addQuadCurve(to: CGPoint(x: 223, y: 194), control: CGPoint(x: 200, y: 184))
        case .stars:
            // A layered inner star and fine orbit-like sparkle accents.
            fineDetails.move(to: CGPoint(x: 200, y: 78))
            fineDetails.addLine(to: CGPoint(x: 211, y: 157))
            fineDetails.addLine(to: CGPoint(x: 292, y: 172))
            fineDetails.addLine(to: CGPoint(x: 211, y: 187))
            fineDetails.addLine(to: CGPoint(x: 200, y: 246))
            fineDetails.addLine(to: CGPoint(x: 189, y: 187))
            fineDetails.addLine(to: CGPoint(x: 108, y: 172))
            fineDetails.addLine(to: CGPoint(x: 189, y: 157))
            fineDetails.closeSubpath()
            fineDetails.addEllipse(in: CGRect(x: 194, y: 166, width: 12, height: 12))
            // A delicate dotted constellation path links three differently sized stars.
            for index in 0..<18 {
                let t = CGFloat(index) / 17
                let x = 106 + t * 190
                let y = 224 - sin(t * .pi * 1.5) * 108
                fineDetails.addEllipse(in: CGRect(x: x, y: y, width: 2.8, height: 2.8))
            }
            for center in [CGPoint(x: 95, y: 229), CGPoint(x: 302, y: 105), CGPoint(x: 316, y: 237)] {
                fineDetails.move(to: CGPoint(x: center.x, y: center.y - 13))
                fineDetails.addLine(to: CGPoint(x: center.x + 3, y: center.y - 3))
                fineDetails.addLine(to: CGPoint(x: center.x + 13, y: center.y))
                fineDetails.addLine(to: CGPoint(x: center.x + 3, y: center.y + 3))
                fineDetails.addLine(to: CGPoint(x: center.x, y: center.y + 13))
                fineDetails.addLine(to: CGPoint(x: center.x - 3, y: center.y + 3))
                fineDetails.addLine(to: CGPoint(x: center.x - 13, y: center.y))
                fineDetails.addLine(to: CGPoint(x: center.x - 3, y: center.y - 3))
                fineDetails.closeSubpath()
            }
        case .crescentMoon:
            // Lunar maria, delicate hanging bead chains, stars and a tiny heart.
            fineDetails.addEllipse(in: CGRect(x: 224, y: 83, width: 22, height: 15))
            fineDetails.addEllipse(in: CGRect(x: 185, y: 135, width: 30, height: 21))
            fineDetails.addEllipse(in: CGRect(x: 169, y: 194, width: 18, height: 13))
            fineDetails.move(to: CGPoint(x: 246, y: 103))
            fineDetails.addQuadCurve(to: CGPoint(x: 190, y: 225), control: CGPoint(x: 250, y: 186))
            fineDetails.move(to: CGPoint(x: 260, y: 126))
            fineDetails.addQuadCurve(to: CGPoint(x: 213, y: 239), control: CGPoint(x: 256, y: 205))
            for chain in 0..<4 {
                let x = CGFloat(157 + chain * 29)
                let endY = CGFloat(252 + (chain % 2) * 18)
                fineDetails.move(to: CGPoint(x: x, y: 194))
                fineDetails.addLine(to: CGPoint(x: x + CGFloat(chain - 2) * 4, y: endY))
                for bead in 0..<5 {
                    let y = CGFloat(204 + bead * 9)
                    fineDetails.addEllipse(in: CGRect(x: x - 2, y: y, width: 4, height: 4))
                }
            }
            // Hanging four-point stars and a small heart ornament.
            for center in [CGPoint(x: 145, y: 258), CGPoint(x: 255, y: 270), CGPoint(x: 202, y: 286)] {
                fineDetails.move(to: CGPoint(x: center.x, y: center.y - 9))
                fineDetails.addLine(to: CGPoint(x: center.x + 3, y: center.y - 3))
                fineDetails.addLine(to: CGPoint(x: center.x + 9, y: center.y))
                fineDetails.addLine(to: CGPoint(x: center.x + 3, y: center.y + 3))
                fineDetails.addLine(to: CGPoint(x: center.x, y: center.y + 9))
                fineDetails.addLine(to: CGPoint(x: center.x - 3, y: center.y + 3))
                fineDetails.addLine(to: CGPoint(x: center.x - 9, y: center.y))
                fineDetails.addLine(to: CGPoint(x: center.x - 3, y: center.y - 3))
                fineDetails.closeSubpath()
            }
        case .sun:
            // Concentric corona rings and engraved ray divisions.
            fineDetails.addEllipse(in: CGRect(x: 154, y: 104, width: 92, height: 92))
            fineDetails.addEllipse(in: CGRect(x: 164, y: 114, width: 72, height: 72))
            for angle in stride(from: CGFloat(0), to: CGFloat(360), by: CGFloat(45)) {
                let radians = angle * .pi / 180
                let inner = CGPoint(x: 200 + cos(radians) * 91, y: 150 + sin(radians) * 91)
                let outer = CGPoint(x: 200 + cos(radians) * 104, y: 150 + sin(radians) * 104)
                fineDetails.move(to: inner)
                fineDetails.addLine(to: outer)
            }
        default:
            break
        }
        let fineDetailColor = motifTint.opacity(min(1, opacity * brightness * 0.78))
        drawing.stroke(fineDetails, with: .color(fineDetailColor), style: StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round))

        // Micro-anatomy pass: small contour marks make the creatures read as
        // illustrated animals rather than flat cut-out symbols. All marks use
        // the selected animation tint and inherit the user's opacity/brightness.
        var microDetails = Path()
        switch shape {
        case .dragon:
            // Night-Fury facial planes, nostrils, jaw, neck folds and wing structure.
            microDetails.move(to: CGPoint(x: 242, y: 95))
            microDetails.addQuadCurve(to: CGPoint(x: 281, y: 101), control: CGPoint(x: 260, y: 88))
            microDetails.move(to: CGPoint(x: 282, y: 116))
            microDetails.addQuadCurve(to: CGPoint(x: 306, y: 116), control: CGPoint(x: 296, y: 122))
            microDetails.addEllipse(in: CGRect(x: 292, y: 106, width: 3.2, height: 2.2))
            microDetails.addEllipse(in: CGRect(x: 302, y: 108, width: 3.2, height: 2.2))
            microDetails.move(to: CGPoint(x: 281, y: 126))
            microDetails.addQuadCurve(to: CGPoint(x: 303, y: 123), control: CGPoint(x: 294, y: 132))
            microDetails.move(to: CGPoint(x: 254, y: 136))
            microDetails.addQuadCurve(to: CGPoint(x: 286, y: 137), control: CGPoint(x: 269, y: 145))
            microDetails.move(to: CGPoint(x: 223, y: 111))
            microDetails.addQuadCurve(to: CGPoint(x: 241, y: 125), control: CGPoint(x: 225, y: 123))
            microDetails.move(to: CGPoint(x: 211, y: 132))
            microDetails.addQuadCurve(to: CGPoint(x: 229, y: 145), control: CGPoint(x: 216, y: 143))
            microDetails.move(to: CGPoint(x: 188, y: 166))
            microDetails.addQuadCurve(to: CGPoint(x: 166, y: 204), control: CGPoint(x: 172, y: 176))
            microDetails.move(to: CGPoint(x: 169, y: 211))
            microDetails.addQuadCurve(to: CGPoint(x: 137, y: 199), control: CGPoint(x: 149, y: 219))
            // Fine wing spars and membrane tension lines.
            for index in 0..<5 {
                let t = CGFloat(index)
                microDetails.move(to: CGPoint(x: 198 + t * 5, y: 157 + t * 2))
                microDetails.addQuadCurve(
                    to: CGPoint(x: 252 - t * 7, y: 207 - t * 3),
                    control: CGPoint(x: 231 + t * 2, y: 174 + t * 5)
                )
            }
            // Small toe separations and hooked claws.
            microDetails.move(to: CGPoint(x: 239, y: 188))
            microDetails.addLine(to: CGPoint(x: 247, y: 195))
            microDetails.addLine(to: CGPoint(x: 243, y: 199))
            microDetails.move(to: CGPoint(x: 230, y: 193))
            microDetails.addLine(to: CGPoint(x: 236, y: 200))
            microDetails.addLine(to: CGPoint(x: 232, y: 203))
            // Tail-fin ribbing and its characteristic split.
            microDetails.move(to: CGPoint(x: 42, y: 82))
            microDetails.addQuadCurve(to: CGPoint(x: 79, y: 103), control: CGPoint(x: 57, y: 91))
            microDetails.move(to: CGPoint(x: 73, y: 91))
            microDetails.addQuadCurve(to: CGPoint(x: 95, y: 105), control: CGPoint(x: 84, y: 95))
            microDetails.move(to: CGPoint(x: 79, y: 113))
            microDetails.addQuadCurve(to: CGPoint(x: 97, y: 113), control: CGPoint(x: 88, y: 119))
        case .bird:
            // Beak, eye ring, layered flight-feather shafts and separated talons.
            microDetails.addEllipse(in: CGRect(x: 207, y: 143, width: 7, height: 7))
            microDetails.move(to: CGPoint(x: 214, y: 151))
            microDetails.addLine(to: CGPoint(x: 233, y: 157))
            microDetails.addLine(to: CGPoint(x: 214, y: 161))
            microDetails.move(to: CGPoint(x: 194, y: 174))
            microDetails.addQuadCurve(to: CGPoint(x: 200, y: 211), control: CGPoint(x: 190, y: 194))
            microDetails.addQuadCurve(to: CGPoint(x: 206, y: 174), control: CGPoint(x: 210, y: 194))
            for index in 0..<7 {
                let t = CGFloat(index)
                microDetails.move(to: CGPoint(x: 184 - t * 3, y: 158 + t * 2))
                microDetails.addQuadCurve(to: CGPoint(x: 39 + t * 13, y: 83 + t * 8), control: CGPoint(x: 106 + t * 8, y: 127 + t * 4))
                microDetails.move(to: CGPoint(x: 216 + t * 3, y: 158 + t * 2))
                microDetails.addQuadCurve(to: CGPoint(x: 361 - t * 13, y: 83 + t * 8), control: CGPoint(x: 294 - t * 8, y: 127 + t * 4))
            }
            microDetails.move(to: CGPoint(x: 187, y: 218))
            microDetails.addLine(to: CGPoint(x: 177, y: 239))
            microDetails.addLine(to: CGPoint(x: 191, y: 233))
            microDetails.move(to: CGPoint(x: 213, y: 218))
            microDetails.addLine(to: CGPoint(x: 223, y: 239))
            microDetails.addLine(to: CGPoint(x: 209, y: 233))
        case .snake:
            // Paired hood markings, vertical pupils, belly scutes and forked tongue.
            for y in stride(from: CGFloat(54), through: CGFloat(86), by: CGFloat(10)) {
                microDetails.addEllipse(in: CGRect(x: 132, y: y, width: 12, height: 7))
                microDetails.addEllipse(in: CGRect(x: 256, y: y, width: 12, height: 7))
            }
            microDetails.move(to: CGPoint(x: 166, y: 66))
            microDetails.addLine(to: CGPoint(x: 166, y: 76))
            microDetails.move(to: CGPoint(x: 234, y: 66))
            microDetails.addLine(to: CGPoint(x: 234, y: 76))
            for index in 0..<8 {
                let y = CGFloat(166 + index * 12)
                let inset = CGFloat(index) * 1.7
                microDetails.move(to: CGPoint(x: 181 + inset, y: y))
                microDetails.addQuadCurve(to: CGPoint(x: 219 - inset, y: y), control: CGPoint(x: 200, y: y + 6))
            }
            microDetails.move(to: CGPoint(x: 200, y: 103))
            microDetails.addLine(to: CGPoint(x: 200, y: 128))
            microDetails.addLine(to: CGPoint(x: 193, y: 139))
            microDetails.move(to: CGPoint(x: 200, y: 128))
            microDetails.addLine(to: CGPoint(x: 207, y: 139))
        case .wolf:
            // Brow, eye socket, nose bridge, muzzle split and cheek-fur notches.
            microDetails.move(to: CGPoint(x: 274, y: 118))
            microDetails.addQuadCurve(to: CGPoint(x: 298, y: 126), control: CGPoint(x: 288, y: 112))
            microDetails.addEllipse(in: CGRect(x: 282, y: 125, width: 7, height: 5))
            microDetails.move(to: CGPoint(x: 290, y: 139))
            microDetails.addQuadCurve(to: CGPoint(x: 322, y: 145), control: CGPoint(x: 308, y: 134))
            microDetails.addEllipse(in: CGRect(x: 316, y: 139, width: 7, height: 5))
            microDetails.move(to: CGPoint(x: 303, y: 148))
            microDetails.addQuadCurve(to: CGPoint(x: 292, y: 160), control: CGPoint(x: 302, y: 158))
            for index in 0..<6 {
                let x = CGFloat(160 + index * 9)
                microDetails.move(to: CGPoint(x: x, y: 169 + CGFloat(index % 2) * 4))
                microDetails.addLine(to: CGPoint(x: x - 9, y: 185 + CGFloat(index % 2) * 4))
            }
        case .fox:
            // Facial mask, pointed muzzle, inner ear edges and tail-tip banding.
            microDetails.move(to: CGPoint(x: 166, y: 111))
            microDetails.addQuadCurve(to: CGPoint(x: 199, y: 145), control: CGPoint(x: 174, y: 139))
            microDetails.move(to: CGPoint(x: 234, y: 111))
            microDetails.addQuadCurve(to: CGPoint(x: 201, y: 145), control: CGPoint(x: 226, y: 139))
            microDetails.addEllipse(in: CGRect(x: 194, y: 147, width: 8, height: 6))
            microDetails.move(to: CGPoint(x: 198, y: 153))
            microDetails.addLine(to: CGPoint(x: 190, y: 164))
            microDetails.addLine(to: CGPoint(x: 202, y: 160))
            microDetails.move(to: CGPoint(x: 155, y: 72))
            microDetails.addQuadCurve(to: CGPoint(x: 180, y: 111), control: CGPoint(x: 158, y: 98))
            microDetails.move(to: CGPoint(x: 245, y: 72))
            microDetails.addQuadCurve(to: CGPoint(x: 220, y: 111), control: CGPoint(x: 242, y: 98))
            for index in 0..<4 {
                let y = CGFloat(231 + index * 7)
                microDetails.move(to: CGPoint(x: 166, y: y))
                microDetails.addQuadCurve(to: CGPoint(x: 234, y: y), control: CGPoint(x: 200, y: y + 8))
            }
        case .phoenix:
            // Feather barbs branching from the main flight feathers.
            for index in 0..<8 {
                let t = CGFloat(index)
                let x = 70 + t * 11
                let y = 67 + t * 7
                microDetails.move(to: CGPoint(x: 119 + t * 4, y: 104 + t * 3))
                microDetails.addLine(to: CGPoint(x: x, y: y))
                microDetails.move(to: CGPoint(x: 281 - t * 4, y: 104 + t * 3))
                microDetails.addLine(to: CGPoint(x: 330 - t * 11, y: y))
            }
            for index in 0..<6 {
                let y = CGFloat(230 + index * 7)
                microDetails.move(to: CGPoint(x: 200, y: y))
                microDetails.addQuadCurve(to: CGPoint(x: 178, y: y + 15), control: CGPoint(x: 184, y: y + 5))
                microDetails.move(to: CGPoint(x: 200, y: y))
                microDetails.addQuadCurve(to: CGPoint(x: 222, y: y + 15), control: CGPoint(x: 216, y: y + 5))
            }
        case .cat:
            // Fine brow arcs and layered cheek whisker follicles.
            microDetails.move(to: CGPoint(x: 181, y: 145))
            microDetails.addQuadCurve(to: CGPoint(x: 198, y: 149), control: CGPoint(x: 189, y: 140))
            microDetails.move(to: CGPoint(x: 219, y: 149))
            microDetails.addQuadCurve(to: CGPoint(x: 236, y: 145), control: CGPoint(x: 228, y: 140))
            for index in 0..<4 {
                let y = CGFloat(171 + index * 5)
                microDetails.addEllipse(in: CGRect(x: 181, y: y, width: 2, height: 2))
                microDetails.addEllipse(in: CGRect(x: 232, y: y, width: 2, height: 2))
            }
        case .mermaid:
            // Finger separations, shoulder contours and individual fin rays.
            microDetails.move(to: CGPoint(x: 250, y: 177))
            microDetails.addLine(to: CGPoint(x: 265, y: 183))
            microDetails.addLine(to: CGPoint(x: 260, y: 189))
            microDetails.move(to: CGPoint(x: 139, y: 177))
            microDetails.addLine(to: CGPoint(x: 126, y: 184))
            for index in 0..<7 {
                let t = CGFloat(index)
                microDetails.move(to: CGPoint(x: 222 + t * 7, y: 252 - t * 2))
                microDetails.addQuadCurve(to: CGPoint(x: 302 + t * 3, y: 269 - t * 2), control: CGPoint(x: 260 + t * 4, y: 282 - t * 2))
            }
        case .paw:
            // Fine toe creases and individual claw arcs around each pad.
            for (x, y) in [(CGFloat(118), CGFloat(108)), (CGFloat(180), CGFloat(72)), (CGFloat(235), CGFloat(72)), (CGFloat(291), CGFloat(108))] {
                microDetails.move(to: CGPoint(x: x, y: y))
                microDetails.addQuadCurve(to: CGPoint(x: x + 17, y: y + 24), control: CGPoint(x: x + 22, y: y + 7))
            }
            microDetails.move(to: CGPoint(x: 163, y: 246))
            microDetails.addQuadCurve(to: CGPoint(x: 237, y: 246), control: CGPoint(x: 200, y: 258))
        default:
            break
        }
        let microDetailColor = motifTint.opacity(min(1, opacity * brightness * 0.62))
        drawing.stroke(microDetails, with: .color(microDetailColor), style: StrokeStyle(lineWidth: 1.05, lineCap: .round, lineJoin: .round))

        // A second, illustration-led engraving pass translates the approved concept
        // sheet into the in-app vectors. Keep every mark in the selected motif hue.
        var conceptDetails = Path()
        switch shape {
        case .dragon:
            // Night-Fury facial planes, ribbed folded wing, shoulder scales and fin webbing.
            conceptDetails.move(to: CGPoint(x: 251, y: 91))
            conceptDetails.addQuadCurve(to: CGPoint(x: 282, y: 103), control: CGPoint(x: 267, y: 85))
            conceptDetails.move(to: CGPoint(x: 257, y: 119))
            conceptDetails.addQuadCurve(to: CGPoint(x: 281, y: 126), control: CGPoint(x: 270, y: 132))
            for index in 0..<4 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 195 + t * 7, y: 160 + t * 3))
                conceptDetails.addQuadCurve(to: CGPoint(x: 244 + t * 3, y: 203 - t * 2), control: CGPoint(x: 226 + t * 5, y: 168 + t * 5))
            }
            for index in 0..<3 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 48 + t * 8, y: 86 + t * 7))
                conceptDetails.addQuadCurve(to: CGPoint(x: 83 + t * 5, y: 105 + t * 5), control: CGPoint(x: 61 + t * 7, y: 94 + t * 6))
            }
        case .bird:
            // Hawk flight feathers, layered covert rows and hooked beak accents.
            for index in 0..<5 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 188 - t * 5, y: 160 + t * 4))
                conceptDetails.addQuadCurve(to: CGPoint(x: 45 + t * 19, y: 86 + t * 12), control: CGPoint(x: 111 + t * 8, y: 128 + t * 5))
                conceptDetails.move(to: CGPoint(x: 212 + t * 5, y: 160 + t * 4))
                conceptDetails.addQuadCurve(to: CGPoint(x: 355 - t * 19, y: 86 + t * 12), control: CGPoint(x: 289 - t * 8, y: 128 + t * 5))
            }
            conceptDetails.move(to: CGPoint(x: 203, y: 147))
            conceptDetails.addQuadCurve(to: CGPoint(x: 224, y: 157), control: CGPoint(x: 220, y: 144))
        case .snake:
            // Cobra hood ribbing and belly plate segmentation.
            for index in 0..<5 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 133 + t * 3, y: 65 + t * 8))
                conceptDetails.addQuadCurve(to: CGPoint(x: 166 + t * 2, y: 103 + t * 3), control: CGPoint(x: 140 + t * 4, y: 93 + t * 5))
                conceptDetails.move(to: CGPoint(x: 267 - t * 3, y: 65 + t * 8))
                conceptDetails.addQuadCurve(to: CGPoint(x: 234 - t * 2, y: 103 + t * 3), control: CGPoint(x: 260 - t * 4, y: 93 + t * 5))
            }
            for index in 0..<6 {
                let y = CGFloat(176 + index * 10)
                conceptDetails.move(to: CGPoint(x: 181, y: y))
                conceptDetails.addQuadCurve(to: CGPoint(x: 219, y: y), control: CGPoint(x: 200, y: y + 5))
            }
        case .fox:
            // Nine-tail fur flow and cheek-mask engraving.
            for index in 0..<4 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 164 + t * 5, y: 173 + t * 8))
                conceptDetails.addQuadCurve(to: CGPoint(x: 118 + t * 10, y: 244 - t * 3), control: CGPoint(x: 128 + t * 8, y: 191 + t * 9))
                conceptDetails.move(to: CGPoint(x: 236 - t * 5, y: 173 + t * 8))
                conceptDetails.addQuadCurve(to: CGPoint(x: 282 - t * 10, y: 244 - t * 3), control: CGPoint(x: 272 - t * 8, y: 191 + t * 9))
            }
            conceptDetails.move(to: CGPoint(x: 175, y: 117))
            conceptDetails.addQuadCurve(to: CGPoint(x: 198, y: 146), control: CGPoint(x: 181, y: 141))
            conceptDetails.move(to: CGPoint(x: 225, y: 117))
            conceptDetails.addQuadCurve(to: CGPoint(x: 202, y: 146), control: CGPoint(x: 219, y: 141))
        case .phoenix:
            // Layered flight-feather barbs and flame-like tail vanes.
            for index in 0..<6 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 192 - t * 4, y: 129 + t * 5))
                conceptDetails.addQuadCurve(to: CGPoint(x: 78 + t * 17, y: 52 + t * 12), control: CGPoint(x: 125 + t * 12, y: 92 + t * 7))
                conceptDetails.move(to: CGPoint(x: 208 + t * 4, y: 129 + t * 5))
                conceptDetails.addQuadCurve(to: CGPoint(x: 322 - t * 17, y: 52 + t * 12), control: CGPoint(x: 275 - t * 12, y: 92 + t * 7))
            }
            for index in 0..<4 {
                let y = CGFloat(232 + index * 8)
                conceptDetails.move(to: CGPoint(x: 198, y: y))
                conceptDetails.addQuadCurve(to: CGPoint(x: 151, y: y + 35), control: CGPoint(x: 172, y: y + 15))
                conceptDetails.move(to: CGPoint(x: 202, y: y))
                conceptDetails.addQuadCurve(to: CGPoint(x: 249, y: y + 35), control: CGPoint(x: 228, y: y + 15))
            }
        case .wolf:
            // Layered cheek fur, neck ruff and shoulder direction lines.
            for index in 0..<5 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 270 + t * 5, y: 151 + t * 4))
                conceptDetails.addLine(to: CGPoint(x: 291 + t * 4, y: 166 + t * 5))
                conceptDetails.move(to: CGPoint(x: 256 - t * 4, y: 172 + t * 7))
                conceptDetails.addQuadCurve(to: CGPoint(x: 220 - t * 3, y: 225 + t * 2), control: CGPoint(x: 235 - t * 3, y: 190 + t * 5))
            }
            conceptDetails.move(to: CGPoint(x: 288, y: 132))
            conceptDetails.addQuadCurve(to: CGPoint(x: 316, y: 143), control: CGPoint(x: 305, y: 129))
        case .cat:
            // Fine whiskers, forehead stripes, chest fur and curled-tail texture.
            for index in 0..<3 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 178 + t * 8, y: 137))
                conceptDetails.addQuadCurve(to: CGPoint(x: 169 + t * 7, y: 154), control: CGPoint(x: 173 + t * 8, y: 145))
                conceptDetails.move(to: CGPoint(x: 222 - t * 8, y: 137))
                conceptDetails.addQuadCurve(to: CGPoint(x: 231 - t * 7, y: 154), control: CGPoint(x: 227 - t * 8, y: 145))
            }
            for index in 0..<3 {
                let y = CGFloat(202 + index * 8)
                conceptDetails.move(to: CGPoint(x: 176, y: y))
                conceptDetails.addQuadCurve(to: CGPoint(x: 190, y: y + 9), control: CGPoint(x: 182, y: y + 7))
                conceptDetails.move(to: CGPoint(x: 224, y: y))
                conceptDetails.addQuadCurve(to: CGPoint(x: 210, y: y + 9), control: CGPoint(x: 218, y: y + 7))
            }
        case .mermaid:
            // Flowing hair strands, scale rows and fin-ray structure.
            for index in 0..<5 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 174 - t * 5, y: 61 + t * 4))
                conceptDetails.addCurve(to: CGPoint(x: 121 + t * 4, y: 139 + t * 2), control1: CGPoint(x: 132 - t * 2, y: 80 + t * 6), control2: CGPoint(x: 112 + t * 4, y: 112 + t * 4))
                conceptDetails.move(to: CGPoint(x: 189, y: 194 + t * 8))
                conceptDetails.addQuadCurve(to: CGPoint(x: 211, y: 194 + t * 8), control: CGPoint(x: 200, y: 201 + t * 8))
            }
            for index in 0..<5 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 215 + t * 5, y: 250 - t * 2))
                conceptDetails.addQuadCurve(to: CGPoint(x: 315 - t * 7, y: 258 - t * 3), control: CGPoint(x: 270 + t * 2, y: 276 - t * 2))
            }
        case .paw:
            // Anatomical toe creases and a softly segmented central pad.
            for index in 0..<4 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 112 + t * 57, y: 104))
                conceptDetails.addQuadCurve(to: CGPoint(x: 130 + t * 47, y: 136), control: CGPoint(x: 128 + t * 44, y: 119))
            }
            conceptDetails.move(to: CGPoint(x: 169, y: 207))
            conceptDetails.addQuadCurve(to: CGPoint(x: 231, y: 207), control: CGPoint(x: 200, y: 221))
            conceptDetails.move(to: CGPoint(x: 159, y: 228))
            conceptDetails.addQuadCurve(to: CGPoint(x: 241, y: 228), control: CGPoint(x: 200, y: 242))
        case .stars:
            // Faceted star core, inner glint and delicate orbiting sparkles.
            conceptDetails.move(to: CGPoint(x: 200, y: 56))
            conceptDetails.addLine(to: CGPoint(x: 207, y: 151))
            conceptDetails.addLine(to: CGPoint(x: 316, y: 172))
            conceptDetails.move(to: CGPoint(x: 200, y: 56))
            conceptDetails.addLine(to: CGPoint(x: 193, y: 151))
            conceptDetails.addLine(to: CGPoint(x: 84, y: 172))
            conceptDetails.move(to: CGPoint(x: 200, y: 185))
            conceptDetails.addLine(to: CGPoint(x: 200, y: 244))
            conceptDetails.addEllipse(in: CGRect(x: 190, y: 162, width: 20, height: 20))
            for (x, y, r) in [(CGFloat(70), CGFloat(74), CGFloat(3)), (CGFloat(327), CGFloat(86), CGFloat(4)), (CGFloat(92), CGFloat(253), CGFloat(3)), (CGFloat(315), CGFloat(244), CGFloat(3))] {
                conceptDetails.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
        case .crescentMoon:
            // Lunar surface: crater rings and a fine inner crescent contour.
            conceptDetails.addEllipse(in: CGRect(x: 211, y: 83, width: 24, height: 18))
            conceptDetails.addEllipse(in: CGRect(x: 235, y: 139, width: 15, height: 12))
            conceptDetails.addEllipse(in: CGRect(x: 190, y: 195, width: 19, height: 14))
            conceptDetails.addEllipse(in: CGRect(x: 160, y: 148, width: 9, height: 7))
            conceptDetails.move(to: CGPoint(x: 258, y: 63))
            conceptDetails.addCurve(to: CGPoint(x: 177, y: 235), control1: CGPoint(x: 292, y: 153), control2: CGPoint(x: 239, y: 232))
        case .spiral:
            // Fine spiral etching and alternating ray facets.
            for index in 0..<4 {
                let t = CGFloat(index)
                conceptDetails.move(to: CGPoint(x: 200 + t * 3, y: 150 + t * 3))
                conceptDetails.addCurve(to: CGPoint(x: 222 - t * 5, y: 137 + t * 7), control1: CGPoint(x: 244 - t * 5, y: 171 + t * 3), control2: CGPoint(x: 234 - t * 6, y: 125 + t * 8))
            }
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let inner = CGPoint(x: 200 + cos(angle) * 111, y: 150 + sin(angle) * 111)
                let outer = CGPoint(x: 200 + cos(angle) * 137, y: 150 + sin(angle) * 137)
                conceptDetails.move(to: inner)
                conceptDetails.addLine(to: outer)
            }
        case .sun:
            // Sun-disc face and segmented, engraved rays.
            conceptDetails.addEllipse(in: CGRect(x: 169, y: 119, width: 62, height: 62))
            conceptDetails.move(to: CGPoint(x: 185, y: 151))
            conceptDetails.addQuadCurve(to: CGPoint(x: 215, y: 151), control: CGPoint(x: 200, y: 163))
            conceptDetails.move(to: CGPoint(x: 184, y: 139))
            conceptDetails.addQuadCurve(to: CGPoint(x: 193, y: 139), control: CGPoint(x: 188, y: 135))
            conceptDetails.move(to: CGPoint(x: 207, y: 139))
            conceptDetails.addQuadCurve(to: CGPoint(x: 216, y: 139), control: CGPoint(x: 212, y: 135))
            for angle in stride(from: CGFloat(0), to: CGFloat(360), by: CGFloat(45)) {
                let radians = angle * .pi / 180
                let inner = CGPoint(x: 200 + cos(radians) * 91, y: 150 + sin(radians) * 91)
                let outer = CGPoint(x: 200 + cos(radians) * 105, y: 150 + sin(radians) * 105)
                conceptDetails.move(to: inner)
                conceptDetails.addLine(to: outer)
            }
        }
        let conceptDetailColor = motifTint.opacity(min(1, opacity * brightness * 0.78))
        drawing.stroke(conceptDetails, with: .color(conceptDetailColor), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))

        if shape == .snake || shape == .wolf || shape == .cat || shape == .bird || shape == .fox {
            var eye = Path()
            let eyeRect: CGRect
            switch shape {
            case .snake: eyeRect = CGRect(x: 224, y: 57, width: 8, height: 6)
            case .fox: eyeRect = CGRect(x: 184, y: 126, width: 8, height: 6)
            case .wolf: eyeRect = CGRect(x: 282, y: 123, width: 7, height: 7)
            case .cat: eyeRect = CGRect(x: 245, y: 151, width: 7, height: 7)
            case .bird: eyeRect = CGRect(x: 207, y: 145, width: 9, height: 7)
            default: eyeRect = .zero
            }
            eye.addEllipse(in: eyeRect)
            drawing.fill(eye, with: .color(shape == .snake || shape == .bird ? eyeColor.opacity(min(1, opacity * 1.15)) : motifTint.opacity(min(1, opacity * 0.95))))
        }
    }
}

struct EclipseAmbientMotionBackground: View {
    let topClearance: CGFloat
    let ambientColor: Color?
    let accentColor: Color
    let motionEnabled: Bool
    var allowsAnimatedShape: Bool = true
    @AppStorage(HomeAnimatedBackgroundQuality.storageKey) private var qualityRawValue = HomeAnimatedBackgroundQuality.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundFrameRate.storageKey) private var frameRateRawValue = HomeAnimatedBackgroundFrameRate.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundParticleColor.storageKey) private var particleColorRawValue = HomeAnimatedBackgroundParticleColor.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundShape.storageKey) private var shapeRawValue = HomeAnimatedBackgroundShape.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundSettings.shapeEnabledKey) private var shapeEnabled = HomeAnimatedBackgroundSettings.defaultShapeEnabled
    @AppStorage(HomeAnimatedBackgroundSettings.shapeOpacityKey) private var shapeOpacity = HomeAnimatedBackgroundSettings.defaultShapeOpacity
    @AppStorage(HomeAnimatedBackgroundSettings.shapeSizeKey) private var shapeSize = HomeAnimatedBackgroundSettings.defaultShapeSize
    @AppStorage(HomeAnimatedBackgroundSettings.shapeGlowKey) private var shapeGlow = HomeAnimatedBackgroundSettings.defaultShapeGlow
    @AppStorage(HomeAnimatedBackgroundSettings.shapeBrightnessKey) private var shapeBrightness = HomeAnimatedBackgroundSettings.defaultShapeBrightness
    @AppStorage(HomeAnimatedBackgroundParticleColor.customColorDataKey) private var customParticleColorData = Data()

    private let particles: [(x: CGFloat, y: CGFloat, size: CGFloat, drift: CGFloat, opacity: Double)] = [
        (0.25, 0.24, 2.8, 15, 0.34),
        (0.75, 0.25, 3.2, -15, 0.38),
        (0.39, 0.42, 2.4, 12, 0.30),
        (0.63, 0.50, 2.7, -12, 0.30),
        (0.25, 0.70, 3.0, 14, 0.32),
        (0.76, 0.70, 2.8, -14, 0.32),
        (0.47, 0.18, 2.2, 11, 0.28),
        (0.53, 0.84, 3.0, -11, 0.28),
        (0.36, 0.60, 1.9, 10, 0.24),
        (0.66, 0.34, 2.1, -10, 0.24)
    ]

    private var customParticleColor: Color {
        guard let archived = try? PortableColorArchive.color(from: customParticleColorData) else { return .purple }
#if os(macOS)
        return Color(nsColor: archived)
#else
        return Color(uiColor: archived)
#endif
    }

    private var primaryColor: Color {
        HomeAnimatedBackgroundParticleColor.resolved(particleColorRawValue)
            .color(accent: ambientColor ?? accentColor, custom: customParticleColor)
    }

    private var quality: HomeAnimatedBackgroundQuality {
        HomeAnimatedBackgroundQuality.resolved(qualityRawValue)
    }

    private var frameInterval: Double {
        HomeAnimatedBackgroundFrameRate.resolved(frameRateRawValue).frameInterval
    }

    private var selectedShape: HomeAnimatedBackgroundShape {
        HomeAnimatedBackgroundShape.resolved(shapeRawValue)
    }

    @AppStorage("homeAnimatedBackgroundToothlessEyeColorData") private var toothlessEyeColorData = Data()
    @AppStorage("homeAnimatedBackgroundCobraEyeColorData") private var cobraEyeColorData = Data()
    @AppStorage("homeAnimatedBackgroundHawkEyeColorData") private var hawkEyeColorData = Data()

    private func archivedEyeColor(_ data: Data, fallback: Color) -> Color {
        guard !data.isEmpty, let archived = try? PortableColorArchive.color(from: data) else { return fallback }
#if os(macOS)
        return Color(nsColor: archived)
#else
        return Color(uiColor: archived)
#endif
    }

    private var selectedCreatureEyeColor: Color {
        switch selectedShape {
        case .dragon: return archivedEyeColor(toothlessEyeColorData, fallback: Color(red: 1.0, green: 0.78, blue: 0.20))
        case .snake: return archivedEyeColor(cobraEyeColorData, fallback: Color(red: 1.0, green: 0.72, blue: 0.20))
        case .bird: return archivedEyeColor(hawkEyeColorData, fallback: Color(red: 1.0, green: 0.82, blue: 0.34))
        default: return primaryColor
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let clearance = min(max(topClearance, 0), max(size.height, 0))
            let availableHeight = max(size.height - clearance, 1)

            if clearance > 1 {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: clearance)

                    ambientLayer(size: CGSize(width: size.width, height: availableHeight), motionEnabled: motionEnabled)
                        .frame(width: size.width, height: availableHeight)
                        .mask {
                            topFadeMask(fadeHeight: min(max(availableHeight * 0.18, 72), 160))
                        }
                }
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipped()
            } else {
                ambientLayer(size: size, motionEnabled: motionEnabled)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func topFadeMask(fadeHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .white.opacity(0.82), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)

            Color.white
        }
    }

    private func ambientLayer(size: CGSize, motionEnabled: Bool) -> some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: !motionEnabled)) { timeline in
            Canvas(opaque: false, colorMode: .linear) { context, canvasSize in
                var drawingContext = context
                drawAmbientLayer(
                    context: &drawingContext,
                    size: canvasSize,
                    date: motionEnabled ? timeline.date : Date(timeIntervalSinceReferenceDate: 0),
                    motionEnabled: motionEnabled,
                    quality: quality
                )
            }
        }
        .blendMode(.screen)
        .opacity(quality.layerOpacity)
        .compositingGroup()
    }

    private func drawAmbientLayer(
        context: inout GraphicsContext,
        size: CGSize,
        date: Date,
        motionEnabled: Bool,
        quality: HomeAnimatedBackgroundQuality
    ) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let center = CGPoint(x: width * 0.5, y: height * 0.5)
        let largeRingDiameter = min(max(min(width, height) * 1.05, 340), min(max(width, height) * 0.96, 760))
        let smallRingDiameter = min(max(min(width, height) * 0.78, 260), min(max(width, height) * 0.74, 560))
        let seconds = date.timeIntervalSinceReferenceDate
        let drift = motionEnabled ? wave(seconds: seconds, period: 19.0) : 0.5
        let pulse = motionEnabled ? wave(seconds: seconds, period: 9.6) : 0.5
        let ringRotation = motionEnabled ? -18 + 360 * normalized(seconds: seconds, period: 28.0) : -18
        let counterRingRotation = motionEnabled ? 14 - 360 * normalized(seconds: seconds, period: 36.0) : 14
        let driftX = lerp(-width * 0.018, width * 0.018, drift)
        let driftY = lerp(height * 0.012, -height * 0.012, drift)

        var pulseContext = context
        pulseContext.addFilter(.blur(radius: 2.5))
        drawEllipseStroke(
            context: &pulseContext,
            center: center,
            diameter: largeRingDiameter * lerp(0.94, 1.06, pulse) * 0.78,
            color: primaryColor.opacity(lerpDouble(0.09, 0.18, pulse)),
            lineWidth: lerp(5, 9, pulse)
        )

        drawArc(
            context: &context,
            center: shifted(center, x: driftX, y: driftY),
            radius: largeRingDiameter * 0.5 * lerp(0.992, 1.018, pulse),
            startDegrees: ringRotation + 18,
            endDegrees: ringRotation + 128,
            color: accentColor.opacity(0.30),
            lineWidth: 1.45
        )
        drawArc(
            context: &context,
            center: shifted(center, x: driftX, y: driftY),
            radius: largeRingDiameter * 0.5 * lerp(0.992, 1.018, pulse),
            startDegrees: ringRotation + 128,
            endDegrees: ringRotation + 228,
            color: primaryColor.opacity(0.22),
            lineWidth: 1.45
        )
        drawArc(
            context: &context,
            center: shifted(center, x: driftX, y: driftY),
            radius: largeRingDiameter * 0.5 * lerp(0.992, 1.018, pulse),
            startDegrees: ringRotation + 228,
            endDegrees: ringRotation + 292,
            color: Color.white.opacity(0.16),
            lineWidth: 1.45
        )

        drawArc(
            context: &context,
            center: shifted(center, x: -driftX, y: -driftY),
            radius: smallRingDiameter * 0.5 * lerp(1.02, 0.98, pulse),
            startDegrees: counterRingRotation + 29,
            endDegrees: counterRingRotation + 259,
            color: primaryColor.opacity(0.28),
            lineWidth: 1.6
        )
        drawArc(
            context: &context,
            center: shifted(center, x: -driftX, y: -driftY),
            radius: smallRingDiameter * 0.5 * lerp(1.02, 0.98, pulse),
            startDegrees: counterRingRotation + 132,
            endDegrees: counterRingRotation + 224,
            color: accentColor.opacity(0.20),
            lineWidth: 1.6
        )
        drawArc(
            context: &context,
            center: shifted(center, x: -driftX * 0.6, y: driftY * 0.6),
            radius: largeRingDiameter * 0.45,
            startDegrees: ringRotation + 79,
            endDegrees: ringRotation + 130,
            color: primaryColor.opacity(lerpDouble(0.58, 0.86, pulse)),
            lineWidth: 2.4
        )
        drawArc(
            context: &context,
            center: shifted(center, x: driftX * 0.8, y: -driftY * 0.8),
            radius: smallRingDiameter * 0.58,
            startDegrees: counterRingRotation + 160,
            endDegrees: counterRingRotation + 210,
            color: accentColor.opacity(lerpDouble(0.48, 0.74, pulse)),
            lineWidth: 2.1
        )

        for angle in [18.0, 146.0, 274.0] {
            let glintCenter = point(
                center: center,
                radius: largeRingDiameter * 0.42,
                degrees: ringRotation + angle
            )
            let glintSize = lerp(4.0, 5.4, pulse)
            var glowContext = context
            glowContext.addFilter(.blur(radius: 1.5))
            drawCircle(
                context: &glowContext,
                center: glintCenter,
                diameter: glintSize * 2.2,
                color: primaryColor.opacity(lerpDouble(0.18, 0.26, pulse))
            )
            drawCircle(
                context: &context,
                center: glintCenter,
                diameter: glintSize,
                color: Color.white.opacity(lerpDouble(0.30, 0.46, pulse))
            )
        }

        for particle in particles {
            let particleSize = particle.size * lerp(1.0, 1.25, pulse)
            let particleCenter = CGPoint(
                x: width * particle.x + lerp(-particle.drift, particle.drift, drift),
                y: height * particle.y + lerp(12, -12, drift)
            )
            drawCircle(
                context: &context,
                center: particleCenter,
                diameter: particleSize,
                color: primaryColor.opacity(particle.opacity + lerpDouble(0, 0.08, pulse))
            )
            drawCircle(
                context: &context,
                center: particleCenter,
                diameter: particleSize,
                color: Color.white.opacity(particle.opacity * lerpDouble(0.38, 0.55, pulse))
            )
        }

        if shapeEnabled && allowsAnimatedShape && shapeOpacity > 0 {
            let shapePulse = lerp(0.94, 1.06, pulse)
            let shapeCenter = CGPoint(
                x: center.x + driftX * 0.55,
                y: center.y + driftY * 0.55
            )
            let safeShapeScale = min(max(shapeSize, 0.5), 1.8)
            let motifSize = min(max(min(width, height) * 0.34, 112), 270) * shapePulse * safeShapeScale
            let motif = HomeAnimatedCreatureMotif(
                shape: selectedShape,
                color: primaryColor,
                eyeColor: selectedCreatureEyeColor,
                opacity: shapeOpacity,
                brightness: shapeBrightness,
                size: CGSize(width: motifSize * 4 / 3, height: motifSize),
                phase: seconds
            )
            let motifOrigin = CGPoint(
                x: shapeCenter.x - motifSize * 2 / 3,
                y: shapeCenter.y - motifSize / 2
            )
            var motifGlow = context
            motifGlow.addFilter(.blur(radius: 13))
            motifGlow.opacity = shapeGlow
            motifGlow.translateBy(x: motifOrigin.x, y: motifOrigin.y)
            motif.draw(in: &motifGlow, canvasSize: motif.size)

            var motifContext = context
            motifContext.translateBy(x: motifOrigin.x, y: motifOrigin.y)
            motif.draw(in: &motifContext, canvasSize: motif.size)
        }

        guard quality != .low else { return }

        drawMediumMotion(
            context: &context,
            size: size,
            center: center,
            seconds: seconds,
            drift: drift,
            pulse: pulse,
            largeRingDiameter: largeRingDiameter,
            smallRingDiameter: smallRingDiameter
        )

        guard quality == .high else { return }

        drawHighMotion(
            context: &context,
            size: size,
            center: center,
            seconds: seconds,
            drift: drift,
            pulse: pulse,
            largeRingDiameter: largeRingDiameter,
            smallRingDiameter: smallRingDiameter
        )
    }

    private struct CelestialPalette {
        let core: Color
        let cool: Color
        let warm: Color
        let bright: Color
    }

    private func drawMediumMotion(
        context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        seconds: TimeInterval,
        drift: Double,
        pulse: Double,
        largeRingDiameter: CGFloat,
        smallRingDiameter: CGFloat
    ) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let minDim = min(width, height)
        let palette = celestialPalette()

        drawVortexFilaments(
            context: &context,
            center: center,
            minRadius: smallRingDiameter * 0.30,
            maxRadius: largeRingDiameter * 0.61,
            seconds: seconds,
            arms: 2,
            steps: 48,
            turns: 0.82,
            rotationPeriod: 13.0,
            palette: palette,
            opacity: 0.20,
            lineWidth: 1.2
        )

        drawStarfield(context: &context, size: size, seconds: seconds, count: 26, seedOffset: 0, speedScale: 1.0, palette: palette)
        drawOrbitingEmbers(
            context: &context,
            center: center,
            minDim: minDim,
            seconds: seconds,
            count: 18,
            seedOffset: 0,
            palette: palette,
            intensity: 0.78
        )
        drawEnergyWavefronts(
            context: &context,
            center: center,
            minDim: minDim,
            seconds: seconds,
            count: 1,
            period: 4.6,
            palette: palette,
            opacity: 0.18
        )
        let coronaBreath = wave(seconds: seconds, period: 5.8)
        let coronaWander = wave(seconds: seconds, period: 8.4)
        drawCorona(
            context: &context,
            center: shifted(
                center,
                x: lerp(-width * 0.025, width * 0.025, coronaWander),
                y: lerp(height * 0.018, -height * 0.018, coronaBreath)
            ),
            radius: largeRingDiameter * lerp(0.62, 0.74, coronaBreath),
            color: palette.core,
            peak: lerpDouble(0.11, 0.19, coronaBreath)
        )
    }

    private func drawHighMotion(
        context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        seconds: TimeInterval,
        drift: Double,
        pulse: Double,
        largeRingDiameter: CGFloat,
        smallRingDiameter: CGFloat
    ) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let minDim = min(width, height)
        let palette = celestialPalette()

        drawVortexFilaments(
            context: &context,
            center: center,
            minRadius: smallRingDiameter * 0.18,
            maxRadius: largeRingDiameter * 0.78,
            seconds: -seconds,
            arms: 3,
            steps: 68,
            turns: 1.22,
            rotationPeriod: 10.5,
            palette: palette,
            opacity: 0.18,
            lineWidth: 1.05
        )

        drawKineticMesh(context: &context, size: size, seconds: seconds, count: 20, palette: palette)
        drawStarfield(context: &context, size: size, seconds: seconds, count: 44, seedOffset: 100, speedScale: 1.8, palette: palette)
        drawOrbitingEmbers(
            context: &context,
            center: center,
            minDim: minDim,
            seconds: -seconds * 1.16,
            count: 30,
            seedOffset: 100,
            palette: palette,
            intensity: 1.0
        )
        drawEnergyWavefronts(
            context: &context,
            center: center,
            minDim: minDim,
            seconds: seconds + 1.1,
            count: 1,
            period: 3.2,
            palette: palette,
            opacity: 0.22
        )
        drawMeteorBursts(context: &context, size: size, seconds: seconds, palette: palette)
    }

    private func drawVortexFilaments(
        context: inout GraphicsContext,
        center: CGPoint,
        minRadius: CGFloat,
        maxRadius: CGFloat,
        seconds: TimeInterval,
        arms: Int,
        steps: Int,
        turns: Double,
        rotationPeriod: Double,
        palette: CelestialPalette,
        opacity: Double,
        lineWidth: CGFloat
    ) {
        guard arms > 0, steps > 1, maxRadius > minRadius else { return }
        let rotation = 360 * normalized(seconds: seconds, period: rotationPeriod)

        for arm in 0..<arms {
            var path = Path()
            for index in 0...steps {
                let progress = Double(index) / Double(steps)
                let eased = progress * progress * (3 - 2 * progress)
                let wobble = sin(seconds * 1.05 + progress * 7.0 + Double(arm) * 1.7)
                let radius = lerp(minRadius, maxRadius, eased) + CGFloat(wobble) * maxRadius * 0.025
                let degrees = rotation
                    + Double(arm) * (360 / Double(arms))
                    + progress * 360 * turns
                    + wobble * 7
                let point = point(center: center, radius: radius, degrees: degrees)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }

            let color: Color
            switch arm % 3 {
            case 0: color = palette.cool
            case 1: color = palette.core
            default: color = palette.warm
            }
            context.stroke(
                path,
                with: .color(color.opacity(opacity * 0.22)),
                style: StrokeStyle(lineWidth: lineWidth * 4.2, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                path,
                with: .color(color.opacity(opacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawStarfield(
        context: inout GraphicsContext,
        size: CGSize,
        seconds: TimeInterval,
        count: Int,
        seedOffset: Int,
        speedScale: Double,
        palette: CelestialPalette
    ) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        for index in 0..<count {
            let seed = Double(index + seedOffset)
            let baseX = hash(seed * 3.17 + 1.0)
            let baseY = hash(seed * 5.91 + 4.2)
            let depth = hash(seed * 2.31 + 7.0)
            let travel = seconds * (0.006 + 0.012 * depth) * speedScale
            let x = width * CGFloat(unitFraction(baseX + travel * (index.isMultiple(of: 2) ? 1 : -1)))
            let y = height * CGFloat(unitFraction(baseY + travel * 0.18))
                + CGFloat(sin(seconds * (0.35 + depth * 0.4) + seed)) * (3 + 9 * CGFloat(depth))
            let twinkle = wave(
                seconds: seconds * (1.0 + depth) + seed * 0.7,
                period: 1.2 + hash(seed + 9.0) * 2.3
            )
            let position = CGPoint(x: x, y: y)
            let coreDiameter = CGFloat(0.7 + depth * 2.4) * lerp(0.65, 1.5, twinkle)
            let alpha = (0.12 + 0.54 * twinkle) * (0.42 + 0.58 * depth)
            if depth > 0.68 {
                drawSoftGlow(
                    context: &context,
                    center: position,
                    radius: coreDiameter * 3.2,
                    color: index.isMultiple(of: 3) ? palette.cool : palette.warm,
                    coreOpacity: alpha * 0.38
                )
            }
            drawCircle(context: &context, center: position, diameter: coreDiameter, color: palette.bright.opacity(min(alpha, 0.86)))
        }
    }

    private func drawOrbitingEmbers(
        context: inout GraphicsContext,
        center: CGPoint,
        minDim: CGFloat,
        seconds: TimeInterval,
        count: Int,
        seedOffset: Int,
        palette: CelestialPalette,
        intensity: Double
    ) {
        guard count > 0 else { return }
        for index in 0..<count {
            let seed = Double(index + seedOffset)
            let depth = hash(seed * 4.17 + 0.8)
            let baseRadius = minDim * CGFloat(0.17 + hash(seed * 1.91 + 3.0) * 0.52)
            let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
            let angularSpeed = direction * (10 + 23 * depth)
            let angle = hash(seed * 8.13) * 360 + seconds * angularSpeed
            let radialWobble = sin(seconds * (0.8 + depth * 0.9) + seed) * Double(minDim) * 0.025
            let radius = max(baseRadius + CGFloat(radialWobble), minDim * 0.08)
            let radians = angle * .pi / 180
            let position = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius * (0.68 + 0.18 * CGFloat(depth))
            )
            let twinkle = wave(seconds: seconds + seed, period: 1.4 + depth * 2.2)
            let diameter = CGFloat(1.2 + depth * 3.4) * lerp(0.78, 1.28, twinkle)
            let color = index.isMultiple(of: 3) ? palette.warm : palette.cool

            if index.isMultiple(of: 4) {
                drawArc(
                    context: &context,
                    center: center,
                    radius: radius,
                    startDegrees: angle - direction * (9 + depth * 15),
                    endDegrees: angle,
                    color: color.opacity(intensity * (0.08 + depth * 0.10)),
                    lineWidth: max(0.6, diameter * 0.36)
                )
            }
            drawSoftGlow(
                context: &context,
                center: position,
                radius: diameter * 3.0,
                color: color,
                coreOpacity: intensity * (0.14 + 0.20 * twinkle)
            )
            drawCircle(
                context: &context,
                center: position,
                diameter: diameter,
                color: palette.bright.opacity(min(intensity * (0.34 + 0.48 * twinkle), 0.92))
            )
        }
    }

    private func drawEnergyWavefronts(
        context: inout GraphicsContext,
        center: CGPoint,
        minDim: CGFloat,
        seconds: TimeInterval,
        count: Int,
        period: Double,
        palette: CelestialPalette,
        opacity: Double
    ) {
        guard count > 0, period > 0 else { return }
        let basePhase = normalized(seconds: seconds, period: period)
        for index in 0..<count {
            let progress = unitFraction(basePhase + Double(index) / Double(count))
            let eased = 1 - pow(1 - progress, 2)
            let fade = pow(1 - progress, 1.4)
            let diameter = minDim * CGFloat(0.36 + eased * 1.22)
            let color = index.isMultiple(of: 2) ? palette.cool : palette.warm
            drawEllipseStroke(
                context: &context,
                center: center,
                diameter: diameter,
                color: color.opacity(opacity * fade),
                lineWidth: lerp(2.6, 0.55, progress)
            )
        }
    }

    private func drawKineticMesh(
        context: inout GraphicsContext,
        size: CGSize,
        seconds: TimeInterval,
        count: Int,
        palette: CelestialPalette
    ) {
        guard count > 2 else { return }
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        var nodes: [CGPoint] = []
        nodes.reserveCapacity(count)

        for index in 0..<count {
            let seed = Double(index)
            let depth = hash(seed * 3.73 + 5.0)
            let x = width * CGFloat(unitFraction(hash(seed * 7.1) + seconds * (0.007 + depth * 0.009)))
            let y = height * CGFloat(unitFraction(
                hash(seed * 4.9 + 2.0)
                    + seconds * (index.isMultiple(of: 2) ? 0.0038 : -0.0038)
                    + sin(seconds * 0.32 + seed) * 0.035
            ))
            nodes.append(CGPoint(x: x, y: y))
        }

        let connectionLimit = max(width, height) * 0.42
        var connections = Path()
        for index in nodes.indices {
            let partnerIndex = (index * 7 + 3) % nodes.count
            guard partnerIndex != index else { continue }
            let a = nodes[index]
            let b = nodes[partnerIndex]
            let distance = hypot(b.x - a.x, b.y - a.y)
            guard distance < connectionLimit else { continue }
            connections.move(to: a)
            connections.addLine(to: b)
        }
        context.stroke(
            connections,
            with: .color(palette.core.opacity(0.075)),
            style: StrokeStyle(lineWidth: 0.65, lineCap: .round)
        )

        for (index, node) in nodes.enumerated() {
            let pulse = wave(seconds: seconds + Double(index) * 0.31, period: 1.7 + hash(Double(index)) * 2.0)
            let color = index.isMultiple(of: 2) ? palette.cool : palette.warm
            drawCircle(
                context: &context,
                center: node,
                diameter: lerp(1.2, 3.3, pulse),
                color: color.opacity(lerpDouble(0.25, 0.68, pulse))
            )
        }
    }

    private func drawMeteorBursts(
        context: inout GraphicsContext,
        size: CGSize,
        seconds: TimeInterval,
        palette: CelestialPalette
    ) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        for index in 0..<3 {
            let period = 6.2 + Double(index) * 0.9
            let cycle = normalized(seconds: seconds + Double(index) * 2.05, period: period)
            let activeSpan = 0.34
            guard cycle < activeSpan else { continue }
            let progress = cycle / activeSpan
            let visibility = sin(progress * .pi)
            guard visibility > 0.02 else { continue }

            let lane = hash(Double(index) * 7.3 + floor(seconds / period))
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let start = CGPoint(
                x: direction > 0 ? -width * 0.18 : width * 1.18,
                y: height * CGFloat(0.08 + lane * 0.54)
            )
            let travel = CGVector(dx: direction * width * 1.36, dy: height * CGFloat(0.20 + lane * 0.10))
            let head = CGPoint(
                x: start.x + travel.dx * CGFloat(progress),
                y: start.y + travel.dy * CGFloat(progress)
            )
            let magnitude = max(hypot(travel.dx, travel.dy), 1)
            let unit = CGVector(dx: travel.dx / magnitude, dy: travel.dy / magnitude)
            let tail = CGPoint(
                x: head.x - unit.dx * width * 0.20,
                y: head.y - unit.dy * width * 0.20
            )
            let color = index.isMultiple(of: 2) ? palette.cool : palette.warm
            let tailGradient = Gradient(stops: [
                .init(color: color.opacity(0), location: 0),
                .init(color: color.opacity(0.34 * visibility), location: 0.72),
                .init(color: palette.bright.opacity(0.82 * visibility), location: 1)
            ])
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: head)
            context.stroke(
                streak,
                with: .linearGradient(tailGradient, startPoint: tail, endPoint: head),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )
            drawSoftGlow(context: &context, center: head, radius: 8, color: color, coreOpacity: 0.32 * visibility)
            drawCircle(context: &context, center: head, diameter: 2.4, color: palette.bright.opacity(0.78 * visibility))
        }
    }

    private func drawSoftGlow(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, coreOpacity: Double) {
        guard radius > 1, coreOpacity > 0.001 else { return }
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let gradient = Gradient(stops: [
            .init(color: color.opacity(coreOpacity), location: 0.0),
            .init(color: color.opacity(coreOpacity * 0.5), location: 0.45),
            .init(color: color.opacity(coreOpacity * 0.16), location: 0.72),
            .init(color: color.opacity(0), location: 1.0)
        ])
        context.fill(Path(ellipseIn: rect), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
    }

    private func drawCorona(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, peak: Double) {
        guard radius > 1, peak > 0.001 else { return }
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let gradient = Gradient(stops: [
            .init(color: color.opacity(peak * 0.35), location: 0.0),
            .init(color: color.opacity(peak), location: 0.32),
            .init(color: color.opacity(peak * 0.55), location: 0.55),
            .init(color: color.opacity(0), location: 1.0)
        ])
        context.fill(Path(ellipseIn: rect), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
    }

    private func celestialPalette() -> CelestialPalette {
        let base = primaryColor
        return CelestialPalette(
            core: base,
            cool: hueShifted(base, by: -26, saturationScale: 0.9, brightnessScale: 1.14),
            warm: hueShifted(base, by: 28, saturationScale: 0.95, brightnessScale: 1.08),
            bright: blend(base, .white, 0.42)
        )
    }

    private func blend(_ base: Color, _ other: Color, _ t: Double) -> Color {
        #if canImport(UIKit) || os(macOS)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard UIColor(base).getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return base }
        let f = CGFloat(min(max(t, 0), 1))
        return Color(
            red: Double(r1 + (r2 - r1) * f),
            green: Double(g1 + (g2 - g1) * f),
            blue: Double(b1 + (b2 - b1) * f),
            opacity: Double(a1 + (a2 - a1) * f)
        )
        #else
        return t < 0.5 ? base : other
        #endif
    }

    private func hueShifted(_ color: Color, by degrees: Double, saturationScale: Double = 1, brightnessScale: Double = 1) -> Color {
        #if canImport(UIKit) || os(macOS)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        var hue = (h + CGFloat(degrees / 360)).truncatingRemainder(dividingBy: 1)
        if hue < 0 { hue += 1 }
        return Color(
            hue: Double(hue),
            saturation: Double(min(max(s * CGFloat(saturationScale), 0), 1)),
            brightness: Double(min(max(b * CGFloat(brightnessScale), 0), 1)),
            opacity: Double(a)
        )
        #else
        return color
        #endif
    }

    private func drawEllipseStroke(context: inout GraphicsContext, center: CGPoint, diameter: CGFloat, color: Color, lineWidth: CGFloat) {
        let rect = CGRect(x: center.x - diameter * 0.5, y: center.y - diameter * 0.5, width: diameter, height: diameter)
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: lineWidth)
    }

    private func drawArc(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, startDegrees: Double, endDegrees: Double, color: Color, lineWidth: CGFloat) {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    private func drawCircle(context: inout GraphicsContext, center: CGPoint, diameter: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - diameter * 0.5, y: center.y - diameter * 0.5, width: diameter, height: diameter)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func shifted(_ point: CGPoint, x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: point.x + x, y: point.y + y)
    }

    private func point(center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
    }

    private func normalized(seconds: TimeInterval, period: Double) -> Double {
        guard period > 0 else { return 0 }
        let value = seconds.truncatingRemainder(dividingBy: period) / period
        return value < 0 ? value + 1 : value
    }

    private func wave(seconds: TimeInterval, period: Double) -> Double {
        guard period > 0 else { return 0.5 }
        return (sin(normalized(seconds: seconds, period: period) * 2 * .pi) + 1) * 0.5
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
        start + (end - start) * CGFloat(progress)
    }

    private func lerpDouble(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        start + (end - start) * progress
    }

    private func hash(_ value: Double) -> Double {
        let x = sin(value * 12.9898) * 43758.5453
        return x - floor(x)
    }

    private func unitFraction(_ value: Double) -> Double {
        let fraction = value.truncatingRemainder(dividingBy: 1)
        return fraction < 0 ? fraction + 1 : fraction
    }
}

struct GlobalGradientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var theme = EclipseTheme.shared
    @AppStorage(HomeAnimatedBackgroundSettings.enabledKey) private var animatedBackgroundEnabled = HomeAnimatedBackgroundSettings.defaultEnabled
    @State private var isVisible = false
    var overrideColor: Color? = nil
    var scrollOffset: CGFloat = 0
    var allowsAnimatedBackground: Bool = true
    var animatedBackgroundTopClearance: CGFloat = 0

    private var gradientColor: Color {
        overrideColor ?? theme.scopedGradientColor()
    }

    private var gradientOffset: CGFloat {
        -scrollOffset * 0.15 * CGFloat(ExperimentalVisualTuning.current.gradientScrollMotion)
    }

    @ViewBuilder
    var body: some View {
        baseBackground
            .overlay {
                if allowsAnimatedBackground
                    && animatedBackgroundEnabled
                    && theme.scopedAtmosphereStyle() != .aurora
                    && theme.scopedAtmosphereStyle() != .ember {
                    EclipseIsolatedAmbientMotionBackground(
                        topClearance: animatedBackgroundTopClearance,
                        ambientColor: overrideColor,
                        accentColor: gradientColor,
                        motionEnabled: !reduceMotion && scenePhase == .active && isVisible
                    )
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }

    @ViewBuilder
    private var baseBackground: some View {
        AtmosphereBackdrop(
            input: theme.atmosphereInput(dominant: overrideColor, hasHeroBleed: false, heroHeight: 0, fadeDistance: 1),
            scrollOffset: scrollOffset
        )
    }

    private var legacyBackground: some View {
        GeometryReader { geo in
            let h = geo.size.height * 5.0
            if theme.scopedAtmosphereStyle() == .solid {
                theme.scopedAtmosphereColor(dominant: gradientColor)
                    .frame(height: h)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: theme.backgroundBase, location: 0.0),
                        .init(color: gradientColor.opacity(0.7), location: 0.06),
                        .init(color: gradientColor.opacity(0.4), location: 0.15),
                        .init(color: gradientColor.opacity(0.15), location: 0.3),
                        .init(color: gradientColor.opacity(0.05), location: 0.5),
                        .init(color: theme.backgroundBase, location: 0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: h)
                .offset(y: gradientOffset)
            }
        }
        .clipped()
    }
}

struct HeroBleedGradientBackground: View {
    var dominantColor: Color
    var scrollOffset: CGFloat
    var heroHeight: CGFloat
    var fadeDistance: CGFloat
    var bleedStrength: Double
    var style: AtmosphereStyle

    private var fadeProgress: Double {
        guard fadeDistance > 0 else { return 1 }
        let rawProgress = Double(max(0, min(scrollOffset / fadeDistance, 1)))
        return rawProgress * rawProgress * (3 - 2 * rawProgress)
    }

    private var activeStrength: Double {
        max(0, bleedStrength * (1 - fadeProgress))
    }

    @ViewBuilder
    private var baseBackground: some View {
        GlobalGradientBackground(scrollOffset: scrollOffset, allowsAnimatedBackground: false)
    }

    var body: some View {
        GeometryReader { geo in
            let bleedHeight = max(heroHeight + fadeDistance, geo.size.height * 0.72)
            let safeStrength = min(max(activeStrength, 0), 1.5)

            ZStack(alignment: .top) {
                baseBackground

                LinearGradient(
                    stops: [
                        .init(color: dominantColor.opacity(0.82 * safeStrength), location: 0.00),
                        .init(color: dominantColor.opacity(0.66 * safeStrength), location: 0.24),
                        .init(color: dominantColor.opacity(0.38 * safeStrength), location: 0.54),
                        .init(color: dominantColor.opacity(0.15 * safeStrength), location: 0.80),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bleedHeight)
                .offset(y: -scrollOffset * 0.08)

                RadialGradient(
                    colors: [
                        dominantColor.opacity(0.34 * safeStrength),
                        dominantColor.opacity(0.13 * safeStrength),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.18),
                    startRadius: 10,
                    endRadius: max(geo.size.width, bleedHeight) * 0.72
                )
                .frame(height: bleedHeight)
                .blendMode(style.isMultiGradient ? .screen : .normal)

                LinearGradient(
                    colors: [
                        .black.opacity(0.06),
                        .clear,
                        .black.opacity(0.18 * (1 - fadeProgress))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bleedHeight)
            }
        }
        .clipped()
    }
}

#if !os(tvOS)
struct ExperimentalGradientBackground: View {
    @ObservedObject private var theme = EclipseTheme.shared
    @AppStorage(ExperimentalMultiGradientPalette.storageKey) private var multiGradientPaletteRaw = ExperimentalMultiGradientPalette.defaultValue.rawValue
    @AppStorage(ExperimentalVisualTuning.gradientBaseDarknessKey) private var gradientBaseDarkness = ExperimentalVisualTuning.defaultGradientBaseDarkness
    @AppStorage(ExperimentalVisualTuning.gradientAccentIntensityKey) private var gradientAccentIntensity = ExperimentalVisualTuning.defaultGradientAccentIntensity
    @AppStorage(ExperimentalVisualTuning.gradientScrollMotionKey) private var gradientScrollMotion = ExperimentalVisualTuning.defaultGradientScrollMotion
    @AppStorage(ExperimentalVisualTuning.gradientUseCustomColorsKey) private var gradientUseCustomColors = false
    @AppStorage(ExperimentalVisualTuning.gradientColorAKey) private var gradientColorAData = Data()
    @AppStorage(ExperimentalVisualTuning.gradientColorBKey) private var gradientColorBData = Data()
    @AppStorage(ExperimentalVisualTuning.gradientColorCKey) private var gradientColorCData = Data()
    var dominantColor: Color? = nil
    var scrollOffset: CGFloat = 0
    var style: AtmosphereStyle = .multiGradient

    private var accent: Color {
        dominantColor ?? Color(red: 0.25, green: 0.21, blue: 0.34)
    }

    private var palette: ExperimentalMultiGradientPalette {
        ExperimentalMultiGradientPalette(rawValue: multiGradientPaletteRaw) ?? .defaultValue
    }

    private var resolvedStyle: AtmosphereStyle {
        style.isMultiGradient ? style : .multiGradient
    }

    private var sanitizedBaseDarkness: Double {
        ExperimentalVisualTuning.sanitizedGradientBaseDarkness(gradientBaseDarkness)
    }

    private var sanitizedAccentIntensity: Double {
        ExperimentalVisualTuning.sanitizedGradientAccentIntensity(gradientAccentIntensity)
    }

    private var sanitizedScrollMotion: Double {
        ExperimentalVisualTuning.sanitizedGradientScrollMotion(gradientScrollMotion)
    }

    private var customGradientColors: [Color]? {
        guard gradientUseCustomColors,
              let first = ExperimentalVisualTuning.loadColor(data: gradientColorAData),
              let second = ExperimentalVisualTuning.loadColor(data: gradientColorBData),
              let third = ExperimentalVisualTuning.loadColor(data: gradientColorCData) else {
            return nil
        }
        return [first, second, third]
    }

    private var baseStops: [Gradient.Stop] {
        if let customGradientColors {
            return [
                .init(color: Color(red: 0.054, green: 0.048, blue: 0.066), location: 0.00),
                .init(color: customGradientColors[0].opacity(0.34), location: 0.24),
                .init(color: customGradientColors[1].opacity(0.30), location: 0.52),
                .init(color: customGradientColors[2].opacity(0.26), location: 0.76),
                .init(color: Color(red: 0.060, green: 0.052, blue: 0.070), location: 1.00)
            ]
        }

        switch resolvedStyle {
        case .aurora:
            return [
                .init(color: Color(red: 0.05, green: 0.10, blue: 0.14), location: 0.00),
                .init(color: Color(red: 0.08, green: 0.25, blue: 0.26), location: 0.22),
                .init(color: Color(red: 0.22, green: 0.21, blue: 0.46), location: 0.48),
                .init(color: Color(red: 0.18, green: 0.12, blue: 0.27), location: 0.72),
                .init(color: Color(red: 0.07, green: 0.06, blue: 0.10), location: 1.00)
            ]
        case .ember:
            return [
                .init(color: Color(red: 0.11, green: 0.08, blue: 0.10), location: 0.00),
                .init(color: Color(red: 0.29, green: 0.15, blue: 0.16), location: 0.24),
                .init(color: Color(red: 0.48, green: 0.31, blue: 0.20), location: 0.50),
                .init(color: Color(red: 0.23, green: 0.16, blue: 0.27), location: 0.76),
                .init(color: Color(red: 0.08, green: 0.06, blue: 0.09), location: 1.00)
            ]
        case .multiGradient, .gradient, .solid:
            switch palette {
            case .eclipse:
                return [
                    .init(color: Color(red: 0.070, green: 0.062, blue: 0.090), location: 0.00),
                    .init(color: Color(red: 0.105, green: 0.086, blue: 0.130), location: 0.24),
                    .init(color: Color(red: 0.165, green: 0.126, blue: 0.188), location: 0.50),
                    .init(color: Color(red: 0.145, green: 0.094, blue: 0.124), location: 0.74),
                    .init(color: Color(red: 0.074, green: 0.064, blue: 0.088), location: 1.00)
                ]
            case .nocturne:
                return [
                    .init(color: Color(red: 0.052, green: 0.058, blue: 0.078), location: 0.00),
                    .init(color: Color(red: 0.078, green: 0.100, blue: 0.126), location: 0.24),
                    .init(color: Color(red: 0.114, green: 0.118, blue: 0.166), location: 0.50),
                    .init(color: Color(red: 0.118, green: 0.084, blue: 0.126), location: 0.74),
                    .init(color: Color(red: 0.058, green: 0.056, blue: 0.074), location: 1.00)
                ]
            case .velvet:
                return [
                    .init(color: Color(red: 0.080, green: 0.058, blue: 0.082), location: 0.00),
                    .init(color: Color(red: 0.132, green: 0.082, blue: 0.112), location: 0.24),
                    .init(color: Color(red: 0.170, green: 0.112, blue: 0.158), location: 0.50),
                    .init(color: Color(red: 0.112, green: 0.088, blue: 0.150), location: 0.74),
                    .init(color: Color(red: 0.068, green: 0.058, blue: 0.080), location: 1.00)
                ]
            case .auroraMuted:
                return [
                    .init(color: Color(red: 0.052, green: 0.076, blue: 0.086), location: 0.00),
                    .init(color: Color(red: 0.070, green: 0.124, blue: 0.126), location: 0.24),
                    .init(color: Color(red: 0.112, green: 0.112, blue: 0.168), location: 0.50),
                    .init(color: Color(red: 0.126, green: 0.092, blue: 0.136), location: 0.74),
                    .init(color: Color(red: 0.058, green: 0.060, blue: 0.078), location: 1.00)
                ]
            }
        }
    }

    private var washStops: [Gradient.Stop] {
        switch resolvedStyle {
        case .aurora:
            return [
                .init(color: Color(red: 0.08, green: 0.80, blue: 0.72).opacity(0.36), location: 0.02),
                .init(color: Color(red: 0.28, green: 0.38, blue: 0.92).opacity(0.28), location: 0.34),
                .init(color: Color(red: 0.78, green: 0.30, blue: 0.72).opacity(0.22), location: 0.68),
                .init(color: Color(red: 0.92, green: 0.64, blue: 0.28).opacity(0.12), location: 0.95)
            ]
        case .ember:
            return [
                .init(color: Color(red: 0.94, green: 0.54, blue: 0.18).opacity(0.30), location: 0.02),
                .init(color: Color(red: 0.82, green: 0.24, blue: 0.40).opacity(0.24), location: 0.34),
                .init(color: Color(red: 0.35, green: 0.26, blue: 0.84).opacity(0.22), location: 0.68),
                .init(color: Color(red: 0.07, green: 0.62, blue: 0.72).opacity(0.12), location: 0.95)
            ]
        case .multiGradient, .gradient, .solid:
            switch palette {
            case .eclipse:
                return [
                    .init(color: Color(red: 0.06, green: 0.30, blue: 0.30).opacity(0.18), location: 0.04),
                    .init(color: Color(red: 0.28, green: 0.20, blue: 0.40).opacity(0.18), location: 0.34),
                    .init(color: Color(red: 0.38, green: 0.14, blue: 0.22).opacity(0.14), location: 0.68),
                    .init(color: Color(red: 0.48, green: 0.30, blue: 0.16).opacity(0.10), location: 0.96)
                ]
            case .nocturne:
                return [
                    .init(color: Color(red: 0.08, green: 0.26, blue: 0.34).opacity(0.16), location: 0.04),
                    .init(color: Color(red: 0.18, green: 0.22, blue: 0.42).opacity(0.16), location: 0.38),
                    .init(color: Color(red: 0.28, green: 0.16, blue: 0.30).opacity(0.12), location: 0.72)
                ]
            case .velvet:
                return [
                    .init(color: Color(red: 0.38, green: 0.14, blue: 0.24).opacity(0.18), location: 0.04),
                    .init(color: Color(red: 0.30, green: 0.18, blue: 0.42).opacity(0.16), location: 0.40),
                    .init(color: Color(red: 0.54, green: 0.28, blue: 0.16).opacity(0.10), location: 0.88)
                ]
            case .auroraMuted:
                return [
                    .init(color: Color(red: 0.08, green: 0.42, blue: 0.36).opacity(0.16), location: 0.04),
                    .init(color: Color(red: 0.24, green: 0.28, blue: 0.50).opacity(0.16), location: 0.44),
                    .init(color: Color(red: 0.46, green: 0.22, blue: 0.38).opacity(0.11), location: 0.88)
                ]
            }
        }
    }

    private var angularColors: [Color] {
        if let customGradientColors {
            return [
                customGradientColors[0].opacity(0.24),
                accent.opacity(0.28),
                customGradientColors[1].opacity(0.24),
                customGradientColors[2].opacity(0.22),
                customGradientColors[0].opacity(0.24)
            ]
        }

        switch resolvedStyle {
        case .aurora:
            return [
                Color(red: 0.08, green: 0.84, blue: 0.70).opacity(0.28),
                accent.opacity(0.30),
                Color(red: 0.56, green: 0.26, blue: 0.88).opacity(0.26),
                Color(red: 0.10, green: 0.46, blue: 0.62).opacity(0.30),
                Color(red: 0.08, green: 0.84, blue: 0.70).opacity(0.28)
            ]
        case .ember:
            return [
                Color(red: 0.96, green: 0.54, blue: 0.20).opacity(0.28),
                accent.opacity(0.30),
                Color(red: 0.80, green: 0.22, blue: 0.42).opacity(0.24),
                Color(red: 0.28, green: 0.26, blue: 0.70).opacity(0.26),
                Color(red: 0.96, green: 0.54, blue: 0.20).opacity(0.28)
            ]
        case .multiGradient, .gradient, .solid:
            return [
                Color(red: 0.07, green: 0.34, blue: 0.36).opacity(0.12),
                accent.opacity(0.16),
                Color(red: 0.38, green: 0.15, blue: 0.27).opacity(0.12),
                Color(red: 0.24, green: 0.22, blue: 0.44).opacity(0.14),
                Color(red: 0.07, green: 0.34, blue: 0.36).opacity(0.12)
            ]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let h = max(geo.size.height * 1.65, geo.size.height + 1)
            ZStack {
                Color(red: 0.068, green: 0.060, blue: 0.088)

                LinearGradient(
                    stops: baseStops,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: h)
                .offset(y: -scrollOffset * 0.10 * sanitizedScrollMotion)

                LinearGradient(
                    stops: washStops,
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .opacity(sanitizedAccentIntensity)
                .blendMode(.screen)
                .offset(y: -scrollOffset * 0.055 * sanitizedScrollMotion)

                RadialGradient(
                    colors: angularColors,
                    center: UnitPoint(x: 0.48, y: 0.34),
                    startRadius: 16,
                    endRadius: max(geo.size.width, geo.size.height) * 0.86
                )
                .opacity(0.54 * sanitizedAccentIntensity)
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        accent.opacity((resolvedStyle == .multiGradient ? 0.18 : 0.24) * sanitizedAccentIntensity),
                        .clear,
                        Color(red: 0.06, green: 0.24, blue: 0.26).opacity((resolvedStyle == .multiGradient ? 0.14 : 0.22) * sanitizedAccentIntensity)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(y: -scrollOffset * 0.03 * sanitizedScrollMotion)

                Color.black
                    .opacity(max(0, sanitizedBaseDarkness - 1) * 0.28)

                Color.white
                    .opacity(max(0, 1 - sanitizedBaseDarkness) * 0.06)
                    .blendMode(.screen)

                LinearGradient(
                    colors: [
                        .black.opacity(resolvedStyle == .multiGradient ? 0.10 : 0.08),
                        .clear,
                        .black.opacity(resolvedStyle == .multiGradient ? 0.34 : 0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
    }
}

#endif

enum EclipseSpacing {
    static let xs: CGFloat = 6
    static let s: CGFloat = 10
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

enum EclipseRadius {

    static var card: CGFloat { ExperimentalMediaDesignMetrics.current.cardRadius }
    static let chip: CGFloat = 10
    static let control: CGFloat = 14
    static let hero: CGFloat = 20
}

enum EclipseType {
    static func screenTitle(_ pad: Bool = false) -> Font { .system(size: isIPad ? 34 : 28, weight: .heavy) }
    static var sectionHeader: Font { .system(size: isIPad ? 24 : 21, weight: .bold) }
    static var cardTitle: Font { .system(size: isIPad ? 19 : 17, weight: .semibold) }
    static var cardSubtitle: Font { .system(size: isIPad ? 15 : 14, weight: .regular) }
    static var badge: Font { .system(size: 11, weight: .bold) }
}

enum EclipseShadowTier {
    case subtle
    case standard
    case elevated
    case floating

    var radius: CGFloat {
        switch self {
        case .subtle: return 8
        case .standard: return 14
        case .elevated: return 18
        case .floating: return 26
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .subtle: return 4
        case .standard: return 8
        case .elevated: return 10
        case .floating: return 14
        }
    }

    var opacity: Double {
        switch self {
        case .subtle: return 0.20
        case .standard: return 0.26
        case .elevated: return 0.30
        case .floating: return 0.34
        }
    }
}

extension View {

    func eclipseShadow(_ tier: EclipseShadowTier = .standard) -> some View {
        shadow(color: Color.black.opacity(tier.opacity), radius: tier.radius, x: 0, y: tier.yOffset)
    }
}

extension Color {

    func atmosphereScaled(_ intensity: Double) -> Color {
        guard intensity != 1.0 else { return self }
        #if canImport(UIKit) || os(macOS)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let f = CGFloat(intensity)
        return Color(
            red: Double(min(max(r * f, 0), 1)),
            green: Double(min(max(g * f, 0), 1)),
            blue: Double(min(max(b * f, 0), 1)),
            opacity: Double(a)
        )
        #else
        return self
        #endif
    }
}

struct AtmospherePalette: Equatable {
    let id: String
    let displayName: String

    let mesh: [Color]

    let verticalStops: [Gradient.Stop]

    let topWash: Color

    func meshColors(intensity: Double) -> [Color] {
        intensity == 1.0 ? mesh : mesh.map { $0.atmosphereScaled(intensity) }
    }

    func scaledVerticalStops(intensity: Double) -> [Gradient.Stop] {
        intensity == 1.0 ? verticalStops : verticalStops.map {
            Gradient.Stop(color: $0.color.atmosphereScaled(intensity), location: $0.location)
        }
    }
}

enum AtmospherePaletteID: String, CaseIterable, Identifiable {
    case midnightPurple
    case nocturne
    case velvet
    case mutedAurora
    case aurora
    case ember
    case custom

    var id: String { rawValue }
    static var defaultValue: AtmospherePaletteID { .midnightPurple }

    var displayName: String {
        switch self {
        case .midnightPurple: return "Midnight Purple"
        case .nocturne: return "Nocturne"
        case .velvet: return "Velvet"
        case .mutedAurora: return "Muted Aurora"
        case .aurora: return "Aurora"
        case .ember: return "Ember"
        case .custom: return "Custom"
        }
    }

    static func from(_ raw: String?) -> AtmospherePaletteID {
        AtmospherePaletteID(rawValue: raw ?? "") ?? .defaultValue
    }
}

enum AppearancePalettes {
    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    static let midnightPurple = AtmospherePalette(
        id: "midnightPurple", displayName: "Midnight Purple",
        mesh: [
            c(0.105, 0.070, 0.210), c(0.165, 0.085, 0.235), c(0.085, 0.090, 0.240),
            c(0.195, 0.082, 0.215), c(0.180, 0.110, 0.300), c(0.095, 0.110, 0.285),
            c(0.150, 0.080, 0.215), c(0.130, 0.100, 0.270), c(0.080, 0.100, 0.235),
            c(0.065, 0.052, 0.110), c(0.078, 0.060, 0.130), c(0.055, 0.055, 0.105)
        ],
        verticalStops: [
            .init(color: c(0.130, 0.085, 0.235), location: 0.0),
            .init(color: c(0.175, 0.105, 0.285), location: 0.40),
            .init(color: c(0.070, 0.058, 0.120), location: 1.0)
        ],
        topWash: c(0.42, 0.22, 0.58)
    )

    static let nocturne = AtmospherePalette(
        id: "nocturne", displayName: "Nocturne",
        mesh: [
            c(0.060, 0.095, 0.205), c(0.080, 0.125, 0.255), c(0.060, 0.105, 0.225),
            c(0.072, 0.150, 0.270), c(0.100, 0.165, 0.320), c(0.070, 0.135, 0.300),
            c(0.060, 0.120, 0.235), c(0.090, 0.140, 0.295), c(0.070, 0.105, 0.260),
            c(0.048, 0.060, 0.120), c(0.058, 0.072, 0.140), c(0.044, 0.058, 0.110)
        ],
        verticalStops: [
            .init(color: c(0.078, 0.125, 0.255), location: 0.0),
            .init(color: c(0.095, 0.155, 0.305), location: 0.40),
            .init(color: c(0.050, 0.062, 0.125), location: 1.0)
        ],
        topWash: c(0.20, 0.42, 0.62)
    )

    static let velvet = AtmospherePalette(
        id: "velvet", displayName: "Velvet",
        mesh: [
            c(0.165, 0.060, 0.140), c(0.205, 0.080, 0.180), c(0.140, 0.070, 0.165),
            c(0.225, 0.080, 0.205), c(0.245, 0.105, 0.260), c(0.165, 0.085, 0.225),
            c(0.185, 0.070, 0.180), c(0.165, 0.095, 0.245), c(0.125, 0.075, 0.190),
            c(0.085, 0.050, 0.105), c(0.095, 0.062, 0.125), c(0.072, 0.050, 0.100)
        ],
        verticalStops: [
            .init(color: c(0.205, 0.080, 0.180), location: 0.0),
            .init(color: c(0.235, 0.100, 0.250), location: 0.40),
            .init(color: c(0.082, 0.052, 0.105), location: 1.0)
        ],
        topWash: c(0.55, 0.20, 0.46)
    )

    static let mutedAurora = AtmospherePalette(
        id: "mutedAurora", displayName: "Muted Aurora",
        mesh: [
            c(0.050, 0.130, 0.140), c(0.070, 0.165, 0.180), c(0.065, 0.125, 0.205),
            c(0.072, 0.185, 0.200), c(0.095, 0.205, 0.240), c(0.110, 0.140, 0.265),
            c(0.075, 0.155, 0.205), c(0.095, 0.165, 0.250), c(0.110, 0.120, 0.265),
            c(0.048, 0.072, 0.115), c(0.058, 0.090, 0.135), c(0.052, 0.072, 0.120)
        ],
        verticalStops: [
            .init(color: c(0.070, 0.165, 0.185), location: 0.0),
            .init(color: c(0.100, 0.185, 0.245), location: 0.40),
            .init(color: c(0.050, 0.072, 0.120), location: 1.0)
        ],
        topWash: c(0.16, 0.52, 0.54)
    )

    static let aurora = AtmospherePalette(
        id: "aurora", displayName: "Aurora",
        mesh: [
            c(0.025, 0.115, 0.235), c(0.035, 0.205, 0.285), c(0.075, 0.125, 0.310),
            c(0.035, 0.285, 0.315), c(0.085, 0.315, 0.390), c(0.115, 0.190, 0.390),
            c(0.060, 0.205, 0.310), c(0.095, 0.245, 0.365), c(0.130, 0.155, 0.340),
            c(0.025, 0.060, 0.135), c(0.035, 0.075, 0.155), c(0.025, 0.055, 0.125)
        ],
        verticalStops: [
            .init(color: c(0.035, 0.205, 0.285), location: 0.0),
            .init(color: c(0.075, 0.235, 0.340), location: 0.42),
            .init(color: c(0.025, 0.060, 0.135), location: 1.0)
        ],
        topWash: c(0.12, 0.58, 0.66)
    )

    static let ember = AtmospherePalette(
        id: "ember", displayName: "Ember",
        mesh: [
            c(0.235, 0.075, 0.045), c(0.315, 0.105, 0.045), c(0.265, 0.075, 0.090),
            c(0.385, 0.135, 0.045), c(0.405, 0.185, 0.065), c(0.305, 0.105, 0.105),
            c(0.295, 0.095, 0.055), c(0.345, 0.145, 0.085), c(0.245, 0.085, 0.105),
            c(0.105, 0.045, 0.045), c(0.125, 0.052, 0.045), c(0.085, 0.038, 0.042)
        ],
        verticalStops: [
            .init(color: c(0.315, 0.105, 0.045), location: 0.0),
            .init(color: c(0.365, 0.145, 0.060), location: 0.42),
            .init(color: c(0.105, 0.045, 0.045), location: 1.0)
        ],
        topWash: c(0.72, 0.28, 0.08)
    )

    static func base(for id: AtmospherePaletteID) -> AtmospherePalette {
        switch id {
        case .midnightPurple: return midnightPurple
        case .nocturne: return nocturne
        case .velvet: return velvet
        case .mutedAurora: return mutedAurora
        case .aurora: return aurora
        case .ember: return ember
        case .custom: return midnightPurple
        }
    }

    static func resolved(id: AtmospherePaletteID, customColors: [Color]) -> AtmospherePalette {
        id == .custom ? custom(customColors) : base(for: id)
    }

    static func custom(_ colors: [Color]) -> AtmospherePalette {
        let a = colors.indices.contains(0) ? colors[0] : c(0.16, 0.12, 0.20)
        let b = colors.indices.contains(1) ? colors[1] : c(0.26, 0.16, 0.34)
        let cc = colors.indices.contains(2) ? colors[2] : c(0.20, 0.12, 0.16)
        let aD = a.atmosphereScaled(0.5)
        let bMid = b.atmosphereScaled(0.62)
        let bD = b.atmosphereScaled(0.5)
        let cD = cc.atmosphereScaled(0.46)
        let deep = c(0.058, 0.050, 0.080)
        return AtmospherePalette(
            id: "custom", displayName: "Custom",
            mesh: [
                aD, a.atmosphereScaled(0.56), aD,
                bD, bMid, bD,
                cD, cc.atmosphereScaled(0.52), cD,
                deep, deep, deep
            ],
            verticalStops: [
                .init(color: aD, location: 0.0),
                .init(color: bMid, location: 0.42),
                .init(color: deep, location: 1.0)
            ],
            topWash: a
        )
    }
}

enum AppearanceConfig {
    static let paletteKey = "appearancePalette"
    static let bleedStrengthKey = "appearanceBleedStrength"
    static let backgroundIntensityKey = "appearanceBackgroundIntensity"
    static let motionKey = "appearanceMotion"
    static let customColorsKey = "appearanceCustomColors"
#if !os(tvOS)
    static let readerPaletteKey = "readerAppearancePalette"
    static let readerBleedStrengthKey = "readerAppearanceBleedStrength"
    static let readerBackgroundIntensityKey = "readerAppearanceBackgroundIntensity"
    static let readerMotionKey = "readerAppearanceMotion"
    static let readerCustomColorsKey = "readerAppearanceCustomColors"
#endif
    private static let migratedKey = "appearanceMigratedV1"

    static let defaultBleedStrength = 1.0
    static let defaultBackgroundIntensity = 1.0
    static let defaultMotion = 1.0

    static let bleedRange: ClosedRange<Double> = 0.0...1.2
    static let intensityRange: ClosedRange<Double> = 0.6...1.3
    static let motionRange: ClosedRange<Double> = 0.0...1.2

    static func clampBleed(_ v: Double) -> Double { v.isFinite ? min(max(v, bleedRange.lowerBound), bleedRange.upperBound) : defaultBleedStrength }
    static func clampIntensity(_ v: Double) -> Double { v.isFinite ? min(max(v, intensityRange.lowerBound), intensityRange.upperBound) : defaultBackgroundIntensity }
    static func clampMotion(_ v: Double) -> Double { v.isFinite ? min(max(v, motionRange.lowerBound), motionRange.upperBound) : defaultMotion }

    static let defaultCustomColors: [Color] = [
        Color(red: 0.16, green: 0.12, blue: 0.20),
        Color(red: 0.26, green: 0.16, blue: 0.34),
        Color(red: 0.20, green: 0.12, blue: 0.16)
    ]

    static func encodeColors(_ colors: [Color]) -> Data? {
        #if canImport(UIKit) || os(macOS)
        let uiColors = colors.map { UIColor($0) }
        return try? PortableColorArchive.data(for: uiColors)
        #else
        return nil
        #endif
    }

    static func decodeColors(_ data: Data?) -> [Color]? {
        #if canImport(UIKit) || os(macOS)
        guard let data, !data.isEmpty,
              let uiColors = try? PortableColorArchive.colors(from: data),
              !uiColors.isEmpty else { return nil }
        return uiColors.map { Color($0) }
        #else
        return nil
        #endif
    }

    static func migrateIfNeeded(defaults: UserDefaults = ProfileSettingsStore.active) {
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)

        if defaults.object(forKey: paletteKey) == nil,
           let oldPalette = defaults.string(forKey: "experimentalMultiGradientPalette") {
            let mapped: String
            switch oldPalette {
            case "eclipse": mapped = AtmospherePaletteID.midnightPurple.rawValue
            case "nocturne": mapped = AtmospherePaletteID.nocturne.rawValue
            case "velvet": mapped = AtmospherePaletteID.velvet.rawValue
            case "auroraMuted": mapped = AtmospherePaletteID.mutedAurora.rawValue
            default: mapped = AtmospherePaletteID.midnightPurple.rawValue
            }
            defaults.set(mapped, forKey: paletteKey)
        }

        if defaults.object(forKey: bleedStrengthKey) == nil,
           defaults.object(forKey: "experimentalHeroBleedStrength") != nil {
            defaults.set(clampBleed(defaults.double(forKey: "experimentalHeroBleedStrength")), forKey: bleedStrengthKey)
        }

        if defaults.object(forKey: backgroundIntensityKey) == nil,
           let darkness = defaults.object(forKey: "experimentalGradientBaseDarkness") as? Double {
            defaults.set(clampIntensity(darkness), forKey: backgroundIntensityKey)
        }

        if defaults.object(forKey: motionKey) == nil,
           defaults.object(forKey: "experimentalGradientScrollMotion") != nil {
            defaults.set(clampMotion(defaults.double(forKey: "experimentalGradientScrollMotion")), forKey: motionKey)
        }

        if defaults.bool(forKey: "experimentalGradientUseCustomColors"),
           defaults.string(forKey: paletteKey) != AtmospherePaletteID.custom.rawValue {
            let a = ExperimentalVisualTuning.loadColor(key: "experimentalGradientColorA")
            let b = ExperimentalVisualTuning.loadColor(key: "experimentalGradientColorB")
            let cc = ExperimentalVisualTuning.loadColor(key: "experimentalGradientColorC")
            if let a, let b, let cc, let data = encodeColors([a, b, cc]) {
                defaults.set(data, forKey: customColorsKey)
                defaults.set(AtmospherePaletteID.custom.rawValue, forKey: paletteKey)
            }
        }
    }
}

enum AtmosphereBackgroundMode: Equatable {
    case multiGradient
    case classicGradient
    case solid
}

struct AtmosphereInput: Equatable {
    var mode: AtmosphereBackgroundMode
    var style: AtmosphereStyle
    var palette: AtmospherePalette
    var classicColor: Color
    var baseColor: Color
    var dominant: Color?
    var hasHeroBleed: Bool
    var heroHeight: CGFloat
    var fadeDistance: CGFloat
    var bleedStrength: Double
    var backgroundIntensity: Double
    var motion: Double
}

struct AtmosphereBackdrop: View {
    var input: AtmosphereInput
    var scrollOffset: CGFloat = 0

    private var fadeProgress: Double {
        guard input.fadeDistance > 0 else { return 1 }
        let t = Double(max(0, min(scrollOffset / input.fadeDistance, 1)))
        return t * t * (3 - 2 * t)
    }

    private var bleedAlpha: Double {
        guard input.hasHeroBleed, input.dominant != nil else { return 0 }
        return max(0, input.bleedStrength * (1 - fadeProgress))
    }

    private var parallax: CGFloat {
        -scrollOffset * 0.06 * CGFloat(max(0, input.motion))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AtmosphereBaseLayer(input: input, size: geo.size)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(y: parallax)

                if let dominant = input.dominant, bleedAlpha > 0.001 {
                    AtmosphereBleedLayer(
                        color: dominant,
                        alpha: bleedAlpha,
                        heroHeight: input.heroHeight,
                        containerSize: geo.size
                    )
                    .offset(y: parallax)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .animation(
            input.hasHeroBleed && input.style != .aurora && input.style != .ember
                ? .easeInOut(duration: 0.35)
                : nil,
            value: input.dominant
        )
    }
}

private struct AtmosphereBaseLayer: View {
    let input: AtmosphereInput
    let size: CGSize

    @ViewBuilder
    var body: some View {
        switch input.mode {
        case .solid:
            input.classicColor
        case .classicGradient:
            classicGradient
        case .multiGradient:
#if !os(tvOS)
            if input.style == .aurora || input.style == .ember {
                ExperimentalGradientBackground(
                    dominantColor: input.dominant,
                    scrollOffset: 0,
                    style: input.style
                )
            } else {
                AtmosphereMeshLayer(palette: input.palette, intensity: input.backgroundIntensity, size: size)
            }
#else
            AtmosphereMeshLayer(palette: input.palette, intensity: input.backgroundIntensity, size: size)
#endif
        }
    }

    private var classicGradient: some View {
        let accent = input.classicColor.atmosphereScaled(input.backgroundIntensity)
        return LinearGradient(
            stops: [
                .init(color: input.baseColor, location: 0.0),
                .init(color: accent.opacity(0.70), location: 0.08),
                .init(color: accent.opacity(0.35), location: 0.22),
                .init(color: input.baseColor, location: 0.55),
                .init(color: input.baseColor, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct AtmosphereMeshLayer: View {
    let palette: AtmospherePalette
    let intensity: Double
    let size: CGSize

    @ViewBuilder
    var body: some View {
        if #available(iOS 18.0, tvOS 18.0, macOS 15.0, *) {
            MeshGradient(
                width: 3,
                height: 4,
                points: AtmosphereMeshLayer.points,
                colors: palette.meshColors(intensity: intensity)
            )
        } else {
            AtmosphereFallbackLayer(palette: palette, intensity: intensity, size: size)
        }
    }

    static let points: [SIMD2<Float>] = [
        SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
        SIMD2<Float>(0.0, 0.33), SIMD2<Float>(0.46, 0.30), SIMD2<Float>(1.0, 0.34),
        SIMD2<Float>(0.0, 0.66), SIMD2<Float>(0.54, 0.70), SIMD2<Float>(1.0, 0.66),
        SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
    ]
}

private struct AtmosphereFallbackLayer: View {
    let palette: AtmospherePalette
    let intensity: Double
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                stops: palette.scaledVerticalStops(intensity: intensity),
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.topWash.atmosphereScaled(intensity).opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.95
            )
        }
    }
}

private struct AtmosphereBleedLayer: View {
    let color: Color
    let alpha: Double
    let heroHeight: CGFloat
    let containerSize: CGSize

    var body: some View {

        let tail = max(containerSize.height * 0.55, 220)
        let h = max(heroHeight + tail, 1)
        let holdEnd = min(max(heroHeight / h, 0.05), 0.9)
        return LinearGradient(
            stops: [
                .init(color: color.opacity(0.95 * alpha), location: 0.0),
                .init(color: color.opacity(0.88 * alpha), location: holdEnd * 0.7),
                .init(color: color.opacity(0.72 * alpha), location: holdEnd),
                .init(color: color.opacity(0.40 * alpha), location: holdEnd + (1 - holdEnd) * 0.35),
                .init(color: color.opacity(0.14 * alpha), location: holdEnd + (1 - holdEnd) * 0.70),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: h)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct HeroBannerBleed: View {
    var color: Color
    var heroHeight: CGFloat
    var tail: CGFloat
    var strength: Double
    var startOffset: CGFloat = 0

    var body: some View {
        let h = max(heroHeight + tail, 1)
        let start = min(max(startOffset / h, 0), 0.90)
        let hold = min(max(heroHeight / h, start + 0.02), 0.94)
        let s = max(0, strength)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: start),
                .init(color: color.opacity(min(1, 1.00 * s)), location: min(start + 0.01, hold)),
                .init(color: color.opacity(min(1, 1.00 * s)), location: hold),
                .init(color: color.opacity(min(1, 0.60 * s)), location: hold + (1 - hold) * 0.28),
                .init(color: color.opacity(min(1, 0.30 * s)), location: hold + (1 - hold) * 0.52),
                .init(color: color.opacity(min(1, 0.09 * s)), location: hold + (1 - hold) * 0.78),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .allowsHitTesting(false)
    }
}

extension View {

    @ViewBuilder
    func heroBannerBleed(color: Color?, heroHeight: CGFloat, tail: CGFloat, strength: Double, startOffset: CGFloat = 0) -> some View {
        if let color, strength > 0.001, heroHeight > 0 {
            background(alignment: .top) {
                HeroBannerBleed(color: color, heroHeight: heroHeight, tail: tail, strength: strength, startOffset: startOffset)
            }
        } else {
            self
        }
    }
}


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

