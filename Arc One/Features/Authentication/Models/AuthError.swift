import Foundation

enum AuthError: LocalizedError {
    case missingClientID
    case missingUser
    case emailNotVerified
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Missing Firebase clientID."
        case .missingUser:
            return "Could not read signed-in user."
        case .emailNotVerified:
            return "Please verify your email first. Check your inbox (and spam), then log in again."
        case .invalidInput(let msg):
            return msg
        }
    }
}
