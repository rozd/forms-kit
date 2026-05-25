import SwiftUI

public struct FormBindFocusViewModifier<T>: ViewModifier {

    let focus: FocusState<PartialKeyPath<T>?>.Binding

    let controller: FormController<T>

    public func body(content: Content) -> some View {
        content
            .onChange(of: focus.wrappedValue) { _, new in
                Self.syncControllerFocus(controller, to: new)
            }
            .onChange(of: controller.focus) { _, new in
                guard focus.wrappedValue != new else { return }
                Task { @MainActor in
                    focus.wrappedValue = new
                }
            }
    }

    static func syncControllerFocus(
        _ controller: FormController<T>,
        to new: PartialKeyPath<T>?
    ) {
        if controller.focus != new {
            controller.focus = new
        }
    }
}

// MARK: - View Extension

public extension View {

    func formBindFocus<T>(
        _ focus: FocusState<PartialKeyPath<T>?>.Binding,
        on controller: FormController<T>
    ) -> some View {
        modifier(
            FormBindFocusViewModifier(
                focus: focus,
                controller: controller
            )
        )
    }
}
