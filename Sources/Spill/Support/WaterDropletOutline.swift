import CoreGraphics

/// The Spill waterdrop mark outline, sampled from `spill_waterdrop_teal_final.svg`.
enum WaterDropletOutline {
    /// Width / height of the drop's true bounding box before normalizing points to a unit square.
    static let aspectRatio: CGFloat = 660.0 / 866.0

    static let start = CGPoint(x: 0.5000, y: 0.0000)

    static let segments: [WaterDropletSegment] = [
        .line(to: CGPoint(x: 0.8212, y: 0.4088)),
        .curve(
            to: CGPoint(x: 0.8788, y: 0.8730),
            control1: CGPoint(x: 0.9545, y: 0.5796),
            control2: CGPoint(x: 1.0000, y: 0.7529)
        ),
        .curve(
            to: CGPoint(x: 0.5000, y: 1.0000),
            control1: CGPoint(x: 0.7894, y: 0.9619),
            control2: CGPoint(x: 0.6485, y: 1.0000)
        ),
        .curve(
            to: CGPoint(x: 0.1212, y: 0.8730),
            control1: CGPoint(x: 0.3515, y: 1.0000),
            control2: CGPoint(x: 0.2106, y: 0.9619)
        ),
        .curve(
            to: CGPoint(x: 0.1788, y: 0.4088),
            control1: CGPoint(x: 0.0000, y: 0.7529),
            control2: CGPoint(x: 0.0455, y: 0.5796)
        ),
    ]
}
