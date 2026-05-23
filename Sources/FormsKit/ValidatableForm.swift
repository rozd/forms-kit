public protocol ValidatableForm {
    var validates: [ValidateAccessor<Self>] { get }
}

extension ValidatableForm {
    var isValid: Bool {
        for accessor in validates {
            if !accessor.isValid(self) {
                return false
            }
        }
        return true
    }

    var validationErrors: [String: [String]] {
        var errors: [String: [String]] = [:]
        for accessor in validates {
            if let messages = accessor.errors(self),
               let name = accessor.name(self) {
                errors[name] = messages
            }
        }
        return errors
    }
}
