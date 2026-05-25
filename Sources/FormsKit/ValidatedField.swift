public struct ValidatedField<Form> {
    public let keyPath: PartialKeyPath<Form>

    let validate: (inout Form) -> Bool
    let markAsInvalid: (inout Form, [String]) -> Void
    let isDirty: (Form) -> Bool
    let isValid: (Form) -> Bool
    let name: (Form) -> String?
    let errors: (Form) -> [String]?

    public init<V: Equatable>(
        _ keyPath: KeyPath<Form, V>,
        wrappedBy wrapperKeyPath: WritableKeyPath<Form, Validated<V>>,
    ) {
        self.keyPath = keyPath
        self.validate = { $0[keyPath: wrapperKeyPath].validate() }
        self.markAsInvalid = { $0[keyPath: wrapperKeyPath].markAsInvalid(messages: $1) }
        self.isDirty = { $0[keyPath: wrapperKeyPath].isDirty }
        self.isValid = { $0[keyPath: wrapperKeyPath].isValid }
        self.name = { $0[keyPath: wrapperKeyPath].name }
        self.errors = { $0[keyPath: wrapperKeyPath].errors }
    }
}
