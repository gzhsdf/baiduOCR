import Foundation

// MARK: - Common response for text-based OCR

struct OCRResponse: Decodable {
    let logId: Int64?
    let wordsResultNum: Int?
    let wordsResult: [WordItem]?
    let errorCode: Int?
    let errorMsg: String?

    enum CodingKeys: String, CodingKey {
        case logId = "log_id"
        case wordsResultNum = "words_result_num"
        case wordsResult = "words_result"
        case errorCode = "error_code"
        case errorMsg = "error_msg"
    }
}

struct WordItem: Decodable {
    let words: String
}

// MARK: - QR code response

struct QRCodeResponse: Decodable {
    let logId: Int64?
    let wordsResultNum: Int?
    let wordsResult: [QRCodeItem]?
    let errorCode: Int?
    let errorMsg: String?

    enum CodingKeys: String, CodingKey {
        case logId = "log_id"
        case wordsResultNum = "words_result_num"
        case wordsResult = "words_result"
        case errorCode = "error_code"
        case errorMsg = "error_msg"
    }
}

struct QRCodeItem: Decodable {
    let type: String?
    let text: [String]?
}

// MARK: - Table response

struct TableOCRResponse: Decodable {
    let logId: Int64?
    let tablesResult: [TableResultItem]?
    let errorCode: Int?
    let errorMsg: String?

    enum CodingKeys: String, CodingKey {
        case logId = "log_id"
        case tablesResult = "tables_result"
        case errorCode = "error_code"
        case errorMsg = "error_msg"
    }
}

struct TableResultItem: Decodable {
    let tableStructure: TableStructure?

    enum CodingKeys: String, CodingKey {
        case tableStructure = "table_structure"
    }
}

struct TableStructure: Decodable {
    let rows: [TableRow]?
}

struct TableRow: Decodable {
    let cells: [TableCell]?
}

struct TableCell: Decodable {
    let words: String?
}

// MARK: - Auth response

struct AuthResponse: Decodable {
    let accessToken: String?
    let expiresIn: Int?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Token cache

struct TokenCache: Codable {
    let token: String
    let expiresAt: TimeInterval
}
