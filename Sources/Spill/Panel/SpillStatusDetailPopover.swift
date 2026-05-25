import SwiftUI

struct SpillStatusDetailAction: Identifiable {
    let id: String
    let title: String
    let symbolName: String
    let help: String
    let completedTitle: String
    let completedSymbolName: String
    let perform: () -> Void

    init(
        id: String,
        title: String,
        symbolName: String,
        help: String,
        completedTitle: String = "Done",
        completedSymbolName: String = "checkmark",
        perform: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.help = help
        self.completedTitle = completedTitle
        self.completedSymbolName = completedSymbolName
        self.perform = perform
    }
}

struct SpillStatusDetailPopover: View {
    let title: String
    let symbolName: String
    let tint: Color
    let rows: [SpillStatusDetailRow]
    let actions: [SpillStatusDetailAction]
    let showsInMenuBar: Binding<Bool>?
    @State private var completedActionID: String?

    init(
        title: String,
        symbolName: String,
        tint: Color,
        rows: [SpillStatusDetailRow],
        actions: [SpillStatusDetailAction] = [],
        showsInMenuBar: Binding<Bool>?
    ) {
        self.title = title
        self.symbolName = symbolName
        self.tint = tint
        self.rows = rows
        self.actions = actions
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

            if !actions.isEmpty {
                Divider()

                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        let isCompleted = completedActionID == action.id

                        Button {
                            action.perform()
                            completedActionID = action.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                if completedActionID == action.id {
                                    completedActionID = nil
                                }
                            }
                        } label: {
                            Label(
                                isCompleted ? action.completedTitle : action.title,
                                systemImage: isCompleted ? action.completedSymbolName : action.symbolName
                            )
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(action.help)
                    }
                }
            }

            if let showsInMenuBar {
                Divider()

                Toggle(isOn: showsInMenuBar) {
                    Label("Show in menu bar", systemImage: "menubar.rectangle")
                        .font(.system(size: 11, weight: .medium))
                }
                .toggleStyle(.switch)
            }
        }
        .padding(12)
        .frame(width: 244)
    }
}
