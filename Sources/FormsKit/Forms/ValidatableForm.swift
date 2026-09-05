public protocol ValidatableForm {
    var validatedFields: [ValidatedField<Self>] { get }
}

extension ValidatableForm {
    var isValid: Bool {
        for accessor in validatedFields {
            if !accessor.isValid(self) {
                return false
            }
        }
        return true
    }

    var validationErrors: [String: [String]] {
        var errors: [String: [String]] = [:]
        for accessor in validatedFields {
            if let messages = accessor.errors(self),
               let name = accessor.name(self) {
                errors[name] = messages
            }
        }
        return errors
    }
}
