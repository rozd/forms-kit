import Foundation

// SKIP @nobridge
public struct RegularExpressionValidationRule: StringValidationRule {
    let pattern: String
    let message: String

    public func validate(value: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return regex?.firstMatch(in: value, range: range) != nil ? nil : message
    }
}

// Kotlin companion objects cannot express static members added via
// generically-constrained extensions; these factories are Swift-only sugar.
// SKIP @nobridge
public extension ValidationRule where Self == RegularExpressionValidationRule {
    static func pattern(_ pattern: String, message: String) -> RegularExpressionValidationRule {
        RegularExpressionValidationRule(pattern: pattern, message: message)
    }
}
