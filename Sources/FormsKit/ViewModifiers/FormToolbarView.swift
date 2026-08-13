// FormsKitSwiftUI re-exports real SwiftUI, or SkipSwiftUI in Skip bridge
// builds. The import must stay unconditional: the bridge generator mirrors it
// into the generated *_Bridge.swift files. See FormsKitSwiftUI.swift.
import FormsKitSwiftUI

public struct FormToolbarView: View {
    // internal (not private): Skip's Android bridge for SwiftUI types
    // cannot reach private property-wrapper storage.
    @Environment(\.dismiss) var dismiss

    @State var showsDiscardWarning: Bool = false

    let content: AnyView
    let cancelTitle: String
    let submitTitle: String
    let preventsAccidentalDismiss: Bool
    let isDirty: () -> Bool
    let isLoading: () -> Bool
    let validateReturningIsValid: () -> Bool
    let onSubmit: () -> Void

    public var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle, action: cancelTapped)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle, action: submitTapped)
                        .bold()
                        .disabled(!isDirty() || isLoading())
                }
            }
            .interactiveDismissDisabled(preventsAccidentalDismiss && isDirty())
            .confirmationDialog("Discard Changes?", isPresented: $showsDiscardWarning) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
    }

    func cancelTapped() {
        if preventsAccidentalDismiss && isDirty() {
            showsDiscardWarning = true
        } else {
            dismiss()
        }
    }

    func submitTapped() {
        if validateReturningIsValid() {
            onSubmit()
        }
    }
}

// MARK: - View Extension

// SKIP @nobridge
public extension View {

    func formToolbar<T: ValidatableForm & SubmittableForm>(
        controller: FormController<T>,
        cancelTitle: String = "Cancel",
        submitTitle: String = "Submit",
        preventsAccidentalDismiss: Bool = true,
        onSubmit: @escaping () -> Void
    ) -> some View {
        FormToolbarView(
            content: AnyView(self),
            cancelTitle: cancelTitle,
            submitTitle: submitTitle,
            preventsAccidentalDismiss: preventsAccidentalDismiss,
            isDirty: { controller.isDirty },
            isLoading: { controller.isLoading },
            validateReturningIsValid: { controller.validate(); return controller.form.isValid },
            onSubmit: onSubmit
        )
    }
}
