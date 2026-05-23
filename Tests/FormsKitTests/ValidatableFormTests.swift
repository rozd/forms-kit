import Testing
@testable import FormsKit

// MARK: - Test forms

/// A simple two-field form mirroring the README's signup example.
private struct SignupForm: ValidatableForm {
    @Validate(name: "email", .isNotEmpty(message: "Required"), .email(message: "Invalid email"))
    var email: String = ""

    @Validate(name: "password", .minLength(8, message: "At least 8"))
    var password: String = ""

    var validates: [ValidateAccessor<Self>] {
        [.init(\._email), .init(\._password)]
    }
}

/// A form with a field that intentionally omits its `name:` to confirm the protocol skips
/// nameless fields from `validationErrors`.
private struct AnonymousFieldForm: ValidatableForm {
    @Validate(name: nil, .isNotEmpty(message: "Required"))
    var anonymous: String = ""

    @Validate(name: "named", .isNotEmpty(message: "Required"))
    var named: String = ""

    var validates: [ValidateAccessor<Self>] {
        [.init(\._anonymous), .init(\._named)]
    }
}

/// A form with zero validatable fields — should trivially be valid and yield no errors.
private struct EmptyForm: ValidatableForm {
    var validates: [ValidateAccessor<Self>] { [] }
}

/// Single-field form using the documented CLAUDE.md syntax `[.init(\_name)]`.
/// This exercises the README's call-site shape (a single-element array literal with
/// the shorthand `.init` and contextual key path) which is the most common form usage.
private struct SingleFieldForm: ValidatableForm {
    @Validate(name: "name", .isNotEmpty(message: "Required"))
    var name: String = ""

    var validates: [ValidateAccessor<Self>] { [.init(\._name)] }
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
        for accessor in form.validates {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == true)
    }

    @Test("Form is invalid if any single field fails")
    func invalidWhenAnyFieldFails() {
        var form = SignupForm()
        form.email = "user@example.com"   // valid
        form.password = "short"            // invalid (<8)
        for accessor in form.validates {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == false)
    }

    @Test("Empty validates array means the form is trivially valid")
    func emptyValidatesIsValid() {
        let form = EmptyForm()
        #expect(form.isValid == true)
    }

    @Test("Single-field form using the documented `[.init(\\_field)]` syntax works end-to-end")
    func singleFieldFormDocumentedSyntax() {
        var form = SingleFieldForm()
        for accessor in form.validates {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == false)
        form.name = "John"
        for accessor in form.validates {
            let _ = accessor.validate(&form)
        }
        #expect(form.isValid == true)
    }
}

@Suite("ValidatableForm.validationErrors")
struct ValidatableFormValidationErrorsTests {

    @Test("Returns errors keyed by Validate.name for each invalid field")
    func errorsKeyedByName() {
        var form = SignupForm()
        for accessor in form.validates {
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
        for accessor in form.validates {
            let _ = accessor.validate(&form)
        }
        let errors = form.validationErrors
        #expect(errors["email"] == nil)
        #expect(errors["password"] != nil)
    }

    @Test("Fields with no `name:` are excluded from validationErrors")
    func unnamedFieldsExcluded() {
        var form = AnonymousFieldForm()
        for accessor in form.validates {
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
        for accessor in form.validates {
            let _ = accessor.validate(&form)
        }
        #expect(form.validationErrors.isEmpty)
    }
}
