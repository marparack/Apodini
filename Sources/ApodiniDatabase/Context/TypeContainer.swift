import Foundation

enum TypeContainer: Codable, Equatable {
    case string(String), bool(Bool), int(Int), int8(Int8), int16(Int16), int32(Int32), int64(Int64), uint(UInt), uint8(UInt8), uint16(UInt16), uint32(UInt32), uint64(UInt64), uuid(UUID), float(Float), double(Double), noValue
    
    init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        self = .noValue
        if let value = try? values.decode(Int.self) {
            self = .int(value)
        } else if let value = try? values.decode(Int8.self) {
            self = .int8(value)
        } else if let value = try? values.decode(Int16.self) {
            self = .int16(value)
        } else if let value = try? values.decode(Int32.self) {
            self = .int32(value)
        } else if let value = try? values.decode(Int64.self) {
            self = .int64(value)
        } else if let value = try? values.decode(UInt.self) {
            self = .uint(value)
        } else if let value = try? values.decode(UInt8.self) {
            self = .uint8(value)
        } else if let value = try? values.decode(UInt16.self) {
            self = .uint16(value)
        } else if let value = try? values.decode(UInt32.self) {
            self = .uint32(value)
        } else if let value = try? values.decode(UInt64.self) {
            self = .uint64(value)
        } else if let value = try? values.decode(Double.self) {
            self = .double(value)
        } else if let value = try? values.decode(Float.self) {
            self = .float(value)
        } else if let value = try? values.decode(UUID.self) {
            self = .uuid(value)
        } else if let value = try? values.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? values.decode(String.self) {
            self = .string(value)
        }
    }
    
    init(with anyCodable: AnyCodable?) {
        guard let wrappedValue = anyCodable?.wrappedValue else { self = .noValue; return }
        if let value = wrappedValue as? Int {
            self = .int(value)
        } else if let value = wrappedValue as? Int8 {
            self = .int8(value)
        } else if let value = wrappedValue as? Int16 {
            self = .int16(value)
        } else if let value = wrappedValue as? Int32 {
            self = .int32(value)
        } else if let value = wrappedValue as? Int64 {
            self = .int64(value)
        } else if let value = wrappedValue as? UInt {
            self = .uint(value)
        } else if let value = wrappedValue as? UInt8 {
            self = .uint8(value)
        } else if let value = wrappedValue as? UInt16 {
            self = .uint16(value)
        } else if let value = wrappedValue as? UInt32 {
            self = .uint32(value)
        } else if let value = wrappedValue as? UInt64 {
            self = .uint64(value)
        } else if let value = wrappedValue as? Double {
            self = .double(value)
        } else if let value = wrappedValue as? Float {
            self = .float(value)
        } else if let value = wrappedValue as? UUID {
            self = .uuid(value)
        } else if let value = wrappedValue as? Bool {
            self = .bool(value)
        } else if let value = wrappedValue as? String {
            self = .string(value)
        } else {
            self = .noValue
        }
    }
    
    init(with codable: Codable?) {
        guard let wrappedValue = codable else { self = .noValue; return }
        if let value = wrappedValue as? Int {
            self = .int(value)
        } else if let value = wrappedValue as? Int8 {
            self = .int8(value)
        } else if let value = wrappedValue as? Int16 {
            self = .int16(value)
        } else if let value = wrappedValue as? Int32 {
            self = .int32(value)
        } else if let value = wrappedValue as? Int64 {
            self = .int64(value)
        } else if let value = wrappedValue as? UInt {
            self = .uint(value)
        } else if let value = wrappedValue as? UInt8 {
            self = .uint8(value)
        } else if let value = wrappedValue as? UInt16 {
            self = .uint16(value)
        } else if let value = wrappedValue as? UInt32 {
            self = .uint32(value)
        } else if let value = wrappedValue as? UInt64 {
            self = .uint64(value)
        } else if let value = wrappedValue as? Double {
            self = .double(value)
        } else if let value = wrappedValue as? Float {
            self = .float(value)
        } else if let value = wrappedValue as? UUID {
            self = .uuid(value)
        } else if let value = wrappedValue as? Bool {
            self = .bool(value)
        } else if let value = wrappedValue as? String {
            self = .string(value)
        } else {
            self = .noValue
        }
    }
    
    func typed() -> Codable? {
        switch self {
        case .bool(let value):
            return value
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .int8(let value):
            return value
        case .int16(let value):
            return value
        case .int32(let value):
            return value
        case .int64(let value):
            return value
        case .uint(let value):
            return value
        case .uint8(let value):
            return value
        case .uint16(let value):
            return value
        case .uint32(let value):
            return value
        case .uint64(let value):
            return value
        case .uuid(let value):
            return value
        case .float(let value):
            return value
        case .double(let value):
            return value
        case .noValue:
            return nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .int8(let value):
            try container.encode(value)
        case .int16(let value):
            try container.encode(value)
        case .int32(let value):
            try container.encode(value)
        case .int64(let value):
            try container.encode(value)
        case .uint(let value):
            try container.encode(value)
        case .uint8(let value):
            try container.encode(value)
        case .uint16(let value):
            try container.encode(value)
        case .uint32(let value):
            try container.encode(value)
        case .uint64(let value):
            try container.encode(value)
        case .uuid(let value):
            try container.encode(value)
        case .float(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .noValue:
            break
        }
        
    }

    var description: String {
        String(reflecting: self)
    }
    
}
