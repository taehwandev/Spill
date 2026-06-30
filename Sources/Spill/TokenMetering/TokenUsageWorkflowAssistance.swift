enum TokenUsageWorkflowAssistance {
    static func isAssisted(_ event: TokenUsageEvent) -> Bool {
        event.taskType != .uncategorized || event.stage != .summarize
    }
}
