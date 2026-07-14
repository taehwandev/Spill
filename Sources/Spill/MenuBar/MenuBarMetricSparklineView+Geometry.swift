import AppKit

extension MenuBarMetricSparklineView {
    func smoothedPath(from points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard points.count >= 2 else {
            if let first = points.first {
                path.move(to: first)
            }
            return path
        }

        path.move(to: points[0])
        if points.count == 2 {
            path.line(to: points[1])
            return path
        }

        for index in 0..<points.count - 1 {
            let currentPoint = points[index]
            let nextPoint = points[index + 1]
            let midpoint = NSPoint(
                x: (currentPoint.x + nextPoint.x) / 2,
                y: (currentPoint.y + nextPoint.y) / 2
            )

            if index == 0 {
                path.line(to: midpoint)
            } else {
                let startPoint = path.currentPoint
                let firstControlPoint = NSPoint(
                    x: startPoint.x + 2.0 / 3.0 * (currentPoint.x - startPoint.x),
                    y: startPoint.y + 2.0 / 3.0 * (currentPoint.y - startPoint.y)
                )
                let secondControlPoint = NSPoint(
                    x: midpoint.x + 2.0 / 3.0 * (currentPoint.x - midpoint.x),
                    y: midpoint.y + 2.0 / 3.0 * (currentPoint.y - midpoint.y)
                )
                path.curve(
                    to: midpoint,
                    controlPoint1: firstControlPoint,
                    controlPoint2: secondControlPoint
                )
            }

            if index == points.count - 2 {
                path.line(to: nextPoint)
            }
        }

        return path
    }

    func points(for values: [Double], in rect: NSRect) -> [NSPoint] {
        if values.count == 1, let value = values.first {
            let y = rect.minY + rect.height * CGFloat(value)
            return [NSPoint(x: rect.minX, y: y), NSPoint(x: rect.maxX, y: y)]
        }

        return values.enumerated().map { index, value in
            let progress = CGFloat(index) / CGFloat(values.count - 1)
            return NSPoint(
                x: rect.minX + rect.width * progress,
                y: rect.minY + rect.height * CGFloat(value)
            )
        }
    }

    static func normalizedValues(
        _ values: [Double],
        role: MenuBarStatusSegment.GraphSeries.Role,
        relativePeak: Double
    ) -> [Double] {
        switch role {
        case .status:
            return values.map { $0.clamped(to: 0...1) }
        case .received, .sent:
            guard relativePeak > 0 else {
                return values.map { _ in 0 }
            }
            return values.map { ($0 / relativePeak).clamped(to: 0...1) }
        }
    }

    static func color(
        for role: MenuBarStatusSegment.GraphSeries.Role,
        statusColor: NSColor
    ) -> NSColor {
        switch role {
        case .status:
            return statusColor
        case .received:
            return .systemTeal
        case .sent:
            return .systemOrange
        }
    }
}
