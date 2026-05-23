import Testing
@testable import FormsKit

// MARK: - Test fixtures

/// A form whose submit() either returns a value, throws a generic error,
/// or throws `ValidationError.invalid(errors:)` based on configuration.
private struct TestForm: ValidatableForm, SubmittableForm {

    enum Outcome {
        case success(String)
        case generic(Error)
        case serverFieldErrors([String: [String]])
    }

    @Validate(name: "email", .isNotEmpty(message: "Required"), .email(message: "Invalid email"))
    var email: String = ""

    @Validate(name: "password", .minLength(8, message: "At least 8"))
    var password: String = ""

    var outcome: Outcome = .success("ok")

    var validates: [ValidateAccessor<Self>] {
        [.init(\._email), .init(\._password)]
    }

    @MainActor
    func submit() async throws -> String {
        switch outcome {
        case .success(let value):
            return value
        case .generic(let error):
            throw error
        case .serverFieldErrors(let map):
            throw ValidationError.invalid(errors: map)
        }
    }
}

private struct DummyError: Error, Equatable {
    let id: Int
}

// MARK: - Tests

@MainActor
@Suite("FormController initial state")
struct FormControllerInitialStateTests {

    @Test("Controller starts in .initial state with the form wired in")
    func startsInitial() {
        let controller = FormController(form: TestForm())
        if case .initial = controller.state {} else {
            Issue.record("expected .initial")
        }
        #expect(controller.isLoading == false)
    }

    @Test("isDirty is false when no field has been edited")
    func notDirtyByDefault() {
        let controller = FormController(form: TestForm())
        #expect(controller.isDirty == false)
    }

    @Test("isValid reflects the underlying form's validity")
    func isValidPassthrough() {
        let controller = FormController(form: TestForm())
        // None of the fields have been validated — they're all .idle, so not .valid.
        #expect(controller.isValid == false)
    }
}

@MainActor
@Suite("FormController.validate()")
struct FormControllerValidateTests {

    @Test("validate() runs every field's rules and marks the form invalid if any fail")
    func validateRunsAllRules() {
        let controller = FormController(form: TestForm())
        controller.validate()
        #expect(controller.isValid == false)
        #expect(controller.form.validationErrors["email"] == ["Required"])
        #expect(controller.form.validationErrors["password"] == ["At least 8"])
    }

    @Test("validate() yields valid form when every field passes")
    func validateOnGoodInput() {
        let controller = FormController(form: TestForm())
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        controller.validate()
        #expect(controller.isValid == true)
        #expect(controller.form.validationErrors.isEmpty)
    }

    @Test("isDirty becomes true after the user edits any field")
    func isDirtyAfterEdit() {
        let controller = FormController(form: TestForm())
        controller.form.email = "x"
        #expect(controller.isDirty == true)
    }
}

@MainActor
@Suite("FormController.submit()")
struct FormControllerSubmitTests {

    @Test("submit() with invalid form throws ValidationError.invalid and does NOT enter .loading")
    func submitInvalidThrowsImmediately() async {
        let controller = FormController(form: TestForm())
        // Form is empty — invalid.
        await #expect(throws: ValidationError.self) {
            try await controller.submit()
        }
        // State remains .initial (per spec, validation gate runs BEFORE the .loading transition)
        if case .initial = controller.state {} else {
            Issue.record("expected .initial — submit must not flip to .loading when validation fails")
        }
        #expect(controller.isLoading == false)
    }

    @Test("submit() on a valid form transitions .initial → .loading → .success and returns the output")
    func submitSuccessFlow() async throws {
        let controller = FormController(form: TestForm())
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        controller.form.outcome = .success("hello")

        let result = try await controller.submit()
        #expect(result == "hello")
        if case .success = controller.state {} else {
            Issue.record("expected .success")
        }
        #expect(controller.isLoading == false)
    }

    @Test("submit() rethrows generic errors and sets state to .failure(error)")
    func submitGenericErrorFlow() async {
        let controller = FormController(form: TestForm())
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        controller.form.outcome = .generic(DummyError(id: 7))

        await #expect(throws: DummyError.self) {
            try await controller.submit()
        }
        guard case .failure(let error) = controller.state else {
            Issue.record("expected .failure(_)")
            return
        }
        #expect((error as? DummyError) == DummyError(id: 7))
    }

    @Test("Server-side ValidationError.invalid(errors:) is mapped back onto matching @Validate fields by name")
    func serverErrorRemap() async {
        let controller = FormController(form: TestForm())
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        controller.form.outcome = .serverFieldErrors([
            "email": ["Already taken"],
            "password": ["Weak password"],
        ])

        await #expect(throws: ValidationError.self) {
            try await controller.submit()
        }

        // After the throw, the matching fields should have been marked .invalid with the server messages.
        // Drive through the accessor API to verify (matches how the controller does it internally).
        var snapshot = controller.form
        let emailAccessor = snapshot.validates[0]
        let passwordAccessor = snapshot.validates[1]
        #expect(emailAccessor.errors(snapshot) == ["Already taken"])
        #expect(passwordAccessor.errors(snapshot) == ["Weak password"])
        _ = snapshot // silence warning
    }

    @Test("isLoading is true while submit() is suspended on its inner await")
    func isLoadingDuringSubmit() async {
        // A form whose submit() awaits a continuation we hold, so we can observe
        // the controller while it's parked in `.loading`.
        @MainActor
        final class Gate {
            var resume: (@Sendable () -> Void)?
        }
        struct GatedForm: ValidatableForm, SubmittableForm {
            @Validate(name: "n", .isNotEmpty(message: "r"))
            var n: String = "x"
            var validates: [ValidateAccessor<Self>] { [.init(\._n)] }
            let gate: Gate

            @MainActor
            func submit() async throws -> String {
                await withCheckedContinuation { cont in
                    gate.resume = { cont.resume() }
                }
                return "done"
            }
        }

        let gate = Gate()
        let controller = FormController(form: GatedForm(gate: gate))
        let task = Task { try await controller.submit() }

        // Yield enough to let the controller transition to .loading and the form's submit()
        // park itself on the continuation.
        for _ in 0..<5 {
            await Task.yield()
        }
        #expect(controller.isLoading == true)

        // Resume the form's continuation so the controller can finish.
        gate.resume?()
        _ = await task.result
        #expect(controller.isLoading == false)
    }

    @Test("Server-side errors for unknown fields are silently dropped (no crash)")
    func serverErrorUnknownField() async {
        let controller = FormController(form: TestForm())
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        controller.form.outcome = .serverFieldErrors([
            "email": ["Bad"],
            "unknownField": ["does not exist"],
        ])

        await #expect(throws: ValidationError.self) {
            try await controller.submit()
        }
        // Email gets marked. Unknown is dropped without crash.
        var snapshot = controller.form
        let emailAccessor = snapshot.validates[0]
        #expect(emailAccessor.errors(snapshot) == ["Bad"])
        _ = snapshot
    }
}
