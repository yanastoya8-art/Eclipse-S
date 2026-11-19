//
//  MainMenu.swift
//  Eclipse
//
//  Shared header components for the legacy Kanzen views.
//  The manga Reader mode root and mode switch have been removed.
//

import SwiftUI

#if !os(tvOS)
struct KanzenRootHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(ExperimentalFeatureState.isEnabledAtLaunch ? .system(size: isIPad ? 42 : 34, weight: .heavy) : .largeTitle)
                .fontWeight(ExperimentalFeatureState.isEnabledAtLaunch ? .heavy : .bold)
                .foregroundColor(ExperimentalFeatureState.isEnabledAtLaunch ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, ExperimentalFeatureState.isEnabledAtLaunch ? 16 : 10)
        .padding(.bottom, ExperimentalFeatureState.isEnabledAtLaunch ? 8 : 2)
    }
}

extension KanzenRootHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}
#endif
