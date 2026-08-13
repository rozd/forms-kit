// FormsKitSwiftUI re-exports real SwiftUI, or SkipSwiftUI in Skip bridge
// builds. The import must stay unconditional: the bridge generator mirrors it
// into the generated *_Bridge.swift files. See FormsKitSwiftUI.swift.
import FormsKitSwiftUI

public struct FocusedOnView: View {
    let content: AnyView
    let fieldKeyPath: AnyKeyPath
    let currentFocus: () -> AnyKeyPath?
    let setFocus: (AnyKeyPath?) -> Void

    // internal (not private): Skip's Android bridge for SwiftUI types
    // cannot reach private property-wrapper storage.
    @FocusState var isFocused: Bool

    public var body: some View {
        content
            .focused($isFocused)
            .onChange(of: currentFocus()) { _, new in
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
                    if currentFocus() != fieldKeyPath {
                        setFocus(fieldKeyPath)
                    }
                } else if currentFocus() == fieldKeyPath {
                    setFocus(nil)
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
        FocusedOnView(
            content: AnyView(self),
            fieldKeyPath: keyPath,
            currentFocus: { controller.wrappedValue.focus },
            setFocus: { controller.wrappedValue.focus = $0.flatMap { $0 as? PartialKeyPath<T> } }
        )
    }
}
