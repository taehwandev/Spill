import SwiftUI

struct SpillBrandIconView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            // The drop is narrower than it is tall (see WaterDropletOutline.aspectRatio) —
            // sizing its frame from availableHeight, not from the full square side, keeps
            // that true proportion instead of stretching it out to fill a square slot.
            let availableHeight = side * (1 - 0.24)
            let availableWidth = availableHeight * WaterDropletOutline.aspectRatio

            WaterDropletShape()
                .fill(Color(red: 0.0863, green: 0.7451, blue: 0.5451)) // #16BE8B — spill_waterdrop_teal_final.svg's key color
                .frame(width: availableWidth, height: availableHeight)
                .frame(width: side, height: side)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
