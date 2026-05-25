import Testing
@testable import FormsKit

// MARK: - Test forms

/// A simple two-field form mirroring the README's signup example.
private struct SignupForm: ValidatableForm {
    @Validated(name: "email", .isNotEmpty(message: "Required"), .email(message: "Invalid email"))
    var email: String = ""

    @Validated(name: "password", .minLength(8, message: "At least 8"))
    var password: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.email, wrappedBy: \._email),
         .init(\.password, wrappedBy: \._password)]
    }
}

/// A form with a field that intentionally omits its `name:` to confirm the protocol skips
/// nameless fields from `validationErrors`.
private struct AnonymousFieldForm: ValidatableForm {
    @Validated(name: nil, .isNotEmpty(message: "Required"))
    var anonymous: String = ""

    @Validated(name: "named", .isNotEmpty(message: "Required"))
    var named: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.anonymous, wrappedBy: \._anonymous),
         .init(\.named, wrappedBy: \._named)]
    }
}

/// A form with zero validatable fields — should trivially be valid and yield no errors.
private struct EmptyForm: ValidatableForm {
    var validatedFields: [ValidatedField<Self>] { [] }
}

/// Single-field form using the documented call-site shape:
/// `.init(\.field, wrappedBy: \._field)`.
/// Exercises the README's signup-style usage with a single-element array literal,
/// contextual key paths, and the value-then-wrapper init shape.
private struct SingleFieldForm: ValidatableForm {
    @Validated(name: "name", .isNotEmpty(message: "Required"))
    var name: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.name, wrappedBy: \._name)]
    }
}

// MARK: - Tests

@Suite("ValidatableForm.isValid")
struct ValidatableFormIsValidTests {

    @Test("Fresh form whose fields are .idle is NOT considered valid")
    func freshFormIsNotValid() {
        // None of the fields have been validated yet, so isValid (which checks per-field .valid)
        // should be false. This matches the README convention: isValid means "all fields have
        // passed their rules", not merely "no errors reported yet".
        let form = SignupForm()
        #expect(form.isValid == false)
    }

    @Test("Form becomes valid only when every field is .valid")
    func validWhenAllFieldsAreValid() {
        var form = SignupForm()
        form.email = "user@example.com"
        form.password = "12345678"
        // Mutation alone leaves fields in .editing; we need an explicit validate() pass.
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == true)
    }

    @Test("Form is invalid if any single field fails")
    func invalidWhenAnyFieldFails() {
        var form = SignupForm()
        form.email = "user@example.com"   // valid
        form.password = "short"            // invalid (<8)
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == false)
    }

    @Test("Empty validatedFields array means the form is trivially valid")
    func emptyValidatedFieldsIsValid() {
        let form = EmptyForm()
        #expect(form.isValid == true)
    }

    @Test("Single-field form using the `.init(\\.field, wrappedBy: \\._field)` shape works end-to-end")
    func singleFieldFormDocumentedSyntax() {
        var form = SingleFieldForm()
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == false)
        form.name = "John"
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == true)
    }
}

@Suite("ValidatableForm.validationErrors")
struct ValidatableFormValidationErrorsTests {

    @Test("Returns errors keyed by Validated.name for each invalid field")
    func errorsKeyedByName() {
        var form = SignupForm()
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        let errors = form.validationErrors
        // email is empty → fails isNotEmpty (email rule allows empty so doesn't fire)
        #expect(errors["email"] == ["Required"])
        // password is empty → fails minLength(8)
        #expect(errors["password"] == ["At least 8"])
    }

    @Test("Valid fields are omitted from the errors map")
    func validFieldsAreOmitted() {
        var form = SignupForm()
        form.email = "user@example.com"
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        let errors = form.validationErrors
        #expect(errors["email"] == nil)
        #expect(errors["password"] != nil)
    }

    @Test("Fields with no `name:` are excluded from validationErrors")
    func unnamedFieldsExcluded() {
        var form = AnonymousFieldForm()
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        let errors = form.validationErrors
        // Both fields are invalid, but only the named one reports.
        #expect(errors.keys.contains("named"))
        #expect(errors.count == 1)
    }

    @Test("Returns empty map when no fields are invalid")
    func emptyWhenAllPass() {
        var form = SignupForm()
        form.email = "ok@ok.io"
        form.password = "12345678"
        for accessor in form.validatedFields {
            let _ = accessor.validate(&form)
        }
        #expect(form.validationErrors.isEmpty)
    }
}
