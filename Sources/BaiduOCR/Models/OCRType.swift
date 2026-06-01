import Foundation

enum OCRType: String, CaseIterable, Identifiable {
    case generalBasic
    case accurateBasic
    case handwriting
    case numbers
    case qrcode
    case table

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generalBasic:  return "通用文字识别(标准)"
        case .accurateBasic: return "通用文字识别(高精度)"
        case .handwriting:   return "手写文字识别"
        case .numbers:       return "数字识别"
        case .qrcode:        return "二维码识别"
        case .table:         return "表格文字识别"
        }
    }

    var endpoint: String {
        switch self {
        case .generalBasic:  return "/rest/2.0/ocr/v1/general_basic"
        case .accurateBasic: return "/rest/2.0/ocr/v1/accurate_basic"
        case .handwriting:   return "/rest/2.0/ocr/v1/handwriting"
        case .numbers:       return "/rest/2.0/ocr/v1/numbers"
        case .qrcode:        return "/rest/2.0/ocr/v1/qrcode"
        case .table:         return "/rest/2.0/ocr/v1/table"
        }
    }

    var maxImageSizeMB: Int {
        self == .table ? 10 : 4
    }
}
