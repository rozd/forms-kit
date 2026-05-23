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

    private(set) var state: State = .initial

    public init(form: T) {
        self.form = form
    }
}

// MARK: Controller Extension for Validatable Forms

extension FormController where T: ValidatableForm {

    var isDirty: Bool {
        for accessor in form.validates {
            if accessor.isDirty(form) {
                return true
            }
        }
        return false
    }

    var isValid: Bool {
        form.isValid
    }

    func validate() {
        for accessor in form.validates {
            let _ = accessor.validate(&form)
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
            for accessor in form.validates {
                if let property = accessor.name(form),
                   let messages = errors[property] {
                    accessor.markAsInvalid(&form, messages)
                }
            }
            throw error
        }
    }

}
