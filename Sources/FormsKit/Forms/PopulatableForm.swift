public protocol PopulatableForm {
    associatedtype Data

    @MainActor
    mutating func populate(from data: Data)
}
