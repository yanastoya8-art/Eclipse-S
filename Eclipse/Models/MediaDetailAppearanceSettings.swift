import Foundation

enum MediaDetailTitleArtworkSettings {
    static let enabledKey = "mediaDetailTitleArtworkEnabled"
    static let defaultEnabled = true

    static func isEnabled(defaults: UserDefaults = ProfileSettingsStore.active) -> Bool {
        defaults.object(forKey: enabledKey) == nil ? defaultEnabled : defaults.bool(forKey: enabledKey)
    }
}

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
