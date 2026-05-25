import Testing
@testable import FormsKit

// MARK: - Tiny rule helpers used only in tests

/// A "true if" style rule that fails with the given message when `predicate` is false.
private struct AssertRule<V: Equatable>: ValidationRule {
    typealias Value = V
    let message: String
    let predicate: (V) -> Bool
    func validate(value: V) -> String? {
        predicate(value) ? nil : message
    }
}

/// Two failures so we can assert the wrapper aggregates messages from multiple rules.
private struct AlwaysFail<V: Equatable>: ValidationRule {
    typealias Value = V
    let message: String
    func validate(value: V) -> String? { message }
}

// MARK: - @Validated state machine

@Suite("Validated state machine")
struct ValidatedStateTests {

    @Test("Newly initialized field is .idle when mode is .onChange")
    func startsIdleOnChange() {
        var sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .onChange,
            AlwaysFail(message: "nope")
        )
        sut.wrappedValue = ""        // no-op equal mutation
        #expect(!sut.state.isDirty)
        #expect(!sut.state.isValid)
        #expect(!sut.state.isInvalid)
    }

    @Test("Newly initialized field is .idle when mode is .onSubmit")
    func startsIdleOnSubmit() {
        let sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .onSubmit,
            AlwaysFail(message: "nope")
        )
        #expect(!sut.state.isDirty)
        #expect(!sut.state.isValid)
        #expect(!sut.state.isInvalid)
    }

    @Test("mode .always validates at init time and reports invalid")
    func alwaysValidatesAtInit() {
        let sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .always,
            AlwaysFail(message: "bad")
        )
        #expect(sut.state.isInvalid)
        #expect(sut.errors == ["bad"])
    }

    @Test("mode .always with passing rule validates at init time and reports valid")
    func alwaysValidatesAtInitValid() {
        let sut = Validated<String>(
            wrappedValue: "hello",
            name: "x",
            mode: .always,
            AssertRule(message: "x") { !$0.isEmpty }
        )
        #expect(sut.state.isValid)
        #expect(sut.errors == nil)
    }

    @Test("Mutating wrappedValue to a different value transitions .idle to .editing")
    func mutationFromIdleGoesToEditing() {
        var sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .onChange,
            AlwaysFail(message: "bad")
        )
        sut.wrappedValue = "a"
        // .editing is "dirty" but neither .valid nor .invalid
        #expect(sut.state.isDirty)
        #expect(!sut.state.isValid)
        #expect(!sut.state.isInvalid)
    }

    @Test("Mutating wrappedValue to the SAME value does not change state")
    func equalMutationIsNoop() {
        var sut = Validated<String>(
            wrappedValue: "hello",
            name: "x",
            mode: .onChange,
            AlwaysFail(message: "bad")
        )
        sut.wrappedValue = "hello"
        #expect(!sut.state.isDirty)
    }

    @Test("Once invalid, each new value triggers re-validation on the new value (.onChange semantics)")
    func reValidatesAfterInvalid() {
        var sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .onChange,
            // Becomes invalid on empty, recovers when non-empty
            AssertRule(message: "required") { !$0.isEmpty }
        )

        // Trigger validation -> invalid
        sut.validate()
        #expect(sut.state.isInvalid)
        #expect(sut.errors == ["required"])

        // Keystroke that fixes it: must auto-revalidate to .valid
        sut.wrappedValue = "x"
        #expect(sut.state.isValid)

        // Keystroke that breaks it again: must auto-revalidate to .invalid
        sut.wrappedValue = ""
        #expect(sut.state.isInvalid)
        #expect(sut.errors == ["required"])
    }

    @Test("projectedValue exposes the current state")
    func projectedValueExposesState() {
        var sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .always,
            AlwaysFail(message: "boom")
        )
        // Whatever the state is, it must equal the projected value.
        if case .invalid(let messages) = sut.projectedValue {
            #expect(messages == ["boom"])
        } else {
            Issue.record("expected .invalid via projectedValue")
        }
        sut.wrappedValue = "anything-different"
        // After mutation while invalid, re-validation runs on the new value;
        // AlwaysFail still fails, so projectedValue should reflect .invalid.
        #expect(sut.projectedValue.isInvalid)
    }

    @Test("validate() aggregates messages from multiple failing rules in order")
    func aggregatesMessages() {
        var sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .onSubmit,
            AlwaysFail(message: "one"),
            AlwaysFail(message: "two")
        )
        let result = sut.validate()
        #expect(result == false)
        #expect(sut.errors == ["one", "two"])
    }

    @Test("validate() returns true and clears errors when all rules pass")
    func validReturnsTrueAndClears() {
        var sut = Validated<String>(
            wrappedValue: "ok",
            name: "x",
            mode: .onSubmit,
            AssertRule(message: "required") { !$0.isEmpty }
        )
        let result = sut.validate()
        #expect(result == true)
        #expect(sut.state.isValid)
        #expect(sut.errors == nil)
    }

    @Test("markAsInvalid sets the state to .invalid with supplied messages")
    func markAsInvalidApplies() {
        var sut = Validated<String>(
            wrappedValue: "ok",
            name: "x",
            mode: .onChange
        )
        sut.markAsInvalid(messages: ["server says no"])
        #expect(sut.state.isInvalid)
        #expect(sut.errors == ["server says no"])
    }

    @Test("Mutating after a server-marked .invalid re-runs local rules on the new value")
    func mutationAfterMarkAsInvalidRevalidates() {
        var sut = Validated<String>(
            wrappedValue: "ok",
            name: "x",
            mode: .onChange,
            AssertRule(message: "required") { !$0.isEmpty }
        )
        sut.markAsInvalid(messages: ["server says no"])
        // Editing should re-validate (local rules now pass since "ok!" is non-empty),
        // clearing the server message.
        sut.wrappedValue = "ok!"
        #expect(sut.state.isValid)
    }
}

// MARK: - @Validated init overloads & ExpressibleByNilLiteral

@Suite("Validated init overloads")
struct ValidatedInitTests {

    @Test("Optional initializer (no wrappedValue) defaults to nil")
    func optionalNilDefault() {
        let sut = Validated<String?>(
            name: "nickname",
            mode: .onChange
        )
        #expect(sut.wrappedValue == nil)
        #expect(sut.name == "nickname")
        #expect(!sut.state.isDirty)
    }

    @Test("Optional initializer respects mode .always and validates immediately")
    func optionalAlwaysValidates() {
        let sut = Validated<String?>(
            name: "nickname",
            mode: .always,
            AssertRule(message: "must be non-nil") { $0 != nil }
        )
        #expect(sut.state.isInvalid)
        #expect(sut.errors == ["must be non-nil"])
    }

    @Test("Non-optional initializer carries wrappedValue and name")
    func nonOptionalInitCarriesValues() {
        let sut = Validated<Int>(
            wrappedValue: 42,
            name: "age",
            mode: .onChange
        )
        #expect(sut.wrappedValue == 42)
        #expect(sut.name == "age")
    }

    @Test("Validated works for arbitrary Equatable value types, not just String")
    func nonStringValueTypes() {
        var sut = Validated<Int>(
            wrappedValue: 3,
            name: "n",
            mode: .onSubmit,
            AssertRule(message: "even") { $0 % 2 == 0 }
        )
        sut.validate()
        #expect(sut.state.isInvalid)
        sut.wrappedValue = 4
        // After a fix while .invalid the wrapper re-validates and lands on .valid.
        #expect(sut.state.isValid)
    }
}

// MARK: - Validated.State.isDirty / isValid / isInvalid

@Suite("Validated.State helpers")
struct ValidatedStateHelpersTests {

    @Test("isDirty is false only for .idle")
    func isDirtyMatrix() {
        #expect(Validated<String>.State.idle.isDirty == false)
        #expect(Validated<String>.State.editing.isDirty == true)
        #expect(Validated<String>.State.valid.isDirty == true)
        #expect(Validated<String>.State.invalid(messages: ["x"]).isDirty == true)
    }

    @Test("isValid is true only for .valid")
    func isValidMatrix() {
        #expect(Validated<String>.State.idle.isValid == false)
        #expect(Validated<String>.State.editing.isValid == false)
        #expect(Validated<String>.State.valid.isValid == true)
        #expect(Validated<String>.State.invalid(messages: ["x"]).isValid == false)
    }

    @Test("isInvalid is true only for .invalid")
    func isInvalidMatrix() {
        #expect(Validated<String>.State.idle.isInvalid == false)
        #expect(Validated<String>.State.editing.isInvalid == false)
        #expect(Validated<String>.State.valid.isInvalid == false)
        #expect(Validated<String>.State.invalid(messages: ["x"]).isInvalid == true)
    }

    @Test("Wrapper's `isInvalid` / `isValid` / `isDirty` shortcuts mirror its state")
    func wrapperShortcuts() {
        var sut = Validated<String>(
            wrappedValue: "",
            name: "x",
            mode: .onChange,
            AssertRule(message: "required") { !$0.isEmpty }
        )
        #expect(sut.isDirty == false)
        #expect(sut.isValid == false)
        #expect(sut.isInvalid == false)

        sut.validate()
        #expect(sut.isDirty == true)
        #expect(sut.isInvalid == true)
        #expect(sut.isValid == false)

        sut.wrappedValue = "ok"
        #expect(sut.isValid == true)
        #expect(sut.isInvalid == false)
    }
}
