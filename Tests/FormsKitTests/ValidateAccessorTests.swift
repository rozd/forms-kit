import Testing
@testable import FormsKit

// MARK: - Test fixture

private struct AccessorForm: ValidatableForm {
    @Validate(name: "value", .isNotEmpty(message: "required"))
    var value: String = ""

    var validates: [ValidateAccessor<Self>] { [.init(\._value)] }
}

// MARK: - Tests

@Suite("ValidateAccessor closures")
struct ValidateAccessorTests {

    @Test("name() returns the wrapper's `name`")
    func nameAccessor() {
        let form = AccessorForm()
        let accessor = form.validates[0]
        #expect(accessor.name(form) == "value")
    }

    @Test("isDirty() reflects the wrapped field's dirtiness")
    func isDirtyAccessor() {
        var form = AccessorForm()
        let accessor = form.validates[0]
        #expect(accessor.isDirty(form) == false)
        form.value = "x"
        #expect(accessor.isDirty(form) == true)
    }

    @Test("isValid()/errors() reflect validation result")
    func isValidAndErrorsAccessor() {
        var form = AccessorForm()
        let accessor = form.validates[0]

        // Pre-validation: not valid, no error messages reported.
        #expect(accessor.isValid(form) == false)
        #expect(accessor.errors(form) == nil)

        // Trigger validation on an empty string — invalid.
        _ = accessor.validate(&form)
        #expect(accessor.isValid(form) == false)
        #expect(accessor.errors(form) == ["required"])

        // Fix the value and re-validate via accessor — valid.
        form.value = "ok"
        // The wrapper auto-revalidates once invalid, so accessor.isValid should already be true.
        #expect(accessor.isValid(form) == true)
        #expect(accessor.errors(form) == nil)
    }

    @Test("validate() returns the bool from the underlying wrapper")
    func validateReturnValue() {
        var form = AccessorForm()
        let accessor = form.validates[0]
        let result1 = accessor.validate(&form)
        #expect(result1 == false)
        form.value = "ok"
        let result2 = accessor.validate(&form)
        #expect(result2 == true)
    }

    @Test("markAsInvalid() sets state to .invalid with given messages")
    func markAsInvalidAccessor() {
        var form = AccessorForm()
        let accessor = form.validates[0]
        accessor.markAsInvalid(&form, ["server"])
        #expect(accessor.errors(form) == ["server"])
    }
}

// MARK: - PopulatableForm

private struct EditableForm: ValidatableForm, PopulatableForm {

    struct Source {
        let email: String
        let password: String
    }

    @Validate(name: "email", .isNotEmpty(message: "required"))
    var email: String = ""

    @Validate(name: "password", .minLength(8, message: "min"))
    var password: String = ""

    var validates: [ValidateAccessor<Self>] {
        [.init(\._email), .init(\._password)]
    }

    @MainActor
    mutating func populate(from data: Source) {
        email = data.email
        password = data.password
    }
}

@MainActor
@Suite("PopulatableForm.populate(from:)")
struct PopulatableFormTests {

    @Test("populate(from:) hydrates wrapped fields' wrappedValues")
    func populateSetsValues() {
        var form = EditableForm()
        form.populate(from: .init(email: "u@e.io", password: "12345678"))
        #expect(form.email == "u@e.io")
        #expect(form.password == "12345678")
    }

    @Test("Populated form still has all fields in .editing (not validated until controller asks)")
    func populateLeavesFieldsEditing() {
        var form = EditableForm()
        form.populate(from: .init(email: "u@e.io", password: "12345678"))
        // The fields were edited via mutation; .onChange semantics leave them in .editing
        // (dirty but not yet validated). Controller validate() is required before .isValid is true.
        #expect(form.isValid == false)
        for accessor in form.validates {
            #expect(accessor.isDirty(form) == true)
        }
    }
}
