public enum ValidationError: Error {
    case misconfigured(message: String)
    case invalid(errors: [String: [String]])
}
