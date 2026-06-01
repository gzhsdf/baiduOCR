import AppKit

struct BatchImageItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    var thumbnail: NSImage?
    var result: String = ""
    var status: Status = .pending

    enum Status: Equatable {
        case pending
        case processing
        case done
        case error(String)

        static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .pending), (.processing, .processing), (.done, .done): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }
}
