import SwiftUI

public struct FormValidationErrorModifier<T: Equatable>: ViewModifier {

    let state: Validated<T>.State

    let alignment: HorizontalAlignment
    let spacing: CGFloat?

    init(
        state: Validated<T>.State,
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = 4
    ) {
        self.state = state
        self.alignment = alignment
        self.spacing = spacing
    }

    public func body(content: Content) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
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

// MARK: - View Extension

public extension View {

    func formValidationError<T: Equatable>(
        for state: Validated<T>.State,
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat? = 4
    ) -> some View {
        modifier(
            FormValidationErrorModifier<T>(
                state: state,
                alignment: alignment,
                spacing: spacing
            )
        )
    }
}
