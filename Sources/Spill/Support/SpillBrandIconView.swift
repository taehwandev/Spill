import SwiftUI

struct SpillBrandIconView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Outer Ripple Wave (Water rippling)
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.19, green: 0.87, blue: 0.81).opacity(0.18),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: side * 0.7, height: side * 0.15)
                    .offset(y: side * 0.22)

                // Inner Ripple Wave (Water rippling)
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.19, green: 0.87, blue: 0.81).opacity(0.32),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: side * 0.45, height: side * 0.09)
                    .offset(y: side * 0.24)

                // Water Droplet (Dripping water)
                WaterDropletShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.19, green: 0.87, blue: 0.81), // Neon Teal
                                Color(red: 0.00, green: 0.35, blue: 0.74)  // Royal Blue
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: Color(red: 0.19, green: 0.87, blue: 0.81).opacity(0.42),
                        radius: side * 0.065,
                        x: 0,
                        y: side * 0.015
                    )

                // Inner Gloss Highlight
                WaterDropletHighlightShape()
                    .stroke(
                        Color.white.opacity(0.65),
                        style: StrokeStyle(lineWidth: max(1.2, side * 0.032), lineCap: .round)
                    )
            }
            .frame(width: side, height: side)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct WaterDropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Start at the top point of the teardrop
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.20))

        // Curve down to bottom-right
        path.addCurve(
            to: CGPoint(x: w * 0.725, y: h * 0.58),
            control1: CGPoint(x: w * 0.5, y: h * 0.20),
            control2: CGPoint(x: w * 0.725, y: h * 0.45)
        )

        // Curve along the bottom circle
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.76),
            control1: CGPoint(x: w * 0.725, y: h * 0.70),
            control2: CGPoint(x: w * 0.625, y: h * 0.76)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.275, y: h * 0.58),
            control1: CGPoint(x: w * 0.375, y: h * 0.76),
            control2: CGPoint(x: w * 0.275, y: h * 0.70)
        )

        // Curve back to the top
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.20),
            control1: CGPoint(x: w * 0.275, y: h * 0.45),
            control2: CGPoint(x: w * 0.5, y: h * 0.20)
        )

        path.closeSubpath()
        return path
    }
}

struct WaterDropletHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Arc highlight inside the top-left of the droplet
        path.move(to: CGPoint(x: w * 0.425, y: h * 0.45))
        path.addCurve(
            to: CGPoint(x: w * 0.425, y: h * 0.58),
            control1: CGPoint(x: w * 0.375, y: h * 0.48),
            control2: CGPoint(x: w * 0.375, y: h * 0.55)
        )
        return path
    }
}
