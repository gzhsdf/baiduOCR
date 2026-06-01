import Foundation

struct APICredentials: Codable {
    var apiKey: String
    var secretKey: String

    var isValid: Bool {
        !apiKey.isEmpty && !secretKey.isEmpty
    }
}
