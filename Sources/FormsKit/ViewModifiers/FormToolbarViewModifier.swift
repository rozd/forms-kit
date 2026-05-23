import SwiftUI

public struct FormToolbarViewModifier<T: ValidatableForm & SubmittableForm>: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    @State private var showsDiscardWarning: Bool = false

    let controller: FormController<T>

    let cancelTitle: String

    let submitTitle: String

    let preventsAccidentalDismiss: Bool

    let onSubmit: (() -> Void)

    public func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        if preventsAccidentalDismiss && controller.isDirty {
                            showsDiscardWarning = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle) {
                        controller.validate()
                        if controller.form.isValid {
                            onSubmit()
                        }
                    }
                    .bold()
                    .disabled(!controller.isDirty || controller.isLoading)
                }
            }
            .interactiveDismissDisabled(preventsAccidentalDismiss && controller.isDirty)
            .confirmationDialog("Discard Changes?", isPresented: $showsDiscardWarning) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
    }
}

// MARK: - View Extension

public extension View {

    func formToolbar<T: ValidatableForm & SubmittableForm>(
        controller: FormController<T>,
        cancelTitle: String = "Cancel",
        submitTitle: String = "Submit",
        preventsAccidentalDismiss: Bool = true,
        onSubmit: @escaping () -> Void,
    ) -> some View {
        self.modifier(
            FormToolbarViewModifier(
                controller: controller,
                cancelTitle: cancelTitle,
                submitTitle: submitTitle,
                preventsAccidentalDismiss: preventsAccidentalDismiss,
                onSubmit: onSubmit
            )
        )
    }
}
