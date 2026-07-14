import SwiftUI

struct ClockAreaPreviewChart: View {
    let series: [[Double]]

    var body: some View {
        Canvas { context, size in
            let frameRect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            let framePath = Path(roundedRect: frameRect, cornerRadius: 3)
            context.fill(framePath, with: .color(Color.primary.opacity(0.07)))
            context.stroke(framePath, with: .color(Color.primary.opacity(0.18)), lineWidth: 0.7)

            var guidePath = Path()
            guidePath.move(to: CGPoint(x: frameRect.minX + 2, y: frameRect.midY))
            guidePath.addLine(to: CGPoint(x: frameRect.maxX - 2, y: frameRect.midY))
            context.stroke(guidePath, with: .color(Color.primary.opacity(0.15)), lineWidth: 0.5)

            for (index, values) in series.enumerated() where !values.isEmpty {
                let color: Color = series.count > 1
                    ? (index == 0 ? .teal : .orange)
                    : .primary
                let points = chartPoints(values: values, rect: frameRect.insetBy(dx: 2, dy: 2))
                guard let firstPoint = points.first, let lastPoint = points.last else { continue }

                var fillPath = Path()
                fillPath.move(to: CGPoint(x: firstPoint.x, y: frameRect.maxY - 2))
                fillPath.addLines(points)
                fillPath.addLine(to: CGPoint(x: lastPoint.x, y: frameRect.maxY - 2))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(color.opacity(0.13)))

                var linePath = Path()
                linePath.addLines(points)
                context.stroke(linePath, with: .color(color.opacity(0.9)), lineWidth: 1.1)
                context.fill(
                    Path(ellipseIn: CGRect(x: lastPoint.x - 1, y: lastPoint.y - 1, width: 2, height: 2)),
                    with: .color(color)
                )
            }
        }
        .frame(width: 36, height: 13)
    }

    private func chartPoints(values: [Double], rect: CGRect) -> [CGPoint] {
        if values.count == 1, let value = values.first {
            let y = rect.maxY - rect.height * CGFloat(value.clamped(to: 0...1))
            return [CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)]
        }

        return values.enumerated().map { index, value in
            let progress = CGFloat(index) / CGFloat(values.count - 1)
            return CGPoint(
                x: rect.minX + rect.width * progress,
                y: rect.maxY - rect.height * CGFloat(value.clamped(to: 0...1))
            )
        }
    }
}
