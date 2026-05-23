import Testing
import SwiftUI
@testable import FormsKit

// MARK: - Fixtures

private struct VMForm: ValidatableForm, SubmittableForm {
    @Validate(name: "name", .isNotEmpty(message: "Required"))
    var name: String = ""

    var validates: [ValidateAccessor<Self>] { [.init(\._name)] }

    @MainActor
    func submit() async throws -> String { name }
}

// MARK: - ValidatorViewModifier

@MainActor
@Suite("ValidatorViewModifier")
struct ValidatorViewModifierTests {

    @Test("View extension `.validator(state:)` builds a modified view without crashing — .idle branch")
    func validatorIdle() {
        let view = Text("hello").validator(
            state: Validate<String>.State.idle
        )
        // Force SwiftUI to instantiate the modifier's body by rendering once into a host.
        _renderOnce(view)
    }

    @Test("View extension `.validator(state:)` exercises the .invalid messages branch")
    func validatorInvalid() {
        let view = Text("hello").validator(
            state: Validate<String>.State.invalid(messages: ["a", "b"])
        )
        _renderOnce(view)
    }

    @Test("Custom alignment and spacing arguments are accepted")
    func validatorCustomLayout() {
        let view = Text("hello").validator(
            state: Validate<String>.State.invalid(messages: ["x"]),
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

// MARK: - Helpers

/// Renders a SwiftUI view into an `ImageRenderer` so the modifier's `body` is invoked at least once.
/// This is enough to drive coverage of the view-modifier construction and body code paths.
@MainActor
private func _renderOnce<V: View>(_ view: V) {
    let renderer = ImageRenderer(content: view)
    // Touching cgImage forces SwiftUI to evaluate the view graph (and therefore invoke body()).
    _ = renderer.cgImage
}
