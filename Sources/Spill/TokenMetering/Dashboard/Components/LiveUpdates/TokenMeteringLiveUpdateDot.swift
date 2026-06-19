import SwiftUI

struct TokenMeteringLiveUpdateDot: View {
    let isActive: Bool
    let marker: TokenUsageLiveUpdateMarker
    var tint: Color = .teal

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.24))
                .scaleEffect(isPulsing ? 2.25 : 0.8)
                .opacity(isActive ? (isPulsing ? 0.0 : 0.55) : 0.0)
            Circle()
                .fill(tint)
                .scaleEffect(isActive && isPulsing ? 1.28 : 0.82)
                .opacity(isActive ? 1.0 : 0.0)
        }
        .frame(width: 7, height: 7)
        .animation(.easeOut(duration: 0.42), value: isPulsing)
        .animation(.easeOut(duration: 0.14), value: isActive)
        .onAppear {
            triggerPulse()
        }
        .onChange(of: marker.sequence) { _, _ in
            triggerPulse()
        }
    }

    private func triggerPulse() {
        guard isActive else {
            isPulsing = false
            return
        }

        isPulsing = false
        DispatchQueue.main.async {
            guard isActive else {
                return
            }
            isPulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                isPulsing = false
            }
        }
    }
}
