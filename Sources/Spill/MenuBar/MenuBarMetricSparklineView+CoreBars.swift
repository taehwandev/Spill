import AppKit

extension MenuBarMetricSparklineView {
    func drawFrame() {
        let frameRect = bounds
        let cornerRadius = frameRect.height / 2
        let framePath = NSBezierPath(roundedRect: frameRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        NSColor.labelColor.withAlphaComponent(0.04).setFill()
        framePath.fill()
    }

    func drawCPUCores() {
        guard let renderedSeries = series.first, !renderedSeries.values.isEmpty else { return }

        let drawableRect = bounds.insetBy(dx: 2.0, dy: 1.0)
        let scale = scaleFactor
        var coreValues = renderedSeries.values
        if coreValues.count > 12 {
            let chunkSize = Double(coreValues.count) / 12.0
            var grouped: [Double] = []
            for index in 0..<12 {
                let start = Int(Double(index) * chunkSize)
                let end = min(coreValues.count, Int(Double(index + 1) * chunkSize))
                let slice = coreValues[start..<end]
                let average = slice.isEmpty ? 0.0 : slice.reduce(0.0, +) / Double(slice.count)
                grouped.append(average)
            }
            coreValues = grouped
        }

        let coreCount = coreValues.count
        guard coreCount > 0 else { return }

        let spacing: CGFloat = 0.6
        let availableWidth = drawableRect.width
        let totalSpacing = CGFloat(coreCount - 1) * spacing
        let rawBarWidth = max(0.8, (availableWidth - totalSpacing) / CGFloat(coreCount))
        let barWidth = round(rawBarWidth * scale) / scale
        let totalWidth = CGFloat(coreCount) * barWidth + totalSpacing
        let startX = drawableRect.minX + (availableWidth - totalWidth) / 2

        for index in 0..<coreCount {
            let height = CGFloat(coreValues[index]) * drawableRect.height
            let barHeight = max(1, min(height, drawableRect.height))
            let rawBarX = startX + CGFloat(index) * (barWidth + spacing)
            let barX = round(rawBarX * scale) / scale
            let barRect = NSRect(
                x: barX,
                y: drawableRect.minY,
                width: barWidth,
                height: round(barHeight * scale) / scale
            )
            let barPath = NSBezierPath(
                roundedRect: barRect,
                xRadius: barWidth / 2,
                yRadius: barWidth / 2
            )

            let coreVal = coreValues[index]
            let baseColor: NSColor
            if coreVal >= 0.9 {
                baseColor = NSColor(red: 0.90, green: 0.38, blue: 0.38, alpha: 1.0)
            } else if coreVal >= 0.8 {
                baseColor = NSColor(red: 0.94, green: 0.60, blue: 0.38, alpha: 1.0)
            } else if coreVal >= 0.7 {
                baseColor = NSColor(red: 0.96, green: 0.79, blue: 0.42, alpha: 1.0)
            } else {
                baseColor = renderedSeries.color
            }

            let gradient = NSGradient(
                starting: baseColor.withAlphaComponent(0.20),
                ending: baseColor.withAlphaComponent(0.80)
            )
            gradient?.draw(in: barPath, angle: 90)
        }
    }
}
