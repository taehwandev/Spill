enum TokenUsageValidationError: Error, Equatable {
    case notJSONObject
    case forbiddenFieldPresent([String])
    case unknownFieldPresent([String])
    case invalidRequiredField
}
