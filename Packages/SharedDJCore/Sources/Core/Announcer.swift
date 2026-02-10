import Foundation

public enum Announcer: String, CaseIterable, Identifiable, Codable {
    case bigBill = "big-bill"
    case carlos = "carlos"
    case tommy = "tommy"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .bigBill: return "Big Bill"
        case .carlos: return "Carlos"
        case .tommy: return "Tommy"
        }
    }

    public var fileCode: String {
        rawValue
    }

    public var voiceId: String {
        switch self {
        case .bigBill: return "f4HZwL9UpBpdxFJROWww"
        case .carlos: return "cxTfloXxmtcB5XslCKWk"
        case .tommy: return "CoRFx057hOgzPkNPqOWC"
        }
    }

    public init(code: String) {
        self = Announcer(rawValue: code) ?? .bigBill
    }
}
