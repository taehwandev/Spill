import CoreGraphics

struct SpillGlancePlacement: Codable, Equatable {
    enum HorizontalAnchor: String, Codable {
        case leading
        case proportional
        case trailing
    }

    enum VerticalAnchor: String, Codable {
        case bottom
        case proportional
        case top
    }

    let displayID: String?
    let horizontalAnchor: HorizontalAnchor
    let verticalAnchor: VerticalAnchor
    let horizontalInset: Double
    let verticalInset: Double
    let normalizedX: Double
    let normalizedY: Double

    static func capture(
        frame: CGRect,
        display: SpillGlanceScreenDescriptor,
        snapDistance: CGFloat = SpillGlanceLayout.anchorSnapDistance
    ) -> SpillGlancePlacement {
        let visibleFrame = display.visibleFrame
        let constrainedFrame = SpillGlanceLayout.constrainedFrame(
            frame,
            visibleFrame: visibleFrame
        )
        let leadingInset = constrainedFrame.minX - visibleFrame.minX
        let trailingInset = visibleFrame.maxX - constrainedFrame.maxX
        let bottomInset = constrainedFrame.minY - visibleFrame.minY
        let topInset = visibleFrame.maxY - constrainedFrame.maxY

        let horizontalAnchor: HorizontalAnchor
        if leadingInset <= snapDistance {
            horizontalAnchor = .leading
        } else if trailingInset <= snapDistance {
            horizontalAnchor = .trailing
        } else {
            horizontalAnchor = .proportional
        }

        let verticalAnchor: VerticalAnchor
        if bottomInset <= snapDistance {
            verticalAnchor = .bottom
        } else if topInset <= snapDistance {
            verticalAnchor = .top
        } else {
            verticalAnchor = .proportional
        }

        let allowedX = SpillGlanceLayout.allowedOriginXRange(
            contentWidth: constrainedFrame.width,
            visibleFrame: visibleFrame
        )
        let allowedY = SpillGlanceLayout.allowedOriginYRange(
            contentHeight: constrainedFrame.height,
            visibleFrame: visibleFrame
        )

        return SpillGlancePlacement(
            displayID: display.id,
            horizontalAnchor: horizontalAnchor,
            verticalAnchor: verticalAnchor,
            horizontalInset: Double(max(0, horizontalAnchor == .trailing ? trailingInset : leadingInset)),
            verticalInset: Double(max(0, verticalAnchor == .top ? topInset : bottomInset)),
            normalizedX: normalizedPosition(constrainedFrame.minX, in: allowedX),
            normalizedY: normalizedPosition(constrainedFrame.minY, in: allowedY)
        )
    }

    func frame(
        contentSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let allowedX = SpillGlanceLayout.allowedOriginXRange(
            contentWidth: contentSize.width,
            visibleFrame: visibleFrame
        )
        let allowedY = SpillGlanceLayout.allowedOriginYRange(
            contentHeight: contentSize.height,
            visibleFrame: visibleFrame
        )

        let x: CGFloat
        switch horizontalAnchor {
        case .leading:
            x = visibleFrame.minX + CGFloat(max(0, horizontalInset))
        case .proportional:
            x = position(normalizedX, in: allowedX)
        case .trailing:
            x = visibleFrame.maxX - contentSize.width - CGFloat(max(0, horizontalInset))
        }

        let y: CGFloat
        switch verticalAnchor {
        case .bottom:
            y = visibleFrame.minY + CGFloat(max(0, verticalInset))
        case .proportional:
            y = position(normalizedY, in: allowedY)
        case .top:
            y = visibleFrame.maxY - contentSize.height - CGFloat(max(0, verticalInset))
        }

        return SpillGlanceLayout.constrainedFrame(
            CGRect(origin: CGPoint(x: x, y: y), size: contentSize),
            visibleFrame: visibleFrame
        )
    }
}

private extension SpillGlancePlacement {
    static func normalizedPosition(_ value: CGFloat, in range: ClosedRange<CGFloat>) -> Double {
        let distance = range.upperBound - range.lowerBound
        guard distance > 0 else {
            return 0.5
        }
        return Double(min(max((value - range.lowerBound) / distance, 0), 1))
    }

    func position(_ normalizedValue: Double, in range: ClosedRange<CGFloat>) -> CGFloat {
        let normalizedValue = min(max(normalizedValue, 0), 1)
        return range.lowerBound + ((range.upperBound - range.lowerBound) * CGFloat(normalizedValue))
    }
}
