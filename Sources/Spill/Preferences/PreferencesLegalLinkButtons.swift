import SwiftUI

struct PreferencesLegalLinkButtons: View {
    enum Style {
        case bordered
        case accent
    }

    let language: SpillAppLanguage
    let source: String
    let style: Style

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                buttons
            }

            VStack(alignment: .leading, spacing: 4) {
                buttons
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        ForEach(PreferencesLegalLink.allCases) { link in
            legalButton(link)
        }
    }

    @ViewBuilder
    private func legalButton(_ link: PreferencesLegalLink) -> some View {
        switch style {
        case .bordered:
            Button {
                link.open(source: source)
            } label: {
                Label(link.title(appLanguage: language), systemImage: link.symbolName)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: 12, weight: .semibold))
        case .accent:
            Button {
                link.open(source: source)
            } label: {
                Label(link.title(appLanguage: language), systemImage: link.symbolName)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.teal)
        }
    }
}
