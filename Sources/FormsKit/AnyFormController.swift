// Type-erased facade over `FormController<T>` for the bridged (non-generic)
// view modifiers: skip-bridge cannot represent generic types, so the erased
// modifier variants store this instead of `FormController<T>` and reach the
// controller through closures. Internal: consumers only ever see the generic
// `FormController<T>` through the public `View` extension functions.
@MainActor
struct AnyFormController {
    let isDirty: () -> Bool
    let isLoading: () -> Bool
    let validateReturningIsValid: () -> Bool
    let getFocus: () -> AnyKeyPath?
    let setFocus: (AnyKeyPath?) -> Void

    init<T: ValidatableForm & SubmittableForm>(_ controller: FormController<T>) {
        self.isDirty = { controller.isDirty }
        self.isLoading = { controller.isLoading }
        self.validateReturningIsValid = { controller.validate(); return controller.form.isValid }
        self.getFocus = { controller.focus }
        self.setFocus = { controller.focus = $0.flatMap { $0 as? PartialKeyPath<T> } }
    }

    /// Focus-only erasure for `focused(on:equals:)`, whose form type carries no
    /// validation constraints. The validation closures are inert stubs.
    init<T>(focusing controller: FormController<T>) {
        self.isDirty = { false }
        self.isLoading = { false }
        self.validateReturningIsValid = { false }
        self.getFocus = { controller.focus }
        self.setFocus = { controller.focus = $0.flatMap { $0 as? PartialKeyPath<T> } }
    }
}
