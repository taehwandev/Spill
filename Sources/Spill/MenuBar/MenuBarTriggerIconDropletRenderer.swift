import AppKit

@MainActor
enum MenuBarTriggerIconDropletRenderer {
    private static let keyColor = NSColor(calibratedRed: 0.0863, green: 0.7451, blue: 0.5451, alpha: 1)

    /// A glint of light traces down the drop's own outline — top, down the right edge, to the
    /// bottom point — like a bead of water running down the side of a glass, rather than a
    /// beam crossing through the interior. It's a short fading comet trail (bright head,
    /// transparent tail), only during the first `traceWindow` of the burst (fast, not a slow
    /// glide); the icon then sits still for the rest of the burst. The drop shape itself
    /// never moves — the earlier squash-stretch "slosh" wobble was too small a pixel delta at
    /// menu bar size (±10% width / ±7% height, well under 2px) to reliably read as motion,
    /// and an interior-crossing shine band (two prior attempts: a wide sideways sweep, then a
    /// straight top-to-bottom drop) both read as unrelated to the drop's own shape rather than
    /// water actually moving on its surface.
    static func image(phase: CGFloat, size: CGFloat) -> NSImage? {
        guard size.isFinite, size > 0 else {
            return nil
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.shouldAntialias = true

        let canvas = NSRect(x: 0, y: 0, width: size, height: size)
        let availableHeight = size * (1 - 0.24)
        let availableWidth = availableHeight * WaterDropletOutline.aspectRatio
        let rect = NSRect(
            x: canvas.midX - availableWidth / 2,
            y: canvas.midY - availableHeight / 2,
            width: availableWidth,
            height: availableHeight
        )

        let path = outline(in: rect)
        keyColor.setFill()
        path.fill()

        let trail = edgeGlintTrail(phase: phase, rect: rect)
        if !trail.isEmpty {
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            for (segmentPath, alpha) in trail {
                NSColor.white.withAlphaComponent(alpha).setStroke()
                segmentPath.lineWidth = size * 0.09
                segmentPath.lineCapStyle = .round
                segmentPath.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        image.isTemplate = false
        return image
    }
}

private extension MenuBarTriggerIconDropletRenderer {
    /// Points sampling the top-to-bottom-via-the-right-edge half of the outline (the initial
    /// straight edge plus the first two curves — `WaterDropletOutline.segments[0...2]` — which
    /// end exactly at the drop's bottom point), flattened into short line segments so a
    /// sub-range of them can be stroked as a moving trail. Curves are sampled at 10 steps each;
    /// coarser would look faceted at this line width, finer is wasted precision at icon size.
    private static let topToBottomPolyline: [CGPoint] = {
        let samplesPerCurve = 10
        var points = [WaterDropletOutline.start]
        var previous = WaterDropletOutline.start
        for segment in WaterDropletOutline.segments.prefix(3) {
            if let control1 = segment.control1, let control2 = segment.control2 {
                for step in 1...samplesPerCurve {
                    let t = CGFloat(step) / CGFloat(samplesPerCurve)
                    points.append(cubicBezierPoint(previous, control1, control2, segment.end, t))
                }
            } else {
                points.append(segment.end)
            }
            previous = segment.end
        }
        return points
    }()

    private static func cubicBezierPoint(
        _ start: CGPoint,
        _ control1: CGPoint,
        _ control2: CGPoint,
        _ end: CGPoint,
        _ t: CGFloat
    ) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * mt * start.x + 3 * mt * mt * t * control1.x + 3 * mt * t * t * control2.x + t * t * t * end.x
        let y = mt * mt * mt * start.y + 3 * mt * mt * t * control1.y + 3 * mt * t * t * control2.y + t * t * t * end.y
        return CGPoint(x: x, y: y)
    }
}

private extension MenuBarTriggerIconDropletRenderer {
    /// The moving comet trail, as individual short segments each with their own fade-in
    /// alpha (transparent tail, opaque head) — a single stroke can't carry a gradient along
    /// its length in AppKit, so the trail is built from several short overlapping strokes
    /// instead. Empty once `phase` is past `traceWindow`, so nothing draws for the remainder
    /// of the burst.
    private static func edgeGlintTrail(phase: CGFloat, rect: NSRect) -> [(path: NSBezierPath, alpha: CGFloat)] {
        let traceWindow: CGFloat = 0.4
        guard phase <= traceWindow else {
            return []
        }

        let points = topToBottomPolyline
        let traceT = phase / traceWindow
        let headIndex = Int((traceT * CGFloat(points.count - 1)).rounded())
        let trailLength = 9
        let tailIndex = max(0, headIndex - trailLength)
        guard headIndex > tailIndex else {
            return []
        }

        func mapped(_ fraction: CGPoint) -> NSPoint {
            NSPoint(
                x: rect.minX + rect.width * fraction.x,
                y: rect.minY + rect.height * (1 - fraction.y)
            )
        }

        var trail: [(NSBezierPath, CGFloat)] = []
        for index in tailIndex..<headIndex {
            let fractionAlongTrail = CGFloat(index - tailIndex) / CGFloat(headIndex - tailIndex)
            let alpha = fractionAlongTrail * fractionAlongTrail // eases in toward the bright head
            let segmentPath = NSBezierPath()
            segmentPath.move(to: mapped(points[index]))
            segmentPath.line(to: mapped(points[index + 1]))
            trail.append((segmentPath, alpha))
        }
        return trail
    }

    private static func outline(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()

        func point(_ fraction: CGPoint) -> NSPoint {
            NSPoint(
                x: rect.minX + rect.width * fraction.x,
                y: rect.minY + rect.height * (1 - fraction.y)
            )
        }

        path.move(to: point(WaterDropletOutline.start))
        for segment in WaterDropletOutline.segments {
            if let control1 = segment.control1, let control2 = segment.control2 {
                path.curve(to: point(segment.end), controlPoint1: point(control1), controlPoint2: point(control2))
            } else {
                path.line(to: point(segment.end))
            }
        }
        path.close()

        return path
    }
}
