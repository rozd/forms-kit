// FormsKitSwiftUI re-exports real SwiftUI, or SkipSwiftUI in Skip bridge
// builds. The import must stay unconditional: the bridge generator mirrors it
// into the generated *_Bridge.swift files. See FormsKitSwiftUI.swift.
import FormsKitSwiftUI

// MARK: - View Extension

// SKIP @nobridge
public extension View {

    func formBindFocus<T>(
        _ focus: FocusState<PartialKeyPath<T>?>.Binding,
        on controller: FormController<T>
    ) -> some View {
        self
            .onChange(of: focus.wrappedValue) { _, new in
                if controller.focus != new {
                    controller.focus = new
                }
            }
            .onChange(of: controller.focus) { _, new in
                guard focus.wrappedValue != new else { return }
                Task { @MainActor in
                    focus.wrappedValue = new
                }
            }
    }
}
