import Foundation

// MARK: - Protobuf Wire Types

public enum ProtoWireType: UInt8 {
    case varint = 0
    case fixed64 = 1
    case lengthDelimited = 2
    case startGroup = 3
    case endGroup = 4
    case fixed32 = 5
}

// MARK: - Protobuf Binary Writer

public final class ProtoWriter {
    public private(set) var data = Data()

    public init() {}

    private func writeTag(fieldNumber: Int, wireType: ProtoWireType) {
        let tag = UInt64((fieldNumber << 3) | Int(wireType.rawValue))
        writeRawVarint(tag)
    }

    private func writeRawVarint(_ val: UInt64) {
        var v = val
        while v >= 0x80 {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v & 0x7F))
    }

    public func writeVarint(field: Int, value: UInt64) {
        guard value != 0 else { return }
        writeTag(fieldNumber: field, wireType: .varint)
        writeRawVarint(value)
    }

    public func writeInt32(field: Int, value: Int32) {
        guard value != 0 else { return }
        writeTag(fieldNumber: field, wireType: .varint)
        writeRawVarint(UInt64(bitPattern: Int64(value)))
    }

    public func writeUInt32(field: Int, value: UInt32) {
        guard value != 0 else { return }
        writeTag(fieldNumber: field, wireType: .varint)
        writeRawVarint(UInt64(value))
    }

    public func writeInt64(field: Int, value: Int64) {
        guard value != 0 else { return }
        writeTag(fieldNumber: field, wireType: .varint)
        writeRawVarint(UInt64(bitPattern: value))
    }

    public func writeBool(field: Int, value: Bool) {
        guard value else { return }
        writeTag(fieldNumber: field, wireType: .varint)
        data.append(1)
    }

    public func writeFloat(field: Int, value: Float) {
        guard value != 0 else { return }
        writeTag(fieldNumber: field, wireType: .fixed32)
        var bitPattern = value.bitPattern
        withUnsafeBytes(of: &bitPattern) { data.append(contentsOf: $0) }
    }

    public func writeString(field: Int, value: String) {
        guard !value.isEmpty, let utf8 = value.data(using: .utf8) else { return }
        writeTag(fieldNumber: field, wireType: .lengthDelimited)
        writeRawVarint(UInt64(utf8.count))
        data.append(utf8)
    }

    public func writeBytes(field: Int, value: Data) {
        guard !value.isEmpty else { return }
        writeTag(fieldNumber: field, wireType: .lengthDelimited)
        writeRawVarint(UInt64(value.count))
        data.append(value)
    }

    public func writeMessage(field: Int, submessage: Data) {
        guard !submessage.isEmpty else { return }
        writeTag(fieldNumber: field, wireType: .lengthDelimited)
        writeRawVarint(UInt64(submessage.count))
        data.append(submessage)
    }
}

// MARK: - Protobuf Binary Reader

public final class ProtoReader {
    private let data: Data
    private var offset: Int = 0

    public var isAtEnd: Bool { offset >= data.count }

    public init(data: Data) {
        self.data = data
    }

    public func nextField() -> (fieldNumber: Int, wireType: ProtoWireType)? {
        guard offset < data.count else { return nil }
        guard let tag = readVarint() else { return nil }
        let wireRaw = UInt8(tag & 0x07)
        guard let wireType = ProtoWireType(rawValue: wireRaw) else { return nil }
        let fieldNumber = Int(tag >> 3)
        return (fieldNumber, wireType)
    }

    public func readVarint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let b = data[offset]
            offset += 1
            result |= UInt64(b & 0x7F) << shift
            if (b & 0x80) == 0 { return result }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    public func readInt32() -> Int32? {
        guard let v = readVarint() else { return nil }
        return Int32(truncatingIfNeeded: v)
    }

    public func readUInt32() -> UInt32? {
        guard let v = readVarint() else { return nil }
        return UInt32(truncatingIfNeeded: v)
    }

    public func readInt64() -> Int64? {
        guard let v = readVarint() else { return nil }
        return Int64(bitPattern: v)
    }

    public func readBool() -> Bool? {
        guard let v = readVarint() else { return nil }
        return v != 0
    }

    public func readFloat() -> Float? {
        guard offset + 4 <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + 4))
        offset += 4
        let bits = sub.withUnsafeBytes { $0.load(as: UInt32.self) }
        return Float(bitPattern: bits)
    }

    public func readString() -> String? {
        guard let len = readVarint().map(Int.init), offset + len <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + len))
        offset += len
        return String(data: sub, encoding: .utf8)
    }

    public func readBytes() -> Data? {
        guard let len = readVarint().map(Int.init), offset + len <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + len))
        offset += len
        return sub
    }

    public func skip(wireType: ProtoWireType) {
        switch wireType {
        case .varint:
            _ = readVarint()
        case .fixed64:
            offset = min(offset + 8, data.count)
        case .lengthDelimited:
            if let len = readVarint().map(Int.init) {
                offset = min(offset + len, data.count)
            }
        case .fixed32:
            offset = min(offset + 4, data.count)
        default:
            break
        }
    }
}
