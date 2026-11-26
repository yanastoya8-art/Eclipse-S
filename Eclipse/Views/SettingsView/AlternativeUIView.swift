//
//  AlternativeUIView.swift
//  Sora
//
//  Created by Francesco on 20/08/25.
//  Reworked for the modern Eclipse appearance system.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppearanceSettingsSearchTarget: String, Hashable {
    case palette
    case backgroundStyle
    case solidColorSource
    case customBackgroundColor
    case backgroundIntensity
    case interface
    case globalAppearance
    case accentColor
    case liquidGlassDarkBarColor
    case liquidGlassLightBarColor
    case liquidGlassBottomBarColor
    case browseFilterChipColor
    case browseFilterButtonColor
    case browseFilterOptionsColor
    case animatedBackground
    case animationQuality
    case animationColor
    case customAnimationColor
    case animationFrameRate
    case animationShape
    case animationShapeEnabled
    case animationShapeOpacity
    case animationShapeGlow
    case animationShapeBrightness
    case animationShapeSize
    case appPerformanceOverlay
    case hideSplashScreen
    case splashScreenDuration
    case splashScreenMaximumDuration
    case openInLibrary
    case alternativeSeasonMenu
    case horizontalEpisodeList
    case episodeCardColor
    case scheduleCardColor
    case scheduleControlsCornerRadius
    case scheduleTimeCornerRadius
    case showUnairedEpisodes
    case titleLogoPosition
    case titleLogoSize
    case titleLogoWeight
    case heroActionPosition
    case heroSynopsisPosition
    case portraitHeroBleedIntensity
    case landscapeHeroBleedIntensity
    case landscapeTitleLogoPosition
    case landscapeTitleLogoHorizontalPosition
    case landscapeTitleLogoSize
    case landscapeTitleLogoWeight
    case landscapeHeroActionPosition
    case landscapeHeroSynopsisPosition
    case landscapeHeroHorizontalStretch
    case landscapeHeroVerticalStretch
    case landscapeContentHorizontalPosition
    case dataSaver
    case ageRating
    case similarTitles
    case libraryBookmarks
    case libraryCollectionLayout

    var anchorID: String {
        "appearance-settings-search-\(rawValue)"
    }

    var sectionKey: String {
        switch self {
        case .palette, .backgroundStyle, .solidColorSource, .customBackgroundColor, .backgroundIntensity:
            return "theme"
        case .interface, .globalAppearance, .accentColor, .liquidGlassDarkBarColor, .liquidGlassLightBarColor, .liquidGlassBottomBarColor, .browseFilterChipColor, .browseFilterButtonColor, .browseFilterOptionsColor:
            return "interface"
        case .animatedBackground, .animationQuality, .animationColor, .customAnimationColor, .animationFrameRate, .animationShape, .animationShapeEnabled, .animationShapeOpacity, .animationShapeGlow, .animationShapeBrightness, .animationShapeSize, .appPerformanceOverlay:
            return "animation"
        case .hideSplashScreen, .splashScreenDuration, .splashScreenMaximumDuration, .openInLibrary:
            return "startup"
        case .alternativeSeasonMenu, .horizontalEpisodeList, .episodeCardColor, .showUnairedEpisodes, .titleLogoPosition, .titleLogoSize, .titleLogoWeight, .heroActionPosition, .heroSynopsisPosition, .portraitHeroBleedIntensity, .landscapeHeroBleedIntensity, .landscapeTitleLogoPosition, .landscapeTitleLogoHorizontalPosition, .landscapeTitleLogoSize, .landscapeTitleLogoWeight, .landscapeHeroActionPosition, .landscapeHeroSynopsisPosition, .landscapeHeroHorizontalStretch, .landscapeHeroVerticalStretch, .landscapeContentHorizontalPosition, .dataSaver, .ageRating, .similarTitles:
            return "details"
        case .scheduleCardColor, .scheduleControlsCornerRadius, .scheduleTimeCornerRadius:
            return "schedule"
        case .libraryBookmarks, .libraryCollectionLayout:
            return "library"
        }
    }
}

struct AlternativeUIView: View {
    let initialSearchTarget: AppearanceSettingsSearchTarget?

    @AppStorage(MediaDetailPlatformDefaults.seasonMenuKey) private var useSeasonMenu = MediaDetailPlatformDefaults.prefersCompactSeasonMenu
    @AppStorage(MediaDetailPlatformDefaults.horizontalEpisodeListKey) private var horizontalEpisodeList = MediaDetailPlatformDefaults.prefersHorizontalEpisodes
    @AppStorage(MediaDetailEpisodeCardAppearanceSettings.colorDataKey) private var episodeCardColorData = Data()
    @AppStorage(ScheduleCardAppearanceSettings.colorDataKey) private var scheduleCardColorData = Data()
    @AppStorage("scheduleControlsCornerRadius") private var scheduleControlsCornerRadiusValue = 19.0
    @AppStorage("scheduleTimeCornerRadius") private var scheduleTimeCornerRadiusValue = 23.0
    @AppStorage(MediaDetailEpisodeVisibilitySettings.showUnairedEpisodesKey) private var showUnairedEpisodes = MediaDetailEpisodeVisibilitySettings.defaultShowUnairedEpisodes
    @AppStorage(MediaDetailTitleLogoPositionSettings.verticalPositionKey) private var titleLogoVerticalPosition = MediaDetailTitleLogoPositionSettings.defaultVerticalPosition
    @AppStorage(MediaDetailTitleLogoAppearanceSettings.sizeKey) private var titleLogoSize = MediaDetailTitleLogoAppearanceSettings.defaultSize
    @AppStorage(MediaDetailTitleLogoAppearanceSettings.weightKey) private var titleLogoWeight = MediaDetailTitleLogoAppearanceSettings.defaultWeight
    @AppStorage(MediaDetailHeroContentPositionSettings.actionsOffsetKey) private var heroActionsOffset = MediaDetailHeroContentPositionSettings.defaultActionsOffset
    @AppStorage(MediaDetailHeroContentPositionSettings.synopsisOffsetKey) private var heroSynopsisOffset = MediaDetailHeroContentPositionSettings.defaultSynopsisOffset
    @AppStorage(MediaDetailRatingNotesPositionSettings.portraitOffsetKey) private var portraitRatingNotesOffset = MediaDetailRatingNotesPositionSettings.defaultPortraitOffset
    @AppStorage(MediaDetailRatingNotesPositionSettings.landscapeOffsetKey) private var landscapeRatingNotesOffset = MediaDetailRatingNotesPositionSettings.defaultLandscapeOffset
    @AppStorage(LandscapeMediaDetailAppearanceSettings.logoPositionKey) private var landscapeTitleLogoPosition = LandscapeMediaDetailAppearanceSettings.defaultLogoPosition
    @AppStorage(LandscapeMediaDetailAppearanceSettings.logoHorizontalPositionKey) private var landscapeTitleLogoHorizontalPosition = LandscapeMediaDetailAppearanceSettings.defaultLogoHorizontalPosition
    @AppStorage(LandscapeMediaDetailAppearanceSettings.logoSizeKey) private var landscapeTitleLogoSize = LandscapeMediaDetailAppearanceSettings.defaultLogoSize
    @AppStorage(LandscapeMediaDetailAppearanceSettings.logoWeightKey) private var landscapeTitleLogoWeight = LandscapeMediaDetailAppearanceSettings.defaultLogoWeight
    @AppStorage(LandscapeMediaDetailAppearanceSettings.actionsOffsetKey) private var landscapeHeroActionsOffset = LandscapeMediaDetailAppearanceSettings.defaultActionsOffset
    @AppStorage(LandscapeMediaDetailAppearanceSettings.synopsisOffsetKey) private var landscapeHeroSynopsisOffset = LandscapeMediaDetailAppearanceSettings.defaultSynopsisOffset
    @AppStorage(LandscapeMediaDetailAppearanceSettings.contentHorizontalOffsetKey) private var landscapeContentHorizontalOffset = LandscapeMediaDetailAppearanceSettings.defaultContentHorizontalOffset
    @AppStorage("mediaDetailPortraitHeroBleedIntensity") private var portraitHeroBleedIntensity = 1.0
    @AppStorage("mediaDetailLandscapeHeroBleedIntensity") private var landscapeHeroBleedIntensity = LandscapeMediaDetailAppearanceSettings.defaultHeroBleedIntensity
    @AppStorage("mediaDetailLandscapeHeroHorizontalStretch") private var landscapeHeroHorizontalStretch = LandscapeMediaDetailAppearanceSettings.defaultHeroHorizontalStretch
    @AppStorage("mediaDetailLandscapeHeroVerticalStretch") private var landscapeHeroVerticalStretch = LandscapeMediaDetailAppearanceSettings.defaultHeroVerticalStretch
    @AppStorage(ImageDataSaverSettings.enabledKey, store: .standard) private var imageDataSaverEnabled = false
    @AppStorage(MediaDetailAgeRatingSettings.enabledKey) private var mediaDetailAgeRatingEnabled = MediaDetailAgeRatingSettings.defaultEnabled
    @AppStorage(MediaDetailSimilarTitlesSettings.enabledKey) private var mediaDetailSimilarTitlesEnabled = MediaDetailSimilarTitlesSettings.defaultEnabled
    @AppStorage(LibraryDisplaySettings.showBookmarksSectionKey) private var showsBookmarksSection = LibraryDisplaySettings.defaultShowBookmarksSection
    @AppStorage(LibraryDisplaySettings.collectionLayoutKey) private var collectionLayoutRaw = LibraryCollectionLayout.defaultValue.rawValue

    @AppStorage(ExperimentalMediaDesignPreset.storageKey) private var experimentalDesignPreset = ExperimentalMediaDesignPreset.defaultValue.rawValue
    @AppStorage(ExperimentalHomeCardShape.storageKey) private var experimentalHomeCardShape = ExperimentalHomeCardShape.defaultValue.rawValue
    @AppStorage(ExperimentalVisualTuning.sectionSpacingScaleKey) private var experimentalSectionSpacingScale = ExperimentalVisualTuning.defaultSectionSpacingScale
    @AppStorage(ExperimentalVisualTuning.cardRadiusScaleKey) private var experimentalCardRadiusScale = ExperimentalVisualTuning.defaultCardRadiusScale
    @AppStorage(ExperimentalVisualTuning.mediaCardScaleKey) private var experimentalMediaCardScale = ExperimentalVisualTuning.defaultMediaCardScale
    @AppStorage(ExperimentalVisualTuning.glassStrengthKey) private var experimentalGlassStrength = ExperimentalVisualTuning.defaultGlassStrength
    @AppStorage(ExperimentalVisualTuning.heroHeightScaleKey) private var experimentalHeroHeightScale = ExperimentalVisualTuning.defaultHeroHeightScale
    @AppStorage(HomeAnimatedBackgroundSettings.enabledKey) private var homeAnimatedBackgroundEnabled = HomeAnimatedBackgroundSettings.defaultEnabled
    @AppStorage(HomeAnimatedBackgroundQuality.storageKey) private var homeAnimatedBackgroundQuality = HomeAnimatedBackgroundQuality.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundFrameRate.storageKey) private var homeAnimatedBackgroundFrameRate = HomeAnimatedBackgroundFrameRate.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundParticleColor.storageKey) private var homeAnimatedBackgroundParticleColor = HomeAnimatedBackgroundParticleColor.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundShape.storageKey) private var homeAnimatedBackgroundShape = HomeAnimatedBackgroundShape.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundSettings.shapeEnabledKey) private var homeAnimatedBackgroundShapeEnabled = HomeAnimatedBackgroundSettings.defaultShapeEnabled
    @AppStorage(HomeAnimatedBackgroundSettings.shapeOpacityKey) private var homeAnimatedBackgroundShapeOpacity = HomeAnimatedBackgroundSettings.defaultShapeOpacity
    @AppStorage(HomeAnimatedBackgroundSettings.shapeSizeKey) private var homeAnimatedBackgroundShapeSize = HomeAnimatedBackgroundSettings.defaultShapeSize
    @AppStorage(HomeAnimatedBackgroundSettings.shapeGlowKey) private var homeAnimatedBackgroundShapeGlow = HomeAnimatedBackgroundSettings.defaultShapeGlow
    @AppStorage(HomeAnimatedBackgroundSettings.shapeBrightnessKey) private var homeAnimatedBackgroundShapeBrightness = HomeAnimatedBackgroundSettings.defaultShapeBrightness
    @AppStorage(HomeAnimatedBackgroundSettings.detailBackgroundKey) private var detailAnimatedBackgroundEnabled = true
    @AppStorage(HomeAnimatedBackgroundSettings.detailShapeKey) private var detailAnimatedShapeEnabled = true
    @AppStorage(HomeAnimatedBackgroundSettings.downloadsBackgroundKey) private var downloadsAnimatedBackgroundEnabled = true
    @AppStorage(HomeAnimatedBackgroundSettings.downloadsShapeKey) private var downloadsAnimatedShapeEnabled = true
    @AppStorage(HomeAnimatedBackgroundParticleColor.customColorDataKey) private var customAnimationParticleColorData = Data()
    @AppStorage(AppPerformanceOverlaySettings.enabledKey) private var appPerformanceOverlayEnabled = AppPerformanceOverlaySettings.defaultEnabled
#if !os(tvOS)
    @AppStorage("hideSplashScreen", store: ProfileSettingsStore.device) private var hideSplashScreen = false
    @AppStorage("splashScreenMinimumDuration", store: ProfileSettingsStore.device) private var splashScreenMinimumDuration = 1.6
    @AppStorage("splashScreenMaximumDuration", store: ProfileSettingsStore.device) private var splashScreenMaximumDuration = 4.0
    @AppStorage("openAppInLibrary", store: ProfileSettingsStore.device) private var openAppInLibrary = false
#endif

    @AppStorage(ExperimentalFeatureState.enabledKey, store: ProfileSettingsStore.device)
    private var modernInterfaceEnabled = true
    @State private var showRestartAlert = false

    @StateObject private var accentColorManager = AccentColorManager.shared
    @StateObject private var glassAppearance = LiquidGlassAppearanceSettings.shared
    @ObservedObject private var theme = EclipseTheme.shared
    @State private var mediaDetailElements = MediaDetailElement.orderedElements()
    @State private var hiddenMediaDetailElements = MediaDetailElement.hiddenElements()

    private var accent: Color { accentColorManager.currentAccentColor }

    init(initialSearchTarget: AppearanceSettingsSearchTarget? = nil) {
        self.initialSearchTarget = initialSearchTarget
    }

    var body: some View {
        List {
            customizationSection
                .eclipseExperimentalSettingsRows()
            behaviorSection
                .eclipseExperimentalSettingsRows()
            layoutAndDetailsSection
                .eclipseExperimentalSettingsRows()
            resetSection
                .eclipseExperimentalSettingsRows()
        }
        .eclipsePageTitle("Appearance")
        .accessibilityIdentifier("tv.settings.appearance.screen")
        .eclipseSettingsStyle()
        .onAppear {
            AppPerformanceRuntimeContext.shared.setSurface("settings.appearance")
            reloadMediaDetailElements()
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The interface style is applied when Eclipse launches. Restart the app to switch between the Modern and Classic layouts.")
        }
    }

    private var customizationSection: some View {
        Section {
            NavigationLink {
                AppearanceSettingsSubpage(title: "Theme", sectionKey: "theme", initialSearchTarget: initialSearchTarget) {
                    themeSection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Theme",
                    description: "Palette, background style, and color intensity.",
                    systemImage: "paintpalette"
                )
            }
#if os(tvOS)
            NavigationLink {
                AppearanceSettingsSubpage(title: "Accent Color", sectionKey: "interface", initialSearchTarget: initialSearchTarget) {
                    tvColorPresetSection(
                        title: "Accent Color",
                        selection: Binding(
                            get: { accentColorManager.currentAccentColor },
                            set: { accentColorManager.saveAccentColor($0) }
                        ),
                        presets: tvAccentPresets
                    )
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Accent Color",
                    description: "Color for buttons, links, and selection indicators.",
                    systemImage: "paintbrush"
                )
            }
            .accessibilityIdentifier("tv.appearance.accentColor")
#endif
        } header: {
            Text("Customize")
        }
    }

    private var behaviorSection: some View {
        Section {
#if !os(tvOS)
            NavigationLink {
                AppearanceSettingsSubpage(title: "Interface", sectionKey: "interface", initialSearchTarget: initialSearchTarget) {
                    interfaceSection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Interface",
                    description: "Layout style, global appearance, and accent color.",
                    systemImage: "rectangle.3.group"
                )
            }
#endif

            NavigationLink {
                AppearanceSettingsSubpage(title: "Animation", sectionKey: "animation", initialSearchTarget: initialSearchTarget) {
                    animationSection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Animation",
                    description: "Animated backgrounds, style, color, quality, and performance.",
                    systemImage: "sparkles"
                )
            }

            NavigationLink {
                AppearanceSettingsSubpage(title: "Startup", sectionKey: "startup", initialSearchTarget: initialSearchTarget) {
                    startupSection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Startup",
                    description: "Choose what Eclipse displays when it launches.",
                    systemImage: "power"
                )
            }
        } header: {
            Text("Behavior")
        }
    }

    private var layoutAndDetailsSection: some View {
        Section {
            NavigationLink {
                HomeLayoutView()
            } label: {
                appearanceCategoryLabel(
                    title: "Home Layout",
                    description: "Size and orientation of home rows, globally or per catalog.",
                    systemImage: "rectangle.grid.1x2"
                )
            }
            .accessibilityIdentifier("tv.appearance.homeLayout")

            NavigationLink {
                AppearanceSettingsSubpage(title: "Detail Pages", sectionKey: "details", initialSearchTarget: initialSearchTarget) {
                    detailPagesSection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Detail Pages",
                    description: "Season menus, episode lists, and title artwork.",
                    systemImage: "text.below.photo"
                )
            }

            NavigationLink {
                AppearanceSettingsSubpage(title: "Schedule", sectionKey: "schedule", initialSearchTarget: initialSearchTarget) {
                    scheduleAppearanceSection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Schedule",
                    description: "Customize schedule cards and release-time badges.",
                    systemImage: "calendar"
                )
            }

            NavigationLink {
                AppearanceSettingsSubpage(title: "Library", sectionKey: "library", initialSearchTarget: initialSearchTarget) {
                    librarySection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Library",
                    description: "Choose which sections appear and how collections are arranged.",
                    systemImage: "books.vertical"
                )
            }

            NavigationLink {
                AppearanceSettingsSubpage(title: "Media Detail Layout", sectionKey: "mediaDetailLayout", initialSearchTarget: initialSearchTarget) {
                    mediaDetailSection
                        .eclipseExperimentalSettingsRows()
                }
            } label: {
                appearanceCategoryLabel(
                    title: "Media Detail Layout",
                    description: "Choose and order sections on media detail pages.",
                    systemImage: "rectangle.3.group"
                )
            }
        } header: {
            Text("Layout & Details")
        }
    }

    private var themeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Palette")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(availablePaletteIDs) { id in
                            paletteSwatch(id)
                        }
                    }
                    .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Background Atmosphere")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AtmosphereStyle.allCases) { style in
                                let selected = backgroundStyleBinding.wrappedValue == style
                                Button {
                                    backgroundStyleBinding.wrappedValue = style
                                } label: {
                                    HStack(spacing: 5) {
                                        if selected {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(style.displayName)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(selected
                                            ? Color.accentColor.opacity(0.28)
                                            : Color.white.opacity(0.08))
                                    )
                                    .overlay(Capsule().stroke(
                                        Color.white.opacity(selected ? 0.42 : 0.12),
                                        lineWidth: 1
                                    ))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("settings.appearance.atmosphere.\(style.rawValue)")
                            }
                        }
                    }
                    .id(AppearanceSettingsSearchTarget.backgroundStyle.anchorID)
                }
            }
            .padding(.vertical, 4)
            .id(AppearanceSettingsSearchTarget.palette.anchorID)

#if !os(tvOS)
            if theme.appearancePaletteRaw == AtmospherePaletteID.custom.rawValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom palette colors blend into a multi-gradient. Pick three.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ColorPicker("Color 1", selection: customColorBinding(0))
                    ColorPicker("Color 2", selection: customColorBinding(1))
                    ColorPicker("Color 3", selection: customColorBinding(2))
                }
                .padding(.vertical, 2)
                .id(AppearanceSettingsSearchTarget.customBackgroundColor.anchorID)
            }
#endif

            if backgroundStyleBinding.wrappedValue == .solid {
                settingRow(
                    title: "Solid Color Source",
                    description: "Use the poster's color where available, or a custom color everywhere."
                ) {
                    Picker("", selection: $theme.atmosphereSolidColorSource) {
                        ForEach(AtmosphereSolidColorSource.allCases) { source in
                            Text(source.displayName).tag(source)
                        }
                }
                .pickerStyle(.menu)
                    .id(AppearanceSettingsSearchTarget.solidColorSource.anchorID)
                }

                if theme.atmosphereSolidColorSource == .custom {
#if os(tvOS)
                    NavigationLink("Custom Background Color") {
                        AppearanceSettingsSubpage(title: "Background Color", sectionKey: "theme", initialSearchTarget: nil) {
                            tvColorPresetSection(
                                title: "Background Color",
                                selection: $theme.atmosphereSolidColor,
                                presets: tvBackgroundPresets
                            )
                        }
                    }
#else
                    ColorPicker("Custom Background Color", selection: $theme.atmosphereSolidColor)
                        .id(AppearanceSettingsSearchTarget.customBackgroundColor.anchorID)
#endif
                }
            }

            if theme.atmosphereStyle != .solid {
                sliderRow(
                    title: "Background Intensity",
                    description: "Lighten or deepen the overall background.",
                    value: $theme.backgroundIntensity,
                    range: AppearanceConfig.intensityRange,
                    step: 0.05
                )
                .id(AppearanceSettingsSearchTarget.backgroundIntensity.anchorID)
            }
        } header: {
            Text("Theme")
        }
    }

#if !os(tvOS)
    private var interfaceSection: some View {
        Section {
#if !os(macOS)
            settingRow(
                title: "Interface",
                description: "Modern is the redesigned look. Classic restores the original layout (requires restart)."
            ) {
                Picker("", selection: interfaceBinding) {
                    Text("Modern").tag(true)
                    Text("Classic").tag(false)
                }
                .pickerStyle(.menu)
                .id(AppearanceSettingsSearchTarget.interface.anchorID)
            }

            if modernInterfaceEnabled != ExperimentalFeatureState.isEnabledAtLaunch {
                Label("Restart required to apply the interface change", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

#endif
            toggleRow(
                title: "Global Appearance",
                description: "Apply the same appearance settings across the entire Watch interface.",
                isOn: $theme.globalAppearanceEnabled
            )
            .id(AppearanceSettingsSearchTarget.globalAppearance.anchorID)

#if !os(tvOS)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accent Color")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Affects buttons, links and other interactive elements.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                ColorPicker("", selection: $accentColorManager.currentAccentColor)
                    .labelsHidden()
                .onChangeComp(of: accentColorManager.currentAccentColor) { _, newColor in
                    accentColorManager.saveAccentColor(newColor)
                }
            }
            .id(AppearanceSettingsSearchTarget.accentColor.anchorID)

            VStack(alignment: .leading, spacing: 10) {
                Text("Liquid Glass")
                    .font(.subheadline.weight(.semibold))
                Text("Liquid Glass buttons and selected controls follow Accent Color. Choose separate colors for the bars behind them.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                settingRow(
                    title: "Dark Liquid Glass Bars",
                    description: "Color for darker control bars and search fields."
                ) {
                    ColorPicker("", selection: $glassAppearance.darkBarColor)
                        .labelsHidden()
                }
                .id(AppearanceSettingsSearchTarget.liquidGlassDarkBarColor.anchorID)

                settingRow(
                    title: "Light Liquid Glass Bars",
                    description: "Color for lighter control bars and search fields."
                ) {
                    ColorPicker("", selection: $glassAppearance.lightBarColor)
                        .labelsHidden()
                }
                .id(AppearanceSettingsSearchTarget.liquidGlassLightBarColor.anchorID)

                settingRow(
                    title: "Bottom Liquid Glass Bar",
                    description: "Color of the bottom navigation bar, independent of its buttons."
                ) {
                    ColorPicker("", selection: $glassAppearance.bottomBarColor)
                        .labelsHidden()
                }
                .id(AppearanceSettingsSearchTarget.liquidGlassBottomBarColor.anchorID)

                settingRow(
                    title: "Browse Filter Chips",
                    description: "Background color for the genre, year, country, order, rating, and age filter chips in Browse."
                ) {
                    ColorPicker("", selection: $glassAppearance.browseFilterChipColor)
                        .labelsHidden()
                }
                .id(AppearanceSettingsSearchTarget.browseFilterChipColor.anchorID)

                settingRow(
                    title: "Browse Filters Button",
                    description: "Background color for the Filters button shown above Browse results."
                ) {
                    ColorPicker("", selection: $glassAppearance.browseFilterButtonColor)
                        .labelsHidden()
                }
                .id(AppearanceSettingsSearchTarget.browseFilterButtonColor.anchorID)

                settingRow(
                    title: "Browse Filter Options Panel",
                    description: "Background color for the expanded list of filter choices."
                ) {
                    ColorPicker("", selection: $glassAppearance.browseFilterOptionsColor)
                        .labelsHidden()
                }
                .id(AppearanceSettingsSearchTarget.browseFilterOptionsColor.anchorID)
            }
            .padding(.vertical, 6)
#endif
        } header: {
            Text("Interface & Scope")
        }
    }
#endif

    private var animationSection: some View {
        Section {
            toggleRow(
                title: "Animated Background",
                description: "Show ambient motion behind broad app surfaces.",
                isOn: $homeAnimatedBackgroundEnabled
            )
            .id(AppearanceSettingsSearchTarget.animatedBackground.anchorID)


            Section {
                toggleRow(title: "Detail Page Animated Background", description: "Show ambient motion on media detail pages.", isOn: $detailAnimatedBackgroundEnabled)
                toggleRow(title: "Detail Page Animation Shape", description: "Show the selected floating shape on media detail pages.", isOn: $detailAnimatedShapeEnabled)
                toggleRow(title: "Downloads Animated Background", description: "Show ambient motion on Downloads and downloaded-show pages.", isOn: $downloadsAnimatedBackgroundEnabled)
                toggleRow(title: "Downloads Animation Shape", description: "Show the selected floating shape on Downloads and downloaded-show pages.", isOn: $downloadsAnimatedShapeEnabled)
            } header: {
                Text("Page Appearance")
            }

            settingRow(
                title: "Animation Shape",
                description: "Choose the glowing motif that floats through the animated background."
            ) {
                Picker("", selection: $homeAnimatedBackgroundShape) {
                    ForEach(HomeAnimatedBackgroundShape.allCases) { shape in
                        Text(shape.displayName).tag(shape.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Animation Shape")
                .accessibilityIdentifier("settings.appearance.animationShape")
                .accessibilityValue(HomeAnimatedBackgroundShape.resolved(homeAnimatedBackgroundShape).displayName)
                .id(AppearanceSettingsSearchTarget.animationShape.anchorID)
            }

            toggleRow(
                title: "Show Animation Shape",
                description: "Hide the floating motif while keeping the ambient rings and particles animated.",
                isOn: $homeAnimatedBackgroundShapeEnabled
            )
            .id(AppearanceSettingsSearchTarget.animationShapeEnabled.anchorID)

            sliderRow(
                title: "Animation Shape Opacity",
                description: "Adjust how transparent the floating motif appears.",
                value: $homeAnimatedBackgroundShapeOpacity,
                range: 0...1,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.animationShapeOpacity.anchorID)

            sliderRow(
                title: "Animation Shape Glow",
                description: "Adjust the strength of the soft halo surrounding the floating motif, independently of its opacity.",
                value: $homeAnimatedBackgroundShapeGlow,
                range: 0...1,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.animationShapeGlow.anchorID)

            sliderRow(
                title: "Animation Shape Brightness",
                description: "Make the floating motif's fill and details brighter or more subtle without changing the background circles.",
                value: $homeAnimatedBackgroundShapeBrightness,
                range: 0.5...2.0,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.animationShapeBrightness.anchorID)

            sliderRow(
                title: "Animation Shape Size",
                description: "Scale the floating motif independently of the rest of the animated background.",
                value: $homeAnimatedBackgroundShapeSize,
                range: 0.5...1.8,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.animationShapeSize.anchorID)

            settingRow(
                title: "Animation Quality",
                description: "Low keeps the core eclipse rings and particles. Medium adds a plasma field, starfield, orbiting embers, energy wavefronts, and a corona. High adds denser motion, a kinetic mesh, more orbiting embers, and meteor bursts."
            ) {
                Picker("", selection: $homeAnimatedBackgroundQuality) {
                    ForEach(HomeAnimatedBackgroundQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .id(AppearanceSettingsSearchTarget.animationQuality.anchorID)
            }

            settingRow(
                title: "Animation Color",
                description: "Choose the particle color used by animated backgrounds throughout the Watch interface."
            ) {
                Picker("", selection: $homeAnimatedBackgroundParticleColor) {
                    ForEach(HomeAnimatedBackgroundParticleColor.allCases) { color in
                        Text(color.displayName).tag(color.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Animation Color")
                .accessibilityIdentifier("settings.appearance.animationColor")
                .accessibilityValue(HomeAnimatedBackgroundParticleColor.resolved(homeAnimatedBackgroundParticleColor).displayName)
                .id(AppearanceSettingsSearchTarget.animationColor.anchorID)
            }
            if HomeAnimatedBackgroundParticleColor.resolved(homeAnimatedBackgroundParticleColor) == .custom {
                settingRow(
                    title: "Custom Animation Color",
                    description: "Choose the exact color used by the animated background particles."
                ) {
                    ColorPicker("Custom Animation Color", selection: customAnimationParticleColorBinding)
                        .labelsHidden()
                        .accessibilityIdentifier("settings.appearance.customAnimationColor")
                        .id(AppearanceSettingsSearchTarget.customAnimationColor.anchorID)
                }
            }


            settingRow(
                title: "Animation Frame Rate",
                description: "Choose 20, 30, 60, or 120 FPS for background motion. Higher rates use more power; the display and system may limit the actual rate."
            ) {
                Picker("", selection: $homeAnimatedBackgroundFrameRate) {
                    ForEach(HomeAnimatedBackgroundFrameRate.allCases) { frameRate in
                        Text(frameRate.displayName).tag(frameRate.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .id(AppearanceSettingsSearchTarget.animationFrameRate.anchorID)
                .accessibilityLabel("Animation Frame Rate")
                .accessibilityIdentifier("settings.appearance.animationFrameRate")
                .accessibilityValue(HomeAnimatedBackgroundFrameRate(rawValue: homeAnimatedBackgroundFrameRate)?.displayName ?? homeAnimatedBackgroundFrameRate)
            }

            toggleRow(
                title: "App Performance Overlay",
                description: "Show live CPU, RAM, thermal state, and background quality diagnostics throughout Eclipse. While visible, sparse samples and CPU spikes are added to Performance logs. Sampling and logging pause when the app is inactive or playback covers the interface.",
                isOn: $appPerformanceOverlayEnabled
            )
            .id(AppearanceSettingsSearchTarget.appPerformanceOverlay.anchorID)

        } header: {
            Text("Animation")
        }
    }

    private var startupSection: some View {
        Section {
#if os(iOS)
            toggleRow(
                title: "Hide Splash Screen",
                description: "Skip the launch splash once Eclipse opens.",
                isOn: $hideSplashScreen
            )
            .id(AppearanceSettingsSearchTarget.hideSplashScreen.anchorID)

            sliderRow(
                title: "Splash Screen Duration",
                description: "Set the minimum time the animated splash remains visible before the app continues.",
                value: $splashScreenMinimumDuration,
                range: 1.5...10.0,
                step: 0.5
            )
            .id(AppearanceSettingsSearchTarget.splashScreenDuration.anchorID)

            sliderRow(
                title: "Maximum Splash Screen Duration",
                description: "Set the longest time the splash screen can remain visible while startup finishes. The app will continue automatically when this limit is reached.",
                value: $splashScreenMaximumDuration,
                range: 3...30,
                step: 1
            )
            .id(AppearanceSettingsSearchTarget.splashScreenMaximumDuration.anchorID)

            toggleRow(
                title: "Open in Library",
                description: "Open Eclipse directly to your Library when the app launches.",
                isOn: $openAppInLibrary
            )
            .id(AppearanceSettingsSearchTarget.openInLibrary.anchorID)
#endif
        } header: {
            Text("Startup")
        }
    }

    private var episodeCardColorBinding: Binding<Color> {
        Binding(
            get: {
                guard !episodeCardColorData.isEmpty,
                      let archived = try? PortableColorArchive.color(from: episodeCardColorData) else {
                    return Color.white.opacity(0.07)
                }
#if os(macOS)
                return Color(nsColor: archived)
#else
                return Color(uiColor: archived)
#endif
            },
            set: { color in
#if os(macOS)
                let archived = NSColor(color)
#else
                let archived = UIColor(color)
#endif
                if let data = try? PortableColorArchive.data(for: archived, requiringSecureCoding: false) {
                    episodeCardColorData = data
                }
            }
        )
    }

    private var scheduleCardColorBinding: Binding<Color> {
        Binding(
            get: {
                guard !scheduleCardColorData.isEmpty,
                      let archived = try? PortableColorArchive.color(from: scheduleCardColorData) else {
                    return Color.white.opacity(0.07)
                }
#if os(macOS)
                return Color(nsColor: archived)
#else
                return Color(uiColor: archived)
#endif
            },
            set: { color in
#if os(macOS)
                let archived = NSColor(color)
#else
                let archived = UIColor(color)
#endif
                if let data = try? PortableColorArchive.data(for: archived, requiringSecureCoding: false) {
                    scheduleCardColorData = data
                }
            }
        )
    }


    private var customAnimationParticleColorBinding: Binding<Color> {
        Binding(
            get: {
                guard let archived = try? PortableColorArchive.color(from: customAnimationParticleColorData) else { return .purple }
#if os(macOS)
                return Color(nsColor: archived)
#else
                return Color(uiColor: archived)
#endif
            },
            set: { color in
#if os(macOS)
                let archived = NSColor(color)
#else
                let archived = UIColor(color)
#endif
                if let data = try? PortableColorArchive.data(for: archived, requiringSecureCoding: false) {
                    customAnimationParticleColorData = data
                }
            }
        )
    }

    private var detailPagesSection: some View {
        Section {
            toggleRow(
                title: "Image Data Saver",
                description: "Load smaller TMDB artwork and supported tracker thumbnails throughout the app on this device. Applies to newly loaded images; provider artwork keeps its original quality.",
                isOn: $imageDataSaverEnabled
            )
            .id(AppearanceSettingsSearchTarget.dataSaver.anchorID)
            toggleRow(
                title: "Alternative Season Menu",
                description: "Dropdown menus instead of horizontal scrolls for seasons, specials and OVAs.",
                isOn: $useSeasonMenu
            )
            .id(AppearanceSettingsSearchTarget.alternativeSeasonMenu.anchorID)
            toggleRow(
                title: "Horizontal Episode List",
                description: "Use a horizontal instead of vertical episode list.",
                isOn: $horizontalEpisodeList
            )
            .id(AppearanceSettingsSearchTarget.horizontalEpisodeList.anchorID)
            ColorPicker("Episode Card Color", selection: episodeCardColorBinding, supportsOpacity: true)
                .id(AppearanceSettingsSearchTarget.episodeCardColor.anchorID)
            Text("Episode cards use the selected tint in portrait, horizontal and iPad layouts.")
                .font(.caption)
                .foregroundColor(.secondary)
            toggleRow(
                title: "Show Unaired Episodes",
                description: "Keep future episodes visible in show and anime episode lists.",
                isOn: $showUnairedEpisodes
            )
            .id(AppearanceSettingsSearchTarget.showUnairedEpisodes.anchorID)
            Text("Portrait Detail Page").font(.subheadline.weight(.semibold))
            sliderRow(
                title: "Title Logo Vertical Position",
                description: "Adjust the title logo position only in portrait detail pages.",
                value: $titleLogoVerticalPosition,
                range: MediaDetailTitleLogoPositionSettings.supportedRange,
                step: MediaDetailTitleLogoPositionSettings.step
            )
            .id(AppearanceSettingsSearchTarget.titleLogoPosition.anchorID)
            sliderRow(
                title: "Title Logo Size",
                description: "Adjust title logo size only in portrait detail pages.",
                value: $titleLogoSize,
                range: MediaDetailTitleLogoAppearanceSettings.sizeRange,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.titleLogoSize.anchorID)
            sliderRow(
                title: "Title Logo Weight",
                description: "Adjust title logo weight only in portrait detail pages.",
                value: $titleLogoWeight,
                range: MediaDetailTitleLogoAppearanceSettings.weightRange,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.titleLogoWeight.anchorID)
            sliderRow(
                title: "Action Buttons Vertical Position",
                description: "Adjust action button position only in portrait detail pages.",
                value: $heroActionsOffset,
                range: MediaDetailHeroContentPositionSettings.supportedRange,
                step: MediaDetailHeroContentPositionSettings.step
            )
            .id(AppearanceSettingsSearchTarget.heroActionPosition.anchorID)
            sliderRow(
                title: "Synopsis Vertical Position",
                description: "Adjust synopsis position only in portrait detail pages.",
                value: $heroSynopsisOffset,
                range: MediaDetailHeroContentPositionSettings.supportedRange,
                step: MediaDetailHeroContentPositionSettings.step
            )
            .id(AppearanceSettingsSearchTarget.heroSynopsisPosition.anchorID)
            sliderRow(
                title: "Portrait Ratings & Notes Position",
                description: "Adjust the Ratings & Notes section independently in portrait detail pages.",
                value: $portraitRatingNotesOffset,
                range: MediaDetailRatingNotesPositionSettings.supportedRange,
                step: MediaDetailRatingNotesPositionSettings.step
            )
            sliderRow(
                title: "Portrait Hero Color Bleed Intensity",
                description: "Set how strongly the detail-page hero color extends down the page in portrait mode.",
                value: $portraitHeroBleedIntensity,
                range: 0...2,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.portraitHeroBleedIntensity.anchorID)

            Divider()
            Text("Landscape Detail Page").font(.subheadline.weight(.semibold))
            sliderRow(title: "Landscape Title Logo Vertical Position", description: "Move the title logo independently in landscape detail pages.", value: $landscapeTitleLogoPosition, range: LandscapeMediaDetailAppearanceSettings.logoPositionRange, step: 0.05)
                .id(AppearanceSettingsSearchTarget.landscapeTitleLogoPosition.anchorID)
            sliderRow(title: "Landscape Title Logo Horizontal Position", description: "Move the title logo left or right independently in landscape detail pages.", value: $landscapeTitleLogoHorizontalPosition, range: LandscapeMediaDetailAppearanceSettings.logoHorizontalPositionRange, step: LandscapeMediaDetailAppearanceSettings.logoHorizontalPositionStep)
                .id(AppearanceSettingsSearchTarget.landscapeTitleLogoHorizontalPosition.anchorID)
            sliderRow(title: "Landscape Title Logo Size", description: "Change title logo size only in landscape detail pages.", value: $landscapeTitleLogoSize, range: LandscapeMediaDetailAppearanceSettings.logoSizeRange, step: 0.05)
                .id(AppearanceSettingsSearchTarget.landscapeTitleLogoSize.anchorID)
            sliderRow(title: "Landscape Title Logo Weight", description: "Change title logo weight only in landscape detail pages.", value: $landscapeTitleLogoWeight, range: LandscapeMediaDetailAppearanceSettings.logoWeightRange, step: 0.05)
                .id(AppearanceSettingsSearchTarget.landscapeTitleLogoWeight.anchorID)
            sliderRow(title: "Landscape Action Buttons Vertical Position", description: "Move action buttons independently in landscape detail pages.", value: $landscapeHeroActionsOffset, range: LandscapeMediaDetailAppearanceSettings.offsetRange, step: LandscapeMediaDetailAppearanceSettings.offsetStep)
                .id(AppearanceSettingsSearchTarget.landscapeHeroActionPosition.anchorID)
            sliderRow(title: "Landscape Synopsis Vertical Position", description: "Move the synopsis independently in landscape detail pages.", value: $landscapeHeroSynopsisOffset, range: LandscapeMediaDetailAppearanceSettings.offsetRange, step: LandscapeMediaDetailAppearanceSettings.offsetStep)
                .id(AppearanceSettingsSearchTarget.landscapeHeroSynopsisPosition.anchorID)
            sliderRow(title: "Landscape Content Horizontal Position", description: "Move the genre, action buttons, ratings, notes and episode content left or right on landscape detail pages.", value: $landscapeContentHorizontalOffset, range: LandscapeMediaDetailAppearanceSettings.contentHorizontalOffsetRange, step: LandscapeMediaDetailAppearanceSettings.contentHorizontalOffsetStep)
                .id(AppearanceSettingsSearchTarget.landscapeContentHorizontalPosition.anchorID)
            sliderRow(
                title: "Landscape Hero Horizontal Stretch",
                description: "Stretch or narrow the detail-page hero artwork from left to right. This affects landscape only.",
                value: $landscapeHeroHorizontalStretch,
                range: 0.85...1.5,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.landscapeHeroHorizontalStretch.anchorID)
            sliderRow(
                title: "Landscape Hero Vertical Stretch",
                description: "Stretch or compress the detail-page hero artwork from top to bottom. This affects landscape only.",
                value: $landscapeHeroVerticalStretch,
                range: 0.85...1.5,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.landscapeHeroVerticalStretch.anchorID)
            sliderRow(
                title: "Landscape Ratings & Notes Position",
                description: "Adjust the Ratings & Notes section independently in landscape detail pages.",
                value: $landscapeRatingNotesOffset,
                range: MediaDetailRatingNotesPositionSettings.supportedRange,
                step: MediaDetailRatingNotesPositionSettings.step
            )
            sliderRow(
                title: "Landscape Hero Color Bleed Intensity",
                description: "Adjust the strength of the artwork color fade at the bottom of the landscape detail hero.",
                value: $landscapeHeroBleedIntensity,
                range: 0...3.5,
                step: 0.05
            )
            .id(AppearanceSettingsSearchTarget.landscapeHeroBleedIntensity.anchorID)
        } header: {
            Text("Detail Pages")
        }
    }

    private var scheduleAppearanceSection: some View {
        Section {
            ColorPicker("Schedule Card Color", selection: scheduleCardColorBinding, supportsOpacity: true)
                .id(AppearanceSettingsSearchTarget.scheduleCardColor.anchorID)
            Text("Choose the background tint for scheduled movies, series and anime. The release-time badge follows the selected app accent color.")
                .font(.caption)
                .foregroundColor(.secondary)

            sliderRow(
                title: "Schedule Corner Roundness",
                description: "Adjust the corners of the Schedule mode selector, timezone selector and date chips.",
                value: $scheduleControlsCornerRadiusValue,
                range: 0...32,
                step: 1
            )
            .id(AppearanceSettingsSearchTarget.scheduleControlsCornerRadius.anchorID)

            sliderRow(
                title: "Schedule Time Roundness",
                description: "Adjust the corner radius of the release-time badge on schedule cards.",
                value: $scheduleTimeCornerRadiusValue,
                range: 0...24,
                step: 1
            )
            .id(AppearanceSettingsSearchTarget.scheduleTimeCornerRadius.anchorID)
        } header: {
            Text("Schedule Appearance")
        }
    }

    private var librarySection: some View {
        Section {
            toggleRow(
                title: "Show Bookmarks",
                description: "Keep the Bookmarks section visible in Library. Hiding it does not remove any saved bookmarks.",
                isOn: $showsBookmarksSection
            )
            .id(AppearanceSettingsSearchTarget.libraryBookmarks.anchorID)

            settingRow(
                title: "Collection Layout",
                description: "Show collections in a horizontal row or a vertical grid."
            ) {
                Picker("", selection: $collectionLayoutRaw) {
                    ForEach(LibraryCollectionLayout.allCases) { layout in
                        Text(layout.displayName).tag(layout.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            .id(AppearanceSettingsSearchTarget.libraryCollectionLayout.anchorID)
        } header: {
            Text("Library")
        }
    }

    private var resetSection: some View {
        Section {
            Button(action: resetAppearance) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Appearance")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Restore the default theme, layout, animation, and startup display values.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(accent)
                }
            }
        } footer: {
            Text("Resets theme, layout, app experience, and per-catalog overrides to their defaults.")
        }
    }

    private var mediaDetailSection: some View {
        Section {
#if os(tvOS)
            ForEach(Array(tvMediaDetailElements.enumerated()), id: \.element.id) { index, element in
                HStack(spacing: 18) {
                    mediaDetailElementRow(element)
                    VStack(spacing: 8) {
                        Button {
                            moveMediaDetailElement(at: index, by: -1)
                        } label: {
                            Label("Move Up", systemImage: "chevron.up")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(index == 0)

                        Button {
                            moveMediaDetailElement(at: index, by: 1)
                        } label: {
                            Label("Move Down", systemImage: "chevron.down")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(index == tvMediaDetailElements.count - 1)
                    }
                }
            }
#else
            ForEach(mediaDetailElements) { element in
                if element == .similarTitles {
                    mediaDetailElementRow(element)
                        .id(AppearanceSettingsSearchTarget.similarTitles.anchorID)
                } else {
                    mediaDetailElementRow(element)
                }
            }
            .onMove(perform: moveMediaDetailElements)
#endif

            toggleRow(
                title: "Show Age Rating",
                description: "Display the available content age rating in the media detail layout.",
                isOn: $mediaDetailAgeRatingEnabled
            )
            .id(AppearanceSettingsSearchTarget.ageRating.anchorID)

            Button(action: resetMediaDetailElements) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Media Detail Layout")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Restore the default order and visibility.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(accent)
                }
            }
        } header: {
            Text("Media Detail Page")
        } footer: {
#if os(tvOS)
            Text("Use the arrow buttons to change section order. Hidden rows will not appear on media detail pages.")
#else
            Text("Drag rows to change their order. Hidden rows will not appear on media detail pages. Episodes only appear for series. Stills and Trailers appear in the Modern interface.")
#endif
        }
#if !os(tvOS) && !os(macOS)
        .environment(\.editMode, .constant(.active))
#endif
    }

    private var backgroundStyleBinding: Binding<AtmosphereStyle> {
        Binding(
            get: { theme.atmosphereStyle },
            set: { theme.atmosphereStyle = $0 }
        )
    }

    private var interfaceBinding: Binding<Bool> {
        Binding(
            get: { modernInterfaceEnabled },
            set: { newValue in
                ExperimentalFeatureState.setStoredValue(newValue)
                modernInterfaceEnabled = newValue
                showRestartAlert = true
            }
        )
    }

    private var availablePaletteIDs: [AtmospherePaletteID] {
#if os(tvOS)
        AtmospherePaletteID.allCases.filter { $0 != .custom }
#else
        AtmospherePaletteID.allCases
#endif
    }

#if os(tvOS)
    private var tvMediaDetailElements: [MediaDetailElement] {
        mediaDetailElements.filter { $0 != .trailers }
    }

    private var tvAccentPresets: [(name: String, color: Color)] {
        [
            ("Eclipse", AccentColorManager.defaultAccentColor),
            ("Blue", .blue),
            ("Teal", .teal),
            ("Green", .green),
            ("Orange", .orange),
            ("Red", .red),
            ("Pink", .pink),
            ("White", .white)
        ]
    }

    private var tvBackgroundPresets: [(name: String, color: Color)] {
        [
            ("Black", .black),
            ("Charcoal", Color(white: 0.07)),
            ("Midnight", Color(red: 0.025, green: 0.045, blue: 0.10)),
            ("Eclipse", Color(red: 0.09, green: 0.045, blue: 0.14)),
            ("Forest", Color(red: 0.025, green: 0.09, blue: 0.07)),
            ("Warm Gray", Color(red: 0.10, green: 0.08, blue: 0.07))
        ]
    }

    private func tvColorPresetSection(
        title: String,
        selection: Binding<Color>,
        presets: [(name: String, color: Color)]
    ) -> some View {
        Section {
            HStack {
                Text("Current Color")
                Spacer()
                Circle()
                    .fill(selection.wrappedValue)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
            }

            ForEach(presets.indices, id: \.self) { index in
                let preset = presets[index]
                let selected = tvColorsMatch(selection.wrappedValue, preset.color)
                Button {
                    selection.wrappedValue = preset.color
                } label: {
                    HStack(spacing: 18) {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                        Text(preset.name)
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundColor(.white.opacity(0.88))
                    .padding(12)
                }
                .buttonStyle(TVGlassRowButtonStyle())
                .accessibilityLabel("\(title), \(preset.name)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        } header: {
            Text(title)
        } footer: {
            Text("Choose a preset with the remote. A custom color synced from another device remains in use until you select a preset.")
        }
    }

    private func tvColorsMatch(_ first: Color, _ second: Color) -> Bool {
        var firstRed: CGFloat = 0
        var firstGreen: CGFloat = 0
        var firstBlue: CGFloat = 0
        var firstAlpha: CGFloat = 0
        var secondRed: CGFloat = 0
        var secondGreen: CGFloat = 0
        var secondBlue: CGFloat = 0
        var secondAlpha: CGFloat = 0
        guard UIColor(first).getRed(&firstRed, green: &firstGreen, blue: &firstBlue, alpha: &firstAlpha),
              UIColor(second).getRed(&secondRed, green: &secondGreen, blue: &secondBlue, alpha: &secondAlpha) else { return false }
        return abs(firstRed - secondRed) < 0.005
            && abs(firstGreen - secondGreen) < 0.005
            && abs(firstBlue - secondBlue) < 0.005
            && abs(firstAlpha - secondAlpha) < 0.005
    }
#endif

#if !os(tvOS)
    private func customColorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                let colors = theme.customPaletteColors
                if colors.indices.contains(index) { return colors[index] }
                if AppearanceConfig.defaultCustomColors.indices.contains(index) { return AppearanceConfig.defaultCustomColors[index] }
                return .purple
            },
            set: { newColor in
                var colors = theme.customPaletteColors
                while colors.count <= index { colors.append(.purple) }
                colors[index] = newColor
                theme.customPaletteColors = colors
            }
        )
    }
#endif

    private func paletteSwatch(_ id: AtmospherePaletteID) -> some View {
        let palette = AppearancePalettes.resolved(id: id, customColors: theme.customPaletteColors)
        let selected = theme.appearancePaletteRaw == id.rawValue
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                theme.appearancePaletteRaw = id.rawValue
            }
        } label: {
            VStack(spacing: isTvOS ? 10 : 6) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(stops: palette.verticalStops, startPoint: .top, endPoint: .bottom))
                    .frame(width: isTvOS ? 120 : 56, height: isTvOS ? 120 : 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(selected ? accent : Color.white.opacity(0.14), lineWidth: selected ? 2.5 : 1)
                    )
                    .scaleEffect(selected ? 1.05 : 1.0)

                Text(id.displayName)
                    .font(.system(size: isTvOS ? 25 : 11, weight: selected ? .semibold : .regular))
                    .foregroundColor(isTvOS ? (selected ? Color.primary : Color.secondary) : (selected ? Color.white : Color.white.opacity(0.6)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: isTvOS ? 134 : 62)
            }
        }
#if os(tvOS)
        .buttonStyle(TVMediaCardButtonStyle(cornerRadius: 13))
        .accessibilityLabel(id.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
#else
        .buttonStyle(.plain)
#endif
    }

    private func appearanceCategoryLabel(
        title: String,
        description: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundColor(accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 2)
    }

    private func settingRow<Trailing: View>(
        title: String,
        description: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            trailing()
        }
    }

    private func toggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .accessibilityLabel(title)
                .tint(accent)
        }
    }

    private func sliderRow(
        title: String,
        description: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
#if os(tvOS)
            HStack(spacing: 18) {
                Button {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                } label: {
                    Label("Decrease", systemImage: "minus")
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Button {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                } label: {
                    Label("Increase", systemImage: "plus")
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
#else
            Slider(value: value, in: range, step: step)
                .tint(accent)
#endif
        }
        .padding(.vertical, 2)
    }

    private func mediaDetailElementRow(_ element: MediaDetailElement) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(element.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(element.settingsDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                Text(isMediaDetailElementVisible(element) ? "Visible" : "Hidden")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isMediaDetailElementVisible(element) },
                set: { setMediaDetailElement(element, visible: $0) }
            ))
            .labelsHidden()
#if os(tvOS)
            .accessibilityLabel(element.displayName)
#endif
            .tint(accent)
        }
        .padding(.vertical, 4)
    }

    private func reloadMediaDetailElements() {
        mediaDetailElements = MediaDetailElement.orderedElements()
        hiddenMediaDetailElements = MediaDetailElement.hiddenElements()
    }

    private func moveMediaDetailElements(from source: IndexSet, to destination: Int) {
        mediaDetailElements.move(fromOffsets: source, toOffset: destination)
        MediaDetailElement.saveOrder(mediaDetailElements)
    }

    private func moveMediaDetailElement(at index: Int, by offset: Int) {
        let destination = index + offset
#if os(tvOS)
        let elements = tvMediaDetailElements
        guard elements.indices.contains(index), elements.indices.contains(destination),
              let sourceIndex = mediaDetailElements.firstIndex(of: elements[index]),
              let destinationIndex = mediaDetailElements.firstIndex(of: elements[destination]) else { return }
        mediaDetailElements.swapAt(sourceIndex, destinationIndex)
#else
        guard mediaDetailElements.indices.contains(index), mediaDetailElements.indices.contains(destination) else { return }
        mediaDetailElements.swapAt(index, destination)
#endif
        MediaDetailElement.saveOrder(mediaDetailElements)
    }

    private func setMediaDetailElement(_ element: MediaDetailElement, visible: Bool) {
        if element == .similarTitles {
            mediaDetailSimilarTitlesEnabled = visible
        }

        if visible {
            hiddenMediaDetailElements.remove(element)
        } else {
            hiddenMediaDetailElements.insert(element)
        }
        MediaDetailElement.saveHiddenElements(hiddenMediaDetailElements)
    }

    private func isMediaDetailElementVisible(_ element: MediaDetailElement) -> Bool {
        if element == .similarTitles {
            return mediaDetailSimilarTitlesEnabled && !hiddenMediaDetailElements.contains(element)
        }
        return !hiddenMediaDetailElements.contains(element)
    }

    private func resetMediaDetailElements() {
#if os(tvOS)
        var defaults = MediaDetailElement.defaultOrder.filter { $0 != .trailers }.makeIterator()
        mediaDetailElements = mediaDetailElements.map { element in
            element == .trailers ? element : (defaults.next() ?? element)
        }
        hiddenMediaDetailElements = MediaDetailElement.defaultHiddenElements.union([.trailers])
#else
        mediaDetailElements = MediaDetailElement.defaultOrder
        hiddenMediaDetailElements = MediaDetailElement.defaultHiddenElements
#endif
        mediaDetailSimilarTitlesEnabled = MediaDetailSimilarTitlesSettings.defaultEnabled
        MediaDetailElement.saveOrder(mediaDetailElements)
        MediaDetailElement.saveHiddenElements(hiddenMediaDetailElements)
    }

    private func resetAppearance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            theme.appearancePaletteRaw = AtmospherePaletteID.defaultValue.rawValue
            theme.bleedStrength = AppearanceConfig.defaultBleedStrength
            theme.backgroundIntensity = AppearanceConfig.defaultBackgroundIntensity
            theme.atmosphereMotion = AppearanceConfig.defaultMotion
            theme.customPaletteColors = AppearanceConfig.defaultCustomColors
        }
        experimentalDesignPreset = ExperimentalMediaDesignPreset.defaultValue.rawValue
        experimentalHomeCardShape = ExperimentalHomeCardShape.defaultValue.rawValue
        experimentalHeroHeightScale = ExperimentalVisualTuning.defaultHeroHeightScale
        experimentalSectionSpacingScale = ExperimentalVisualTuning.defaultSectionSpacingScale
        experimentalCardRadiusScale = ExperimentalVisualTuning.defaultCardRadiusScale
        experimentalMediaCardScale = ExperimentalVisualTuning.defaultMediaCardScale
        experimentalGlassStrength = ExperimentalVisualTuning.defaultGlassStrength
        homeAnimatedBackgroundEnabled = HomeAnimatedBackgroundSettings.defaultEnabled
        homeAnimatedBackgroundQuality = HomeAnimatedBackgroundQuality.defaultValue.rawValue
        homeAnimatedBackgroundFrameRate = HomeAnimatedBackgroundFrameRate.defaultValue.rawValue
        homeAnimatedBackgroundParticleColor = HomeAnimatedBackgroundParticleColor.defaultValue.rawValue
        appPerformanceOverlayEnabled = AppPerformanceOverlaySettings.defaultEnabled
#if !os(tvOS)
        hideSplashScreen = false
#endif
        mediaDetailAgeRatingEnabled = MediaDetailAgeRatingSettings.defaultEnabled
        showUnairedEpisodes = MediaDetailEpisodeVisibilitySettings.defaultShowUnairedEpisodes
        episodeCardColorData = Data()
        mediaDetailSimilarTitlesEnabled = MediaDetailSimilarTitlesSettings.defaultEnabled
        showsBookmarksSection = LibraryDisplaySettings.defaultShowBookmarksSection
        collectionLayoutRaw = LibraryCollectionLayout.defaultValue.rawValue
        HomeCatalogLayoutStore.shared.resetAll()
    }
}

private struct AppearanceSettingsSubpage<Content: View>: View {
    let title: String
    let sectionKey: String
    let initialSearchTarget: AppearanceSettingsSearchTarget?
    private let content: Content

    init(
        title: String,
        sectionKey: String,
        initialSearchTarget: AppearanceSettingsSearchTarget?,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.sectionKey = sectionKey
        self.initialSearchTarget = initialSearchTarget
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                content
            }
            .onAppear {
                AppPerformanceRuntimeContext.shared.setSurface("settings.\(sectionKey)")
                guard let initialSearchTarget,
                      initialSearchTarget.sectionKey == sectionKey else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        scrollProxy.scrollTo(initialSearchTarget.anchorID, anchor: .center)
                    }
                }
            }
            .onDisappear {
                AppPerformanceRuntimeContext.shared.setSurface("settings.appearance")
            }
        }
        .eclipsePageTitle(title)
        .eclipseSettingsStyle()
    }
}


