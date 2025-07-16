import Foundation

enum AuthSessionManagerError: LocalizedError {
    case usernameTooShort
    case usernameAlreadyExists
    case containsInvalidCharacters

    var errorDescription: String? {
        switch self {
        case .usernameTooShort:
            return "Username must be at least 5 characters"
        case .usernameAlreadyExists:
            return "This username is already taken"
        case .containsInvalidCharacters:
            return "Only letters and numbers are allowed"
        }
    }
}
