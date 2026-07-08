import SwiftUI

struct SpillBrandSMarkView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            WordmarkSShape()
                .fill(Color(red: 0.51, green: 0.84, blue: 0.78))
                .padding(side * 0.12)
                .frame(width: side, height: side)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
