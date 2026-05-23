import Foundation

public struct EmailValidator: StringValidationRule {
    let message: String

    init(_ message: String = "Invalid email address") {
        self.message = message
    }

    public func validate(value: String) -> String? {
        guard !value.isEmpty else { return nil } // Use RequiredValidator for empty check
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return regex?.firstMatch(in: value, range: range) != nil ? nil : message
    }
}

public extension ValidationRule where Self == EmailValidator {
    static func email(message: String = "Invalid email address") -> EmailValidator {
        EmailValidator(message)
    }
}
