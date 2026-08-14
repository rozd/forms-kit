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
public struct FormToolbarViewModifier<T: ValidatableForm & SubmittableForm>: ViewModifier {
    @Environment(\.dismiss) var dismiss

    @State var showsDiscardWarning: Bool = false

    let controller: FormController<T>
    let cancelTitle: String
    let submitTitle: String
    let preventsAccidentalDismiss: Bool
    let onSubmit: () -> Void

    public func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle, action: cancelTapped)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle, action: submitTapped)
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

    func cancelTapped() {
        if preventsAccidentalDismiss && controller.isDirty {
            showsDiscardWarning = true
        } else {
            dismiss()
        }
    }

    func submitTapped() {
        controller.validate()
        if controller.form.isValid {
            onSubmit()
        }
    }
}
#endif

// Bridged twin for Android: non-generic (skip-bridge requirement), reaching
// the controller through `AnyFormController`'s closures. Must NOT carry
// `// SKIP @nobridge` — the generated Kotlin peer is exactly what makes the
// modifier apply on Android (an unbridged custom ViewModifier falls back to
// SkipSwiftUI's default `Java_modifier`, an EmptyModifier, and silently
// renders nothing). Keep this body in sync with the generic variant above.
public struct ErasedFormToolbarModifier: ViewModifier {
    // internal (not private): Skip's Android bridge for SwiftUI types
    // cannot reach private property-wrapper storage.
    @Environment(\.dismiss) var dismiss

    @State var showsDiscardWarning: Bool = false

    let controller: AnyFormController
    let cancelTitle: String
    let submitTitle: String
    let preventsAccidentalDismiss: Bool
    let onSubmit: () -> Void

    public func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle, action: cancelTapped)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle, action: submitTapped)
                        .bold()
                        .disabled(!controller.isDirty() || controller.isLoading())
                }
            }
            .interactiveDismissDisabled(preventsAccidentalDismiss && controller.isDirty())
            .confirmationDialog("Discard Changes?", isPresented: $showsDiscardWarning) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
    }

    func cancelTapped() {
        if preventsAccidentalDismiss && controller.isDirty() {
            showsDiscardWarning = true
        } else {
            dismiss()
        }
    }

    func submitTapped() {
        if controller.validateReturningIsValid() {
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
        #if SKIP || SKIP_BRIDGE
        return modifier(ErasedFormToolbarModifier(
            controller: AnyFormController(controller),
            cancelTitle: cancelTitle,
            submitTitle: submitTitle,
            preventsAccidentalDismiss: preventsAccidentalDismiss,
            onSubmit: onSubmit
        ))
        #else
        return modifier(FormToolbarViewModifier(
            controller: controller,
            cancelTitle: cancelTitle,
            submitTitle: submitTitle,
            preventsAccidentalDismiss: preventsAccidentalDismiss,
            onSubmit: onSubmit
        ))
        #endif
    }
}
