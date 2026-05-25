import Testing
@testable import FormsKit

// MARK: - Test fixture

private struct AccessorForm: ValidatableForm {
    @Validated(name: "value", .isNotEmpty(message: "required"))
    var value: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.value, wrappedBy: \._value)]
    }
}

// MARK: - Tests

@Suite("ValidatedField closures")
struct ValidatedFieldClosureTests {

    @Test("name() returns the wrapper's `name`")
    func nameAccessor() {
        let form = AccessorForm()
        let accessor = form.validatedFields[0]
        #expect(accessor.name(form) == "value")
    }

    @Test("keyPath is the value key path of the wrapped field")
    func keyPathAccessor() {
        let form = AccessorForm()
        let accessor = form.validatedFields[0]
        // `\Form.fieldName` (the public value key path) is what consumers write
        // in view code. The accessor stores this same key path so `controller.focus`
        // can be compared against it directly.
        let valueKP: PartialKeyPath<AccessorForm> = \AccessorForm.value
        #expect(accessor.keyPath == valueKP)
    }

    @Test("isDirty() reflects the wrapped field's dirtiness")
    func isDirtyAccessor() {
        var form = AccessorForm()
        let accessor = form.validatedFields[0]
        #expect(accessor.isDirty(form) == false)
        form.value = "x"
        #expect(accessor.isDirty(form) == true)
    }

    @Test("isValid()/errors() reflect validation result")
    func isValidAndErrorsAccessor() {
        var form = AccessorForm()
        let accessor = form.validatedFields[0]

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
        let accessor = form.validatedFields[0]
        let result1 = accessor.validate(&form)
        #expect(result1 == false)
        form.value = "ok"
        let result2 = accessor.validate(&form)
        #expect(result2 == true)
    }

    @Test("markAsInvalid() sets state to .invalid with given messages")
    func markAsInvalidAccessor() {
        var form = AccessorForm()
        let accessor = form.validatedFields[0]
        accessor.markAsInvalid(&form, ["server"])
        #expect(accessor.errors(form) == ["server"])
    }
}

// MARK: - ValidatedField init shape

/// Form with two fields whose value and wrapper key paths must be wired
/// independently per accessor. Locks in the `.init(_:wrappedBy:)` shape
/// — value key path is positional, wrapper key path is labelled `wrappedBy:`.
private struct TwoFieldForm: ValidatableForm {
    @Validated(name: "alpha", .isNotEmpty(message: "α"))
    var alpha: String = ""

    @Validated(name: "beta", .isNotEmpty(message: "β"))
    var beta: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.alpha, wrappedBy: \._alpha),
         .init(\.beta,  wrappedBy: \._beta)]
    }
}

@Suite("ValidatedField init wiring")
struct ValidatedFieldInitTests {

    @Test("Each accessor's keyPath equals the value key path it was constructed with")
    func keyPathMatchesValuePath() {
        let form = TwoFieldForm()
        let alphaKP: PartialKeyPath<TwoFieldForm> = \TwoFieldForm.alpha
        let betaKP:  PartialKeyPath<TwoFieldForm> = \TwoFieldForm.beta
        #expect(form.validatedFields[0].keyPath == alphaKP)
        #expect(form.validatedFields[1].keyPath == betaKP)
    }

    @Test("Each accessor's closures read from its own wrapper (no cross-talk)")
    func closuresReadOwnWrapper() {
        var form = TwoFieldForm()
        // Mark only alpha invalid via its accessor.
        let alphaAccessor = form.validatedFields[0]
        let betaAccessor  = form.validatedFields[1]
        alphaAccessor.markAsInvalid(&form, ["alpha-broke"])

        #expect(alphaAccessor.errors(form) == ["alpha-broke"])
        #expect(betaAccessor.errors(form) == nil)
        #expect(alphaAccessor.name(form) == "alpha")
        #expect(betaAccessor.name(form) == "beta")
    }
}

// MARK: - PopulatableForm

private struct EditableForm: ValidatableForm, PopulatableForm {

    struct Source {
        let email: String
        let password: String
    }

    @Validated(name: "email", .isNotEmpty(message: "required"))
    var email: String = ""

    @Validated(name: "password", .minLength(8, message: "min"))
    var password: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.email, wrappedBy: \._email),
         .init(\.password, wrappedBy: \._password)]
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
        for accessor in form.validatedFields {
            #expect(accessor.isDirty(form) == true)
        }
    }
}
