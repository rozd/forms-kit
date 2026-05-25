import Testing
import SwiftUI
@testable import FormsKit

// MARK: - Fixtures

private struct VMForm: ValidatableForm, SubmittableForm {
    @Validated(name: "name", .isNotEmpty(message: "Required"))
    var name: String = ""

    var validatedFields: [ValidatedField<Self>] {
        [.init(\.name, wrappedBy: \._name)]
    }

    @MainActor
    func submit() async throws -> String { name }
}

// MARK: - FormValidationErrorModifier

@MainActor
@Suite("FormValidationErrorModifier")
struct FormValidationErrorModifierTests {

    @Test("View extension `.formValidationError(for:)` builds a modified view — .idle branch")
    func formValidationErrorIdle() {
        let view = Text("hello").formValidationError(
            for: Validated<String>.State.idle
        )
        // Force SwiftUI to instantiate the modifier's body by rendering once into a host.
        _renderOnce(view)
    }

    @Test("View extension `.formValidationError(for:)` exercises the .invalid messages branch")
    func formValidationErrorInvalid() {
        let view = Text("hello").formValidationError(
            for: Validated<String>.State.invalid(messages: ["a", "b"])
        )
        _renderOnce(view)
    }

    @Test("View extension `.formValidationError(for:)` renders the .editing branch (no error shown)")
    func formValidationErrorEditing() {
        let view = Text("hello").formValidationError(
            for: Validated<String>.State.editing
        )
        _renderOnce(view)
    }

    @Test("View extension `.formValidationError(for:)` renders the .valid branch (no error shown)")
    func formValidationErrorValid() {
        let view = Text("hello").formValidationError(
            for: Validated<String>.State.valid
        )
        _renderOnce(view)
    }

    @Test("Custom alignment and spacing arguments are accepted")
    func formValidationErrorCustomLayout() {
        let view = Text("hello").formValidationError(
            for: Validated<String>.State.invalid(messages: ["x"]),
            alignment: .center,
            spacing: 10
        )
        _renderOnce(view)
    }
}

// MARK: - FormToolbarViewModifier

@MainActor
@Suite("FormToolbarViewModifier")
struct FormToolbarViewModifierTests {

    @Test("View extension `.formToolbar(...)` builds a modified view for a dirty form")
    func formToolbarDirty() {
        let controller = FormController(form: VMForm())
        controller.form.name = "changed"
        let view = NavigationStack {
            Text("body").formToolbar(controller: controller) { /* submit */ }
        }
        _renderOnce(view)
    }

    @Test("View extension `.formToolbar(...)` builds a modified view for a clean form")
    func formToolbarClean() {
        let controller = FormController(form: VMForm())
        let view = NavigationStack {
            Text("body").formToolbar(controller: controller) { /* submit */ }
        }
        _renderOnce(view)
    }

    @Test("Custom titles and preventsAccidentalDismiss=false are accepted")
    func formToolbarCustomTitles() {
        let controller = FormController(form: VMForm())
        let view = NavigationStack {
            Text("body").formToolbar(
                controller: controller,
                cancelTitle: "Close",
                submitTitle: "Create",
                preventsAccidentalDismiss: false,
            ) { /* submit */ }
        }
        _renderOnce(view)
    }
}

// MARK: - FormBindFocusViewModifier

/// `@FocusState` is `View`-only, so the smoke test for `.formBindFocus(_:on:)`
/// needs a tiny hosting view that owns the `@FocusState` and applies the modifier.
private struct FormBindFocusHostView: View {
    let controller: FormController<VMForm>
    @FocusState var focus: PartialKeyPath<VMForm>?

    var body: some View {
        Text("body").formBindFocus($focus, on: controller)
    }
}

@MainActor
@Suite("FormBindFocusViewModifier")
struct FormBindFocusViewModifierTests {

    @Test("View extension `.formBindFocus(_:on:)` builds a modified view without crashing")
    func formBindFocusBuilds() {
        let controller = FormController(form: VMForm())
        _renderOnce(FormBindFocusHostView(controller: controller))
    }
}

// MARK: - FocusedOnViewModifier

/// `.focused(on:equals:)` doesn't require the consumer to declare `@FocusState`,
/// but it does require a `Binding<FormController<T>>`. The smoke test needs a
/// hosting view to materialise that binding via `@State`.
private struct FocusedOnHostView: View {
    @State var controller: FormController<VMForm>

    var body: some View {
        Text("body").focused(on: $controller, equals: \.name)
    }
}

@MainActor
@Suite("FocusedOnViewModifier")
struct FocusedOnViewModifierTests {

    @Test("View extension `.focused(on:equals:)` builds a modified view without crashing")
    func focusedOnBuilds() {
        _renderOnce(FocusedOnHostView(controller: FormController(form: VMForm())))
    }
}

// MARK: - Helpers

/// Renders a SwiftUI view into an `ImageRenderer` so the modifier's `body` is invoked at least once.
/// This is enough to drive coverage of the view-modifier construction and body code paths.
@MainActor
private func _renderOnce<V: View>(_ view: V) {
    let renderer = ImageRenderer(content: view)
    // Touching cgImage forces SwiftUI to evaluate the view graph (and therefore invoke body()).
    _ = renderer.cgImage
}
