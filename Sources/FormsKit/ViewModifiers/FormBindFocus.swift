// `SKIP` covers the skipstone bridge generator (which parses with SKIP defined
// and SKIP_BRIDGE undefined); `SKIP_BRIDGE` covers the two real bridge compiles
// (Android cross-compile, Robolectric host). Apple builds take the else branch.
#if SKIP || SKIP_BRIDGE
import SkipSwiftUI
#else
import SwiftUI
#endif

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
