import Testing
@testable import FormsKit

// MARK: - isNotEmpty

@Suite("NotEmptyStringRule")
struct NotEmptyStringRuleTests {

    @Test("Returns nil for non-empty input")
    func nonEmpty() {
        let rule = NotEmptyStringRule(message: "required")
        #expect(rule.validate(value: "a") == nil)
    }

    @Test("Returns message for empty input")
    func empty() {
        let rule = NotEmptyStringRule(message: "required")
        #expect(rule.validate(value: "") == "required")
    }

    @Test("Whitespace-only string fails (rule trims before checking)")
    func whitespaceOnly() {
        // README: "isNotEmpty — non-empty after trimming whitespace"
        let rule = NotEmptyStringRule(message: "required")
        #expect(rule.validate(value: "   ") == "required")
        #expect(rule.validate(value: "\n\t ") == "required")
    }

    @Test("Padded value still passes")
    func paddedValuePasses() {
        let rule = NotEmptyStringRule(message: "required")
        #expect(rule.validate(value: " a ") == nil)
    }

    @Test("Static factory builds an isNotEmpty rule with the given message")
    func staticFactory() {
        let rule: NotEmptyStringRule = .isNotEmpty(message: "boom")
        #expect(rule.validate(value: "") == "boom")
        #expect(rule.validate(value: "ok") == nil)
    }
}

// MARK: - minLength

@Suite("MinStringLengthValidationRule")
struct MinStringLengthValidationRuleTests {

    @Test("Returns nil when value meets the minimum length")
    func meets() {
        let rule = MinStringLengthValidationRule(3)
        #expect(rule.validate(value: "abc") == nil)
        #expect(rule.validate(value: "abcd") == nil)
    }

    @Test("Returns message when value is shorter than minimum")
    func underflow() {
        let rule = MinStringLengthValidationRule(3, "too short")
        #expect(rule.validate(value: "ab") == "too short")
        #expect(rule.validate(value: "") == "too short")
    }

    @Test("Default message includes the configured minimum")
    func defaultMessage() {
        let rule = MinStringLengthValidationRule(5)
        let message = rule.validate(value: "a")
        #expect(message != nil)
        #expect(message?.contains("5") == true)
    }

    @Test("Static factory returns a MinStringLengthValidationRule")
    func staticFactory() {
        let rule: MinStringLengthValidationRule = .minLength(2, message: "min")
        #expect(rule.validate(value: "a") == "min")
        #expect(rule.validate(value: "ab") == nil)
    }
}

// MARK: - maxLength

@Suite("MaxStringLengthValidationRule")
struct MaxStringLengthValidationRuleTests {

    @Test("Returns nil when value is within the maximum")
    func within() {
        let rule = MaxStringLengthValidationRule(3)
        #expect(rule.validate(value: "abc") == nil)
        #expect(rule.validate(value: "") == nil)
    }

    @Test("Returns message when value is longer than maximum")
    func overflow() {
        let rule = MaxStringLengthValidationRule(3, "too long")
        #expect(rule.validate(value: "abcd") == "too long")
    }

    @Test("Default message includes the configured maximum")
    func defaultMessage() {
        let rule = MaxStringLengthValidationRule(7)
        let message = rule.validate(value: "abcdefgh")
        #expect(message != nil)
        #expect(message?.contains("7") == true)
    }

    @Test("Static factory returns a MaxStringLengthValidationRule")
    func staticFactory() {
        let rule: MaxStringLengthValidationRule = .maxLength(4, message: "max")
        #expect(rule.validate(value: "abcde") == "max")
        #expect(rule.validate(value: "abcd") == nil)
    }
}

// MARK: - pattern

@Suite("RegularExpressionValidationRule")
struct RegularExpressionValidationRuleTests {

    @Test("Matching value returns nil")
    func matching() {
        let rule = RegularExpressionValidationRule(pattern: "^[A-Z]+$", message: "uppercase only")
        #expect(rule.validate(value: "ABC") == nil)
    }

    @Test("Non-matching value returns the configured message")
    func nonMatching() {
        let rule = RegularExpressionValidationRule(pattern: "^[A-Z]+$", message: "uppercase only")
        #expect(rule.validate(value: "abc") == "uppercase only")
    }

    @Test("Pattern that finds a substring (no anchors) still matches")
    func substringMatch() {
        let rule = RegularExpressionValidationRule(pattern: #"[A-Z]"#, message: "needs uppercase")
        #expect(rule.validate(value: "passwordA") == nil)
        #expect(rule.validate(value: "password") == "needs uppercase")
    }

    @Test("Static factory builds the rule")
    func staticFactory() {
        let rule: RegularExpressionValidationRule = .pattern("^[0-9]+$", message: "digits only")
        #expect(rule.validate(value: "1234") == nil)
        #expect(rule.validate(value: "abc") == "digits only")
    }
}

// MARK: - email

@Suite("EmailValidator")
struct EmailValidatorTests {

    @Test("Accepts a well-formed email")
    func valid() {
        let rule = EmailValidator()
        #expect(rule.validate(value: "user@example.com") == nil)
        #expect(rule.validate(value: "first.last+tag@sub.example.co") == nil)
    }

    @Test("Rejects an obviously malformed email")
    func invalid() {
        let rule = EmailValidator("nope")
        #expect(rule.validate(value: "not-an-email") == "nope")
        #expect(rule.validate(value: "user@") == "nope")
        #expect(rule.validate(value: "@example.com") == "nope")
        #expect(rule.validate(value: "user@example") == "nope")
    }

    @Test("Empty input is allowed (use isNotEmpty for required)")
    func emptyAllowed() {
        // README: chain `.isNotEmpty(...)` for the required check.
        let rule = EmailValidator()
        #expect(rule.validate(value: "") == nil)
    }

    @Test("Default message is used when none provided")
    func defaultMessage() {
        let rule = EmailValidator()
        #expect(rule.validate(value: "x") == "Invalid email address")
    }

    @Test("Static factory builds an EmailValidator with the given message")
    func staticFactory() {
        let rule: EmailValidator = .email(message: "bad email")
        #expect(rule.validate(value: "bad") == "bad email")
        #expect(rule.validate(value: "ok@ok.io") == nil)
    }
}
