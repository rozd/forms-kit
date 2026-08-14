// SKIP @nobridge
public struct NotEmptyStringRule: StringValidationRule {
    let message: String

    public func validate(value: String) -> String? {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        return nil
    }
}

// Kotlin companion objects cannot express static members added via
// generically-constrained extensions; these factories are Swift-only sugar.
// SKIP @nobridge
public extension ValidationRule where Self == NotEmptyStringRule {
    static func isNotEmpty(message: String) -> NotEmptyStringRule {
        NotEmptyStringRule(message: message)
    }
}
