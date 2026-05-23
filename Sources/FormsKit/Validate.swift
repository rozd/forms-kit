@propertyWrapper
public struct Validate<T: Equatable> {

    public enum State {
        case idle
        case editing
        case valid
        case invalid(messages: [String])
    }

    public enum Mode {
        case always
        case onChange
        case onSubmit
    }

    private var value: T
    private let rules: [any ValidationRule<T>]

    let name: String?

    private(set) var state: State = .idle

    private(set) var mode: Mode

    public var wrappedValue: T {
        get { value }
        set {
            guard newValue != value else {
                return
            }
            value = newValue
            if state.isValid || state.isInvalid {
                validate()
            } else {
                state = .editing
            }
        }
    }

    public var projectedValue: State {
        state
    }

    public init(
        wrappedValue: T,
        name: String? = nil,
        mode: Mode = .onChange,
        _ rules: any ValidationRule<T>...,
    ) {
        self.value = wrappedValue
        self.rules = rules
        self.name = name
        self.mode = mode
        if mode == .always {
            validate()
        }
    }

    public init(
        name: String? = nil,
        mode: Mode = .onChange,
        _ rules: any ValidationRule<T>...
    ) where T: ExpressibleByNilLiteral {
        self.value = nil
        self.rules = rules
        self.name = name
        self.mode = mode
        if mode == .always {
          validate()
        }
    }

}

// MARK: Validation

extension Validate {

    @discardableResult
    mutating func validate() -> Bool {
        var errors: [String] = []
        for rule in rules {
            if let message = rule.validate(value: value) {
                errors.append(message)
            }
        }
        if errors.isEmpty {
            state = .valid
            return true
        } else {
            state = .invalid(messages: errors)
            return false
        }
    }

}

// MARK: Marking Validation State

extension Validate {

    mutating func markAsInvalid(messages: [String]) {
        state = .invalid(messages: messages)
    }
}

// MARK: Validation State Shortcuts

extension Validate {

    var isDirty: Bool {
        state.isDirty
    }

    var isValid: Bool {
        state.isValid
    }

    var isInvalid: Bool {
        state.isInvalid
    }

    var errors: [String]? {
        switch state {
        case .invalid(let messages):
            return messages
        default:
            return nil
        }
    }
}


// MARK: Validation State Extension

extension Validate.State {

    var isDirty: Bool {
        switch self {
        case .idle:
            return false
        default:
            return true
        }
    }

    var isValid: Bool {
        switch self {
        case .valid:
            return true
        default:
            return false
        }
    }

    var isInvalid: Bool {
        switch self {
        case .invalid(_):
            return true
        default:
            return false
        }
    }
}
