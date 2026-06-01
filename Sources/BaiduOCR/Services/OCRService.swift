import AppKit
import Foundation

final class OCRService: @unchecked Sendable {
    private let authService = AuthService()
    private let baseURL = "https://aip.baidubce.com"

    func recognize(image: NSImage, type: OCRType, apiKey: String, secretKey: String) async throws -> String {
        let token = try await authService.getToken(apiKey: apiKey, secretKey: secretKey)
        let base64 = ImageProcessor.toBase64(image, maxSizeMB: type.maxImageSizeMB)

        guard !base64.isEmpty else {
            throw OCRError.imageConversionFailed
        }

        return try await performRequest(
            imageBase64: base64,
            type: type,
            token: token,
            apiKey: apiKey,
            secretKey: secretKey,
            isRetry: false
        )
    }

    private func performRequest(
        imageBase64: String,
        type: OCRType,
        token: String,
        apiKey: String,
        secretKey: String,
        isRetry: Bool
    ) async throws -> String {
        let url = URL(string: baseURL + type.endpoint + "?access_token=\(token)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var params: [String: String] = ["image": imageBase64]
        if type != .qrcode && type != .table {
            params["detect_direction"] = "false"
            params["paragraph"] = "false"
            params["probability"] = "false"
        }
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)

        // Check for token expiry
        let errorCheck = try? JSONDecoder().decode(OCRResponse.self, from: data)
        if let code = errorCheck?.errorCode, (code == 110 || code == 111), !isRetry {
            await authService.invalidateCache()
            let newToken = try await authService.getToken(apiKey: apiKey, secretKey: secretKey)
            return try await performRequest(
                imageBase64: imageBase64,
                type: type,
                token: newToken,
                apiKey: apiKey,
                secretKey: secretKey,
                isRetry: true
            )
        }

        return try parseResponse(data: data, type: type)
    }

    private func parseResponse(data: Data, type: OCRType) throws -> String {
        switch type {
        case .table:
            return try parseTableResponse(data: data)
        case .qrcode:
            return try parseQRCodeResponse(data: data)
        default:
            return try parseTextResponse(data: data)
        }
    }

    private func parseTextResponse(data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(OCRResponse.self, from: data)

        if let code = decoded.errorCode {
            throw OCRError.apiError(code: code, message: decoded.errorMsg ?? "")
        }

        guard let results = decoded.wordsResult, !results.isEmpty else {
            return "未识别到文字"
        }

        return results.map { $0.words }.joined(separator: "\n")
    }

    private func parseQRCodeResponse(data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(QRCodeResponse.self, from: data)

        if let code = decoded.errorCode {
            throw OCRError.apiError(code: code, message: decoded.errorMsg ?? "")
        }

        guard let results = decoded.wordsResult, !results.isEmpty else {
            return "未识别到二维码"
        }

        return results.compactMap { item in
            let typeStr = item.type.map { "[\($0)] " } ?? ""
            let content = item.text?.joined(separator: "\n") ?? ""
            return typeStr + content
        }.joined(separator: "\n---\n")
    }

    private func parseTableResponse(data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(TableOCRResponse.self, from: data)

        if let code = decoded.errorCode {
            throw OCRError.apiError(code: code, message: decoded.errorMsg ?? "")
        }

        guard let tables = decoded.tablesResult, !tables.isEmpty else {
            return "未识别到表格"
        }

        return tables.enumerated().map { tableIndex, table in
            var result = tableIndex > 0 ? "\n--- Table \(tableIndex + 1) ---\n" : ""
            guard let rows = table.tableStructure?.rows else {
                return result + "(空表格)"
            }
            // Calculate column widths for alignment
            var colWidths: [Int] = []
            for row in rows {
                for (ci, cell) in (row.cells ?? []).enumerated() {
                    let len = (cell.words ?? "").count
                    while colWidths.count <= ci { colWidths.append(0) }
                    colWidths[ci] = max(colWidths[ci], len + 2)
                }
            }
            for (ri, row) in rows.enumerated() {
                let cells = row.cells ?? []
                for (ci, cell) in cells.enumerated() {
                    let word = cell.words ?? ""
                    let pad = ci < colWidths.count ? colWidths[ci] : word.count + 2
                    result += word.padding(toLength: pad, withPad: " ", startingAt: 0)
                    result += "|"
                }
                result += "\n"
                if ri == 0 {
                    for w in colWidths {
                        result += String(repeating: "-", count: w) + "+"
                    }
                    result += "\n"
                }
            }
            return result
        }.joined(separator: "\n")
    }
}

enum OCRError: LocalizedError {
    case imageConversionFailed
    case apiError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "图片转换失败"
        case .apiError(let code, let message):
            return apiErrorMessage(code: code, message: message)
        }
    }

    private func apiErrorMessage(code: Int, message: String) -> String {
        switch code {
        case 17: return "日配额已用完，请明天再试"
        case 18: return "请求过于频繁，请稍后"
        case 19: return "总配额已用完"
        case 100: return "参数错误: \(message)"
        case 110: return "Token无效"
        case 111: return "Token已过期"
        case 216100: return "图片格式无效"
        case 216201: return "图片过大"
        case 282000: return "服务器内部错误，请重试"
        default: return "API错误 [\(code)]: \(message)"
        }
    }
}
