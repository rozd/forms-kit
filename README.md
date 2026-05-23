# FormsKit

A small, opinionated **SwiftUI form-validation library** built for modern Swift: `@Observable`, Swift 6 concurrency, zero dependencies.

```swift
struct CreatePlanForm: ValidatableForm, SubmittableForm {
    @Validate(name: "name", .isNotEmpty(message: "Required"), .minLength(3))
    var name: String = ""

    var validates: [ValidateAccessor<Self>] { [.init(\._name)] }

    @MainActor
    func submit() async throws -> Plan { /* … */ }
}
```

---

## Features

- 🎯 **`@Validate<T>` property wrapper** — declarative per-field validation for any `Equatable` value, not just `String`.
- 🧩 **Composable typed rules** — chain multiple rules per field; each rule is a plain value type.
- 🔁 **Validation modes** — `.always`, `.onChange` (default), `.onSubmit`. Errors auto-clear as the user fixes them.
- 📋 **Form protocols** — `ValidatableForm`, `SubmittableForm`, `PopulatableForm` model a form as a value type.
- 🎛️ **`FormController<T>`** — `@Observable` controller with a submission state machine (`initial` / `loading` / `success` / `failure`).
- 🛰️ **Server-error remap** — throw `ValidationError.invalid(errors:)` from `submit()` and per-field errors flow back onto the corresponding `@Validate` fields automatically.
- 🧰 **Built-in string rules** — `isNotEmpty`, `minLength`, `maxLength`, `pattern`, `email`.
- 🎨 **SwiftUI modifiers** — `.validator(state:)` for inline field errors, `.formToolbar(...)` for a Cancel/Submit toolbar.
- 🛡️ **Dirty-state-aware dismiss** — discard confirmation dialog + `interactiveDismissDisabled` when the form has unsaved changes.
- 🪶 **Zero dependencies** — Foundation + SwiftUI + Observation. No Combine, no third-party packages.
- ⚡ **`@Observable` native** — built for iOS 17+ / Swift 5.9+ macros, not `ObservableObject`.
- 🔒 **Swift 6 concurrency** — explicit `@MainActor` isolation on the form lifecycle, no `Sendable` headaches for consumers.

---

## Requirements

- Swift 6.0+ (built with tools 6.3, language mode v6)
- iOS 17 / macOS 14 / tvOS 17 / watchOS 10
- Xcode 16+

## Installation

Swift Package Manager — add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rozd/forms-kit.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "FormsKit", package: "forms-kit"),
    ]),
]
```

Or in Xcode: **File → Add Package Dependencies…** and paste the repository URL.

---

## Quick start

<details>
<summary>End-to-end example: a "Create Plan" sheet</summary>

```swift
import SwiftUI
import FormsKit

struct CreatePlanForm: ValidatableForm, SubmittableForm {
    @Validate(name: "name", .isNotEmpty(message: "Name is required"), .minLength(3))
    var name: String = ""

    @Validate(name: "email", .email())
    var ownerEmail: String = ""

    var validates: [ValidateAccessor<Self>] {
        [.init(\._name), .init(\._ownerEmail)]
    }

    @MainActor
    func submit() async throws -> Plan {
        try await api.createPlan(name: name, ownerEmail: ownerEmail)
    }
}

struct CreatePlanSheet: View {
    @State private var controller = FormController(form: CreatePlanForm())
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $controller.form.name)
                    .validator(state: controller.form.$name)

                TextField("Owner email", text: $controller.form.ownerEmail)
                    .validator(state: controller.form.$ownerEmail)
            }
            .navigationTitle("New Plan")
            .formToolbar(controller: controller) {
                Task {
                    do {
                        _ = try await controller.submit()
                        dismiss()
                    } catch { /* state == .failure(error) */ }
                }
            }
        }
    }
}
```

</details>

---

## Validation

### `@Validate<T>` property wrapper

Wraps any `Equatable` value and tracks its validation state. The projected value (`$field`) exposes a `Validate.State` you can drive UI from.

<details>
<summary>Basic usage</summary>

```swift
@Validate(name: "age", .init(/* rules */)) var age: Int = 18

// Read state from the projected value
switch $age {
case .idle:        // not edited yet
case .editing:     // user touched the field, not yet validated
case .valid:       // passed all rules
case .invalid(let messages): // failed; messages contains all rule failures
}
```

</details>

<details>
<summary>Validation modes</summary>

```swift
// .onChange (default) — stays quiet until invalid, then re-validates on each keystroke
@Validate(name: "name", .isNotEmpty(message: "Required"))
var name: String = ""

// .always — validates immediately at init time
@Validate(name: "tos", mode: .always, .isTrue(message: "Must accept"))
var acceptedTOS: Bool = false

// .onSubmit — only validates when the form is submitted
@Validate(name: "bio", mode: .onSubmit, .maxLength(500))
var bio: String = ""
```

</details>

<details>
<summary>Optional fields</summary>

```swift
// A second initializer exists for ExpressibleByNilLiteral types — no `= nil` needed
@Validate(name: "nickname") var nickname: String?
```

</details>

### Validation rules

Implement the `ValidationRule` protocol — typed over the value the rule validates. Return `nil` for valid, an error message for invalid.

<details>
<summary>Built-in string rules</summary>

```swift
@Validate(name: "email",
    .isNotEmpty(message: "Required"),
    .email(message: "Invalid email"))
var email: String = ""

@Validate(name: "password",
    .minLength(8, message: "At least 8 characters"),
    .maxLength(64),
    .pattern(#"[A-Z]"#, message: "Must contain an uppercase letter"))
var password: String = ""
```

Available rules in the `StringValidationRules/` folder:
- `isNotEmpty(message:)` — non-empty after trimming whitespace
- `minLength(_:message:)` / `maxLength(_:message:)`
- `pattern(_:message:)` — NSRegularExpression match
- `email(message:)` — basic RFC-ish email shape

</details>

<details>
<summary>Writing a custom rule</summary>

```swift
public struct DivisibleBy: ValidationRule {
    public let divisor: Int
    public let message: String

    public func validate(value: Int) -> String? {
        value % divisor == 0 ? nil : message
    }
}

// Add a static factory for nice call-site syntax
public extension ValidationRule where Self == DivisibleBy {
    static func divisibleBy(_ n: Int, message: String) -> DivisibleBy {
        DivisibleBy(divisor: n, message: message)
    }
}

// Use it
@Validate(name: "quantity", .divisibleBy(5, message: "Must be a multiple of 5"))
var quantity: Int = 0
```

</details>

---

## Forms

A form is a **struct** of `@Validate`-wrapped fields that conforms to one or more of these protocols.

### `ValidatableForm`

Declares which fields participate in validation via a `validates` array of key-path-driven accessors.

<details>
<summary>Example</summary>

```swift
struct SignupForm: ValidatableForm {
    @Validate(name: "email", .isNotEmpty(message: "Required"), .email())
    var email: String = ""

    @Validate(name: "password", .minLength(8))
    var password: String = ""

    // Note: key path is to the wrapper (\._email), not the value (\.email)
    // Leading dot is required by Swift 6 when the root type is inferred from context.
    var validates: [ValidateAccessor<Self>] {
        [.init(\._email), .init(\._password)]
    }
}

// Free helpers from the protocol extension:
form.isValid          // Bool
form.validationErrors // [String: [String]] keyed by Validate.name
```

</details>

### `SubmittableForm`

Adds an async `submit()` that returns a typed `Output`. **Required to be `@MainActor`** — see [Concurrency](#concurrency).

<details>
<summary>Example</summary>

```swift
struct CreatePlanForm: ValidatableForm, SubmittableForm {
    // … fields …

    @MainActor
    func submit() async throws -> Plan {
        try await api.createPlan(name: name)
    }
}
```

</details>

### `PopulatableForm`

For "Edit" flows — hydrate a form from an existing entity. **Required to be `@MainActor`**.

<details>
<summary>Example</summary>

```swift
extension CreatePlanForm: PopulatableForm {
    @MainActor
    mutating func populate(from plan: Plan) {
        name = plan.name
        ownerEmail = plan.ownerEmail
    }
}

// In the sheet:
@State private var controller = FormController(form: CreatePlanForm())

.onAppear { controller.form.populate(from: existingPlan) }
```

`Data` is a `Sendable` carrier — load it off MainActor, then `populate(from:)` on MainActor.

</details>

---

## `FormController<T>`

`@Observable @MainActor` controller that wraps a form and manages its submission lifecycle.

### Submission state machine

<details>
<summary>State flow</summary>

```
.initial ──submit()──> .loading ──success──> .success
                            │
                            └──failure──> .failure(Error)
```

```swift
let controller = FormController(form: SignupForm())

Task {
    do {
        let user = try await controller.submit()
        // controller.state == .success
    } catch ValidationError.invalid(let errors) {
        // Per-field errors already mapped back onto controller.form fields
    } catch {
        // controller.state == .failure(error)
    }
}
```

</details>

### Server-side error remap

When `submit()` throws `ValidationError.invalid(errors:)`, the controller maps each per-field error onto the matching `@Validate` field by `name`. The next render shows them inline automatically.

<details>
<summary>Example</summary>

```swift
@MainActor
func submit() async throws -> User {
    let response = try await api.signup(email: email, password: password)
    if let issues = response.fieldIssues {
        throw ValidationError.invalid(errors: issues)
        // e.g. ["email": ["Already taken"]]
        // → controller.form.$email becomes .invalid(["Already taken"])
    }
    return response.user
}
```

</details>

### Convenience accessors

<details>
<summary>API surface</summary>

```swift
controller.form        // T (the form struct)
controller.state       // .initial / .loading / .success / .failure
controller.isDirty     // any field has been edited
controller.isValid     // all fields are .valid
controller.isLoading   // state == .loading
controller.validate()  // runs all rules; mutates field states
try await controller.submit()
```

</details>

---

## SwiftUI modifiers

### `.validator(state:)`

Renders error messages under a field when the wrapper is `.invalid`.

<details>
<summary>Example</summary>

```swift
TextField("Email", text: $controller.form.email)
    .validator(state: controller.form.$email)

// Optional layout overrides
TextField("Bio", text: $controller.form.bio)
    .validator(state: controller.form.$bio, alignment: .leading, spacing: 6)
```

</details>

### `.formToolbar(controller:onSubmit:)`

Cancel/Submit toolbar that respects the controller's dirty/loading state, with a built-in "Discard changes?" confirmation.

<details>
<summary>Example</summary>

```swift
NavigationStack {
    Form { /* … */ }
        .navigationTitle("New Plan")
        .formToolbar(controller: controller) {
            Task { try? await controller.submit() }
        }
}

// Customize titles or opt out of dismiss protection
.formToolbar(
    controller: controller,
    cancelTitle: "Close",
    submitTitle: "Create",
    preventsAccidentalDismiss: false,
) {
    Task { try? await controller.submit() }
}
```

Submit is auto-disabled when `!isDirty || isLoading`. Cancel triggers a confirmation dialog when the form is dirty and `preventsAccidentalDismiss` is on (default `true`).

</details>

---

## Concurrency

FormsKit has a deliberate isolation shape:

| Type / requirement | Isolation |
|---|---|
| `FormController` | `@MainActor` |
| `SubmittableForm.submit()` | `@MainActor` |
| `PopulatableForm.populate(from:)` | `@MainActor` |
| `ValidatableForm` | unconstrained |
| `Validate<T>`, `ValidationRule`, accessors, rules | unconstrained (value types) |

<details>
<summary>Why <code>submit()</code> is <code>@MainActor</code> (and why that's fine)</summary>

A `@MainActor async` function only *enters and resumes* on MainActor. Any `await` inside (URLSession, Firestore, etc.) suspends and frees MainActor while the awaited work runs on its own executor; resumption hops back to MainActor for the next line. So your network call doesn't block the UI — only the entry, the resume, and assignments to the controller happen on MainActor.

The benefit: the form (`T`) never crosses an isolation boundary, so consumers don't need to make every form, every field, and every rule `Sendable`.

</details>

<details>
<summary>Why <code>ValidatableForm</code> is not <code>Sendable</code></summary>

It's intentional. Making the protocol `Sendable` would force the constraint through every layer (`T`, each `ValidationRule`, the closures inside `ValidateAccessor`) for a capability the design doesn't use — forms don't cross actor boundaries in normal flows. If you need to load form data off-MainActor, use `PopulatableForm`: load a `Sendable` `Data` value off-MainActor, then call `populate(from:)` on MainActor.

</details>

---

## What this package is *not*

- A UI kit — only two modifiers, intentionally minimal styling.
- A binding/navigation/router helper.
- A general-purpose `Validated<E, A>` applicative type (cf. `pointfreeco/swift-validated`) — different abstraction.
- An `ObservableObject` library — iOS 17 / `@Observable` is the floor.

## Roadmap

- Localized default error messages via `String(localized:bundle: .module)`.
- Themeable error color on `ValidatorViewModifier` (currently hardcoded `.red`).
- Localizable strings in `FormToolbarViewModifier` ("Discard Changes?", etc.).
- Additional rule families (`Number`, `Date`, `Collection`).

## License

MIT — see [LICENSE](LICENSE).
