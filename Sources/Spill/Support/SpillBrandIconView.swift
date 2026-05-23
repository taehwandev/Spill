import SwiftUI

struct SpillBrandIconView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cornerRadius = side * 0.225
            let borderWidth = max(1, side * 0.01)
            let shadowWidth = max(1, side * 0.006)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.115, green: 0.135, blue: 0.150),
                                Color(red: 0.035, green: 0.042, blue: 0.052)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RadialGradient(
                    colors: [
                        Color(red: 0.050, green: 0.820, blue: 0.760).opacity(0.16),
                        Color(red: 0.050, green: 0.820, blue: 0.760).opacity(0)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.58),
                    startRadius: 0,
                    endRadius: side * 0.46
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                SpillLogoShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.600, green: 1.000, blue: 0.950),
                                Color(red: 0.100, green: 0.840, blue: 0.780),
                                Color(red: 0.030, green: 0.500, blue: 0.540)
                            ],
                            startPoint: UnitPoint(x: 0.34, y: 0.33),
                            endPoint: UnitPoint(x: 0.70, y: 0.72)
                        )
                    )
                    .shadow(
                        color: Color(red: 0.080, green: 0.950, blue: 0.850).opacity(0.55),
                        radius: side * 0.055,
                        y: -side * 0.01
                    )

                SpillLogoShape()
                    .stroke(.white.opacity(0.25), lineWidth: borderWidth)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: borderWidth)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.black.opacity(0.42), lineWidth: shadowWidth)
            }
            .frame(width: side, height: side)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct SpillLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        path.move(to: CGPoint(x: width * 0.22, y: height * 0.43))
        path.addCurve(
            to: CGPoint(x: width * 0.39, y: height * 0.56),
            control1: CGPoint(x: width * 0.22, y: height * 0.52),
            control2: CGPoint(x: width * 0.30, y: height * 0.58)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.54, y: height * 0.51),
            control1: CGPoint(x: width * 0.45, y: height * 0.55),
            control2: CGPoint(x: width * 0.48, y: height * 0.50)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.80, y: height * 0.47),
            control1: CGPoint(x: width * 0.64, y: height * 0.55),
            control2: CGPoint(x: width * 0.79, y: height * 0.57)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.65, y: height * 0.31),
            control1: CGPoint(x: width * 0.81, y: height * 0.36),
            control2: CGPoint(x: width * 0.74, y: height * 0.31)
        )
        path.addLine(to: CGPoint(x: width * 0.34, y: height * 0.31))
        path.addCurve(
            to: CGPoint(x: width * 0.22, y: height * 0.43),
            control1: CGPoint(x: width * 0.25, y: height * 0.31),
            control2: CGPoint(x: width * 0.21, y: height * 0.36)
        )
        path.closeSubpath()

        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -height)
        return path.applying(transform)
    }
}
