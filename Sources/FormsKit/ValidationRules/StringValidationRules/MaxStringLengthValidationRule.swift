public struct MaxStringLengthValidationRule: StringValidationRule {
    let maxLength: Int
    let message: String

    init(_ maxLength: Int, _ message: String? = nil) {
        self.maxLength = maxLength
        self.message = message ?? "Must be no more than \(maxLength) characters"
    }

    public func validate(value: String) -> String? {
        value.count > maxLength ? message : nil
    }
}

public extension ValidationRule where Self == MaxStringLengthValidationRule {
    static func maxLength(_ length: Int, message: String? = nil) -> MaxStringLengthValidationRule {
        MaxStringLengthValidationRule(length, message)
    }
}
