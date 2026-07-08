import SwiftUI

struct WaterDropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        func point(_ fraction: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * fraction.x, y: rect.minY + rect.height * fraction.y)
        }

        path.move(to: point(WaterDropletOutline.start))
        for segment in WaterDropletOutline.segments {
            if let control1 = segment.control1, let control2 = segment.control2 {
                path.addCurve(to: point(segment.end), control1: point(control1), control2: point(control2))
            } else {
                path.addLine(to: point(segment.end))
            }
        }
        path.closeSubpath()
        return path
    }
}
