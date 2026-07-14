import AppKit

@MainActor
final class MenuBarMetricSparklineView: NSView {
    struct RenderedSeries {
        let values: [Double]
        let color: NSColor
    }

    let series: [RenderedSeries]
    let kind: MenuBarStatusSegment.Kind

    var scaleFactor: CGFloat {
        return window?.backingScaleFactor ?? 2.0
    }

    init(series: [MenuBarStatusSegment.GraphSeries], kind: MenuBarStatusSegment.Kind, statusColor: NSColor) {
        self.kind = kind
        let finiteSeries = series.map { graphSeries in
            (
                role: graphSeries.role,
                values: graphSeries.values.filter(\.isFinite).map { max($0, 0) }
            )
        }
        let relativePeak = finiteSeries
            .filter { $0.role != .status }
            .flatMap { $0.values }
            .max() ?? 0

        self.series = finiteSeries.map {
            RenderedSeries(
                values: Self.normalizedValues(
                    $0.values,
                    role: $0.role,
                    relativePeak: relativePeak
                ),
                color: Self.color(for: $0.role, statusColor: statusColor)
            )
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        drawFrame()
        
        switch kind {
        case .cpu:
            drawCPUCores()
        case .network:
            drawNetworkWaves()
        default:
            drawMemoryWave()
        }
    }
}
