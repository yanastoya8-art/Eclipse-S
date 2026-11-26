import SwiftUI
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
        let breathingScale = CGFloat(1.0 + sin(phase * 1.15) * 0.012)
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
/// Reference-matched monochrome artwork for Eclipse's animated background shapes.
/// The approved concept art is packed as a compact grayscale atlas. Screen blending
/// removes its black backing while color multiplication applies the chosen animation tint.
enum HomeAnimatedShapeArtwork {
    private static let encodedAtlas = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wgALCAEgAYABAREA/8QAGwAAAgMBAQEAAAAAAAAAAAAAAAUDBAYCAQf/2gAIAQEAAAAB+fgTcxgAAAAAAAAAAe+AAANYa0fIAXbqyAAAALepeLckuAmcU2mZAAC1dg0wuzvnJ3sHkHzyIAACzrEmlnzedAPoTGt85jAAntNqDaaxiI/D36JoUa1ClAZyqeR1qqnkOTkqgbnRX8TiwAG+pzPjhXHWvLKg/wDpKNPWSL2Wi0/ztQFv6RHCsxIAbfYR4nKa2vm+Au6rtNd57tolVc62WsTLOPGEqDMgDzVO/nKQAk3+m7wHW7yEOUqnrKxoa1df5qsgqA3WkzK528+cpwAGu7X/AD8AcfSqlj53vXcOIxnBeIbDGxZkvp8kAaNlAwQLaQA+ueQ7jArKob3Srs0i+tcyyZf5x5pk2gXRNu7suJphbfW4ryLPgBo2qmi8t3Ek2PPr0lRJg9TsZ7eZwdM9cNGjVRgveANbtUlJC+o5MA3VhDbLtCo4zMH1X3yvkVOteTpvmfge9smbRRmQBn9GnRfPGFLgA1tuOrM8TWucVF9UVe+1WzTqP54iAAOuQAJZIOQAD2/D7Yredx1xq1pTXoJuUS4AAAPfACaEliADo5AAAAOrNQDt+qp+AFpohAua1TJcyUIBe0+c1uAAAPbFqXY2fn60Ot26zmYpnhsmfz+INdehoN8mtA9b6uv1giSMAbspXKrQ5jO1T3X66rzje3ibZrvnHg63avpbb6wXgWnP0BRn8paY3sqEmn0HqV6+WfMaYMfothTHn9dVYZTJHX0C97DUs0MVEE3v1DFeZ/QLrSULuhp6VI+sS4hFwDjfzK7Rzx82iL30le7sohR3kaYP/pOTST07mdhCdkxb12anV/I+OQnuatnSuKsXAFv6bQ8vr+qzbDoQa/S8wnPU7lTSPbOkX2L2lu/Ll0ZdkvXWTDHoQDTfRFdOBnBW4xFMDXXrFGkj8cZsLvPGmz+tdWPl1MsudV32kyVUA0G3sQrOGkKNApAdaWtQgo8O8qMtbatwZlA51tX52NX2oyymlWnqchZYNmDilZQe46MB7pUtbmG/JlS1Z3zKrWjzLdp8uLmp0VLOyalJnlsASbxFrLmWrR5oCxtXNVbTpco+C7rWbiPEUmV/KLAsOWNfzzzPy0wksTMJlEdIDrWdww0a8VfkJeWb9Cp8PfAAAAAAPfAAAD3wAAA98AADoGirwAA69s0/fAA6kd2qCTwAAks0pIwA9m12R9jjALDChYc5W72vAHe/q4yhDXABneaUZMxx4Bas39NWV1M+AWouNQ4+f9S1/Au/Qz5oWIIQBxHo2zHHo+1QduNl4wpcrcVCFmM3di+sxdK1SOtY6W4lupmgAGuzuFC7Dk00Bd19thMt0CRLivCZrc0/TShl0MVUn2d+rgO/LNbkJte3ZJr9LhDnODvXbKOk3oR0vnkI7fMp+ZuYVufRnWu1VfCp2VCeDj1ro7vS6J5Mpyi3y1p59Nci8sovm9cZVOfoN6wv+dQywnrj6F7wiU3ZsMEzvW8w1mSzPpPD1pv1zFdJf+fqQ775av2WH5hr8h2/17O3WzeLpeEmjlvOJ84xyaQB59E5Tnlr5xXAZ0vWrbHMfVgHtiSeepVsUQC/pbEyfOwnIDhspf6TEZsAJ56rhT5EASMKcL9BPDwAWObHtX2EABj5Qv0eQAPfPfAADo5liAAA785AP//EADAQAAICAQMEAQQBBAAHAAAAAAIDAQQABRESEBMUICEVIjAxIyQyM0EGFjRAQkNQ/9oACAEBAAEFAvSFHMEsg/8AhzG0/irV+UWHCySPcZ9+3KHWaXj2nKNDfyIrNsknTEpFVcSVNSpYK7V8Sx6K495ummWU0kdy7Xlyvw119192S71MVHZ8asByirM2KAyElMxMSM9BjkVeZBA0v4LumQ8GLNR/irpl7z+VQqGWU2GV8+oVznUXeVHrSKCqrPdwplOMCVs91wMwCHg16StEVKVrhncUDBg18OTdu71j96d5XbPZSzmcZIRlqjwn0q0m2i1BYrZ/49NM/wCpeIkzTVbzZH73L2qLYSjfxlnppHJ9UeQmIyWa6oAL3oV4c2ZlIvAiOvJzDYFSEqkYFNt4ysUymtXtTZV2H9NOckC5QxLYmcsiRQDjW+4qFWcRSa8k6ekJUMLjUG87HWs3sWP8yqS4U2wjd+qshdX207VEJrg6Sx8tkdaLeYiSlOiEWXa1KnhTBF1G00IqW/MBleYFiTDArHKmNQuAsoLIIW5wCk9zJc3oJSBadqrOZqGRYuJzbicpG4ipQFMS3lJ2lUotauTl+tK728CZGWj3lamfKx6gPMqOneNE8hjfkOrMgo0OpytvDcB0uxbNmglAuQSJ61WuTiLTgcxgLiWKYTVQOMEAwHTJ2FqNNur2vXTNUHi5e0WB5ZzKcpONtzhsGo1prP8AencKsdSyG+safzH10wZO4whrwT9hYztUgPzNQoVyqrKfhkFI6oVjl9w9UV5bjn88SZg0qzinh3IJENEqvOVUtm2C7imrivS9amrMTFqzHBAQEn9hP1V5m622wPqjTt1xCAyS+OWUrEPRqNKVXSrPGOukUezDY2XHF6bTjtDUmIsKiYTy2zffpqGmw0f95p7VShytjo1F9mxb+9fkMxdeyWHwrks6xYy/WrjYsHYZ1RWbYL6KwBVWFbCXEyPzVcO9L20uqJza3Y9r1qnzSxEclaSye9qbSDAYzmaV3VzEiQ/3LHtokSLCpTGNSRVdtip6oNbFtBsDOf2hqNp9QrUjNnqi9K8DZ2L4YK81KmBowtvXSe0JvXyyPsKwJeOvUNlyBGg10WR61vsoSItydJLdGnpQyy7uTpIzmrWzGxp5PfYOY5ajG1+oUBan5OWQGd+d2lHe11QjYpoIrVYZriH7k951rj9O/fqJSEzqL5lOskvFa6JZqgoZ7VLBqKvaU6C7UjqlhIVsm2znJSU+umtF6JgxKW4U8sVWl5ucFFQQucJv2/asHMlzsrb+IxhQ+X/AmRMOlYuPSqBNSRHCDt5GwRqV6bbvwSUlPuLTCPIdxIpMvwRO0zeslnkOyLLoyNQtxnkunO+3ItPjGva+elO+2nJa1J5OpTi9XYvC/wCIGlH1xmRr7IwtfbMWLz7P5dvj1NTAHoCzZ7xElJDIl+aBkpKs8B9A35lQI8eraYjf2rjyemnM1/SqrvWuAvxukOgQ0c4wVLDHDwd60vm7qdMTmKTdq9AKo/hX3DAqLxGpU7ruNdQPrRC3VCX6DtvV8hKxWlo2NL7bbFclZETOTEx10ij3I1Ii7bOPc66XVMIDktsvagSsGQf+64ufK9IiZygs/JdEnBDxx1iez04Hx9VU4M1UTA0+Woz5iMEwX3XsUiyAyNhXYf10+xYSC+9IzOxLhZTqVLwmVCQ4rOl0U19NoRZIPsK85gJn99KtIGl464qjEcJrsPEVpk1MOvGpJO6qY2nqvKrFrOFoLLKtoLckT+1Jg4XaWqbFRDF9QgpNVGySvFiugZnhL+7mmTvIyJZar90nLdy61Wmqa5FwYPMW7zLVRdraejt3rSPKoqE6tCuEzOr2GEfQY3nTdNBY6jM8fpw9s08c7EQU1ltgYllVgyLOvKNggnN8bjXYsxfK+dSfmawb0XrlAnf5VutV3ZbUfKqFayw3lJSs1GwqH8NNDZsrsqkKjrB909pPrVetbU2ucMX8EH3rswwiEhMxJlu8+KyGFBH0qARvqrFKbVtIsBrTXBCc2WBWY8ylqhNmWqlwoZWcuOukgsrZ8mQ0Q5y2QsRTqPCqc0rd6BxiiVPVXHmqVJAkMYyEuCObHSxcV9L0vm23b5eERyZcZ49VqJhJcykdfVALCsVWLiR2U8a1duqqVDmy5nWvM9xfKFEnthTsGdjlsVkE2msgSUiWrwbJcdRXaJnXT2wm33OaD+In4CETjv6lK3SEJkDizXmu3pGISTjUutWWV5symxLT1Kx5V5Jdle876hWmta4TIdKyO+ZCiWoXVnI0mTlWiLiZICjUGMfHrQs0q0r/AMFlZOgk7Gts18iAZBiYlDBVhoLZ0kLfTTrciNodiGkEV2FA4z7StBAPROWP5aXUD2Ut5LyZNxV60aeus3haTZhwJsZYQq0izXKs/oMFwSlCMXSTANsrrSDzeu3cBIMebJ9dIWJXV6hFgqzAnGR3CPbFSQtH7jtiDUcyqqt2JafpWiJqL2a6xbJpd0pyS+yyP8VON7PCRrdKtQrMq02tEQhYyIbYdGs+LWkGrBJlditQjKtjfNZrwdbo90SWlU+TLDJBTS4Ks2Gdhgk5pKMZKtIBMbeiWyqarphKe5DGWuDOAuBw9rBOBaVoW2bJdimc8i9NP+5aY/qWLkCmML4hoGa6yoQF9vbqdGOIoTaOvlM7BLJkRBTJRyIZYuvax2jsEtOotVmqHC6XRXHYbIfV2fzCYd5B0jAK9eNkVuIXalKoIqq2GOUSWdRmd+IoR3cXuAnw4PczBFaideXYT6KQ15UNNfXHwz7bUSeFXjHKDixBMmWRXgiky6VU+Q9V6mjB1CrghjjBS362yZjVbGJ1iIwtcVtcustl1lkZV1U6+Hrgsj6uO31osZrTJgdaZKoZtlixNguoHwIbBwwrUTCdUlYnrEnBW5MpskTvQZiCVrfZV9fZn15+xay48m9ywrHKSeUlM8p6wfEN42qWlVW/8wZevndLf46b/H/Zx+/xx+/xx+/w7fERvOc63g/hgd84llpPj2c229xHkQqIjXo1ox+hPx2lWkxtt+FYkTLa4Vbwx4H7r3Fj6E2apLkC4bAc7l69lkZWSkiM5yivuXNcXtaxKDcy3XJDvWpSKy2tXBOX9QVTx+pWWiFhu5sNvuoUvAtKYI6YhfkvpF5Y0VU4OZI/WuUi3tAtOm1/IZ3Tl15AsBHcuWdVR27PqbJgA33ids0ZW79ZXzr/AOh3iT+93++qFciWvsrsWPFqkcsKf8ddRvYEfyetRcXCUHasaZJJf2t78GB2nKZZfa2JgVpXW6wMlFBW9h9JDWUK3js7GwsXPjQvxFPGbFOQ+7qAlC4CZWs5WyKte6uurxlvVLay9NUjLbu9Yn5lqWwvpEbzpUb2ZYQv1if6bDQqKUTtiv7/AFqclN8qnYOUKXj3GEK1CYmAXaFlqsib9grcmlq+tVorZSrCt8RJPbBLUvUFnDTYx5q55YCEIikKq8/vp88FzblKtJsnKavZAxKYgtsNJOixoz92VHLk+52uidu7oP3QQCLNTiG0s5fZEcprvKu3fcuoM45Tm9bnwwWyvs90EuWLtVLMwvxLdhni4dlqZmS36AMmSX+KQwhmOjvAtIpxczIWHOr5AExc7ktscXdEXJQtWubyGpIdkmZYLGmBG2C5t4leSmGa9ERYvy8egzsWkthNhyeWQnZN6maG5TapbTmJJKDeZ7c8j4lDacYepDwoNsTNVhpbZqsnPGKvWtD3ca4ScydOpw6+90/vpXZ2nvSu2dBLW5zGGAMZaZC0yQuEeABcMeL/AId02RNRI82z9h0ET2GkLAsDBpMe8hszLML4DpH7Awyo8bC7QsxoQ4HaHOfR7G6dDPLxpp1+oduMF4HkoSgHB5UjqTV5LJNoDxZbN1ZzirnE/vrRn+pIeFaHENgLPGrbsdzE2P5X/wA9d9pks6iXGSHjgcedm+5h6W7ujfZ2aI3WrN5xZbK+LCnkXUZkZVY7ZI1MGAvYo+6MNylZc1XiJsJuT++ghJzTirTmGTYYlocXl/KMdqwbpx4purs0Gqj0Ga6hrsF9dqFxBdsp8T4inONLs1nxxf6Q5PiyHw34dpTeF3XG/OV2Go7donP9W7iwT/iGzMR5RSqbM8WHJ4qF+P697arVXCVhfhlxtuE3raJYtjZZglIyU8p9Ktw15ahnBJMYyvqfaP6guV3tQJp+y2SubNiXPWfbZqjobf5xGFMSPqBcJu2e+2HHCY232qfTZ23ayGRBbR6omIcxptOvJnatWJdYWw1E0oJnuNxgrm2RhirjVLmZn8G/xkzvP4JKSnfaM5/xfiAuBzO5ev8A/8QAQRAAAQMCBAQDBQYFAwEJAAAAAQACEQMSITFBURMgImEQMnEEQlKBkSMwM2KhsRRygsHRQEOSoiQ0UFNjo7Lh8P/aAAgBAQAGPwLkmF1D/wADg/d8R5tpjXdWsYGsCDRgAsudhf5DjO4TW50nnpcnU3iCPvbaTJ3OgV1YGq/bRTToUf5XNCtd7OaFTS05rhySIkSOVl3luEov9mF7Z8urUxsYgzCPtDR1tMVO/f7prUaQ8rNE0VfKsWHBAxCdUomY2QBOWSg+IEwv4X26l9n7tQ6IU8Kvs/uzm3/IUcUcQDpcdUWPbBH3bKY94q2meD7M35T6rh05gYkqPOz8xyRqPYQ5gzc3RCow3MaTjtzEk9Jh0jRya5zRPxRinB2dZ5EdkWOzH3DgTB0TXCmcFxKg4TtzkVxb2PDcwCm20TGya6AYKNowJkp1uU8mKaLqdel7pJxC6PsydIwWEfI4fRNNVtx9ZTn0ZdTzxzHKIwbOZTbco6W/lWfy8XfyFFjhbRogfM6Ku+ZMqmzRzsUXuwcGua4d1cwwVLRHbldTgWsOaNraYp5YjErrYITXAYnX7iXeUIijIG5zU4k909jYu7rhsa2fetTnF2TcAndUgaXKK1Kp9VFJ5a/Zyczbxx4zam9MqWufHpipN3qQFxQcBir2NkRiDsnWthh6m+nhlDdTstaruydgBAyCtDLY+vz5GPzAOITagh8t62790+mAbXiWkpjjk0FCkD1OPV/fn4LqTi/QNGaLbIhQ0x6KiOyAGZUPNvxH/CsbdVqa9WSkCO3IGsdYBsnNeOto+qmFLMCri4NadXK2XOHbBBrRw3I0arATGCvc4mPK1Go7XxuaSDuEKb+JUqOwHVgr2gDdYzadk6nMzliuG78an5O/ZNq1wbjkwhRH0GCmo7r0YFYynYN7uY0qh6CITajJJmTjmg+n6ghDYDmDd0KlQDi6KYE5wrk06yWn5LivGDMvVGZ9BqnPrPsp6NbgESHN/wCS6oPcHkeaTZkZ7KC++7RBtV7J7oN4oJ0XUQsYBTG+YzmEH1GyN1fTN1M68ooVQ1gAAbAzRjJbHRyI94ebBNph9zWtxlS6mD+enmsyWnIn7gT5EbT0nNfxFIYt8w3HM1rTDjkdkAwQESg5x6o/VUwfKako3Y9R+fhDDauG57Xf+m0THqi3Lt43OwYMyrG9LBkAgafm0RdFx1Qup02x+ZBprDDLspD6Z7JrzaxoT6bfLbontdqMBzCnUbez9V+E5hInq0TS8wZxEIVG1A2zEuX2fQOyAquugzzCp7Q7htPlb7zlDPZ2+r+pRZT/AOAUshhZtqFhGGSIpMJY7qbAUuo1AP5eT+Jc6X5Nbsi4i4p25T8+HRZ9Sm9QYfdcdChIjtOXgEbcJRfTJc7Yn9vF9KrkiWOa4dkKr8ScgojLTJS2kI7r8KkVbUPDPrKxrz6BfZCXd1c7kimyVdWqAdgvs2gQJJ1RccXkhVWPgPT58zXA85r1B0N8o3Kc46KD1v2GQX4VNPqVKdmEZ5p7PdVK0nGZWDnD5qHANr6PGvqiDgQhCp0zm0YrpKJZU6tlXYxs1H6fNQcFww2q9m5d/ZAtMg4jxp1G+Q/RPc0QHdUbclNjx0NnJcQWuO9q6hBUgyEajaZ4gz8Omfnyiaj3POVNsqcUSBI2lVH4CG6KKjLnZTOYTHUOEbh5aufpsn9Fjmm1xYcJ3jm9njIgn9UC82ke8sPaaUd5Qe+rxXDJrRguw0T3nLIIUabotHVG6Ad1Uxi4nRdG6qfI/oqbnZAyp3QZnCnTZMrDIhMqt/3AvZ49536aprIyUlQoOcgjmua4hyBBA+Sxpie2qirTjuF/EUXZ5jmtphtzjElcIPvjurw4RlgqtFh68B9fCq7/AMzNEk55838M/wA7cWd1rHbBQFC6sBugxol+jRp3V1RjHOOrgrRAA0AXGrGKbdPiT6js3GfCi7PpiU6fCwAw0bJvEFvs7BElXUmxhaCdl04uObisBJ3KL3mAM0YwYMAPuZJ+4Ia4idk1vEdDcQEXOMk6/cyFjWcV5yvxCsK71jUK85WFQoGo8ujfx6epnwHJdXs1P6lfgtC/CYVHApr8Fv1X4DPqV+Cz6ldb8PhGX+jDnNIBy8Ta2Y5wBmUWuEEZj7+ACVc6k4D05RGcri0hiReB+4XEb5H4jnaFWcdm/wCeWmzc4qtTI6ZgoPofa0zqFdWcGshUmtbAdlP7p7dnEc1H+cJtQEB7hmrjEeqF7Ze9pknT7osb5cyrnNhu6AeMJxX2WEaAfujUtGXVjmplvYXSeTqyVlVnEpHqZVp4wibMzMgYFcb2WDGPDKDrCGOy/wALAISM/HjVMGfunezUGxP4j9gjZ5dOR3tJc0e6FXhvQ8zdsg2jMAyVDg6wuzbmFSJPQB0u3KrkDpDuXBA5NbiVi0T6zhshaxzQPe0VRxONkegjxutMbxzcM1ftNQBNvqha5lVoM4KaxqGcIOSa1jKdx0asH2tZi6Ey2CKmBkJr6jY0LhOHqE6nMxyWNayrR3mIXUy13/7VHij5h0J1BzQ9jsQDimPpk2Oy7FBtXAnXJGqbw0a3KpUMik3JMpt0bkE6lRoZ++cmrAz4gvrst2aepGmQWUtlecG+6EQWxAnFQHKXAAtznVqFSnVmP9smFB5IEn5whxXww7Sg4BhbGiNjzGxKrsicND4S50BAD2cOI955xXGpktw8p5Bbmn0zay9wc7HFBtIt73apz6l1rcozKLv4chg/MqxhoxyCEIm5vktLTqpfTcPlyE0/aeEf3QfV9oY6dMFcLQgS6XZ5QjRLpeOphKArNtc06mE6n77clTpHBz8T2CJzXDc6kANG5+MTCue8Gp8LdEGsALu6AJLqgEiTgrmNdSdrhmhpCcTSs+FGhU+1xwbOI9EQ6Z78gb7uvdADMpsfDGCeJMeqjG9mOCxVRtNs1HxJ2Epjd8SuFbjEXcl2sYHuqrwZfOJ1WIcQ7Uq604YQNl79g+I4L2h+3+E2Olzc1UqXzUDSUyMAW9Q0RjLkaW+zXH6qalrHH3NkSJ7lXsMdkGVGAv0dCFRpndO1UGg97Dq10KQI+c+IsEn9kG4wf+rusGF1pmBqg99O07Sre0rqP6J1pA2X/aBrG36roh7B2uci6pTcwfmETyNvk6Wq0OjuugyNyrmgRiCvsy+nVOQcZCsrdIPSZUOxnIhQ7k68oz2TwKt73iIaCme0eyQ7DyT5Ve6obtmqKrnNtyA1+ah3vGSEXtnhAQfVVrfNaVJQOh5IbE9zCkMZfo44oUy+dalWpgPkFfeIdMT2RqUiT7rSr6zoBiJ1KPBddUOMxgnPgCTMDLka3Et+EHNMvxIb1+uyNZ8GoNEeMZwwXEpYtP6ptR4xb9U+8dMaaINDr431RtA7HZGrVJeN9ByCodJgIFvoinGJuNqy+atP4tPX4grTi1cKpjTdkUW5jQ78nSQI1OidX43FPYYK691p+IplIRc9wBtCZ7Ix0MBglMpU+hjQsU4W9DjLSi8ZDx6ninTHmeVZQbUeN3GJVlRwadw9dL21WaFrhKuqPuHwprGAW0zg0bJtTOmMLu/Ndw6rqmU7eiB4Vk4w7NADBjTjuULcLVafKSrmqWkEbFW1BwrsjOCLmdBOyObd2zlyta7yu6J2TsUw1LrpuACmC39U2oxG3yuxCLYnUIfEzkqU7gJ1Rbg5uxQY1vo1oT/a6tRnFaIawHVNqO3zVwOWB8C1wkfsjTd8jv4zk0HMr7VznPP+03++yB4ADjk2clZaD+VmCe6oWMpDDBW084xT9LzJHMwu0xVXh4MaPMdU6lqMSnRmvtB2WGRTtlY/cKQTZkUW1WML24Xt5as5NIVK4TgMEToVii0ZZqiexCaq86Dx2bqVkHEbmV0MZ/wC/DZPYQVDqcforqBvbtqFhLXLrFvohjmuIBizHxotA6KYw/ym1ax1kDunluZ6QnS3qdiFSZJiP1Rc3J2PosiRvupc9gPwziOV35mlqrM+JqdUa/qmJTK7R5jbUasN5V7R6qz8tyewHzmB8lD2XNJj5c1dm4CHwotPh3VJjcTisT1lCj77zcew8bGmKYyCik1t3xZyp9opWbWha+i8pjuvLd/UralPq/VfZOlv5l17qpOojxBJxlU9KTB0j+ldDscwUWVaeI3CtfWa1mgxKAp0HPfu/wAqdxqrqlR25UvpVTtGSspvfTccrgEWOzHJA3TW+8G49yoOb3SfomkHRXu8uaLm5v8A2CpzmcE+hUEY3MeNOW2kwuPZPNRol0arpznFfaCHb7rFzVbeOJotJnBSX8SppsEXOMk+IZpmTsuF7Ownd8Qvx7jsrj9EalR1rAooU2sZ3xK6gx3q1dQcP1WAcT6IXYN0aORjmgh4zMqDTDm6Y5KHey/+4sKB+dT/AOl+FhsHKKVMU++adTr0xUB/pWWEyOyucMeS4RIV5NxnVRw9d1BpT/UgODAAjzIEty7riOE9uUEiRsmsb7MBHwmFhRH/ACX4bEZY1GWY9iptP1ROh05XNHvZqI+a4nA4hGUuyX/d/wDrQwtYMmyo8cv9Jj/qM4+6J28bbDxZzn7rDHssk+l8J+5Dd91aMfRTbb/NgulzD/UpNMkbjH7prWeYnBVWDIO8C3b7hvTPbdMqNpBtQDTVFr8FdqDkVhlpzMNh6sRgnB1Zs2n0UCphsMFTb3V/xAHwaMMcMSngxnvzdxidmr7INEZvOajz1T+iniGDpkvMV1dR3157Xv4bx72hVzHh47K8NxA13TmFvXdh3XG9pdcdG7lFzszjzYMDiREFVBVkVgcApPuovZkEPaco8yDwxsTlCuDYB5uGD6oxsfA1D7oKpvHooQKdvOHKMJnIboUWfM7lPdt+pRc5xJTfUo2xMHM9lB5jRd546XJpe3AOhwK4dT8OpPp6row1P7JxDZe1kKo+60Nwc4o2i2MB3AT/AGioIEQzvyGNEwtcD2Tmk/aZp9MjMImEWnUq1o6jmnNI6mINGfIasGBhPdF2xTXjMFB7QGVDtkqg992CNL3pkLie0RvaEXAQMgNl3TarmmH6x4gK+2W02SFIKpD4jPhTfxhdJwjwHM2uxrpb2QL/AGfE/EP7rGeF5qe8oP6KcZSLnI3Bp3IbCFk8LzPORnuob7MMPhZKbbkPcC66bm+o8Tf5HCCqdRhlr065CoPMxYtxTXFsMGSlH4nKpUeyHHynkAG6NJt3URgFL2x/NgrQ9t2wXXhV/wDkrouJEAJ9z8Xbq6m2R+Urqafmmh0wMh4iclUb2RacwmW+5h4BuyhXt/ZSeTFrXdnIWWimNIhoTWn2ZsHM008+7TwCqV65+zB8vdcHhtHq1AY8J+CcKdKC73nCU+xlNjyPOBipM4+IaM1SpXdQQeHAT3XCpmdyukS7dYj6ro8pQq1Op2iqtfjhKeNj4h/BoOxjFih1O3+Ur8VzfVqvp1WkfJOc58sbngFAfaSJGGamo8AfFgsa5P8AKFDGXfzFTwaA/o8QU1s4YglB8CdU4P8AK7D0Rw8JqUr8DqsBChv12Rty08ft/Z3f0uTaXs1OxpGuJPyUPbY2czh+iq025h0p3CDi1xnAZJt7eouwGsaqjI67wnUq4c0bkIvZZVqbNR6ob8I8WvRfRIuzgqahgDNcFmAjwdGaAIwdiEGOIwRp0oLnZlOxnx9/iXfomi4DHMogEH0Qc89OpOyil5Amunyo2nHMEboz4NHz8cVTskQOuVb/ALgz7900smAgKoGOquZDh9FhTevtCG+qd7PRGJ87v7ckvBd2BhU2UKQp6fEXJoq1HF+tptC4ns2bc4UFknc4FcSqZJyY3FX1y4Fzeluysa+5sXNNqvY+oxzs2FsjlETkmDV2KNSFGsLDVUscArts0bTaMsOSVIy0KBeCW6gK2QGN8rRkFUYcy1Ru5Sx0K9rLSfMEbsGhTySFNOREfJfamPzDJSHB3eZWOS6qlvaVbSloOupVQnkgLj1a7HvHlYzFVK7nW02jz5x6d1Tpsu4bjmTiVSuYwsLZyT22NFOJwCa1zp4dTo7hDh1bXN0OY9QiWuFRuZt05aTmuN3vJt5H+VN7fmVHEasM0SEe+ACeO/KGGjjdncpGLU/1TRo7BU6Y2nwbU6QBlLQnnDPbmwkYD9kXd8wrrsdii5ztcsVGfqgSZMKrc512ERzGjnc64/JU6ntBtDW9LT/dBukWsVZr3dFWCCi6kbm3XQNF1fVS0weynltLulB9Iy12oTKVwadSVw3RaN1Lacrp+u3OHCPonvhuJ0amv2Mqp8IwC6Wj90PNfrzTAPqFNrR0jIdkaVxtJlYzHZZvvv27LDLumAMDbWwY1RGGPM0uyGKue6SqYuzcE57SQNFcxxBRcBE4x9wGNw7q14BPxZHwNNpwKz+4jwk/cyTJRGGPhZ3n7sO2RMR25v/EACkQAQACAQMCBQUBAQEAAAAAAAEAESExQVFhcRAggZGhMLHB0fDh8VD/2gAIAQEAAT8h8lCY8rU1pP8AwgVALWIgImEfplz4buyG9DtZXuxDnymIQqlFOdXz1FtAExK0msp4ZaWdP1XqK9DuMrAmxo/llGPVAr98y75Z0PRwMZsAJQ15dL3gOS4jmAN83HXuRWszA4mws/7Pxfo+kBvAtd4UZD0TXP6ww4VtSMXipdv2hN9ZIaYmI4jgKTxxiti2W7g0lnS9JlLviwcX8m0Ipa2oO1/3WKY14/Qpq9vFOwaLdCa0soDLrXWCuYmZHgzWTquG7xgZNbaxq+wgddYp0PNbXJdcMJ3h3PBhybsw210sww/MCSlpPoWZkz2uEhuRxFdhmVKmGuahuRrLZD9TVjbLYwWanCthesTXdVKscmPGlMg3qYcCaQHF/hlvU1tL7DEEJlddZ+HpGtlUaK3OzEqNMBj6/vymRup+qDzrAmoMC9XLN3X4tJm0yuuvxc05YTe4cZgNhQKe8uySwtKDT5T2lHD+xXNQc0PnoxsNZyNvLc+iQZzzCiGwtYFahkzkg1TnOfoaa3ywwtH/AExM5o5XLNCADQ50md4LfL/JaEuUcdIxDwmgvsSiQ9h+Id96udd2/iDBZwxE6hmVZ2ovN7wbA6JCF5RNap/axFduIttCJKoPLwKl95jPgPoO+0po1VdnYqEwBrtFvK/G3ktE9UDeON6j4Tw68QOrk5/vSc6rExeKuOYvovR1/Dzk7Ew1L+5j9neF0hDLdjHQxWY/3VhlqlATBPk7PA37wi0Pa7qI4CXZt5OD2sbeWJhTI8I2WVXMRYNeIW1pYrlYCapp7wK/+uHvAHla2nvtC4A9Cn1mvI78QgXolJEDoWJP8REo7FiKHROCvqwOTNPK62iVgsstU5RGC7YOHvDwzbpR/qWBPBr68RVfNUlfavM1z1/g47TA3A5mOv8AsB+3hio5+h92/Mol3oov7TtspbO5tHRJsd5XiJj1hoWwCXn7GkzFTHbD/OY67QLcL0dLlCRd+dunWFnmuVR8SuonS0Pr43QnMzBqJcMI3uKVP2xJN6HB6SrqXguW9gGkueDinxNK8ldSAs1Y4eVtkmrP9w2dHMp1aG5GpDvS1nMUC3e2ZVHjYUhveuYBKPZqvv1+gMJbZOP7iLCxMeF3j6aVA9TzaMPfLe9adalVUP5Yz2t1DPik7xWraXfT8BDpCuU2KIwllwYFaDWhF4LMNY5XLLsLtqvG8acqYeiTCeHThEg9ZGh6zBtiiqV7EbjTk3C505sw6nttNsEvaRD95o63lFGxpm146MDOe6wOOFFPhO0OA5zm5ZNuCKipZ01r1zN6oHmRFz6MHQ2Os9FDIfxDcrf9aTBQK6bNTtK4qbjmoG7aLq5Pe51EAryBTkxNO7r9oGLD3hEQM/6mlLC2swsdMyOgFsvpt6wuZ6lD2XuRsrbmNeWRhoBfUmFh9Llv+78aRKRx4bBDHSEgFxfT0gh7VckZRw0DAi9RQx8wzNnhqowrTgGDWJOSVvdLz+I4R6HkHOvvoe8KpfdWFtUjn03p8Q4V9qY51hcRiN6D/VLLxgUcP389r5aTT9JLWoVM6zKwtUruMWcUdn9zK9wnJnTWZcDJCBjIkHGP3Ah7aia03DUPj9oYaikdmWwLbwczbIa9d/m5iyrdZq3MlKjnCWHXc/mKyKHN7QGqdbPqaCCiHYbkovmXk3m+xFVaeHiXMsDqF14Gs22hyD3jO/pHbdltAf8AJmp+YzMYFNEl5qWhmS7wkTSgKLtv5WDrdaeoa88SyDJMt6QLKmNK3rGPBR7q/wBlu0ygpgqn0mPeH4a3Y05hVrbtKYC2sTzUEsgw5bRdE1AduEY5KNV1P2gD8nUXVf1HoMaAOr7wZrzZzUrRvXGftUVZ6MveXQOV1vAq72d0L8yvrdJoEa6MWym1IWfqywZQLWuY0ixr7P0uOHLZxeagoYekxzuyp/jxj8xVWtvkGrwNm8PCTtKiEUlcvMKv4t3Ea+GZRCb1pU+ar5ecf63mkMlup/7scSzYvXZrWPXEPy54Pd+PBVrNexESu1S+4u+rzWWLW/Y6h1jQwOpTKUFN9Tft+3SPk05Mgd4aTxfhBrU1put/Zm7FKqr1iIHQqhK4WHJwTVyihVl6ROxQHVqLlrXRij4CJqNDeHOJZWSNdN6i4HRY6Jd2dEvtA1Dbn4m7qEwbDr1sfRuCXS36BY3Varm8jLWBNIlBVq3+igIiZEh9d+Zrb5UUstgtC9Y6gvLP+3EbjYHii2nitFbqurma6IKWhPC4jg4PKzGAd1mS8vVQfHqSTADzZG83pfZ4grQWsrNfREpDBr5tVWZ8coqM+cy7Sg5iYFUmz9e6I4C45BdV0eVBdMV3maOjebP49KiEF5g25PSIqC3XzcUrntvDgQ1uNF8V5cc2ewMsD2IxNTqdSVhUE6ssQgK3eZYylN7S7dXE/h4fMKdX+yWmhuxerLcSdwv2lXrMGivj6JrovaAnuxogd3aE1bDGo+0wL0N2ABfa+9RqCFclHmubm3lyJQ58mHl2RlfnFbqxl+81ormY7tdd4Wufdj0H8RN8lvt1dSI0j2giQpZ18AVoLZtv2GN+P37xNZ1UwalP37E6KNJ3OfJiRNS3V63xiU5Ew2rhiNZndM6gcTV/7W6HU0iObW6MNtBubdvr9/KhQXtE11JefErNwiVAK0OK1J7x69aFGMR91PEah/STTyjNAt8dyHSAFt6xe2GpaoHq19K5YRexNoB3mJy0DhN1/E3Z1ZTE17fdnb9k3wGHxKsvBLn04Lt/HqS7yHZPlmV4W9kv9nVwML8TVQdtw2+0p/dgOrtT/vEZMC0ZLwFQPjc3W/8AkrmQFaRMIYZOi3c6vWEGUOefEDC3Oem0RwBVs9fVm2Z3e8Gd0rdExhbrO1TX5oc7puSl/NgPZyxEBE1HydR6oUHdixplyfdhJboCxfNQqAXawLdNjcG/3BSKToxhhTW+mr2muyJL6awTNf8ANztT+/IAFb4qAGtAOHCa8ssGYxyF2v8AcWYB4egdI2cCm1l2NYSiAFODED5NMRysi9lZlkYMXavfyc3DG6+75gGqRaY+o49pWqGyNwmCjAsoljgWmvS46L0relZ9JXnKF4jH3kuSBlU9Iq5Cy+6mPEDQtuxhWWcD3Op2xEbQx9zwQEb3el5AmBcLQoX1zDUmwnGkKHaimE3X7TP7tZnnV9pi2GsafJiFmqVJ1mLaJh63VO5jyzPRMGU9xZrnqRNmqCEC5OCn2ZpobJ1iKFcq3vjyWRouu22MvtF9anMpTN2PiGFkbGoD41OdHY3mb5U68kOqrVlow9UJdu0DaShXI7RI72PI7Djv4iQi0ZNT+z0CVp5et0iGtcm+oTsta4lB6LY9paelrscSjb9sPXaInl2bPfxw+uRdFsstXasXVbuCWjGGvb0m4rtRJuBoLpKlg1KTKorF3Opc0CazVg7dkvGyHH+LltYa5jpz5AdItAa+vEKcLrX7TXgtdxlsKtrcZwdRU6D+48JtUtB3+CKTkM87wKGuRNHyI7CQUu3NSllhoAvOsrX0XRlWSA8Ry+nrUV6MsNQ3FEDdXT2JbUW3Zi4M8L2mYL3bYgkyIPkPZ7h+6I1+we1NS45OQC6fAQwg4hYNe011FQ0LvXb8xILGIHnSF2trT8+0QubNE9PIpixu4dvrpMgFlw6HS8RrGAlbB68y4FNOIqQqOAtINTuBYukfKHRBo6doRgSnWDvPvKHqJwpvz+jyZtE9Q0wbjLbfiY5NJXIgA+7Ki2yaNpRQaLPid5lDw3p2ld6l73pG67vG8RfSUwHJajqlfIhth7b/AOTWUquz/kY/NAtOqxsJ0+d/YmghavKwcVObNGYbGbJIGDMDnnxGnPGx/bNhsAe5VYJb2xpXHqUwJwvhOo/udtta9ruF3Iq7D9xtGbRy2rbylWXpLPR1KfQN5vh8l6us1WQrqQdOVKjFFozxnSYnI/ERKO3o9451dDLvMktysDsnJyQtzu4y3PKEKta2rZ9oQHJbxF1yE9b5jNDcQ1gCN2aJHj8bYrqB6LKsrS9vIeBEODm6/uIGFnCNkEXr1qPzKtlM369ILm3UnneA7H22jM9NVLQj7rkndz2Rz4uGPTK+Osyp1oBh5/ZrHZzFeriEjT2aQoK22HOZTN6LXJR7C+0d2hTPNVxk9gF39ohUt9xOnYwvtBi0s2+U/EMLrR6yhDQNG8Rruges9WYizOUXw7RvwCDwO4e0ww8XC/vyu+svvDhwIrfEMGNo2izK75mNOA45lHJ9g/7FxMF37RRWr5fFy3R6EHO8FPjpKFNtn3h+8QrYGgZEvn77/plsotRPuS0FrnIhbg3XhiPOqvRw/jxpI4Dlc/zpM0lck8mc7k7nLKoSoDu5xG4wSulpbrtpOQeq0d01RDgDXZCW5v2yX6sez5KBayneE1byPBZ/stkRR0UP6lvlgZwNa+0Tr5KHhuLsF4ddmLlhzdC6lrUGjY0e7cIciJdeh5g2F1QF9PKMfdj5r8zog1fg+/xNrhimIMLqYZCTc4zLUDq1scQbPCHfZvv4GucQQjAHB3es1x2qLRW9gUyPVNpd0y9XtLId4qFbYer8TacwK0PeLKdqlMxDKLUbQ7po+q/3x4hYQrXpj8wg7Bw5f5BjIONz/pDEDA707zTj2m6HsdOtae99olDmlwnY0JQDbjXuqob0M6y8WQX6Su/kOL8jBvMnlRG9ERjAjjNhMmWFvMzLD8OYZrYDJpteq/EZwD6OurF1lAl24T4iUpd+TpAaNKQgBoM59ajQEXslqYowIWC9ejeSaaNTXFzkpYLSO8uzDQFfBmPQVarr453DJDQDddiK4Ts7dc6Ebs08HXobzbsbQWoOevQi7baln4mzvsfJMb23GA9LqRMqWdAdXr5GUCmotNHpBeImHYdNZkj4SietRKnb4PiDIObgfidCrtb5IXb6UbfEzQLqGvYwcI3pv5EMFoWXTL8kCq1qL6TVcK6m7OHxNtJH/E1ji04cTaSV0HloADnlDBMZwn4jU5PVMpAWXbrHF0FXiMNS3gI6LmaHFlryR7HyPhWFunH9xDJZ3eW3ECcqaz2lu/8AnEtml3GeYUXKd/Aoimd+PoVKxf06UtRu/UpS2jdjrj6YEjRzx9Ibi1g5msabxedPALHt9FK6nAzMwXtipGx4K1Cb+erkFVaolD7XV5QM6nkfdL9W6Q8C/wCVRSpKfPVa+AIWAHWMnag8Hf1VeepcDLu2TJURxc1NHCWY1irVgBgSUoYF6HmbYNcuqUkNbR2fMDhPUidjsw//ADK/HgWnICn9zQrPQPm2hwODr+iH1YazPRxEK9I6SIoslMNuITEmnI06Sn9q+7fzmqXxSw69ZuCjDL22hTldDUYX8MsccnQ1hkA5Mo4Os1/u/rmArR5cutVL1iaqqH5l0GzPQ1iEExFcQOHSc9O8sUEGppvxLZJ7rjyhbRAyWinfx2l1RXa7RG1WSslznEvx+ZVi6v8AP9y3TNb0zNTi3DMKuTsvWJSMY48TXMo9k6LX+YIRcc4scz/bTRDOg9mNKGc5uBu/jEFkgzSfKXjqaPSPl1A1t+zZ5ITA6asaMdWYFOqjR7QQ7X2Fe/4lNgSp3f1HFf3eA4rddYG1ABdhV941pqTq3F9qvyOAuLfvVGpneZSnKzC/iYeFaBmWAdITbYB9ZgHXlx0lyrMdouYVt18gpZtLAtPzKBtAfeISgkSDr7QZu+NmW9Wgp4i82C/ukum0PRdWGbHhlANiO1pswQ6x0DxY3Vagp/kMfLKVLMXxKsxE9YB+YZctQsO9e6f3rEdnaDS1z9vMnMUc4POZU9pfp3Qm2riXY4m//Zlzim3wTNzbpZjGtSbOPD9RL1hY9XaZE3UZM8wW/QjxBBcXayVnStonXNIqTZr0ge/t0i8kYQhvvJBc4SV9Faf3WYKvHdlqaIhbFanMvW7kO+6SzDzElasnHb1gnSb7t7QaOzsTiYc9wj2m70T7xWLcjz4h2UyyF7RWR/m5cNTryxVyUquv+k0jblF96/UehrCFVgmQ7TSN81jyWSlNj9RCrtYumqK3FyHWKg6H7+80V6D3Ue0qxeKKrO5pNTaYraW59sMZLLy4dr6xAsjWT24jE9tS7+Ik2moORLd8zGBLpyJd6rexMF1ZodogqekIWr0BLqZ0nQ6EvNyOpOuKeIIRgouV1Z2Pipp6zih1Jbmj4ix8jRLwYl5wJVQe20rvTujOJ6P5jZntn2IupdMG/fx6GMR4sidXD9o4tMwjGDZ7G/VAZ6sGpyeFCZ0FGzFzX4u4ePGqtBuykd3Vx4KhoejFhSna9n9zWlDDsAS8DXa3svxBaLFK1C7/AAwtboZbP7giQzzRT2bSyLNV6ZfmDpZYVE5xdnecH5C6/BLSDaAURbX9vC+NBzMFApis46xjlvxBk6L+saGc1rBfQohJqLJUqRu6zjkhoQUMl5fHRGtLpWE1XYy0QOUSrWGKoDzsP9Qf1uoBaUEZhArI6/6l7rpmNoOZc/x403K6RC62va9ZbjouUBrNyBLdIFLFPSNVO+tHF7iopEDqt9iWMwDcYdfGh/CzMBfb3RAWXFOhkgaFRm40pN4Zj+MXqGITOKg2+IQ1Gg6byvWPKRYBxx/yZ7dQR5puUtTZzXiNMS9Clv0lMWBYDWKR5K0itbBQ8LVTmWmhFHEsBadjiFFa0FnyVOo3OZZHtsGSAb3HSJWkodBL7aj2/wCyi/sZm/N05m58j0vdJj9S31zFR7+S0H+yoxlOc4nxDFOzXXc2hwn6GxIaQ9UsA+hZ9oFbun4oJ0eOMwBg2c+NUTqrQes5w+FHlZjHAI1WqHLMWYEXhubcc1UwGNBspj+9pQ5mkCXePj5hswRtnYz9mY1RVgdNNYNQYNXVXkNZeeCrbSuomB2hJU6wNN29CZIs03/EsiQPvHBnM50EFGnp5dyXW66qOerjbvxLdwiXdWL1KmRtLvX/AJLwYzzFdYXYX2idCLwHy+mYBo0fPREsCIdnZmDKWqmdHGC1YjtZ+gPQj7WBEqWtAw58ltVePAO2Lo0QPlgodgWW8+7SJS6mwq6b+fwS6kHAcemp7Q6o7o2M1zzK/UmOT35gdgaKqKrq3WvJcpemXoR/KCTM8nld4KElzbXtM5qF64I69H6PPYhR0YqR8ARBtT9kT9dF6BNinlyi4qs2dOk18vwoDEwlThNkEtFpc30Q1Ppr8pz7BLdYW9USn6iZ8wZWuHNZjJz8wgIcq9My0waPSCQLiFmGYbO/0KeK7N+8Y7MHBLmBx0wSlVd1f0LbFXengjJa7/Ruyoq1g9EarPCmk3rXjT6ahAqunRlUALdNDzf/2gAIAQEAAAAQBAAAAAEABgEADgYAYYOAl4JAZoOAGUGAdGWDAQAYFUUoAAMiASHsAgV4WkG0BoScSiGwAEWPUgPwOVQ8HALQBlEkAAHAEAe4wCCQEAAAEHEoIAE4ruAwREcoC9GQIwPcQAcYJAVqOIBiIgCSIcWyJweqWQ/KC+LeMQBGEYZR5YKcGkkkRSPuAcO6AqCYYUD0BgAAAgBAAgCAHgFIDYLIGgBALQYUcEH8XYAAPwKie8VGRkHsbuDXbeZ2PKR4LuSCEYCmDQNMYgKgA4RUIgHMOoE4FACACgBA/8QAKRABAAICAgIBBAIDAQEBAAAAAREhADFBUWFxgRAgkaGxwTDR8OHxUP/aAAgBAQABPxD7CCB0CD+UyDgXTIn5P/wnbIgDa4mF0CETY/41zr6RIcS17xhUwz7a2/x4wwOkTKdv59Ym1xbbL8f+fSEjz9qRs7g1FTutm8W8HinXfcM+T5x0K4JvpPD/AJUwBlEB2lHzlEOSZ0TCDXctHUtYfIMEiGzYxZL1MY9FaXMJZ3AqOfOSHuzk4TsRK6+0oDvJghSficakZWkWYMR6+QHJomqhm4J7AyebCR5fIw+QHl/wgoskNpxkNw6P+c4I9A6KpX01jJ3QJifnCq6aivENU94ickGD8kgT94NTE4WcscfGH2NRwWU/LnIWR+/qDkzCeB4mPODJ/Sw25SYlppJ604wI742w1yAh6PEjoa0ijKWCFN1DYqiqCa8zyPDz/gsQYMLFT9QSIWt5XwE5y4NR7A+Qhi6yZgqK1bZpmyPeS4XKDvDl/wB8byeTVhbBBSJSVnhwgBITiIJSJFpZDX3GqHHEZ25RP/mATkIFhIEtM6guYzWO5ZezjFUus2I/4InhTMIOn3i5wE5eZ84TjYYPKk0+sm/KRY364nDLRlJBys1J2xPWceOSUOo595PtG9hLaCAFzY4m9k4SEEJhbb4+oYKSSEoeDnEIXBHnCBKK4fWNh4pAeV/YIwgFZYbtV+2GagxRHUtMFk6ekHEOl1BK0fHSk+0VQi0RNo5gnxxixVgB+UfGOJO8PErzum+q18/UCIU5IgAJehKsTEsQkPppCSD1fGA5RSNjrwWfiMnVST0QSXjIe0dkAIGI4gh1cZ11m0OQ0jyNOE4WTQKZo4pK7H7YYoWAMJZaSnz+MioBImFozV6q8KmyO12CV8YY8ja5TUQP83pL+9csNVN/36xIDIWI8cfCXzkiyRVF+XXxiogZzQmD4x6RrIbERySfnWOEaADeFcG304ragBJ8SQ4QT71H1y/OMclBCL3/AHrIVkKDY8fD9W7w91IeU3U+sinxI3p5OS0UuSj83OPjmyBYQmnyCLyFrFQHOJRGyuMJNvBhkDwMnxgKwEuGU6y0IUkUhQYmJ7yFsFLAFslSuT31D4LQlGKAKzrvrGAOwVcCChoA0QNz9hcrhRLQ/DggPMhwUjEUYVU8WRhpqEkwpJrRF2OTHWsiiuSgLi+LrJtFGZlJAm51lCU4+9SEIqUBUQyu2T5isOkyAF0GCKrnD4tISZCG2xEmqw8lwyJUuzsQ9Jh9WASq8YWQgAaiEx4kSSqmgYXIVVDS/QaHxJ6zUf5VPSb+xgQetzJtX/wrB1IBPAy9zi0bLHOQs7A6wiF/GDmoFQ9O/jDzkLDjRKHGQUBG80S06vjJvFgaPIN/VcxGSVQBs8z1U8TNcYMEOFcS/V5QygjwmCk1FJspAgTcs5yp1IbyS0et4YXyIuOsnrrxhxIpBQbTm0JsOHjIwGyJ7saGbJ5Xucr6kOsWCMBNJEIzicg040IiD4cYV47QEJNa+N5ZuczbtiD8z9wMoxVjMy5JrZZK4scUonCYsQpFC3DRpSAk4kakU+fGA11xEXYfMl+T7mbCRJc8UFfjB4tA/klIEHCLiAREUIJqe9YGxQ8WmQU+ZxjknQlDnkYNjejJGLgJJhE+SDGM08dp3F+CS4cMTUAS2h0SqdsTeH2lkw9Sx+ZMGMZBo3Qr6zFRFddecduHg/IdY6fe9mXT1TdYQAziW4QLjWo94YEoMwcQiA6xiIsRgL47zcUB4L/vAqSLQR4fHq8h30IkLxez+Nc5xBZb8U439pSuOUjDMKqmYAlm+M+JETDzR/BiA5toNUDEHXhiMrktUNCoa9V8Y80BChEaeSiHowf2ww1BQ07Ju8ni0xVrA8OfY8/4FIsbFMjJd/o4PYdMWJINU943AxTORPk57GeH7kzReqUh8JexcYF1UOUJJRtW5W3GCTdXSsZGRm4ECz4lzkoS+Cynyi+MeGHSgB+FPjGfREp4acQqIRKCNGpjvC4lnpsME2GvgxJEohImGSR+vMgk58H4bxXBOC0dq28YMwTJKFIn3e8mcaXltw9vWIFwSEJ1I77cjvgmO2wu/wDjK3rKETyXEPnEoZQSvBBMX34wr0gUF4iqvxlDdppJSv7SftBIBkRhHICigEApg9iJXjGjX02QQQd+OuCck2TeBoSIFGYk6xDalxCtiKruA2pRkhnV8gMoXo1iaUgYDKRxX3D+CAHsInsfhwa/Bt9BZp+I/GGmnhCB8f8AP5m1jYbIIxPJGtTxgWDRt8FicNRkx0VYFQI4APUYvKiUcPmPsbHRHZElUxIHWpXdDM7ac/8AOsnUEOEu35D94VSg3jAT3EwGKyxHjCw0kk8EuMUL2ZZ3ASAzDyJjS2U108OQvgH1hCeKXiO15cI1q3TG1tPlbw3jMiKSEh+gmTO6Mp5ORm8k4qACOtHHltSYkEt9cVtciXtA/TAvACUajr5V4B88ePzDc4g+ogx7iz8Ya4bTPwxgQEVoQmmFfnnIlRZRn7EryiaD3KrOny/hCx+hy78A9Oph25BHeXEc6JkVNpga0RPnIlFM5CSMzzFv/MN3ZKBVCPhu6+8k5ZM7dnIQp2nE4z8QTZEEU9z1c8Yi7QQdcj4NZUTKiZPnCLjm6aEypR+zIwbFiXcPgJw5aUKCBFHnDpZKsPffOQQagaJBCGdUE9Vj5SHQgwj85076JlNEc5UMNDYyf2SeXFwhvTDz/rAxJEECuyZ5p1sw/pR7ITPUYXFDAEfYwYCm5hykg8TrnCKB0SafHScZHI7QT3OQZyxlOVeMvbGSASYNopEbFEq23qHsF+KY+PooCzHIMYSvgepyPc5V6hNTCj3jaIqwX1sa3lfXkyD2N/vFN+gsPjw+8UUawU7Y9713iOFqJpxLhFYWFpHE/aId9PSzoGirBUzxuqK9DzZ+K/eQZKjg7OTBMGrXjIVbQoshvqlesiSoUMBUytiS2fGGGd1bkh5RZhF7lx2I0oarJLYJkIea+1I6K5hTZpFAPJiwLCEY8NMMw0nxGPG02scsS/nGQBNiHUCYlNf2yEBOZUJsJhlAq3beA/E7w8C15/jENXAA7ROyIPc4qbIeiufN1HM4IUXhpJtCuu9BMSyYwlQY8QcyctSLokFP3GCViWQ8Jx/OOw9ECXlxDqcMoD094iWk2nYfyZG378iwuTIGFKn28UZCsVYs874SZfBBM9k9+cQI9yPHRguj0JUv645cm1ZX7DumB4eTzlaejWvf9RkEwxIFtSc+MQ6TKWPpGnyOEQIaRQfMmGR/hBIchxWzz9xISlmDWGyAsvROsuTxOy0LFChg0HUYRQAo3YTtPB04yiFGHJHcX6kybnKEQcAJow0qice8fkq3aZ+6C0eJ5RpBDKTsXrJC1qg5biVGwNi5I1lGxezK/JwwoYRp0LcBnsPKuRyV8kVAnwBjKIHBCPhOY2vzgSh1pIyq0v8AzxmmatHNaCJ8x1eDMHTBDsCm1r1trFhprgl0eDXxnNbXHWCxEgZogfMgYixoh448Y9sSJIN8Y/lPROZSuYmHeRFGNArQe2baDvWExyX02Y7S2vL0YSVZZxJthxhuyVkPwNe3IOvCr0G3xjJQEB3QsVKqvwcf4auGSLgIP0GT9+pv/gI2eM/ZalQHZj7/ADsqdq/4UwsIQiaRwpCuQXUbicqHMLLOsTmLmp/jI+nwP9YyqJlQVe1wNkmrEYF3Mn+s2locDoNH1iYVmJcBGn1hQChBNRkm8USvRy02eZ+MDdon9ZrNovZeMBa84GJ/SJ+JvKHhqQ/yv5+oJCIAJVwSAKrEYkMP+CXZCrqWPuFwsipqfhi4eL+oDDmZo8e24Nv3s1MNtLAYj3RMIMIn0if8oJb0pfgxV+w2fI4PP2weiE/Kv3gTDpdDKJy7T32iXniiJHtelSejF0IGHgJfuc6aUSSjbxE5H2dLYVvwl84xLGuPsmmCo/6KHI9VqQ6/IXexTnGyHTWCizZDvqHrIYdiFIVANxB+d1g0dXZYScIx6ABq6Wig9I+4VgJ09ByY6kUeo0EkQ9kPZQy4lpdbPKEAroxjBAyz6C5er8/4SKkENKON5K+WkRJBXS+XIch2SMojER51jhw2AQuguCUJJxYWEnIM77OVX1ijoCokVgmBFkhicGTKw4MyA4rW/H2d85F3PJ36xu+DwSa6HfCNJkVMI86iQjwQXcDOUQ5Ovt8gh2h8uFy1OfO0eSmffOKEISgmu8DASaRCUk8SP4+gJSMAFuEZIWMEWB4gE/1waarQTYOXbwHJlRNiBCFSOJifn7DMbDyTBEvYXd5BYNOLD06kYvEBW7T+QG4V8YaLEoQXpyAoqY3jXy45pBA2wRJ24DBJrIKoF1LcHnr7ZUXoTji58eDQnlaOt5ecAjCKHBe/OSIjKELLTVjFRq8r5X8Kg8MB7fqqDbSn8ojEVCI9P2AqASuQ6KghzDRHPBreDfunC4SeIoXwbxs+KBRgEBhGqiJnF1iT4GUQDHoDeO4OvpItSvJK5syFiDJBZkGpb/GCFAII60EIMUPw5ARNSyI2M81F/wAfUomyWhMHrNyZxE4W5/8A0xKpMWSJxRS84gkCAj/cejgJiJAPcduPjyWNdY4aNrzCp5vKYADue0jS0VByTeQXynJ8FPbWOuwNFuwkgk5ec5y1XbFGoNHyt5bhjWY6p5JJ5Wsg0KhGIdw/QtLjEWklhehBLy4DsguCPKSSpeMI0ZJes0QVxsPGKHvEST4nJmM7o3Kx4msEEIcmSAw1EhJJiTD+LFieWYTHbPBiYWgEI9J9gUFaVZ8v/wADzgYmCwYnZIp5iOpwMJfNSVJYebzhL5D5RevGTiCsgYgAZuChhCCPaYKydYSpKBw/ageEKQTODgKTxDGsvcguNVYGmI6HNR9h6yE7SNYY9sdE9mEoHYdVAtUncpAAPlFhTmAckOCEFHV5DEnTXmUgtfGILVg3lBC+p8YEQVSGFnOK8EnyG1DpanDb7h5tQh5fscs3AmcMAXwI85XrUAI4Bb5XkUIZKm98z/GBSyQuQWo6xMQu4ARfoxfjjGchRBo7SRXImd3hOwAZErZnmxb1JhHXwYhBC9wX7x0sVMBeJi/m8HYoBv8AiEErFevqIFpfB7jFAkLoayHMVT26HWIljzUh8BJ3gZOlfOCCqN95OKKCwEHlpkLB64jOgFhkSI8jF4xbNGpFMRyi68VmvQQhCLgR0yk+GQfy9S09jY/ZAdIINrz4NB87cUqPKR48AGJkksDAe7erxgMQtJyG+RY/WX0IsS4IHAhWya1ixlW1wuAdKpE6Ojvxg6UYtLKA+CH5wb5zC9SpyEb5n7FZijkkbN6b8MPGWtU63IVy7IvjAl97Ew6SHiMgo16EkfI2fzjdcCHDYciu8Etl1OBX5TCkHRyo16dj1jfOXEhw9T6cb0iVO2qoQhk8O8GuG31n7BrmZhT7cPcLhmxgFd0reAm7JAt207/rjCTFJegpZuDieYcqmkV5RmOOysTgO2JXkbhP+rCJsAqvEw15ucF2nETHJtHCCI74zl0E/Yrb9Ru0mVBlcAw/GMieNRyL1tvEKcRIGqvCNcxi4XtHPJuiG9ZWSQAShkQexpNkmGUkiYQbJg8ZIYSHggBg946yyoTdYWI0tcVkgjqwDq0I7rKO3Dl0Btetc/Yfj48GptNQlYJQTnG2OaYkHRKpjnBie1mLzzPBkoa4kKEfEw+HWRG0lZ5REPUvnBMQhbB+ik3rzlSIm4AhDyRDHIeMiBh2w9j9j4UgEaFLkT/zkbECygiQWxGP+2cAqFBLnx8ZEPdlF6Q/jANiAzqEwGncBxiGQVVUBhO6N+ZwULgJVCExcIs/7whMnzyX8DhtjO1CZbfeQZJgFpE/yfYmgFSOg3KgPnFKsTSWmafK2KzVd+QvauNBG1TERQXsaSMMWh5YM5qm4oybu29Tthwq0vIwbYpfzhtD8lAgYQREjI6RDiktpIRuCsE8fZIUykEJInKjteCVhQEQLIUAgTowsm8yVD2B6LyULSNEbB3E3veJ1qCh/h3+MZyGIUljqI8jrLYUCYQCBdASLrAbDh5c/wAranHpqtEvQpDVZIAEQweiNPCHr7L91MVTS+NnbBkrMAOUbfJfzjYtSiecCTxQ9PwV+cIUNRfB84jb5niLXMO+T1jUle598Bx6SRGrw9Es61k7TghApI+HhOx+stlAEq8ZwQJ4FqegJesFEABphhm8xiYLMY/CMImJeg26KwvcJuS5VEXU64wf0FE3Nfwe5wCDIIJVyzz3/WbwL/ofC/jEkiGL7MD2TCbIyRW9IkZRW3T9Y612Aeg2nAYwmJSELYIRE20W5MRtMHRg9gnvGSsMoLToT1ihdSnTsEH7xwNSgG4safk75yTqw0ljzEAATiZl+3mtrjcYMl2JgNaltSs4QAttBzpjR4XHvJrJD2dAdBP7yAxRXAkz+XGS1Eu0n5S/PvAipQkQo2JsTrD5/ueQhw9Q7+MFBaZY+hWHwmPQmqDB0qVk6FyeNU/RbdSMeE+wURGEw5j1QDhj9ofRiUCutKk5X+RBEG6UQe8TjLDJAeNP85zHEbseSafnDcAiN0Ex8MnxikgKXIbj2fwYZVXkvL8+Ffz9kymZaEKlFTB+GIgSzVJ2FJ38veI8KhS1uC1WDfWGarS4wGcB01tcY/IYiGQrvblm5bLlPwJH7yAInV3OR7xIHBpuE/ZTWLCQMAZOh/ZwiYkMfRoKIZJIJByg0fOPEfa0CNzEqovYGshHCyfmIf2yPmIWTJQpE+3eTHHTjShbNCFRKuLqCZAkzW40DZtig8GRePuRxJI9kXVwnyvGE4nkQoiDgO1HCccjlS0/1H5zadXGwDvsRMUrVEiRcvqDCaRIOpz7jnJlgTNJxAfyOA2CxcwyfCkfPjCZAEyUjUkRVzlU2GH4WGDEJJMO/tZ2Aa9p/oZETxnAVnwEzy65xMFCiQCWCvRiAjwkvRxeOTRqh21D3X4zuyQ8SR8Yj9JKJxLGMdJSJSB8AP1KCX4fZ4/n4vFR37DyEHpnIQy6P/ByGIio8wcdNkKVlQKZbWGecMJVjgvij5IfGNkro6TpNnvFQk71fI2fvNNmkEg8YZQEDcwP5l8OKqqyu1wiSdcxg3AyGoih5YrAy6VrK2CbbMocQr1goxucg/tjGcFspRSdxKR3EZCIdhWCGtPI+cXkZgB5JktAsS86nIhEBfpgUlzx3jD+SwSdSJh8cYgoySMx9jG87GwP/HzkwZSTRb+IfrnHAfd7WDSUoe3vETUgIQQnDI3wQ94wUwm7n/idOKlZATXA/vHStS8A/kv4ySNZEhUT7P0ySSL7kTyQEE3pxy6KQBgATHMH2wtN++Y1apYHyR/mWDMSu8UEIujIcYgD2Jl8ER37TQRF+MQt05IOHd7dVhYAYdDXoq+4DhvAJFBbYmMsK+0h0crav8Bmy7Jh3W4jxH5yHWd2PIGZdYCF4If0XlwpqGPm5z0Fs0fp+8LkAIgfQgk8T6xmTMlDPMSPucDFLMYrFL3/AFipSh3aYD3Avr6jKypSybDwP5RvDs0AZGQT23B5TAO47UwkZ1CD1m0ZdAIjZpGEh9Vj5HVBbLKVRnez3GFRxgMnuLRxIF2dmdsuC0jMPUE/xkhLaMJ+Z8rlDElnEkFvceMTylLjyPsmkSIrRr3kM3q5ARD8b0Rzktzy+Ih8ROCTUAPAGcaYgkYt4I9ximyoZlCg82sOy43gIV8EN95qBBEEm1pUn4cIQAYk0/ZYyQQmJ1hobizYqPg+Mh7UomCA82z8YXXGyERqyYcFAB1fS8fOAYGbZFw9D2V3GR8JrrJPOrPWamCl8dzYYiyT5U8q/WUIKClS8INvwWmAmFI1Dckf8bcbWYYIZ6QSp1gSjEBFEd1ku4i5XAduDETb35mn4feSif8AAr4gTB4rNDP2Q/zj6qEAGfa1+Mv7taU1Jzwl44+xkkykZQRaAG2YmsiLysp8pIdmjoYNZLATeeFC/wA4MombC9gL+cqlzQL82fnK50ov+aH4DFx/9TWQknr/ANhiAq7hmiNhD/GQRCCuEwvmIHuD7LtpOJwMaU81jqVzhkmJ6ST5wOzI7UISNed5LslJC3G2VSKDOblV7IfjGOkINhwqqrBIBIlgSYjqJ+2J3LJEJsnzhSzgFHcT/avlwZGUg+omA1gCOwmLvRNfvDx5ILHyZl/WLhCSNE72OLJEd0+6zQ1Q3d3piLIcefESofn7AoZILsS/CYfhgSBjQU9oa+Yx/oSxZwIEJ9z8ZNKl4TUPWRKMIPaTBKvjrEhiIP4wTskVDhu8CXVCOZh17/wKNiSTeS8Ex/jDBFSAlD1nP+MIGVICYO4wAhSTT3/jJUqCyYd/4hpaJAMsxBt1xhCSDaODnhxVLIoJuMEcCzxR6wQ0gbJ6/wAETgUKqkpGr15/WDXUgEtd4wAozyQf7+jQOIASJGxxEUSE+5BHZgEsSroxssnqF8PODL5wp+U/rE8CtwN/jLdkoQP2j5jG7gpH71KAj5+i+T2LU1+8H4njW9f19HA2nh6++m+SS8ZcLrW1I+N4PAKyBcU3wWF4ha0kSLiPfeH+EAkSRPzZ5zaTrKxYnnfP3WsArABRbqCGXWBGUxaOiD8pD3kyQsAg+IJyaGln1Mv6nAEoka5ZP3+30RsUI+gLlGWpztdagAzqOPtBWC3IqEgMixpjteLu0vJ7qJBeUBAb4/e8aCEkWQdTGuwL5XGQQTwh0h27nI2McaEJ2OKh9bmjyL+U/fRAZLHWxA1MxEdYAiSBH4ZMvzjohJKSTfSJ4XkxjrN6RlKzFRu6vEKqcmQtYnwEd6Z/ZaptVv3kaFevtiBI4ykSHZgYlDCAb2+Pzk4bGl0S/LReVwO3oQB6IMLQnIBYthCUPyYDVAJDRegq8UzcGbP8m4eo+1CBVYA5zkSBU3MfB/L6MIVgASxOcj1JGDR6nT5wxmlE0pD9/pjjClMdQMfnYjw1O48YIiOgibuHJrzrwmVM9zk0qUkqR9P1AgUE2xMYpGi8SQrqVk8vWTTwxdH8BQdAxhYlzJbl45joxm5M3JLd/K4RwwgPDWEiB0yC7Xg9Cl7HJiGIIr7BREYTIvZusOQ/ksyPdx5KbvFvz+cBGSL2MgaHRi++Meq6WlWQ7Ej/AOsAZs3FV/R+WLWfTNdBuyYc3rBemHZGjUCU8uRWG/GjDps540/YhyAUCaXEkghSrQEkExx3hh7UIZt7/wCOEuebBDT1BilmQAIGNa5wMvWTZ/mMdzAr1CmEfEuNbBK7Egn5hOocFCiDApOhG+L+wRpgaMwXuBHrBeitirF/WNLYyERxmLFLD0ho3XCMZVmA4pssJ5TCst4byfk4I+RqUC1Pg6NtThdzA2jAa/2riQwlR9/ziL4K0RhoIPrrYQny5LfbFSigdbZ8YMgJAKl18VjSiFeP9gfnCCQFtiYya28Zwjx9YnPcPwSP7yadKKhq33FqECL8EEAjF8PjI57SIFegpdWLjR1BSiu5J3xBawIE1aSpkpFG+p3hXZuskMymo3iVcyMoTyaOqNMnpHcVWyWBJcKsbx2gWoPjJNqRRr84YGRN8Pc6+oF0fEPP5wUi9GwkR+PeKmMqCmV1fvAOAgeVx8f3gDIFzLf1g2CQjETftxYGA8DOsumcObSZX9BkIrDJZm4+MAAlBQn6gp9LTaAFfn85dY0DosxKbMEoppMP5v8AWTTZJADUlJGJJB46wwhGqIDaKpMnO8XTi2TIBJ1Lnxgs4VggNSNExQcZJp3ID8MP6wMMsyWcRBnRBLKpxx9QGNJkBElScxzi1MkHsGT9mTMkEkYrZf6wPJG2P+B+cRSNJTjRFS2DqqX4BX+MVw9wlGk84inVkQl+CvsuzUiU/KH4nKVbCC6C17SXvLQfTHVCkhi4jyZskIaJKsiuA/LlDXCq9FyAmOeecGKJApjBAEl1DvIbehkAM9onr5xE5HlA2oCtx848OSGkTC7DE7xMOdWz7rv6wciB7Y/vEipdBhdYeqUEYFACJ+PvGQPOEp4f24BeJKMqjShDuXgtp3pnP541hUMrjIIa/jL5GwGTf1SqHN6grOzZeRo0BGX5I/eEXRYg/IP8Y4GGtw8rI+cGsF0AsSyzF1GaO1GoSG09LqE5wfg3AkPTF+t5GvR0/ID94EuKofgg/eLNlHCKy18MWVe+vpcUAL6x0DTZH8gLEhA81EwnmIrN6RU2tDhv+sRUzskNrwP0Kwr2SeqsBO+iv5ZGFtTBJR6CVwTCli2eC/QUSjPA+8Yi0yq/bTg5SPOkVQb8vrA64DbvAZfMDvBlAmpg5dIeJwSQIoqgJzSOKhOsmnxPTcoHZ+MDWB25Tq4e7YorElTSVI8PxgjwD49ZV9nHBiUwWIOrFfnHVgKywA/B9BODWuk5wj5htpS9h6j94m5ZCITAHa4aIJLtlF91jvamBI3v9Y/lBJxLP9fvKI7C0gt/LlIeCoG94NVPgluJ8sZOHeE3z9OcG1glGkJ9ynxgKhNICzaDkQBUg2fE4MEBGAVgTQq/AGJwLo5hPG9jbPMYHMy+iIBBF3H5DHYV0AAsrUKTuHDBEh6xoSV5kxniBfQ1+hPz9aUFz5ZBQkgsnjHBAfjBFZIWMFI3W/zzgRJt1clpyQFeMn3qRPRHTXNOMjNifljX7xcVOIU/M5JWsUt63fLkwliSCYt1NoURFs5vhkmnv6oypaBA7UP4D5z2IYGxCoQSlQEY0ThEzegNdqu6w1eZp1BtoibDYnUYGNpv9ATrjCDclptBJVzBt3OLvAsF7IZkzZqb4MjqU795ZQtNwWNXkzpSg0wuBPEVhBXVUT8fVJAHZCTjURIEI2H/AOYKVRvyal8QYBasJ8I/GPuMeu5Wv5cAkQpBFm6iHiM3QlCYd8rP/Rhk4ejZP+95OaThir94qqrK/VI6BZdBIT5MdNkOZ5/Jp85KqQEJ8uJ1PGP7OwCogm3yy4jwwHhcfxggllUvQFftMDsBKHDpNOe29inS3DtOL41CYCmkCAPLEHy8YKgKmDQcB4NfYKINiOg7E5HJiQ6tyA8y7+fMvWoLRHBar/wwchEHyMwtPxlya+iz8YEtN3r0FccjCOBlI4hVpMfrDISAmwTTEBHahE/XWwJCB2qgzY2JOrgAx0VPODYhCIRE1MSXQQVE6lr5HQoaHRrJ6qjxGAOyyZ9MYlgkBFiX+evDBzvJmYIu9hzac4LG8/JuSB2dSN4s02U8im15F+zRaes0xlW88XL5cAgqQwBpH/uMdidwX83k6d1BU+YxQhMo/u04Y1gC0ybnKVVg3GFY/rzgCAk6TNx8/YbwBBZfQCh0/wA48cR/1hte/hc1Qs7J5TEGEyvJ/JPxiEEI3y/9DIRAAq9shi2yjGoJL7kPOMv1YPcTMTMB9oSQJTUYyRkU1lbddz4nAjY+7yRT+shOOAKncknjAHYjzAs2xgxyrkiJ42fLgPwUvFtHEXxWFAUGvNlX7InNJlOJ+jqFvZiAE92fB5x5MRsll8RUSu0NYEKVZkZ06ZsH7HDKbMIA3N0njULFZMDHKMoSEBqWsk8BktmAE9qAxePyoh9mAQFmCBeWOPsF7qLxZ3ht4EfHnjHdHVkQOojpLw8CWcbaXAZHNwZBFKpr1ivcpR8kxgIESTCDw/P94qsu/uMjWsrzcmsVA2SKjiK6zUSv5D/WWCQM4mBfinCIxI7zlJo/GIVUhFFU57/WKpVlbftcQaST+RGMKdM2bIYktTAsEJpIJ/eFHuCBf2mM6gHf8Ka8/E4Qp8RAP6cGzq5IVlK3fGAxgghRDNPH3SXMa6EHygY/yJlUeA4MVfsyR2fBObKDqEKxPnn5xY7DL37OfnIHQ6BiQeJmPH3ijIw4mrTkdfDSnedWFnwpCzw55k/7zU4grqZjJRJQUgXb7YPx/gs7nAmfe/j6JBdKmV/w1H5ZMAAfAB8YdxQyFSGaUk+N/SzfaylIiN+Z+P8ADr6Bm3DmDh8OnCRdCWx0SrB93//Z"
    private static let tileSize: CGFloat = 96

    private static let shapeIndexes: [String: Int] = [
        "dragon": 0, "bird": 1, "snake": 2, "fox": 3,
        "phoenix": 4, "wolf": 5, "cat": 6, "mermaid": 7,
        "paw": 8, "stars": 9, "crescentMoon": 10, "sun": 11
    ]

    private static let tileImages: [Image] = {
        #if canImport(UIKit)
        guard let data = Data(base64Encoded: encodedAtlas),
              let cgImage = UIImage(data: data)?.cgImage else { return [] }
        return (0..<12).compactMap { index in
            let rect = CGRect(
                x: CGFloat(index % 4) * tileSize,
                y: CGFloat(index / 4) * tileSize,
                width: tileSize,
                height: tileSize
            )
            guard let crop = cgImage.cropping(to: rect) else { return nil }
            return Image(uiImage: UIImage(cgImage: crop, scale: 1, orientation: .up))
        }
        #else
        return []
        #endif
    }()

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
              tileImages.indices.contains(index) else { return false }

        let side = min(canvasSize.width, canvasSize.height) * 0.96
        let globalAlpha = min(max(opacity * brightness, 0), 1)
        var imageContext = context
        applyTransform(to: &imageContext, canvasSize: canvasSize, side: side, phase: phase)
        imageContext.addFilter(.colorMultiply(color))
        imageContext.blendMode = .screen
        imageContext.opacity = globalAlpha
        imageContext.draw(
            tileImages[index],
            in: CGRect(x: 0, y: 0, width: tileSize, height: tileSize)
        )

        // Preserve the independent eye-colour settings for Toothless, Cobra and Hawk.
        let eyeRect: CGRect?
        switch shape {
        case .dragon: eyeRect = CGRect(x: 65, y: 25, width: 7, height: 5)
        case .snake: eyeRect = CGRect(x: 63, y: 21, width: 5, height: 4)
        case .bird: eyeRect = CGRect(x: 64, y: 44, width: 5, height: 4)
        default: eyeRect = nil
        }
        if let eyeRect {
            var eyeContext = context
            applyTransform(to: &eyeContext, canvasSize: canvasSize, side: side, phase: phase)
            var eye = Path()
            eye.addEllipse(in: eyeRect)
            eyeContext.fill(eye, with: .color(eyeColor.opacity(globalAlpha)))
            var pupil = Path()
            pupil.addEllipse(in: CGRect(
                x: eyeRect.midX - 1,
                y: eyeRect.minY + 0.7,
                width: 2,
                height: max(2, eyeRect.height - 1.2)
            ))
            eyeContext.fill(pupil, with: .color(Color.black.opacity(globalAlpha * 0.9)))
        }
        return true
    }

    private static func applyTransform(
        to context: inout GraphicsContext,
        canvasSize: CGSize,
        side: CGFloat,
        phase: Double
    ) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let breathingScale = CGFloat(1.0 + sin(phase * 1.15) * 0.012)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: .degrees(sin(phase * 0.55) * 1.4))
        context.scaleBy(x: breathingScale, y: breathingScale)
        context.translateBy(x: -center.x, y: -center.y)
        context.translateBy(
            x: (canvasSize.width - side) / 2,
            y: (canvasSize.height - side) / 2
        )
        context.scaleBy(x: side / tileSize, y: side / tileSize)
    }
}
