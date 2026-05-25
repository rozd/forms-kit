public protocol SubmittableForm {
    associatedtype Output

    @MainActor
    func submit() async throws -> Output
}
