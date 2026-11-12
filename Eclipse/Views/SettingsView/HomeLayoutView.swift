import SwiftUI

#if os(tvOS)
private enum TVCardDensity: String, CaseIterable, Identifiable {
    case spacious
    case standard
    case compact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spacious: return "Spacious"
        case .standard: return "Standard"
        case .compact: return "Compact"
        }
    }

}
#endif

struct HomeLayoutView: View {

    @AppStorage(ExperimentalHomeCardShape.storageKey) private var globalCardShape = ExperimentalHomeCardShape.defaultValue.rawValue
    @AppStorage(ExperimentalVisualTuning.mediaCardScaleKey) private var globalCardScale = ExperimentalVisualTuning.defaultMediaCardScale
    @AppStorage(ExperimentalMediaDesignPreset.storageKey) private var designPreset = ExperimentalMediaDesignPreset.defaultValue.rawValue
    @AppStorage(ExperimentalVisualTuning.cardRadiusScaleKey) private var cardRadiusScale = ExperimentalVisualTuning.defaultCardRadiusScale
    @AppStorage(ExperimentalVisualTuning.sectionSpacingScaleKey) private var sectionSpacingScale = ExperimentalVisualTuning.defaultSectionSpacingScale
    @AppStorage(ExperimentalVisualTuning.heroHeightScaleKey) private var heroHeightScale = ExperimentalVisualTuning.defaultHeroHeightScale
    @AppStorage(HomeAnimatedBackgroundSettings.enabledKey) private var animatedBackgroundEnabled = HomeAnimatedBackgroundSettings.defaultEnabled
    @AppStorage(HomeAnimatedBackgroundQuality.storageKey) private var animatedBackgroundQuality = HomeAnimatedBackgroundQuality.defaultValue.rawValue
    @AppStorage(HomeAnimatedBackgroundFrameRate.storageKey) private var animatedBackgroundFrameRate = HomeAnimatedBackgroundFrameRate.defaultValue.rawValue
#if os(tvOS)
    @AppStorage("tvCardDensity") private var tvCardDensityRaw = TVCardDensity.standard.rawValue
#endif

    @AppStorage("heroBannerCatalogId") private var heroBannerCatalogId = "trending"
    @AppStorage("heroBannerBehavior") private var heroBannerBehavior = HeroBannerBehavior.defaultValue.rawValue

    @StateObject private var catalogManager = CatalogManager.shared
    @StateObject private var layoutStore = HomeCatalogLayoutStore.shared
    @StateObject private var accentColorManager = AccentColorManager.shared

    private var accent: Color { accentColorManager.currentAccentColor }

    private var sortedCatalogs: [Catalog] {
        catalogManager.catalogs.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            globalSection
                .eclipseExperimentalSettingsRows()
            heroSection
                .eclipseExperimentalSettingsRows()
            perCatalogSection
                .eclipseExperimentalSettingsRows()
        }
        .eclipsePageTitle("Home Layout")
        .accessibilityIdentifier("tv.appearance.homeLayout.screen")
        .eclipseSettingsStyle()
#if os(tvOS)
        .onAppear {
            let density = TVCardDensity(rawValue: tvCardDensityRaw) ?? .standard
            tvCardDensityRaw = density.rawValue
        }
#endif
    }

    private var globalSection: some View {
        Section {
            pickerRow(
                title: "Orientation",
                description: "Whether shelves prefer poster (tall) or landscape (wide) artwork.",
                selection: $globalCardShape,
                values: ExperimentalHomeCardShape.allCases.map { ($0.rawValue, $0.displayName) }
            )

#if os(tvOS)
            pickerRow(
                title: "Card Density",
                description: "Choose comfortable ten-foot spacing without using phone column counts.",
                selection: Binding(
                    get: { (TVCardDensity(rawValue: tvCardDensityRaw) ?? .standard).rawValue },
                    set: { newValue in
                        let density = TVCardDensity(rawValue: newValue) ?? .standard
                        tvCardDensityRaw = density.rawValue
                    }
                ),
                values: TVCardDensity.allCases.map { ($0.rawValue, $0.displayName) }
            )
#else
            sliderRow(
                title: "Size",
                description: "Scale every home row's cards and widgets.",
                value: $globalCardScale,
                range: HomeCatalogLayoutStore.sizeRange,
                step: 0.05,
                format: "%.2fx"
            )
#endif

            pickerRow(
                title: "Layout Density",
                description: "Controls hero scale, spacing and base card sizing.",
                selection: $designPreset,
                values: ExperimentalMediaDesignPreset.allCases.map { ($0.rawValue, $0.displayName) }
            )

            sliderRow(
                title: "Card Roundness",
                description: "Corner radius of cards.",
                value: $cardRadiusScale,
                range: 0.7...1.4,
                step: 0.05
            )

            sliderRow(
                title: "Section Spacing",
                description: "Vertical rhythm between shelves.",
                value: $sectionSpacingScale,
                range: 0.75...1.35,
                step: 0.05
            )

            settingRow(
                title: "Animated Background",
                description: "Subtle Eclipse-style motion behind broad app surfaces."
            ) {
                Toggle("", isOn: $animatedBackgroundEnabled)
                    .labelsHidden()
#if os(tvOS)
                    .accessibilityLabel("Animated Background")
                    .accessibilityIdentifier("tv.appearance.animatedBackground")
#endif
                    .tint(accent)
            }

            pickerRow(
                title: "Animation Quality",
                description: "Low keeps the core eclipse rings and particles. Medium and High progressively add richer motion layers.",
                selection: $animatedBackgroundQuality,
                values: HomeAnimatedBackgroundQuality.allCases.map { ($0.rawValue, $0.displayName) }
            )

            pickerRow(
                title: "Animation Frame Rate",
                description: "Choose 20, 30, 60, or 120 FPS for background motion. Higher rates use more power; the display and system may limit the actual rate.",
                selection: $animatedBackgroundFrameRate,
                values: HomeAnimatedBackgroundFrameRate.allCases.map { ($0.rawValue, $0.displayName) },
                accessibilityIdentifier: "tv.appearance.animationFrameRate"
            )
        } header: {
            Text("Global")
        } footer: {
            Text("These apply to every home row. Override individual rows below.")
        }
    }

    private var heroSection: some View {
        Section {
            sliderRow(
                title: "Hero Size",
                description: "Scale the large banner artwork.",
                value: $heroHeightScale,
                range: 0.75...1.15,
                step: 0.05
            )

            pickerRow(
                title: "Hero Banner",
                description: "The home catalogue used for the large banner.",
                selection: $heroBannerCatalogId,
                values: sortedCatalogs.map { ($0.id, $0.name) }
            )

            settingRow(title: "Hero Behavior", description: "When the banner changes.") {
                Picker("", selection: heroBehaviorBinding) {
                    ForEach(HeroBannerBehavior.selectableCases) { behavior in
                        Text(behavior.displayName).tag(behavior.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            NavigationLink {
                HomeHeroSelectionView()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose Hero Shows")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Pick the exact movies and TV shows that can appear in the home banner. A custom selection overrides the catalogue above.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            Text("Hero")
        }
    }

    private var perCatalogSection: some View {
        Section {
            ForEach(sortedCatalogs) { catalog in
                NavigationLink {
                    CatalogLayoutEditorView(catalog: catalog)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(catalog.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(summary(for: catalog))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            Button(role: .destructive) {
                layoutStore.resetAll()
            } label: {
                HStack {
                    Text("Reset All Catalogs")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(accent)
                }
            }
        } header: {
            Text("Per Catalog")
        } footer: {
            Text("Rows set to Global follow the settings above. Orientation applies to standard poster rows; widget rows support size only.")
        }
    }

    private func summary(for catalog: Catalog) -> String {
        let override = layoutStore.override(for: catalog.id)
        guard !override.isEmpty else { return "Global" }
        var parts: [String] = []
        if override.orientation != .global { parts.append(override.orientation.displayName) }
        if let scale = override.sizeScale { parts.append(String(format: "%.2fx", scale)) }
        return parts.isEmpty ? "Global" : parts.joined(separator: " · ")
    }

    private var heroBehaviorBinding: Binding<String> {
        Binding(
            get: {
                let resolved = HeroBannerBehavior(rawValue: heroBannerBehavior) ?? .defaultValue
                return HeroBannerBehavior.selectableCases.contains(resolved) ? resolved.rawValue : HeroBannerBehavior.defaultValue.rawValue
            },
            set: { heroBannerBehavior = $0 }
        )
    }

    private func settingRow<Trailing: View>(
        title: String,
        description: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            trailing()
        }
    }

    private func pickerRow(
        title: String,
        description: String,
        selection: Binding<String>,
        values: [(String, String)],
        accessibilityIdentifier: String = ""
    ) -> some View {
        settingRow(title: title, description: description) {
            Picker("", selection: selection) {
                ForEach(values, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.menu)
#if os(tvOS)
            .accessibilityIdentifier(accessibilityIdentifier)
            .accessibilityLabel(title)
            .accessibilityValue(values.first(where: { $0.0 == selection.wrappedValue })?.1 ?? selection.wrappedValue)
#endif
        }
    }

    private func sliderRow(
        title: String,
        description: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String = "%.2f"
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Text(String(format: format, value.wrappedValue))
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
}

private struct CatalogLayoutEditorView: View {
    let catalog: Catalog

    @StateObject private var layoutStore = HomeCatalogLayoutStore.shared
    @StateObject private var accentColorManager = AccentColorManager.shared
    @AppStorage(ExperimentalVisualTuning.mediaCardScaleKey) private var globalCardScale = ExperimentalVisualTuning.defaultMediaCardScale

    private var accent: Color { accentColorManager.currentAccentColor }
    private var supportsOrientation: Bool { catalog.displayStyle == .standard }
    private var effectiveGlobalCardScale: Double {
#if os(tvOS)
        ExperimentalVisualTuning.current.mediaCardScale
#else
        globalCardScale
#endif
    }

    var body: some View {
        List {
            if supportsOrientation {
                Section {
                    Picker("Orientation", selection: orientationBinding) {
                        ForEach(CatalogOrientationOverride.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Orientation")
                } footer: {
#if os(tvOS)
                    Text("Global follows the Home Layout orientation. Automatic chooses one orientation per shelf, using posters for anime or missing backdrop artwork.")
#else
                    Text("Global follows the Home Layout orientation. Automatic picks poster or landscape per item.")
#endif
                }
                .eclipseExperimentalSettingsRows()
            }

            Section {
                Toggle("Custom size", isOn: customSizeBinding)
                    .tint(accent)

                if let _ = layoutStore.override(for: catalog.id).sizeScale {
                    HStack {
                        Text("Size")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.2fx", sizeValueBinding.wrappedValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
#if os(tvOS)
                    HStack(spacing: 18) {
                        Button {
                            sizeValueBinding.wrappedValue = max(
                                HomeCatalogLayoutStore.sizeRange.lowerBound,
                                sizeValueBinding.wrappedValue - 0.05
                            )
                        } label: {
                            Label("Decrease Size", systemImage: "minus")
                        }
                        .disabled(sizeValueBinding.wrappedValue <= HomeCatalogLayoutStore.sizeRange.lowerBound)

                        Button {
                            sizeValueBinding.wrappedValue = min(
                                HomeCatalogLayoutStore.sizeRange.upperBound,
                                sizeValueBinding.wrappedValue + 0.05
                            )
                        } label: {
                            Label("Increase Size", systemImage: "plus")
                        }
                        .disabled(sizeValueBinding.wrappedValue >= HomeCatalogLayoutStore.sizeRange.upperBound)
                    }
#else
                    Slider(value: sizeValueBinding, in: HomeCatalogLayoutStore.sizeRange, step: 0.05)
                        .tint(accent)
#endif
                }
            } header: {
                Text("Size")
            } footer: {
                Text("Off follows the global size. Widget rows support size only.")
            }
            .eclipseExperimentalSettingsRows()

            Section {
                Button(role: .destructive) {
                    layoutStore.reset(id: catalog.id)
                } label: {
                    HStack {
                        Text("Reset to Global")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(accent)
                    }
                }
            }
            .eclipseExperimentalSettingsRows()
        }
        .eclipsePageTitle(catalog.name)
        .eclipseSettingsStyle()
    }

    private var orientationBinding: Binding<CatalogOrientationOverride> {
        Binding(
            get: { layoutStore.override(for: catalog.id).orientation },
            set: { layoutStore.setOrientation($0, for: catalog.id) }
        )
    }

    private var customSizeBinding: Binding<Bool> {
        Binding(
            get: { layoutStore.override(for: catalog.id).sizeScale != nil },
            set: { isOn in
                layoutStore.setSizeScale(isOn ? effectiveGlobalCardScale : nil, for: catalog.id)
            }
        )
    }

    private var sizeValueBinding: Binding<Double> {
        Binding(
            get: { layoutStore.override(for: catalog.id).sizeScale ?? effectiveGlobalCardScale },
            set: { layoutStore.setSizeScale($0, for: catalog.id) }
        )
    }
}


private struct HomeHeroSelectionView: View {
    @StateObject private var tmdbService = TMDBService.shared
    @State private var searchText = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var selectedTitles: [TMDBSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    TextField("Search movies and TV shows", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { search() }
                    Button {
                        search()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                    .accessibilityLabel("Search titles")
                }

                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView("Searching…")
                        Spacer()
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("Find Titles")
            }

            Section {
                if selectedTitles.isEmpty {
                    Text("No custom titles selected. The Home Banner catalogue setting will be used.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(selectedTitles, id: \.stableIdentity) { title in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title.displayTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(titleKindAndYear(title))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                remove(title)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(title.displayTitle) from hero selection")
                        }
                    }

                    Button("Clear Custom Selection", role: .destructive) {
                        selectedTitles = []
                        persistSelection()
                    }
                }
            } header: {
                Text("Selected for Hero (\(selectedTitles.count))")
            } footer: {
                Text("The order shown here is the order used by the carousel. Choose Static to show the first title, or Carousel to rotate through all selected titles.")
            }

            if !searchResults.isEmpty {
                Section("Search Results") {
                    ForEach(searchResults, id: \.stableIdentity) { title in
                        let isSelected = selectedTitles.contains { $0.stableIdentity == title.stableIdentity }
                        Button {
                            toggle(title)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title.displayTitle)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text(titleKindAndYear(title))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .eclipsePageTitle("Choose Hero Shows")
        .eclipseSettingsStyle()
        .onAppear {
            selectedTitles = HomeHeroSelectionSettings.load()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func titleKindAndYear(_ title: TMDBSearchResult) -> String {
        let kind = title.isMovie ? "Movie" : "TV Show"
        let year = title.displayDate.isEmpty ? nil : String(title.displayDate.prefix(4))
        return [kind, year].compactMap { $0 }.joined(separator: " · ")
    }

    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            isSearching = true
            errorMessage = nil
            defer { isSearching = false }
            do {
                let results = try await tmdbService.searchMulti(query: query, maxPages: 1)
                guard !Task.isCancelled else { return }
                searchResults = results.filter { $0.isMovie || $0.isTVShow }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                searchResults = []
            }
        }
    }

    private func toggle(_ title: TMDBSearchResult) {
        if let index = selectedTitles.firstIndex(where: { $0.stableIdentity == title.stableIdentity }) {
            selectedTitles.remove(at: index)
        } else {
            selectedTitles.append(title)
        }
        persistSelection()
    }

    private func remove(_ title: TMDBSearchResult) {
        selectedTitles.removeAll { $0.stableIdentity == title.stableIdentity }
        persistSelection()
    }

    private func persistSelection() {
        HomeHeroSelectionSettings.save(selectedTitles)
    }
}
