import SwiftUI

struct SpillBrandSMarkView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let lineWidth = max(2.0, side * 0.18)

            ZStack {
                SymbolizedSShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.19, green: 0.87, blue: 0.81),
                                Color(red: 0.00, green: 0.35, blue: 0.74)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(
                        color: Color(red: 0.19, green: 0.87, blue: 0.81).opacity(0.32),
                        radius: side * 0.05,
                        x: 0,
                        y: side * 0.012
                    )

                SymbolizedSShape()
                    .trim(from: 0.06, to: 0.45)
                    .stroke(
                        Color.white.opacity(0.52),
                        style: StrokeStyle(lineWidth: max(0.8, side * 0.032), lineCap: .round, lineJoin: .round)
                    )
            }
            .padding(side * 0.12)
            .frame(width: side, height: side)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private struct SymbolizedSShape: Shape {
        func path(in rect: CGRect) -> Path {
            let w = rect.width
            let h = rect.height
            var path = Path()

            path.move(to: CGPoint(x: rect.minX + w * 0.76, y: rect.minY + h * 0.16))
            path.addCurve(
                to: CGPoint(x: rect.minX + w * 0.34, y: rect.minY + h * 0.22),
                control1: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.10),
                control2: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.10)
            )
            path.addCurve(
                to: CGPoint(x: rect.minX + w * 0.27, y: rect.minY + h * 0.42),
                control1: CGPoint(x: rect.minX + w * 0.24, y: rect.minY + h * 0.32),
                control2: CGPoint(x: rect.minX + w * 0.21, y: rect.minY + h * 0.38)
            )
            path.addCurve(
                to: CGPoint(x: rect.minX + w * 0.60, y: rect.minY + h * 0.51),
                control1: CGPoint(x: rect.minX + w * 0.34, y: rect.minY + h * 0.49),
                control2: CGPoint(x: rect.minX + w * 0.51, y: rect.minY + h * 0.48)
            )
            path.addCurve(
                to: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.70),
                control1: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.55),
                control2: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.62)
            )
            path.addCurve(
                to: CGPoint(x: rect.minX + w * 0.25, y: rect.minY + h * 0.84),
                control1: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.86),
                control2: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.90)
            )

            return path
        }
    }
}
