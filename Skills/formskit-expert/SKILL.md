---
name: formskit-expert
description: Build SwiftUI forms using the FormsKit Swift Package — declarative `@Validated` fields, `ValidatableForm` / `SubmittableForm` / `PopulatableForm` protocol conformance, `FormController` submission lifecycle, key-path-driven focus traversal, and inline error display via the four FormsKit view modifiers. Use this skill whenever the user wants to build, edit, or maintain a SwiftUI form in a project that depends on FormsKit — including sign-up / login / creation / edit sheets, server-side validation error remap, focus management, or anything that mentions `@Validated`, `ValidatableForm`, `ValidatedField`, `FormController`, `ValidationRule`, `.formToolbar`, `.formValidationError`, `.focused(on:equals:)`, or `.formBindFocus`. Also trigger when the user has a SwiftUI form-shaped UI in mind ("validate this form", "edit-this-thing sheet", "user input with inline errors") and FormsKit is already a dependency of the target project. Prefer this skill over hand-rolled `@State` + manual validation in any FormsKit-using project.
---

# FormsKit expert

You are helping a consumer build a SwiftUI form using FormsKit. FormsKit is a small, opinionated form-validation library for `@Observable`-based SwiftUI apps (iOS 17+). It has four moving parts: the `@Validated` property wrapper, the form-protocol family (`ValidatableForm` / `SubmittableForm` / `PopulatableForm`), the `FormController<T>` controller, and four view modifiers. Your job is to wire those parts together correctly without drifting back to `@State`-and-manual-validation patterns.

> Need an exact signature, factory name, or modifier parameter list? Open `references/api-cheatsheet.md` — it's the compact API reference. This document focuses on the *patterns* you need to apply; the cheatsheet is for when you need to verify a specific call.

## Before you write any code

If you don't already know it from context, **confirm FormsKit is in the target's dependencies**. A quick grep for `FormsKit` in `Package.swift`, `Project.swift`, or `*.xcodeproj/project.pbxproj` is enough. If it's not there, stop and tell the user — this Skill assumes the dependency is already in place; suggesting they add it is a separate decision.

Once confirmed, gather the shape of the form before writing it:

1. **Fields** — names, types, and which ones are required vs optional.
2. **Rules per field** — required? min/max length? regex? email? Or no validation at all (the field still belongs in the form struct, just without rules)?
3. **Submit output** — what `submit()` returns on success (`User`, `Plan`, `Void`, …) and which API/method it calls.
4. **Population** — is this a "Create" form (starts empty) or an "Edit" form (hydrated from an existing entity)? The latter needs `PopulatableForm`.
5. **Presentation** — sheet, full screen, navigation push? Affects toolbar wiring (`.formToolbar` assumes a `NavigationStack` ancestor).

A short read of the user's existing code (one or two existing forms in the project, if present) is usually faster than asking. Match the conventions you find.

## The minimal template

Every FormsKit form has this shape. Start from this template and add fields:

```swift
import SwiftUI
import FormsKit

struct CreateThingForm: ValidatableForm, SubmittableForm {
    @Validated(name: "title", .isNotEmpty(message: "Title is required"), .minLength(3))
    var title: String = ""

    @Validated(name: "email", .email())
    var ownerEmail: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.title,      wrappedBy: \._title),
         .init(\.ownerEmail, wrappedBy: \._ownerEmail)]
    }

    @MainActor
    func submit() async throws -> Thing {
        try await api.createThing(title: title, ownerEmail: ownerEmail)
    }
}

struct CreateThingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var controller = FormController(form: CreateThingForm())

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $controller.form.title)
                    .focused(on: $controller, equals: \.title)
                    .formValidationError(for: controller.form.$title)

                TextField("Owner email", text: $controller.form.ownerEmail)
                    .focused(on: $controller, equals: \.ownerEmail)
                    .formValidationError(for: controller.form.$ownerEmail)
            }
            .navigationTitle("New Thing")
            .formToolbar(controller: controller) {
                Task {
                    do {
                        _ = try await controller.submit()
                        dismiss()
                    } catch {
                        // controller.state == .failure(error)
                        // Per-field server errors already remapped onto fields
                    }
                }
            }
        }
    }
}
```

That's the shape of nearly every FormsKit form. The rest of this document is the rules of the road that keep that template working.

## Gotchas — read these before writing the form

These are the failure modes Claude is most likely to walk into. Each one looks reasonable; each one is wrong.

### 1. `validatedFields` requires **both** key paths per field

`ValidatedField.init` takes a *value* key path positionally (`\.title`) and a *wrapper* key path labelled `wrappedBy:` (`\._title`). Both are required — the library cannot derive one from the other.

```swift
// ✅ Correct
[.init(\.title, wrappedBy: \._title)]

// ❌ Wrong — won't compile (and even if it did, focus traversal would break)
[.init(\._title)]                // only wrapper path
[.init(\.title)]                 // only value path
```

**Why both:** Swift's `KeyPath` equality is buffer-structural — the composed path `\Form._title.appending(path: \.wrappedValue)` is **not** equal at runtime to the literal `\Form.title` a consumer writes in a view. The value path serves as the field's focus identity (so `controller.focus` matches what views compare against); the wrapper path drives validation, state mutation, and name/error reads. Re-state both; don't try to be clever.

The leading dot is required by Swift 6 when the array literal's root type is inferred from context.

### 2. Use value key paths (`\.title`), not wrapper key paths (`\._title`), in views

Property-wrapper backing storage (`_title`) is brace-private by default — `\._title` works inside the form's own type body and same-file extensions, but a view declared in another file cannot access it. Always reach for `\.title` in view code:

```swift
// ✅ Correct
.focused(on: $controller, equals: \.title)

// ❌ Wrong — won't compile from a separate view file
.focused(on: $controller, equals: \._title)
```

`ValidatedField.keyPath` stores the value path, so `controller.focus` is universally writable as `\.title` from anywhere.

### 3. `submit()` and `populate(from:)` must be `@MainActor`

The protocols require it, and the library's isolation model depends on it. Don't try to mark them `nonisolated` or drop the attribute — you'll see "Sending value of non-Sendable type" diagnostics from `T` crossing actor boundaries.

```swift
// ✅ Correct
@MainActor
func submit() async throws -> Thing { ... }

@MainActor
mutating func populate(from data: ThingData) { ... }
```

**Why this is fine for performance:** A `@MainActor async` function only *enters and resumes* on MainActor. `await` inside (URLSession, Firestore, etc.) suspends MainActor and lets the awaited work run on its own executor; resumption hops back to MainActor for the next line. Network calls don't block the UI.

### 4. Don't make the form `Sendable`

It would force `Sendable` on every field type, every `ValidationRule`, and every closure in `ValidatedField` — for a capability the design doesn't use. Forms don't cross actor boundaries in normal flows. If the user actually needs off-MainActor data loading for an edit form, use `PopulatableForm.Data` as the `Sendable` carrier — load `Data` off-actor, then `populate(from:)` on MainActor.

### 5. Use the `@Validated(name:)` you'll receive from the server

Server-side validation error remap matches by the `name:` string you pass to `@Validated`. If your API returns `{ "errors": { "email": ["Already taken"] } }`, the form needs `@Validated(name: "email", …) var ownerEmail: String`. Skip `name:` only if the field will never receive server-side errors.

### 6. View modifier order matters

`.formValidationError(for:)` wraps the field in a `VStack` so the error sits *below* the field. Put it **outside** layout that should not include the error message (e.g., it should not be inside a container that gives the field a fixed height). Put `.focused(on:equals:)` and `.formValidationError(for:)` directly on the `TextField`/`SecureField`/`Picker` — not on a `VStack` wrapping them.

```swift
// ✅ Correct
TextField("Email", text: $controller.form.email)
    .focused(on: $controller, equals: \.email)
    .formValidationError(for: controller.form.$email)
```

### 7. `.formToolbar(controller:onSubmit:)` needs a `NavigationStack` ancestor

It uses SwiftUI's `.toolbar` API, which requires a navigation context. Wrap the `Form` in `NavigationStack` (or push from one). Without it, the Cancel/Submit buttons silently won't render.

### 8. Property declaration order in the view

Sort the view's property block top-to-bottom in this order — it's a project-wide style preference here:

1. `@Environment(...)` declarations
2. `@FocusState` declarations
3. `@State` declarations
4. Plain stored properties / `let`-injected via init (e.g., `let existing: Profile`)

Don't intermix groups. A correctly-ordered example for an edit form:

```swift
struct EditThingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: PartialKeyPath<EditThingForm>?
    @State private var controller = FormController(form: EditThingForm())
    let existing: Thing

    var body: some View { ... }
}
```

The init signature (if you write one) takes its parameters in the same logical order — environment first is fine to leave implicit; explicit args correspond to the plain stored properties.

### 9. `state` is internal, not public

`FormController.state` is `private(set)` but its enum (`.initial / .loading / .success / .failure(Error)`) is currently package-internal. Consumers usually drive UI from `controller.isLoading`, `controller.isDirty`, and `controller.isValid` — and observe success via the return value of `await controller.submit()`. Don't try to switch on `controller.state` directly from outside the package.

## Patterns

The following sections cover the three most common forms — pick the one that matches the user's request and adapt.

### A) Creation form in a sheet (the default shape)

The minimal template above is exactly this. Key callouts:

- One `@State` controller, owned by the sheet view.
- `Form { … }` inside `NavigationStack { … }`.
- `.formToolbar` for Cancel/Submit. Submit auto-disables when `!isDirty || isLoading`.
- `Task { try? await controller.submit() }` in the `onSubmit` closure.
- Dismiss on success inside the `do` branch.

### B) Edit form (`PopulatableForm`)

Add a `PopulatableForm` conformance with a `Data` type that carries the entity's current values:

```swift
extension EditThingForm: PopulatableForm {
    @MainActor
    mutating func populate(from thing: Thing) {
        title = thing.title
        ownerEmail = thing.ownerEmail
    }
}

struct EditThingSheet: View {
    let existing: Thing
    @State private var controller = FormController(form: EditThingForm())

    var body: some View {
        NavigationStack { Form { /* same as create */ } }
            .formToolbar(controller: controller) { /* submit */ }
            .onAppear { controller.form.populate(from: existing) }
    }
}
```

`controller.isDirty` then correctly reflects whether the user has changed anything from the populated baseline, since `@Validated`'s `state` transitions out of `.idle` only on value changes.

### C) Server-side error remap

Throw `ValidationError.invalid(errors:)` from `submit()` and the controller maps per-field messages back onto the matching `@Validated` fields (by `name:`):

```swift
@MainActor
func submit() async throws -> User {
    let response = try await api.signup(email: email, password: password)
    if let issues = response.fieldIssues {
        // issues: [String: [String]] like ["email": ["Already taken"]]
        throw ValidationError.invalid(errors: issues)
    }
    return response.user
}
```

The next render shows the errors inline via `.formValidationError(for:)`, and `controller.focus` moves to the first invalid field automatically (unless `shouldFocusFirstInvalidFieldOnSubmit = false`).

### D) Focus traversal — pick one of two modifiers

**Zero-ceremony (preferred default):** `.focused(on:equals:)` owns its own hidden `@FocusState` internally. No declaration needed on the view.

```swift
TextField("Title", text: $controller.form.title)
    .focused(on: $controller, equals: \.title)
```

**Shared `@FocusState`:** Use `.formBindFocus(_:on:)` when you also need to read/write the focus state from elsewhere in the same view (a scroll-to-error overlay, a non-form sibling field that participates in the same focus context).

```swift
@FocusState private var focus: PartialKeyPath<MyForm>?
// …
TextField("Title", text: $controller.form.title)
    .focused($focus, equals: \.title)
// On the parent container:
.formBindFocus($focus, on: controller)
```

The two can be mixed on different fields in the same form — they observe the same `controller.focus`.

## Validation rules

### Built-in string rules (all in the `StringValidationRules/` folder)

| Rule | Factory | Notes |
|---|---|---|
| Non-empty (trimmed) | `.isNotEmpty(message:)` | `message:` is required |
| Min length | `.minLength(_:message:)` | `message:` optional — has English default |
| Max length | `.maxLength(_:message:)` | `message:` optional — has English default |
| Email shape | `.email(message:)` | Returns `nil` for empty input — pair with `.isNotEmpty` if required |
| Regex match | `.pattern(_:message:)` | `NSRegularExpression` |

Rules compose — pass them as a variadic list to `@Validated(...)`. Order doesn't matter for behavior (all failures are collected).

### Writing a custom rule

When the user needs a rule that doesn't ship with the package, follow this pattern (mirror `MinStringLengthValidationRule.swift`):

```swift
public struct DivisibleByRule: ValidationRule {
    public let divisor: Int
    public let message: String

    public func validate(value: Int) -> String? {
        value % divisor == 0 ? nil : message
    }
}

public extension ValidationRule where Self == DivisibleByRule {
    static func divisibleBy(_ n: Int, message: String) -> DivisibleByRule {
        DivisibleByRule(divisor: n, message: message)
    }
}

// Now usable as:
@Validated(name: "quantity", .divisibleBy(5, message: "Must be a multiple of 5"))
var quantity: Int = 0
```

Three things to keep consistent with FormsKit conventions:

1. **The struct is a plain value type.** No actors, no classes. `ValidationRule` is `unconstrained` — keep it that way.
2. **Error messages are passed in, not hardcoded.** Don't bake user-facing strings into the rule beyond English defaults (and only when a sensible default exists). The static factory takes a `message:` parameter so consumers localize at the call site.
3. **Add a static factory on `ValidationRule where Self == YourRule`.** That's what enables the `.minLength(3)` call-site syntax. Without it, consumers have to write the full struct name.

If the user wants to add it to the FormsKit package itself rather than their own app, switch to the maintainer workflow — that's outside this Skill's scope.

## What NOT to do

The following are dead-ends Claude reaches for from training-data instinct. None of them are correct here:

- **Don't reach for `ObservableObject` / `@Published` / Combine.** FormsKit is `@Observable`-only and iOS 17+. There are no backports.
- **Don't wrap fields in `@State` inside the view.** The form struct owns the field values via `@Validated`; the view reads them through `$controller.form.fieldName`. Two sources of truth defeats the entire library.
- **Don't store the form as `@State private var form: MyForm`.** Store the *controller* as `@State`; the controller owns the form.
- **Don't validate manually in the view.** `@Validated` re-validates automatically on value changes (in `.onChange` mode) and on `controller.submit()` and `controller.validate()`. Adding extra calls is at best redundant and at worst causes UI thrash.
- **Don't reach for SwiftUI's `.alert` to show validation errors.** Inline `.formValidationError(for:)` is the package's UX. Save `.alert` for *submission* failures (network errors, etc.) that aren't per-field.
- **Don't extend `FormController` in the consumer to add submit logic.** Put domain logic in the form's `submit()` method. The controller is a state machine, not a place for behavior.
- **Don't add a per-form `Focus` enum.** Focus is key-path-driven — `\.title`, `\.email`, etc. directly. The enum-based pattern from older SwiftUI examples is unnecessary here.
- **Don't change `@Validated`'s default mode.** `.onChange` is the UX consumers expect ("stay quiet until invalid, then re-validate on each keystroke"). Reach for `.always` or `.onSubmit` only when there's a specific reason.

## Final-step checklist

Before declaring the form done, verify (in order):

1. The form struct conforms to `ValidatableForm`, plus `SubmittableForm` if it submits, plus `PopulatableForm` if it's an edit form.
2. Every `@Validated` field has a `name:` matching the server's per-field error key (if server-side errors are possible).
3. `validatedFields` lists **every** validated field with both `\.value` and `wrappedBy: \._value`. Missing entries break focus and per-field server error remap.
4. `submit()` and `populate(from:)` carry `@MainActor`.
5. View uses `$controller.form.field` bindings (not `@State`), and references fields via the value key path (`\.title`, never `\._title`) in `.focused(on:equals:)` and `.formBindFocus`.
6. `Form { … }` lives inside `NavigationStack { … }` if `.formToolbar` is used.
7. The `onSubmit` closure dismisses (or routes away) on the success path — the controller does not dismiss for you.
8. View properties are sorted: `@Environment` → `@FocusState` → `@State` → plain stored properties (see gotcha #8). Re-check before declaring the form done.

When all eight are true, the form is wired correctly. If the user has additional fields, follow the same pattern; the template scales linearly.
