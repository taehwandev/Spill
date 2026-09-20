import SwiftUI

struct SpillBrandAIIconView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let availableHeight = side * (1 - 0.24)
            let availableWidth = availableHeight * WaterDropletOutline.aspectRatio

            ZStack(alignment: .bottomTrailing) {
                WaterDropletShape()
                    .fill(Color(red: 0.0863, green: 0.7451, blue: 0.5451)) // #16BE8B
                    .frame(width: availableWidth, height: availableHeight)
                    .frame(width: side, height: side)

                // AI Sparkle accessory badge on top of droplet
                Image(systemName: "sparkles")
                    .font(.system(size: side * 0.36, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.85, blue: 0.95),
                                Color(red: 0.15, green: 0.75, blue: 0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: side * 0.04, y: side * 0.02)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
