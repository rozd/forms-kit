# FormsKit API cheat sheet

Compact reference. Loaded only when you need an exact signature.

## `@Validated<T: Equatable>` (property wrapper)

```swift
// With initial value
@Validated(name: String? = nil, mode: Mode = .onChange, _ rules: any ValidationRule<T>...)
init(wrappedValue: T, name:, mode:, _ rules:)

// For ExpressibleByNilLiteral (e.g., String?)
@Validated(name:, mode:, _ rules:)
init(name:, mode:, _ rules:) where T: ExpressibleByNilLiteral
```

- `Mode`: `.always` | `.onChange` (default) | `.onSubmit`
- Projected value (`$field`) is the current `Validated<T>.State`:
  - `.idle` — never edited
  - `.editing` — touched, not yet validated
  - `.valid`
  - `.invalid(messages: [String])`

## `ValidationRule` protocol

```swift
public protocol ValidationRule<Value> {
    associatedtype Value
    func validate(value: Value) -> String?  // nil = valid; String = error message
}
```

Built-in string rules (in `StringValidationRules/`):

| Factory | Rule struct |
|---|---|
| `.isNotEmpty(message:)` | `NotEmptyStringRule` |
| `.minLength(_:message:)` | `MinStringLengthValidationRule` |
| `.maxLength(_:message:)` | `MaxStringLengthValidationRule` |
| `.pattern(_:message:)` | `RegularExpressionValidationRule` |
| `.email(message:)` | `EmailValidator` |

## Form protocols

```swift
public protocol ValidatableForm {
    var validatedFields: [ValidatedField<Self>] { get }
}

public protocol SubmittableForm {
    associatedtype Output
    @MainActor func submit() async throws -> Output
}

public protocol PopulatableForm {
    associatedtype Data
    @MainActor mutating func populate(from data: Data)
}
```

`ValidatableForm` extensions provide:
- `isValid: Bool`
- `validationErrors: [String: [String]]` keyed by `Validated.name`

## `ValidatedField<Form>` (schema entry)

```swift
public init<V: Equatable>(
    _ keyPath: KeyPath<Form, V>,           // VALUE path — used for focus identity
    wrappedBy wrapperKeyPath: WritableKeyPath<Form, Validated<V>>  // WRAPPER path — drives validation
)
```

Both paths are required. The library cannot derive one from the other.

## `FormController<T>` (`@MainActor @Observable`)

```swift
public final class FormController<T> {
    public var form: T
    public var focus: PartialKeyPath<T>? = nil
    public var shouldFocusFirstInvalidFieldOnSubmit: Bool = true
    public init(form: T)
}

// Where T: ValidatableForm:
controller.isDirty
controller.isValid
controller.validate()
controller.focusFirstInvalidField()

// Where T: ValidatableForm & SubmittableForm:
controller.isLoading
try await controller.submit() -> T.Output
```

`submit()` flow:
1. Run `validate()`.
2. If invalid → optionally focus first invalid field → throw `ValidationError.invalid(errors:)`.
3. Set `state = .loading`.
4. Call `form.submit()`.
5. On success → `state = .success`.
6. On `ValidationError.invalid(errors:)` → remap per-field errors by `name:`, focus first invalid, rethrow.
7. On any other error → `state = .failure(error)`, rethrow.

## `ValidationError`

```swift
public enum ValidationError: Error {
    case misconfigured(message: String)
    case invalid(errors: [String: [String]])  // keyed by Validated.name
}
```

## View modifiers

```swift
// Inline error display below field
.formValidationError(for: Validated<T>.State,
                     alignment: HorizontalAlignment = .leading,
                     spacing: CGFloat? = 4)

// Cancel/Submit toolbar + discard-changes guard (needs NavigationStack ancestor)
.formToolbar(controller: FormController<T>,
             cancelTitle: String = "Cancel",
             submitTitle: String = "Submit",
             preventsAccidentalDismiss: Bool = true,
             onSubmit: @escaping () -> Void)

// Zero-ceremony focus binding (internal hidden @FocusState)
.focused(on: Binding<FormController<T>>, equals: KeyPath<T, V>)

// Shared @FocusState bridge (consumer declares the @FocusState)
.formBindFocus(_ focus: FocusState<PartialKeyPath<T>?>.Binding,
               on: FormController<T>)
```

## Source layout (for reference)

```
Sources/FormsKit/
├── Validated.swift
├── ValidatedField.swift
├── ValidationRule.swift
├── ValidationError.swift
├── FormController.swift
├── Forms/{ValidatableForm,SubmittableForm,PopulatableForm}.swift
├── ValidationRules/StringValidationRule.swift
├── ValidationRules/StringValidationRules/*.swift
└── ViewModifiers/{FormValidationErrorModifier,FormToolbarViewModifier,FocusedOnViewModifier,FormBindFocusViewModifier}.swift
```
