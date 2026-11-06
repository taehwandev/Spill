import Combine
import Foundation

/// Delivers preference invalidation after @Published willSet and defaults persistence.
@MainActor
enum MenuBarAppearanceObservation {
    static func observe(
        settings: SpillSettings,
        onChange: @escaping (String) -> Void
    ) -> AnyCancellable {
        let changes = [
            change(settings.$menuBarStatusLayoutStyle, "menu_bar_status_layout_style"),
            change(settings.$menuBarMetricPresentationStyles, "menu_bar_metric_presentation_styles"),
            change(settings.$menuBarStatusCompactMode, "menu_bar_status_compact_mode"),
            change(settings.$menuBarStatusSplitGroups, "menu_bar_status_split_groups"),
            change(settings.$menuBarStatusPrecision, "menu_bar_status_precision"),
            change(settings.$menuBarStatusHighlightThreshold, "menu_bar_status_highlight_threshold"),
            change(settings.$menuBarTriggerIconStyle, "menu_bar_trigger_icon_style"),
            change(settings.$menuBarTokenDisplayMode, "menu_bar_token_display_mode"),
            change(settings.$useSpillAnimation, "use_spill_animation"),
            change(settings.$menuBarStatusFontSize, "menu_bar_status_font_size"),
            change(settings.$menuBarStatusTextBold, "menu_bar_status_text_bold")
        ]
        return Publishers.MergeMany(changes)
            .receive(on: RunLoop.main)
            .sink(receiveValue: onChange)
    }

    private static func change<Value>(
        _ publisher: Published<Value>.Publisher,
        _ name: String
    ) -> AnyPublisher<String, Never> {
        publisher.dropFirst().map { _ in name }.eraseToAnyPublisher()
    }
}
