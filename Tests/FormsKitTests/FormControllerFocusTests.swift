import Testing
@testable import FormsKit

// MARK: - Test fixture

private struct FocusForm: ValidatableForm, SubmittableForm {

    enum Outcome {
        case success(String)
        case serverFieldErrors([String: [String]])
    }

    @Validated(name: "email", .isNotEmpty(message: "Required"))
    var email: String = ""

    @Validated(name: "password", .minLength(8, message: "At least 8"))
    var password: String = ""

    var outcome: Outcome = .success("ok")

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.email, wrappedBy: \._email),
         .init(\.password, wrappedBy: \._password)]
    }

    @MainActor
    func submit() async throws -> String {
        switch outcome {
        case .success(let value):
            return value
        case .serverFieldErrors(let map):
            throw ValidationError.invalid(errors: map)
        }
    }
}

// MARK: - Tests

@MainActor
@Suite("FormController.focus storage")
struct FormControllerFocusStorageTests {

    @Test("focus defaults to nil")
    func defaultsToNil() {
        let controller = FormController(form: FocusForm())
        #expect(controller.focus == nil)
    }

    @Test("focus accepts a set key path and a clear")
    func setAndClear() {
        let controller = FormController(form: FocusForm())
        controller.focus = \FocusForm.email
        #expect(controller.focus == \FocusForm.email)
        controller.focus = nil
        #expect(controller.focus == nil)
    }
}

@MainActor
@Suite("FormController.focusFirstInvalidField()")
struct FormControllerFocusFirstInvalidTests {

    @Test("All-valid form: focus is left untouched")
    func allValidLeavesFocusAlone() {
        let controller = FormController(form: FocusForm())
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        controller.validate()

        // Pre-condition: form is valid.
        #expect(controller.isValid == true)

        // Park focus somewhere arbitrary and prove the call does not move it.
        controller.focus = \FocusForm.email
        controller.focusFirstInvalidField()
        #expect(controller.focus == \FocusForm.email)
    }

    @Test("Walks validatedFields in order and picks the first invalid")
    func walksInOrder() {
        let controller = FormController(form: FocusForm())
        // Email valid, password invalid.
        controller.form.email = "user@example.com"
        controller.form.password = "" // fails minLength(8)
        controller.validate()

        controller.focusFirstInvalidField()
        #expect(controller.focus == \FocusForm.password)
    }

    @Test("Multiple invalids: picks the first by validatedFields order")
    func multipleInvalidsPicksFirst() {
        let controller = FormController(form: FocusForm())
        // Both invalid by default (idle, never validated → not isValid).
        controller.validate()
        controller.focusFirstInvalidField()
        #expect(controller.focus == \FocusForm.email)
    }
}

@MainActor
@Suite("FormController.submit() auto-focus on failure")
struct FormControllerSubmitAutoFocusTests {

    @Test("Pre-flight invalid: submit throws AND sets focus to the first invalid")
    func preflightInvalidFocusesFirst() async {
        let controller = FormController(form: FocusForm())
        // Form is empty — invalid pre-flight.

        await #expect(throws: ValidationError.self) {
            try await controller.submit()
        }
        #expect(controller.focus == \FocusForm.email)
    }

    @Test("Server-side ValidationError focuses the first server-marked invalid field")
    func serverErrorFocusesFirstRemapped() async {
        let controller = FormController(form: FocusForm())
        // Form is valid client-side so we get past the pre-flight gate.
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        // Server reports password is wrong; email is fine.
        controller.form.outcome = .serverFieldErrors(["password": ["Weak"]])

        await #expect(throws: ValidationError.self) {
            try await controller.submit()
        }
        #expect(controller.focus == \FocusForm.password)
    }

    @Test("shouldFocusFirstInvalidFieldOnSubmit = false: pre-flight failure does not touch focus")
    func optOutPreflight() async {
        let controller = FormController(form: FocusForm())
        controller.shouldFocusFirstInvalidFieldOnSubmit = false

        await #expect(throws: ValidationError.self) {
            try await controller.submit()
        }
        #expect(controller.focus == nil)
    }

    @Test("shouldFocusFirstInvalidFieldOnSubmit = false: server-side failure does not touch focus")
    func optOutServerSide() async {
        let controller = FormController(form: FocusForm())
        controller.shouldFocusFirstInvalidFieldOnSubmit = false
        controller.form.email = "user@example.com"
        controller.form.password = "abcdefgh"
        controller.form.outcome = .serverFieldErrors(["password": ["Weak"]])

        await #expect(throws: ValidationError.self) {
            try await controller.submit()
        }
        #expect(controller.focus == nil)
    }
}
