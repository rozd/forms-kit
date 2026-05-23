public struct ValidateAccessor<Form> {
    let validate: (inout Form) -> Bool
    let markAsInvalid: (inout Form, [String]) -> Void
    let isDirty: (Form) -> Bool
    let isValid: (Form) -> Bool
    let name: (Form) -> String?
    let errors: (Form) -> [String]?

    public init<V: Equatable>(_ keyPath: WritableKeyPath<Form, Validate<V>>) {
        self.validate = { $0[keyPath: keyPath].validate() }
        self.markAsInvalid = { $0[keyPath: keyPath].markAsInvalid(messages: $1) }
        self.isDirty = { $0[keyPath: keyPath].isDirty }
        self.isValid = { $0[keyPath: keyPath].isValid }
        self.name = { $0[keyPath: keyPath].name }
        self.errors = { $0[keyPath: keyPath].errors }
    }
}
