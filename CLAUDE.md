# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this package is

`FormsKit` — a small, opinionated SwiftUI form-validation library. Ships a `@Validate` property wrapper, composable typed `ValidationRule`s, a `FormController` with a submission state machine, and two SwiftUI modifiers (`.validator(state:)` and `.formToolbar(controller:onSubmit:)`).

Target audience: SwiftUI apps on iOS 17+ that use `@Observable` (not `ObservableObject`/Combine). Intentionally no Combine, no third-party deps.

## Build / test

```bash
swift build
swift test
```

Package is `swift-tools-version: 6.3`, Swift 6 language mode, platforms iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1. No dependencies. Don't add any.

## Source layout

```
Sources/FormsKit/
├── Validate.swift              # @Validate<T> property wrapper + State/Mode
├── ValidationRule.swift        # protocol ValidationRule<Value>
├── ValidationRules/
│   ├── StringValidationRule.swift          # protocol StringValidationRule
│   └── StringValidationRules/              # concrete rules (NotEmpty, MinLength, …)
├── ValidatableForm.swift       # protocol + isValid / validationErrors
├── SubmittableForm.swift       # protocol — submit() is @MainActor
├── PopulatableForm.swift       # protocol — populate(from:) is @MainActor
├── ValidateAccessor.swift      # type-erased key-path accessor for a Validate field
├── FormController.swift        # @MainActor @Observable controller + submit() lifecycle
├── ValidationError.swift       # .misconfigured / .invalid(errors:)
└── ViewModifiers/
    ├── ValidatorViewModifier.swift      # .validator(state:)
    └── FormToolbarViewModifier.swift    # .formToolbar(controller:onSubmit:)
```

Keep one type per file. Group concrete rules under `ValidationRules/<Domain>ValidationRules/` (currently only `String`; add `Number`, `Date`, etc. the same way if needed).

## Architecture in one breath

A form is a **struct** of `@Validate`-wrapped fields conforming to `ValidatableForm` (and usually `SubmittableForm`). It exposes a `validates: [ValidateAccessor<Self>]` list built from key paths — that's how the controller drives validation without reflection.

A `FormController<T>` wraps the form, exposes a `state` (`initial` / `loading` / `success` / `failure(Error)`), and orchestrates validate-then-submit. On a thrown `ValidationError.invalid(errors:)` from `submit()`, it maps server-side per-field errors back onto the corresponding `@Validate` fields by `name`.

```swift
struct CreatePlanForm: ValidatableForm, SubmittableForm {
    @Validate(name: "name", .isNotEmpty(message: "Required"), .minLength(3))
    var name: String = ""

    var validates: [ValidateAccessor<Self>] { [.init(\._name)] }

    @MainActor
    func submit() async throws -> Plan { /* … */ }
}
```

Note `\._name` — key path to the *wrapper*, not the value. That's what `ValidateAccessor.init` takes. The leading dot is required by Swift 6 when the root type is inferred from context (e.g. `[.init(...)]`).

## Concurrency model — read this before touching isolation

The library has a deliberate isolation shape; deviating from it will produce confusing `Sendable` / "Sending value" diagnostics for consumers.

| Type / requirement | Isolation | Why |
|---|---|---|
| `FormController` | `@MainActor` | Holds `@Observable` UI state, read by SwiftUI views. |
| `SubmittableForm.submit()` | `@MainActor` | Form lives on MainActor; this keeps `T` from crossing actor boundaries. |
| `PopulatableForm.populate(from:)` | `@MainActor` | Mutates UI form state. `Data` is the off-actor carrier. |
| `ValidatableForm` | unconstrained | Synchronous; used only from already-isolated callers. |
| `Validate<T>`, `ValidationRule`, `ValidateAccessor`, rules | unconstrained | Value types / pure. |
| View modifiers | `View`-driven (MainActor in practice) | SwiftUI. |

**Do not make `ValidatableForm: Sendable`.** It would force `Sendable` on every `T`, every `ValidationRule`, every closure in `ValidateAccessor` — for a capability nothing in the design uses (the form never crosses an isolation boundary in normal use). If a consumer needs off-actor data, that's what `PopulatableForm.Data` is for: load `Data` (Sendable bytes/values) off MainActor, hop to MainActor, then `populate(from:)`.

**Don't add `@MainActor` to `ValidatableForm` either.** It has only synchronous, pure requirements; the isolation comes from the caller. Pinning it would needlessly bar use from non-UI contexts (tests, previews, server-side validation).

**Why the `@MainActor` requirement on `submit()` doesn't block the UI:** a `@MainActor async` function only *enters and resumes* on MainActor. `await` inside (URLSession, Firestore, etc.) suspends and frees MainActor; the awaited work runs on its own executor; resumption hops back to MainActor for the next line. That's the intended behavior — don't try to mark `submit()` `nonisolated` to "free up the main thread."

## Conventions

- **Public surface, narrow.** Default to `internal`; mark `public` only what consumers must touch. The `name` field on `Validate` and accessor closures on `ValidateAccessor` intentionally stay non-public — consumers don't need them.
- **No Combine.** Ever. `@Observable` only.
- **No third-party dependencies.** Foundation + SwiftUI + Observation. If a feature seems to need a dep, find another way or push back.
- **Rules are value types.** A `ValidationRule` impl is a plain struct with a `validate(value:) -> String?` method. Add a static factory on `ValidationRule where Self == YourRule` for call-site sugar (`.minLength(3)` style). Mirror the existing `MinStringLengthValidationRule` pattern.
- **Rule error messages are passed in.** Don't hardcode user-facing strings inside rules beyond English defaults; consumers localize at call site by passing `message:`. (Localizing the package's own defaults via `String(localized:bundle: .module)` is a future improvement — track it as such, not as a quiet refactor.)
- **`@Validate` mode default is `.onChange`.** Means "stay quiet until the field becomes `.invalid`, then re-validate on each keystroke." Don't change the default; it's the UX consumers expect.
- **View modifier UI is intentionally minimal.** `ValidatorViewModifier` hardcodes `.red` and `.caption`; `FormToolbarViewModifier` hardcodes English button titles + a discard dialog. Making these themeable / localizable is on the roadmap but hasn't shipped — don't sneak it in piecemeal; do it as one deliberate change with a public API.

## Things to leave alone

- The `Validate.State.editing` case. It's recorded on value changes but not (yet) read anywhere. Reserved for "field has been touched but not yet validated" UX. Don't remove it without a replacement.
- The two `Validate.init` overloads (with/without `wrappedValue`). The second exists so `@Validate var x: String?` works without `= nil`. Don't merge them.
- `WritableKeyPath` in `ValidateAccessor.init`. `KeyPath` is `Sendable` in Swift 6; `WritableKeyPath` works here because the accessors capture it inside non-Sendable closures used only from MainActor-isolated code. Don't try to "fix" it to `Sendable` closures unless you're also opening the form-Sendable question, which we've already answered (no).

## Adding a new rule (recipe)

1. Create `Sources/FormsKit/ValidationRules/<Domain>ValidationRules/<RuleName>.swift`.
2. Define `public struct <Rule>: <Domain>ValidationRule` (or `ValidationRule` directly).
3. Implement `public func validate(value: Value) -> String?` returning `nil` when valid, the error message when not.
4. Add a static factory: `public extension ValidationRule where Self == <Rule> { static func <name>(...) -> <Rule> { ... } }`.
5. Add a test in `Tests/FormsKitTests/`.

## Tests

Swift Testing framework (`import Testing`, `@Test`, `#expect`). Tests live in `Tests/FormsKitTests/`. Cover at minimum: rule validity matrix, `Validate` state transitions, `FormController.submit()` happy path, and server-error remap (throw `ValidationError.invalid(errors:)` from a stub `submit()` and assert the form's per-field `.invalid` state).

## Versioning / releases

Tag releases semver-style (`0.x.0` until API stabilizes). Breaking changes to any of: `@Validate` API, the form protocols, `FormController`, or `ValidateAccessor` are major bumps even pre-1.0 if consumers exist — they're load-bearing for every form in every consumer.

## What this package is *not*

- A UI kit. There are exactly two view modifiers, and they're minimal. Don't grow this into a styled-input library.
- A binding/router/navigation helper.
- A general-purpose `Validated<E, A>` applicative (cf. `pointfreeco/swift-validated`). Different abstraction; don't try to merge ideas.
- An `ObservableObject`-era library. iOS 17 / `@Observable` is the floor; don't add backports.
