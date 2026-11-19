import SwiftUI

struct FloatingSettingsButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                isPresented = true
            }
        }) {
            Image(systemName: "gear")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .applyLiquidGlassBackground(cornerRadius: 22)
        }
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

#if !os(tvOS) && !os(macOS)
struct AppHubActionPulse: View {
    let isActive: Bool
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(isActive ? 0.24 : 0))
                .scaleEffect(isActive ? 1.22 : 0.45)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.7), tint.opacity(0.3), Color.clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ),
                    lineWidth: 2
                )
                .scaleEffect(isActive ? 1.58 : 0.72)
                .opacity(isActive ? 0 : 0.7)
        }
        .opacity(isActive ? 1 : 0)
        .animation(.easeOut(duration: 0.42), value: isActive)
    }
}

#endif

struct FloatingSettingsOverlay: View {
    @Binding var showingSettings: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .allowsHitTesting(false)

            HStack(spacing: 10) {
                FloatingSettingsButton(isPresented: $showingSettings)
            }
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
    }
}
