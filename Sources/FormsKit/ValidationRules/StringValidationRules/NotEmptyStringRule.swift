public struct NotEmptyStringRule: StringValidationRule {
    let message: String

    public func validate(value: String) -> String? {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        return nil
    }
}

public extension ValidationRule where Self == NotEmptyStringRule {
    static func isNotEmpty(message: String) -> NotEmptyStringRule {
        NotEmptyStringRule(message: message)
    }
}
