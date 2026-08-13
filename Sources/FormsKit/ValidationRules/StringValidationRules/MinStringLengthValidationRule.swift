// SKIP @nobridge
public struct MinStringLengthValidationRule: StringValidationRule {
    let minLength: Int
    let message: String

    init(_ minLength: Int, _ message: String? = nil) {
        self.minLength = minLength
        self.message = message ?? "Must be at least \(minLength) characters"
    }

    public func validate(value: String) -> String? {
        value.count < minLength ? message : nil
    }
}

// Kotlin companion objects cannot express static members added via
// generically-constrained extensions; these factories are Swift-only sugar.
// SKIP @nobridge
public extension ValidationRule where Self == MinStringLengthValidationRule {
    static func minLength(_ length: Int, message: String? = nil) -> MinStringLengthValidationRule {
        MinStringLengthValidationRule(length, message)
    }
}
