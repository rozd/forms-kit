// FormsKitSwiftUI re-exports real SwiftUI, or SkipSwiftUI in Skip bridge
// builds. The import must stay unconditional: the bridge generator mirrors it
// into the generated *_Bridge.swift files. See FormsKitSwiftUI.swift.
import FormsKitSwiftUI

// MARK: - FormBindFocusSupport

internal enum FormBindFocusSupport {
    @MainActor
    static func syncControllerFocus<T>(
        _ controller: FormController<T>,
        to new: PartialKeyPath<T>?
    ) {
        if controller.focus != new {
            controller.focus = new
        }
    }
}

// MARK: - View Extension

// SKIP @nobridge
public extension View {

    func formBindFocus<T>(
        _ focus: FocusState<PartialKeyPath<T>?>.Binding,
        on controller: FormController<T>
    ) -> some View {
        self
            .onChange(of: focus.wrappedValue) { _, new in
                FormBindFocusSupport.syncControllerFocus(controller, to: new)
            }
            .onChange(of: controller.focus) { _, new in
                guard focus.wrappedValue != new else { return }
                Task { @MainActor in
                    focus.wrappedValue = new
                }
            }
    }
}
