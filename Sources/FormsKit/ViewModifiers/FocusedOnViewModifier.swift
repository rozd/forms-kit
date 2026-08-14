// `SKIP` covers the skipstone bridge generator (which parses with SKIP defined
// and SKIP_BRIDGE undefined); `SKIP_BRIDGE` covers the two real bridge compiles
// (Android cross-compile, Robolectric host). Apple builds take the else branch.
#if SKIP || SKIP_BRIDGE
import SkipSwiftUI
#else
import SwiftUI
#endif

// Dual structure: the fully-typed generic modifier serves non-bridge builds;
// the erased twin below serves bridge builds (skip-bridge cannot represent
// generic types). `!SKIP` additionally hides the generic variant from the
// skipstone generator, which parses with SKIP defined but SKIP_BRIDGE
// undefined and would otherwise try to bridge it.
#if !SKIP_BRIDGE && !SKIP
public struct FocusedOnViewModifier<T, V>: ViewModifier {
    let controller: FormController<T>
    let fieldKeyPath: KeyPath<T, V>

    @FocusState var isFocused: Bool

    public func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: controller.focus) { _, new in
                let shouldBeFocused = (new == fieldKeyPath)
                guard isFocused != shouldBeFocused else {
                    return
                }
                Task { @MainActor in
                    isFocused = shouldBeFocused
                }
            }
            .onChange(of: isFocused) { _, new in
                if new {
                    if controller.focus != fieldKeyPath {
                        controller.focus = fieldKeyPath
                    }
                } else if controller.focus == fieldKeyPath {
                    controller.focus = nil
                }
            }
    }
}
#endif

// Bridged twin for Android: non-generic (skip-bridge requirement), reaching
// the controller through `AnyFormController`'s closures and comparing focus
// identity as `AnyKeyPath`. Must NOT carry `// SKIP @nobridge` — the
// generated Kotlin peer is what makes the modifier apply on Android. Keep
// this body in sync with the generic variant above.
public struct ErasedFocusedOnModifier: ViewModifier {
    let controller: AnyFormController
    let fieldKeyPath: AnyKeyPath

    // internal (not private): Skip's Android bridge for SwiftUI types
    // cannot reach private property-wrapper storage.
    @FocusState var isFocused: Bool

    public func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: controller.getFocus()) { _, new in
                let shouldBeFocused = (new == fieldKeyPath)
                guard isFocused != shouldBeFocused else {
                    return
                }
                Task { @MainActor in
                    isFocused = shouldBeFocused
                }
            }
            .onChange(of: isFocused) { _, new in
                if new {
                    if controller.getFocus() != fieldKeyPath {
                        controller.setFocus(fieldKeyPath)
                    }
                } else if controller.getFocus() == fieldKeyPath {
                    controller.setFocus(nil)
                }
            }
    }
}

// MARK: - View Extension

// SKIP @nobridge
public extension View {

    func focused<T, V>(
        on controller: Binding<FormController<T>>,
        equals keyPath: KeyPath<T, V>
    ) -> some View {
        #if SKIP || SKIP_BRIDGE
        return modifier(ErasedFocusedOnModifier(
            controller: AnyFormController(focusing: controller.wrappedValue),
            fieldKeyPath: keyPath
        ))
        #else
        return modifier(FocusedOnViewModifier(
            controller: controller.wrappedValue,
            fieldKeyPath: keyPath
        ))
        #endif
    }
}
