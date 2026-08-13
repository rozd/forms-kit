// FormsKitSwiftUI re-exports real SwiftUI, or SkipSwiftUI in Skip bridge
// builds. The import must stay unconditional: the bridge generator mirrors it
// into the generated *_Bridge.swift files. See FormsKitSwiftUI.swift.
import FormsKitSwiftUI

// MARK: - View Extension

// SKIP @nobridge
public extension View {

    func formValidationError<T: Equatable>(
        for state: Validated<T>.State,
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = 4
    ) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            self
            if case let .invalid(messages) = state {
                ForEach(messages, id: \.self) { message in
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }
}
