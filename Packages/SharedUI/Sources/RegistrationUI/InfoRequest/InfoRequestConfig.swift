import Foundation

final class InfoRequestConfig {
    let title: String
    let continueButtonTitle: String
    let textFieldLeadingSymbol: String?
    let placeholder: String
    let completion: (String) async throws -> Void

    init(title: String,
         continueButtonTitle: String,
         textFieldLeadingSymbol: String? = nil,
         placeholder: String,
         completion: @escaping (String) async throws -> Void) {
        self.title = title
        self.continueButtonTitle = continueButtonTitle
        self.textFieldLeadingSymbol = textFieldLeadingSymbol
        self.placeholder = placeholder
        self.completion = completion
    }
}
