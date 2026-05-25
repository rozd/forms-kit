import Observation

@MainActor
@Observable
public final class FormController<T> {
    enum State {
        case initial
        case loading
        case success
        case failure(Error)
    }

    public var form: T

    public var focus: PartialKeyPath<T>? = nil

    public var shouldFocusFirstInvalidFieldOnSubmit: Bool = true

    private(set) var state: State = .initial

    public init(form: T) {
        self.form = form
    }
}

// MARK: Controller Extension for Validatable Forms

extension FormController where T: ValidatableForm {

    var isDirty: Bool {
        for field in form.validatedFields {
            if field.isDirty(form) {
                return true
            }
        }
        return false
    }

    var isValid: Bool {
        form.isValid
    }

    func validate() {
        for field in form.validatedFields {
            let _ = field.validate(&form)
        }
    }

    public func focusFirstInvalidField() {
        for field in form.validatedFields where !field.isValid(form) {
            focus = field.keyPath
            return
        }
    }

}

// MARK: Controller Extension for Submittable and Validatable Forms

public extension FormController where T: SubmittableForm, T: ValidatableForm {

    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    func submit() async throws -> T.Output {
        self.validate()
        if !form.isValid {
            if shouldFocusFirstInvalidFieldOnSubmit {
                focusFirstInvalidField()
            }
            throw ValidationError.invalid(errors: form.validationErrors)
        }
        state = .loading
        do {
            let output = try await form.submit()
            state = .success
            return output
        } catch {
            state = .failure(error)
            guard case .invalid(let errors) = (error as? ValidationError) else {
                throw error
            }
            for accessor in form.validatedFields {
                if let property = accessor.name(form),
                   let messages = errors[property] {
                    accessor.markAsInvalid(&form, messages)
                }
            }
            if shouldFocusFirstInvalidFieldOnSubmit {
                focusFirstInvalidField()
            }
            throw error
        }
    }

}
