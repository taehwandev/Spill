import CoreGraphics

/// A single straight edge or cubic curve segment in normalized SVG-style coordinates.
struct WaterDropletSegment {
    let end: CGPoint
    let control1: CGPoint?
    let control2: CGPoint?

    static func line(to end: CGPoint) -> WaterDropletSegment {
        WaterDropletSegment(end: end, control1: nil, control2: nil)
    }

    static func curve(to end: CGPoint, control1: CGPoint, control2: CGPoint) -> WaterDropletSegment {
        WaterDropletSegment(end: end, control1: control1, control2: control2)
    }
}
