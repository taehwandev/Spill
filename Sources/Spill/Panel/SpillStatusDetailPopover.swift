import SwiftUI

struct SpillStatusDetailPopover: View {
    let title: String
    let symbolName: String
    let tint: Color
    let rows: [SpillStatusDetailRow]
    let showsInMenuBar: Binding<Bool>?

    init(
        title: String,
        symbolName: String,
        tint: Color,
        rows: [SpillStatusDetailRow],
        showsInMenuBar: Binding<Bool>?
    ) {
        self.title = title
        self.symbolName = symbolName
        self.tint = tint
        self.rows = rows
        self.showsInMenuBar = showsInMenuBar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            } icon: {
                Image(systemName: symbolName)
                    .foregroundStyle(tint)
            }

            VStack(spacing: 6) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(row.value)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .font(.system(size: 11, weight: .medium))
                }
            }

            if let showsInMenuBar {
                Divider()

                Toggle(isOn: showsInMenuBar) {
                    Label(AppL10n.text(.showInMenuBar), systemImage: "menubar.rectangle")
                        .font(.system(size: 11, weight: .medium))
                }
                .toggleStyle(.switch)
            }
        }
        .padding(12)
        .frame(width: 244)
    }
}
