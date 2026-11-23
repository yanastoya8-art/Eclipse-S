import Foundation

enum HomeHeroTitleLogoPositionSettings {
    static let verticalPositionKey = "homeHeroTitleLogoVerticalPosition"
    static let defaultVerticalPosition = 0.50
    static let supportedRange: ClosedRange<Double> = 0.15...0.85
    static let step = 0.05
}

// Retained for backup/profile decoding compatibility. These legacy settings are no longer
// exposed in the UI, but existing backups still encode/decode their stored values.
enum MediaDetailTitleArtworkSettings {
    static let enabledKey = "mediaDetailTitleArtworkEnabled"
    static let defaultEnabled = true

    static func isEnabled(defaults: UserDefaults = ProfileSettingsStore.active) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? defaultEnabled : defaults.bool(forKey: enabledKey)
    }
}

// Retained for backup/profile decoding compatibility. The feature is no longer
// exposed in the UI, but preserve its historical defaults when importing old backups.
enum MediaDetailAlternatePosterSettings {
    static let enabledKey = "mediaDetailAlternatePosterEnabled"

    static var isSupportedOnThisDevice: Bool {
#if os(iOS)
        !isIPad
#else
        false
#endif
    }

    static var defaultEnabled: Bool {
        isSupportedOnThisDevice
    }

    static func isEnabled(defaults: UserDefaults = ProfileSettingsStore.active) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? defaultEnabled : defaults.bool(forKey: enabledKey)
    }
}

enum MediaDetailAgeRatingSettings {
    static let enabledKey = "mediaDetailAgeRatingEnabled"
    static let defaultEnabled = true

    static func isEnabled(defaults: UserDefaults = ProfileSettingsStore.active) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? defaultEnabled : defaults.bool(forKey: enabledKey)
    }
}

enum MediaDetailTitleLogoPositionSettings {
    static let verticalPositionKey = "mediaDetailTitleLogoVerticalPosition"
    static let defaultVerticalPosition = 0.40
    static let supportedRange: ClosedRange<Double> = 0.15...0.85
    static let step = 0.05
}


enum MediaDetailTitleLogoAppearanceSettings {
    static let sizeKey = "mediaDetailTitleLogoSize"
    static let weightKey = "mediaDetailTitleLogoWeight"
    static let defaultSize = 1.0
    static let sizeRange: ClosedRange<Double> = 0.65...1.45
    static let defaultWeight = 0.0
    static let weightRange: ClosedRange<Double> = 0.0...1.0
}

enum MediaDetailHeroContentPositionSettings {
    static let actionsOffsetKey = "mediaDetailHeroActionsOffset"
    static let synopsisOffsetKey = "mediaDetailHeroSynopsisOffset"
    static let defaultOffset = 0.0
    static let supportedRange: ClosedRange<Double> = -100...100
    static let step = 5.0
}

enum LandscapeMediaDetailAppearanceSettings {
    static let logoPositionKey = "mediaDetailLandscapeTitleLogoVerticalPosition"
    static let logoHorizontalPositionKey = "mediaDetailLandscapeTitleLogoHorizontalPosition"
    static let defaultLogoHorizontalPosition = 0.0
    static let logoHorizontalPositionRange: ClosedRange<Double> = -0.45...0.45
    static let logoHorizontalPositionStep = 0.05
    static let logoSizeKey = "mediaDetailLandscapeTitleLogoSize"
    static let logoWeightKey = "mediaDetailLandscapeTitleLogoWeight"
    static let actionsOffsetKey = "mediaDetailLandscapeHeroActionsOffset"
    static let synopsisOffsetKey = "mediaDetailLandscapeHeroSynopsisOffset"
    static let contentHorizontalOffsetKey = "mediaDetailLandscapeContentHorizontalOffset"
    static let defaultContentHorizontalOffset = 0.0
    static let contentHorizontalOffsetRange: ClosedRange<Double> = -300...300
    static let contentHorizontalOffsetStep = 10.0
    static let defaultLogoPosition = 0.40
    static let logoPositionRange: ClosedRange<Double> = 0.15...0.85
    static let defaultLogoSize = 1.0
    static let logoSizeRange: ClosedRange<Double> = 0.65...2.0
    static let defaultLogoWeight = 0.0
    static let logoWeightRange: ClosedRange<Double> = 0.0...1.0
    static let defaultOffset = 0.0
    static let offsetRange: ClosedRange<Double> = -100...100
    static let offsetStep = 5.0
}


enum MediaDetailRatingNotesPositionSettings {
    static let portraitOffsetKey = "mediaDetailPortraitRatingNotesOffset"
    static let landscapeOffsetKey = "mediaDetailLandscapeRatingNotesOffset"
    static let defaultOffset = 0.0
    static let supportedRange: ClosedRange<Double> = -100...100
    static let step = 5.0
}
