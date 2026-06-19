import SwiftUI

struct TokenMeteringDashboardPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let infoTitle: String?
    let infoDetail: String?
    let minimumHeight: CGFloat?
    let content: Content

    init(
        title: String,
        subtitle: String,
        infoTitle: String? = nil,
        infoDetail: String? = nil,
        minimumHeight: CGFloat? = 260,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.infoTitle = infoTitle
        self.infoDetail = infoDetail
        self.minimumHeight = minimumHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let infoTitle, let infoDetail {
                    TokenMeteringInfoButton(title: infoTitle, detail: infoDetail)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .padding(16)
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
