import Foundation
import FirebaseCore
import FirebaseFirestore
import Dependencies

final class AuthSessionManagerImpl: AuthSessionManager {

    static var usersPath: String!

    private static let nameField = "name"

    private static let idFiled = "id"

    private static let usernameField = "username"

    private static let emojiField = "emoji"

    private var db: Firestore {
        Firestore.firestore()
    }

    private let encoder = Firestore.Encoder()

    func checkAlreadyProvidedInfoScopes(for userId: String) async throws -> Set<AdditionalAuthInfoScope> {
        let documentRef = self.db.collection(Self.usersPath).document(userId)
        let document = try await documentRef.getDocument()

        guard document.exists, let data = document.data() else {
            return []
        }

        var scopes = Set<AdditionalAuthInfoScope>()

        if data[Self.nameField] != nil {
            scopes.insert(.name)
        }

        if data[Self.usernameField] != nil {
            scopes.insert(.username)
        }

        if data[Self.emojiField] != nil {
            scopes.insert(.emoji)
        }

        return scopes
    }

    func update(name: String, for userId: String) async throws {
        let documentRef = self.db.collection(Self.usersPath).document(userId)
        let document = try await documentRef.getDocument()

        guard name.allSatisfy({ character in
            character.isLetter || character.isNumber || character.isWhitespace
        }) else {
            throw AuthSessionManagerError.containsInvalidCharacters
        }

        let data = [
            "\(Self.idFiled)": userId,
            "\(Self.nameField)": name
        ]

        if document.exists {
            try await documentRef.updateData(data)
        } else {
            try await documentRef.setData(data)
        }
    }
    
    func update(username: String, for userId: String) async throws {
        guard username.count >= 5 else {
            throw AuthSessionManagerError.usernameTooShort
        }

        guard username.allSatisfy({ character in
            character.isLetter || character.isNumber
        }) else {
            throw AuthSessionManagerError.containsInvalidCharacters
        }

        let snapshot = try await self.db.collection(Self.usersPath)
            .whereField(Self.usernameField, isEqualTo: username).getDocuments()

        if !snapshot.isEmpty && !(snapshot.documents.first?.documentID == userId) {
            throw AuthSessionManagerError.usernameAlreadyExists
        }

        let documentRef = self.db.collection(Self.usersPath).document(userId)
        let document = try await documentRef.getDocument()

        let data = [
            "\(Self.idFiled)": userId,
            "\(Self.usernameField)": username
        ]

        if document.exists {
            try await documentRef.updateData(data)
        } else {
            try await documentRef.setData(data)
        }
    }

    func update(emoji: String, for userId: String) async throws {
        let documentRef = self.db.collection(Self.usersPath).document(userId)
        let document = try await documentRef.getDocument()

        let data = [
            "\(Self.idFiled)": userId,
            "\(Self.emojiField)": emoji
        ]
        
        if document.exists {
            try await documentRef.updateData(data)
        } else {
            try await documentRef.setData(data)
        }
    }

}
