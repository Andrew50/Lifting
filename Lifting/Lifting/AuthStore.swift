//
//  AuthStore.swift
//  Lifting
//

import Combine
import CryptoKit
import Foundation
import GRDB

enum AuthError: LocalizedError {
    case nameRequired
    case emailRequired
    case invalidEmail
    case passwordTooShort
    case emailAlreadyTaken
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .nameRequired: return "Please enter your name."
        case .emailRequired: return "Please enter your email."
        case .invalidEmail: return "Please enter a valid email address."
        case .passwordTooShort: return "Password must be at least 6 characters."
        case .emailAlreadyTaken: return "An account with this email already exists."
        case .invalidCredentials: return "Invalid email or password."
        }
    }
}

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var currentUser: UserRecord?

    private let dbQueue: DatabaseQueue
    private static let sessionUserIdKey = "loggedInUserId"

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue

        // Restore session inline without calling a method (avoids accessing
        // self before all stored properties are initialised).
        if let userId = UserDefaults.standard.string(forKey: Self.sessionUserIdKey) {
            self.currentUser = try? dbQueue.read { db in
                try UserRecord.fetchOne(db, key: userId)
            }
        }
    }

    var isLoggedIn: Bool { currentUser != nil }

    // MARK: - Sign up

    func signUp(name: String, email: String, password: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty else { throw AuthError.nameRequired }
        guard !trimmedEmail.isEmpty else { throw AuthError.emailRequired }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 6 else { throw AuthError.passwordTooShort }

        let passwordHash = Self.hashPassword(password)
        let now = Date().timeIntervalSince1970

        let user = UserRecord(
            id: UUID().uuidString,
            name: trimmedName,
            email: trimmedEmail,
            passwordHash: passwordHash,
            createdAt: now
        )

        do {
            try dbQueue.write { db in
                try user.insert(db)
            }
        } catch {
            // GRDB throws DatabaseError for UNIQUE constraint violations
            if "\(error)".contains("UNIQUE constraint failed") {
                throw AuthError.emailAlreadyTaken
            }
            throw error
        }

        currentUser = user
        persistSession(userId: user.id)
    }

    // MARK: - Log in

    func logIn(email: String, password: String) throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else { throw AuthError.emailRequired }

        let passwordHash = Self.hashPassword(password)

        // --- DEV STUB START ---
        // Store raw credentials for future server integration
        UserDefaults.standard.set(trimmedEmail, forKey: "stub_last_email")
        UserDefaults.standard.set(password, forKey: "stub_last_password")

        // In a real app, we'd only check the DB. For this stub, if the user doesn't
        // exist locally, we'll create them so login "just works" during dev.
        let existingUser: UserRecord? = try dbQueue.read { db in
            try UserRecord
                .filter(UserRecord.Columns.email == trimmedEmail)
                .fetchOne(db)
        }

        let user: UserRecord
        if let existing = existingUser {
            // If user exists but password changed, update local hash (stub behavior)
            if existing.passwordHash != passwordHash {
                var updated = existing
                updated.passwordHash = passwordHash
                try dbQueue.write { db in
                    try updated.update(db)
                }
                user = updated
            } else {
                user = existing
            }
        } else {
            // Auto-create local user record for this email
            let newUser = UserRecord(
                id: UUID().uuidString,
                name: trimmedEmail.components(separatedBy: "@").first?.capitalized ?? "User",
                email: trimmedEmail,
                passwordHash: passwordHash,
                createdAt: Date().timeIntervalSince1970
            )
            try dbQueue.write { db in
                try newUser.insert(db)
            }
            user = newUser
        }
        // --- DEV STUB END ---

        currentUser = user
        persistSession(userId: user.id)
    }

    // MARK: - Log out

    func logOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: Self.sessionUserIdKey)
    }

    // MARK: - Session persistence

    private func persistSession(userId: String) {
        UserDefaults.standard.set(userId, forKey: Self.sessionUserIdKey)
    }

    // MARK: - Password hashing

    private static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
