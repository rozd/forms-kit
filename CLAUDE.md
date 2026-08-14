# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this package is

`FormsKit` — a small, opinionated SwiftUI form-validation library. Ships a `@Validated` property wrapper, composable typed `ValidationRule`s, a `FormController` with a submission state machine, and four SwiftUI modifiers (`.formValidationError(for:)`, `.formToolbar(controller:onSubmit:)`, `.formBindFocus(_:on:)`, and `.focused(on:equals:)`).

Target audience: SwiftUI apps on iOS 17+ that use `@Observable` (not `ObservableObject`/Combine). Intentionally no Combine, no third-party runtime deps. Also compiles for Android as a [Skip](https://skip.dev) Fuse native framework (see "Skip / Android support" below).

## Build / test

```bash
swift build        # Apple build; with Skip installed, also cross-compiles for Android via the skipstone plugin
swift test         # Apple tests; with Skip installed, also builds+runs the Android side via Gradle/Robolectric
SKIP_ZERO=1 swift test   # the pure-Apple, zero-dependency path (Skip plugin + deps stripped from the manifest)
```

Package is `swift-tools-version: 6.3`, Swift 6 language mode, platforms iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1. The only dependencies are the Skip build-time packages (`skip`, `skip-fuse`, `skip-fuse-ui`), which the `SKIP_ZERO=1` manifest block removes entirely; don't add any others, and don't remove that block.

Android test runs need a Gradle JVM ≥ 21 (Robolectric / Android SDK 36 requirement). `~/.gradle/gradle.properties` on this machine pins `org.gradle.java.home` to a Java 17 JBR; override per-run with `GRADLE_OPTS="-Dorg.gradle.java.home=<jdk21+ home>"` rather than editing the global file.

## Source layout

```
Sources/FormsKitSwiftUI/
├── Skip/skip.yml               # native mode, no bridging
└── FormsKitSwiftUI.swift       # shim: re-exports SwiftUI, or SkipSwiftUI in bridge builds
Sources/FormsKit/
├── Skip/
│   └── skip.yml                # Skip config: native (Fuse) mode — see "Skip / Android support"
├── Validated.swift             # @Validated<T> property wrapper + State/Mode
├── ValidatedField.swift        # type-erased schema entry for a Validated field
├── ValidationRule.swift        # protocol ValidationRule<Value>
├── ValidationError.swift       # .misconfigured / .invalid(errors:)
├── FormController.swift        # @MainActor @Observable controller + submit() lifecycle
├── Forms/
│   ├── ValidatableForm.swift       # protocol + isValid / validationErrors
│   ├── SubmittableForm.swift       # protocol — submit() is @MainActor
│   └── PopulatableForm.swift       # protocol — populate(from:) is @MainActor
├── ValidationRules/
│   ├── StringValidationRule.swift          # protocol StringValidationRule
│   └── StringValidationRules/              # concrete rules (NotEmpty, MinLength, …)
├── AnyFormController.swift     # internal closure-erased facade over FormController<T> for the bridged modifiers
└── ViewModifiers/
    ├── FormValidationErrorModifier.swift  # .formValidationError(for:) — single non-generic bridged modifier
    ├── FormToolbarViewModifier.swift      # .formToolbar(controller:onSubmit:) — generic modifier + bridged erased twin
    ├── FormBindFocus.swift                # .formBindFocus(_:on:) — direct composition, no struct
    └── FocusedOnViewModifier.swift        # .focused(on:equals:) — generic modifier + bridged erased twin
```

Keep one type per file. Group concrete rules under `ValidationRules/<Domain>ValidationRules/` (currently only `String`; add `Number`, `Date`, etc. the same way if needed). The three form-conformance protocols live in `Forms/`; everything else is a high-visibility public type and stays at root.

## Architecture in one breath

A form is a **struct** of `@Validated`-wrapped fields conforming to `ValidatableForm` (and usually `SubmittableForm`). It exposes a `validatedFields: [ValidatedField<Self>]` list built from key paths — that's how the controller drives validation without reflection.

A `FormController<T>` wraps the form, exposes a `state` (`initial` / `loading` / `success` / `failure(Error)`), and orchestrates validate-then-submit. On a thrown `ValidationError.invalid(errors:)` from `submit()`, it maps server-side per-field errors back onto the corresponding `@Validated` fields by `name`.

```swift
struct CreatePlanForm: ValidatableForm, SubmittableForm {
    @Validated(name: "name", .isNotEmpty(message: "Required"), .minLength(3))
    var name: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.name, wrappedBy: \._name)]
    }

    @MainActor
    func submit() async throws -> Plan { /* … */ }
}
```

`ValidatedField.init` takes two key paths: the *value* path (`\.name`, positional) and the *wrapper* path (`\._name`, labelled `wrappedBy:`). Both are required because Swift's `KeyPath` equality is buffer-structural — the composed path `\Form._name.appending(path: \.wrappedValue)` is NOT equal to the literal `\Form.name` at runtime, so the library cannot derive one from the other. The value path is stored as `ValidatedField.keyPath` and serves as the field's focus identity (so `controller.focus` can be compared against the same `\.name` literal a consumer writes in a view). The wrapper path drives validation, state mutation, and name/error reads.

The leading dot is required by Swift 6 when the root type is inferred from context (e.g. `[.init(...)]`).

## Concurrency model — read this before touching isolation

The library has a deliberate isolation shape; deviating from it will produce confusing `Sendable` / "Sending value" diagnostics for consumers.

| Type / requirement | Isolation | Why |
|---|---|---|
| `FormController` | `@MainActor` | Holds `@Observable` UI state, read by SwiftUI views. |
| `SubmittableForm.submit()` | `@MainActor` | Form lives on MainActor; this keeps `T` from crossing actor boundaries. |
| `PopulatableForm.populate(from:)` | `@MainActor` | Mutates UI form state. `Data` is the off-actor carrier. |
| `ValidatableForm` | unconstrained | Synchronous; used only from already-isolated callers. |
| `Validated<T>`, `ValidationRule`, `ValidatedField`, rules | unconstrained | Value types / pure. |
| View modifiers | `View`-driven (MainActor in practice) | SwiftUI. |

**Do not make `ValidatableForm: Sendable`.** It would force `Sendable` on every `T`, every `ValidationRule`, every closure in `ValidatedField` — for a capability nothing in the design uses (the form never crosses an isolation boundary in normal use). If a consumer needs off-actor data, that's what `PopulatableForm.Data` is for: load `Data` (Sendable bytes/values) off MainActor, hop to MainActor, then `populate(from:)`.

**Don't add `@MainActor` to `ValidatableForm` either.** It has only synchronous, pure requirements; the isolation comes from the caller. Pinning it would needlessly bar use from non-UI contexts (tests, previews, server-side validation).

**Why the `@MainActor` requirement on `submit()` doesn't block the UI:** a `@MainActor async` function only *enters and resumes* on MainActor. `await` inside (URLSession, Firestore, etc.) suspends and frees MainActor; the awaited work runs on its own executor; resumption hops back to MainActor for the next line. That's the intended behavior — don't try to mark `submit()` `nonisolated` to "free up the main thread."

## Conventions

- **Public surface, narrow.** Default to `internal`; mark `public` only what consumers must touch. The `name` field on `Validated` and the closures on `ValidatedField` intentionally stay non-public — consumers don't need them.
- **No Combine.** Ever. `@Observable` only.
- **No third-party runtime dependencies.** Foundation + SwiftUI + Observation. The Skip packages are the single sanctioned exception: build-time only, inert on Apple platforms, and strippable via `SKIP_ZERO=1`. If any other feature seems to need a dep, find another way or push back.
- **Rules are value types.** A `ValidationRule` impl is a plain struct with a `validate(value:) -> String?` method. Add a static factory on `ValidationRule where Self == YourRule` for call-site sugar (`.minLength(3)` style). Mirror the existing `MinStringLengthValidationRule` pattern.
- **Rule error messages are passed in.** Don't hardcode user-facing strings inside rules beyond English defaults; consumers localize at call site by passing `message:`. (Localizing the package's own defaults via `String(localized:bundle: .module)` is a future improvement — track it as such, not as a quiet refactor.)
- **`@Validated` mode default is `.onChange`.** Means "stay quiet until the field becomes `.invalid`, then re-validate on each keystroke." Don't change the default; it's the UX consumers expect.
- **View modifier UI is intentionally minimal.** `formValidationError` hardcodes `.red` and `.caption`; `FormToolbarViewModifier` hardcodes English button titles + a discard dialog. Making these themeable / localizable is on the roadmap but hasn't shipped — don't sneak it in piecemeal; do it as one deliberate change with a public API.
- **View modifiers prefixed `form*` are package-original concepts; unprefixed ones (e.g. `.focused(on:equals:)`) deliberately overload existing SwiftUI vocabulary.** Don't prefix the overloads (it breaks discovery via SwiftUI muscle memory); do prefix new concepts (it groups the package's surface in autocomplete).

## Focus support

Focus traversal is **key-path-driven** — no per-form `Focus` enum required. Consumers use the *value* key path `\.fieldName` (publicly accessible) at every call site. The `\._fieldName` wrapper backing storage is brace-private and only usable inside the form type's own brace.

For `controller.focusFirstInvalidField()` to set `controller.focus` to a key path that *equals* the `\.fieldName` literal a consumer writes in a view, the value path must be provided explicitly at accessor construction time. This is a hard Swift constraint: `KeyPath` equality is buffer-structural, and the composed path `\Form._name.appending(path: \.wrappedValue)` is NOT equal to the literal `\Form.name` at runtime — there's no programmatic way to derive the literal value path from the wrapper key path. So `ValidatedField.init` requires both:

```swift
struct CreatePlanForm: ValidatableForm {
    @Validated(name: "name", .isNotEmpty(...)) var name: String = ""
    @Validated(name: "email", .email(...))    var email: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.name,  wrappedBy: \._name),
         .init(\.email, wrappedBy: \._email)]
    }
}
```

The positional first arg is the *value* key path — stored as `ValidatedField.keyPath` and used as the field's focus identity. The `wrappedBy:` arg is the *wrapper* key path — used by the controller to mutate state and read name/errors. The value path must be re-stated at construction because the library can't derive it from the wrapper path.

Two SwiftUI modifiers consume the focus state, with overlapping responsibilities — pick whichever feels right at the call site:

### A. Zero-ceremony: `.focused(on:equals:)`

Each modifier internally owns a hidden `@FocusState<Bool>`. No `@FocusState` declaration on the view, no separate bridging modifier.

```swift
struct CreatePlanView: View {
    @State private var controller = FormController(form: CreatePlanForm())

    var body: some View {
        Form {
            TextField("Name", text: $controller.form.name)
                .focused(on: $controller, equals: \.name)
                .formValidationError(for: controller.form.$name)

            TextField("Description", text: $controller.form.description)
                .focused(on: $controller, equals: \.description)
        }
        .formToolbar(controller: controller) {
            Task { try? await controller.submit() }
        }
    }
}
```

How it works: each `.focused(on:equals:)` instance hosts a private `@FocusState<Bool>` and bidirectionally syncs it with `controller.focus`. When SwiftUI gives the field focus, the modifier writes `controller.focus = keyPath`. When SwiftUI takes focus away, the modifier clears `controller.focus` *only if it still equals our key path* (the "still ours" guard handles the race where field B claimed focus before this onChange ran). When `controller.focus` is set programmatically, all modifiers observe the change; exactly one matches and acquires focus.

### B. Shared `@FocusState`: `.formBindFocus(_:on:)`

Consumer declares a single `@FocusState` and uses native SwiftUI `.focused(_:equals:)` on each field. The library provides a bridge modifier that bidirectionally binds the `@FocusState` to `controller.focus`.

```swift
struct CreatePlanView: View {
    @State private var controller = FormController(form: CreatePlanForm())
    @FocusState private var focus: PartialKeyPath<CreatePlanForm>?

    var body: some View {
        Form {
            TextField("Name", text: $controller.form.name)
                .focused($focus, equals: \.name)
                .formValidationError(for: controller.form.$name)

            TextField("Description", text: $controller.form.description)
                .focused($focus, equals: \.description)
        }
        .formBindFocus($focus, on: controller)
        .formToolbar(controller: controller) {
            Task { try? await controller.submit() }
        }
    }
}
```

Use this form when you need the `@FocusState` binding for something else in the same view (e.g., a non-form search field that should participate in the same focus context, or a scroll-to-error overlay that observes `focus.wrappedValue`).

The `bind` in `.formBindFocus` reflects the bidirectional sync: writes to `$focus` flow into `controller.focus`, and programmatic writes to `controller.focus` flow back into `$focus`. The controller→`@FocusState` direction is deferred via `Task { @MainActor }` to dodge SwiftUI's "write inside a view update is silently coalesced" hazard.

### Rules of the road

- **Use value key paths (`\.name`), not wrapper key paths (`\._name`).** Property-wrapper backing storage is brace-private by default — `\._name` works inside the form's own type body and same-file extensions, but a separate view file can't access it. `ValidatedField.keyPath` stores the value path so `controller.focus` is universally writable as `\.name`.
- **Auto-focus on submit failure is default-on.** `controller.submit()` calls `focusFirstInvalidField()` in both the pre-flight branch and the server-error-remap branch. Opt out with `controller.shouldFocusFirstInvalidFieldOnSubmit = false` (e.g. when the consumer wants to scroll the field into view first).
- **`controller.focus` is freely mutable from MainActor.** Useful for "focus on appear", "focus after server-side correction", or scroll-to-error overlays that observe it.
- **Non-validated focusable fields are first-class.** Any `KeyPath<Form, V>` works as a focus identifier; only validated key paths participate in `focusFirstInvalidField()`. Mixing validated `\.name` and non-validated `\.description` in the same form is supported.
- **`.focused(on:equals:)` vs `.formBindFocus(_:on:)` is not exclusive.** A form can mix both modifiers on different fields. They observe the same `controller.focus`, so they stay coordinated.

What's intentionally **not** in this slice: next/previous chevron buttons above the keyboard. That likely needs a `FocusableForm` protocol with an explicit `focusableFields: [PartialKeyPath<Self>]` so non-validated fields participate in ordered traversal. Defer until there's a concrete consumer need.

## Skip / Android support

FormsKit ships as a Skip **Fuse (native) framework**: `Sources/FormsKit/Skip/skip.yml` declares `mode: 'native'`, so the Swift compiles as-is for Android with the Swift SDK for Android, and the SwiftUI layer resolves to SkipFuseUI → Compose. This is the only viable mode — Skip's *transpiled* mode supports neither custom property wrappers (`@Validated`) nor key paths (the `ValidatedField` schema and the whole focus system), so never attempt a transpiled port.

Rules that keep the Android build green:

- **Custom `ViewModifier`s work on Android only when bridged — and only non-generic types bridge.** On Android, SkipSwiftUI's `View.modifier(_:)` never calls `body(content:)` itself; it applies the modifier's `Java_modifier`, whose protocol-default implementation is `SkipUI.EmptyModifier()`. For a *bridged* modifier, skipstone generates the override (`Java_modifier { return self }` plus a Kotlin peer whose `body()` calls back into Swift), and the modifier renders. For an *unbridged* one — generic, `@nobridge`d, or hidden from the generator — the default fires and the modifier silently renders its content unchanged, dropping everything else (this is how the toolbar/validation/focus modifiers originally shipped as no-ops: they were generic, hence unbridgeable). Genericity is the trap, not the `ViewModifier` protocol.
- **Generic modifiers therefore come in dual form: a typed variant for non-bridge builds plus an erased bridged twin.** The generic variant lives in `#if !SKIP_BRIDGE && !SKIP` (Apple + SKIP_ZERO builds; the `!SKIP` half hides it from the skipstone generator, which parses with `SKIP` defined but `SKIP_BRIDGE` undefined). The erased twin (`ErasedFormToolbarModifier`, `ErasedFocusedOnModifier`) is declared **unconditionally** — the generator must see it to emit its Kotlin peer, and the Robolectric host build compiles the generated `*_Bridge.swift` against it — and erases `FormController<T>` behind the internal `AnyFormController` closure facade (`AnyKeyPath` for focus identity). Erased twins must NOT carry `// SKIP @nobridge`, keep their memberwise inits internal (no constructor bridging), and their two bodies must be kept in sync by hand — the mirrored unit tests in `ViewModifierTests.swift` cover both variants. `skip.yml` sets `bridging: true` for the peers.
- **View files import `FormsKitSwiftUI`, never `SwiftUI` directly.** The `FormsKitSwiftUI` shim target re-exports real SwiftUI, except in Skip bridge builds (`-DSKIP_BRIDGE`: the Android cross-compile and the Robolectric host build) where it re-exports SkipSwiftUI, whose `SkipUIBridging`/`SkipUI` machinery the generated bridges reference. The indirection is load-bearing: the bridge generator mirrors source-file imports verbatim into the generated `*_Bridge.swift` files and cannot evaluate `#if` conditions, so the conditional must live at module level in the shim, and the view files' import must stay a plain unconditional `import FormsKitSwiftUI`. `ViewModifierTests.swift` is guarded with `!SKIP_BRIDGE` in addition to `!os(Android)` (in bridge builds FormsKit's views are SkipSwiftUI-typed, so real-SwiftUI hosting doesn't apply). One sharp edge: switching between `SKIP_ZERO` and Skip-active builds in the same checkout can leave stale incremental state (`missing required module 'CJNI'`) — run `swift package clean` when that appears.
- **Everything else public carries `// SKIP @nobridge`.** With `bridging: true`, skipstone tries to bridge the whole public API, and FormsKit's is unbridgeable by design: key paths (`ValidatedField`), generic types with constructors (`FormController`, `Validated`), and statics added via constrained extensions (the `.minLength(3)`-style rule factories) all hard-error in the generator. FormsKit is consumed from Swift only, so the Kotlin-facing surface is deliberately empty except the bridged modifier structs. A new public declaration gets `// SKIP @nobridge` unless it is a non-generic `View` or `ViewModifier` that must render on Android.
- **Property-wrapper storage in public SwiftUI types must be `internal`, not `private`.** Skip's bridge diagnostics reject private `@State`/`@Environment`/`@FocusState` storage inside bridged types ("Private state property cannot be bridged"). This is why `dismiss`, `showsDiscardWarning`, and `isFocused` are internal.
- **`ViewModifierTests.swift` is wrapped in `#if !os(Android)`.** It hosts views via `ImageRenderer`/`NS-`/`UIHostingController`, which don't exist on Android. Logic tests (rules, `Validated`, controller, focus) run on both platforms — keep new UI-hosting tests inside that guard and new logic tests outside it.
- **`FormController.swift` imports `SkipFuse` behind `#if canImport(SkipFuse)`.** On Android this wires `@Observable` change tracking into Compose; under `SKIP_ZERO` the module doesn't exist, hence the guard. Give any future `@Observable` type the same import.
- **The `SKIP_ZERO` block in `Package.swift` is the no-dependency escape hatch** for Apple-only consumers. Preserve it when touching the manifest, and keep the Skip dependencies out of any code path it can't strip.
- **`.formBindFocus(_:on:)` is degraded on Android** (SkipUI doesn't fully support optional-valued `@FocusState`); `.focused(on:equals:)` is the cross-platform-safe variant. Don't build new features on optional `@FocusState`.

## Things to leave alone

- The `Validated.State.editing` case. It's recorded on value changes but not (yet) read anywhere. Reserved for "field has been touched but not yet validated" UX. Don't remove it without a replacement.
- The two `Validated.init` overloads (with/without `wrappedValue`). The second exists so `@Validated var x: String?` works without `= nil`. Don't merge them.
- `WritableKeyPath` in `ValidatedField.init`. `KeyPath` is `Sendable` in Swift 6; `WritableKeyPath` works here because the accessors capture it inside non-Sendable closures used only from MainActor-isolated code. Don't try to "fix" it to `Sendable` closures unless you're also opening the form-Sendable question, which we've already answered (no).
- `Validated.State` and `Validated.Mode` names. They follow Swift's nested-state-machine convention (`URLSessionTask.State`, `Task.State`); don't rename to `Status` / `Trigger` / `Validity` without consumer-facing motivation.

## Adding a new rule (recipe)

1. Create `Sources/FormsKit/ValidationRules/<Domain>ValidationRules/<RuleName>.swift`.
2. Define `public struct <Rule>: <Domain>ValidationRule` (or `ValidationRule` directly).
3. Implement `public func validate(value: Value) -> String?` returning `nil` when valid, the error message when not.
4. Add a static factory: `public extension ValidationRule where Self == <Rule> { static func <name>(...) -> <Rule> { ... } }`.
5. Add a test in `Tests/FormsKitTests/`.

## Tests

Swift Testing framework (`import Testing`, `@Test`, `#expect`). Tests live in `Tests/FormsKitTests/`. Cover at minimum: rule validity matrix, `Validated` state transitions, `FormController.submit()` happy path, and server-error remap (throw `ValidationError.invalid(errors:)` from a stub `submit()` and assert the form's per-field `.invalid` state).

## Versioning / releases

Tag releases semver-style (`0.x.0` until API stabilizes). Breaking changes to any of: `@Validated` API, the form protocols, `FormController`, or `ValidatedField` are major bumps even pre-1.0 if consumers exist — they're load-bearing for every form in every consumer.

## What this package is *not*

- A UI kit. There are four view modifiers, and they're minimal. Don't grow this into a styled-input library.
- A binding/router/navigation helper.
- A general-purpose `Validated<E, A>` applicative (cf. `pointfreeco/swift-validated`). Different abstraction; don't try to merge ideas. FormsKit's `@Validated` is a property wrapper for per-field state; the pointfree type is an applicative result enum — the name overlap is nominal, not semantic.
- An `ObservableObject`-era library. iOS 17 / `@Observable` is the floor; don't add backports.
