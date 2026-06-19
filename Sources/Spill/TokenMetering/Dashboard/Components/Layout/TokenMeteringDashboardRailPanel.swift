import SwiftUI

struct TokenMeteringDashboardRailPanel<Content: View>: View {
    let title: String
    let infoTitle: String?
    let infoDetail: String?
    let content: Content

    init(
        title: String,
        infoTitle: String? = nil,
        infoDetail: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.infoTitle = infoTitle
        self.infoDetail = infoDetail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let infoTitle, let infoDetail {
                    TokenMeteringInfoButton(title: infoTitle, detail: infoDetail)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }
}
