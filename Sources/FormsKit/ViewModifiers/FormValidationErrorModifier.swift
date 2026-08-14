// `SKIP` covers the skipstone bridge generator (which parses with SKIP defined
// and SKIP_BRIDGE undefined); `SKIP_BRIDGE` covers the two real bridge compiles
// (Android cross-compile, Robolectric host). Apple builds take the else branch.
#if SKIP || SKIP_BRIDGE
import SkipSwiftUI
#else
import SwiftUI
#endif

// Non-generic on every platform (the generic `Validated<T>.State` is unpacked
// into plain `[String]?` at the call site), so a single bridged modifier
// serves both. Must NOT carry `// SKIP @nobridge` — the generated Kotlin peer
// is what makes the modifier apply on Android.
public struct FormValidationErrorModifier: ViewModifier {
    let errorMessages: [String]?
    let alignment: HorizontalAlignment
    let spacing: CGFloat?

    public func body(content: Content) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
            if let errorMessages {
                ForEach(errorMessages, id: \.self) { message in
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - View Extension

// SKIP @nobridge
public extension View {

    func formValidationError<T: Equatable>(
        for state: Validated<T>.State,
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = 4
    ) -> some View {
        let errorMessages: [String]?
        if case let .invalid(messages) = state {
            errorMessages = messages
        } else {
            errorMessages = nil
        }
        return modifier(FormValidationErrorModifier(
            errorMessages: errorMessages,
            alignment: alignment,
            spacing: spacing
        ))
    }
}
