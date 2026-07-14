import AppKit

extension MenuBarMetricSparklineView {
    func drawMemoryWave() {
        guard let renderedSeries = series.first, !renderedSeries.values.isEmpty else { return }

        let drawableRect = bounds.insetBy(dx: 2.5, dy: 1.0)
        let scale = scaleFactor
        let pts = points(for: renderedSeries.values, in: drawableRect)
        guard let firstPoint = pts.first, let lastPoint = pts.last else { return }

        let linePath = smoothedPath(from: pts)
        let fillPath = NSBezierPath()
        fillPath.append(linePath)
        fillPath.line(to: NSPoint(x: lastPoint.x, y: drawableRect.minY))
        fillPath.line(to: NSPoint(x: firstPoint.x, y: drawableRect.minY))
        fillPath.close()

        let gradient = NSGradient(
            starting: renderedSeries.color.withAlphaComponent(0.0),
            ending: renderedSeries.color.withAlphaComponent(0.14)
        )
        gradient?.draw(in: fillPath, angle: 90)

        renderedSeries.color.withAlphaComponent(0.90).setStroke()
        linePath.lineWidth = 1.0
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        linePath.stroke()

        drawEndpoint(
            at: lastPoint,
            color: renderedSeries.color,
            haloAlpha: 0.0,
            dotAlpha: 0.95,
            dotSize: 2.0
        )
    }

    func drawNetworkWaves() {
        let drawableRect = bounds.insetBy(dx: 2.5, dy: 1.0)

        for (index, renderedSeries) in series.enumerated() {
            guard !renderedSeries.values.isEmpty else { continue }

            let pts = points(for: renderedSeries.values, in: drawableRect)
            guard let firstPoint = pts.first, let lastPoint = pts.last else { continue }

            let linePath = smoothedPath(from: pts)
            let fillPath = NSBezierPath()
            fillPath.append(linePath)
            fillPath.line(to: NSPoint(x: lastPoint.x, y: drawableRect.minY))
            fillPath.line(to: NSPoint(x: firstPoint.x, y: drawableRect.minY))
            fillPath.close()

            let gradient = NSGradient(
                starting: renderedSeries.color.withAlphaComponent(0.0),
                ending: renderedSeries.color.withAlphaComponent(0.06)
            )
            gradient?.draw(in: fillPath, angle: 90)

            renderedSeries.color.withAlphaComponent(index == 0 ? 0.90 : 0.80).setStroke()
            linePath.lineWidth = 1.0
            linePath.lineCapStyle = .round
            linePath.lineJoinStyle = .round
            linePath.stroke()

            drawEndpoint(
                at: lastPoint,
                color: renderedSeries.color,
                haloAlpha: 0.0,
                dotAlpha: 0.90,
                dotSize: 2.0
            )
        }
    }

    private func drawEndpoint(
        at point: NSPoint,
        color: NSColor,
        haloAlpha: CGFloat,
        dotAlpha: CGFloat,
        dotSize: CGFloat = 2.0
    ) {
        let scale = scaleFactor
        if haloAlpha > 0 {
            let haloSize: CGFloat = 5
            let haloRect = NSRect(
                x: round((point.x - haloSize / 2) * scale) / scale,
                y: round((point.y - haloSize / 2) * scale) / scale,
                width: haloSize,
                height: haloSize
            )
            color.withAlphaComponent(haloAlpha).setFill()
            NSBezierPath(ovalIn: haloRect).fill()
        }

        let dotRect = NSRect(
            x: round((point.x - dotSize / 2) * scale) / scale,
            y: round((point.y - dotSize / 2) * scale) / scale,
            width: dotSize,
            height: dotSize
        )
        color.withAlphaComponent(dotAlpha).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }
}
