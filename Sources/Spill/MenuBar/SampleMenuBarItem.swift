import Foundation

struct SampleMenuBarItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let symbolName: String

    static let samples: [SampleMenuBarItem] = [
        SampleMenuBarItem(title: "Messages", symbolName: "bubble.left.fill"),
        SampleMenuBarItem(title: "Sync", symbolName: "arrow.triangle.2.circlepath"),
        SampleMenuBarItem(title: "Calendar", symbolName: "calendar"),
        SampleMenuBarItem(title: "Notifications", symbolName: "bell.badge.fill"),
        SampleMenuBarItem(title: "Network", symbolName: "point.3.connected.trianglepath.dotted"),
        SampleMenuBarItem(title: "Security", symbolName: "lock.shield.fill")
    ]
}
