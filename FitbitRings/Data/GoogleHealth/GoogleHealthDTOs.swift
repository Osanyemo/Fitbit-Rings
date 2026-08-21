import Foundation

struct GoogleHealthRollUpResponse: Decodable {
    var bucket: [GoogleHealthBucket]
}

struct GoogleHealthBucket: Decodable {
    var dataset: [GoogleHealthDataset]
}

struct GoogleHealthDataset: Decodable {
    var point: [GoogleHealthPoint]
}

struct GoogleHealthListResponse: Decodable {
    var records: [GoogleHealthRecord]
}

struct GoogleHealthRecord: Decodable {
    var startTime: Date?
    var endTime: Date?
    var dataTypeName: String?
    var values: [String: GoogleHealthValue]?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case startTime
        case endTime
        case dataTypeName
        case values
        case metadata
    }
}

struct GoogleHealthPoint: Decodable {
    var startTime: Date?
    var endTime: Date?
    var value: [GoogleHealthValue]
}

struct GoogleHealthValue: Decodable {
    var intVal: Int?
    var fpVal: Double?
    var stringVal: String?
    var mapVal: [String: GoogleHealthValue]?

    var numericValue: Double? {
        if let fpVal { return fpVal }
        if let intVal { return Double(intVal) }
        return nil
    }
}
