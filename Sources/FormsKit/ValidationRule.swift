public protocol ValidationRule<Value> {
    associatedtype Value
    func validate(value: Value) -> String?
}
