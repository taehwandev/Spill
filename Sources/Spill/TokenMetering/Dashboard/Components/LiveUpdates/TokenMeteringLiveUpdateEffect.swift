import SwiftUI

struct TokenMeteringLiveUpdateEffect: ViewModifier {
    let isActive: Bool
    let marker: TokenUsageLiveUpdateMarker
    let cornerRadius: CGFloat

    @State private var isFlashing = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.teal.opacity(isActive && isFlashing ? 0.05 : 0.0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.teal.opacity(isActive && isFlashing ? 0.12 : 0.0), lineWidth: 0.8)
            }
            .animation(.easeOut(duration: 0.34), value: isFlashing)
            .animation(.easeOut(duration: 0.14), value: isActive)
            .onAppear {
                triggerFlash()
            }
            .onChange(of: marker.sequence) { _, _ in
                triggerFlash()
            }
    }

    private func triggerFlash() {
        guard isActive else {
            isFlashing = false
            return
        }

        isFlashing = false
        DispatchQueue.main.async {
            guard isActive else {
                return
            }
            isFlashing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                isFlashing = false
            }
        }
    }
}
