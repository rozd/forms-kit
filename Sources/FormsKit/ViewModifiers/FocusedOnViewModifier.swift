import SwiftUI

// SKIP @nobridge
public struct FocusedOnViewModifier<T, V>: ViewModifier {

    let controller: Binding<FormController<T>>

    let keyPath: KeyPath<T, V>

    // internal (not private): Skip's Android bridge for SwiftUI types
    // cannot reach private property-wrapper storage.
    @FocusState var isFocused: Bool

    public func body(content: Content) -> some View {
        let myKeyPath: PartialKeyPath<T> = keyPath
        return content
            .focused($isFocused)
            .onChange(of: controller.wrappedValue.focus) { _, new in
                let shouldBeFocused = (new == myKeyPath)
                guard isFocused != shouldBeFocused else {
                    return
                }
                Task { @MainActor in
                    isFocused = shouldBeFocused
                }
            }
            .onChange(of: isFocused) { _, new in
                if new {
                    if controller.wrappedValue.focus != myKeyPath {
                        controller.wrappedValue.focus = myKeyPath
                    }
                } else if controller.wrappedValue.focus == myKeyPath {
                    controller.wrappedValue.focus = nil
                }
            }
    }
}

// MARK: - View Extension

public extension View {

    func focused<T, V>(
        on controller: Binding<FormController<T>>,
        equals keyPath: KeyPath<T, V>
    ) -> some View {
        modifier(
            FocusedOnViewModifier(
                controller: controller,
                keyPath: keyPath
            )
        )
    }
}
