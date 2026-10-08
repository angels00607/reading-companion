import Foundation

/// Foundation decoders accept duplicate object keys by choosing a value. Backups
/// must reject that ambiguity, including escaped spellings of the same key.
/// Foundation still performs the complete JSON grammar/encoding/type validation.
enum BackupJSONValidation {
    static func rejectDuplicateKeys(_ data: Data) throws {
        var scanner = Scanner(bytes: Array(data)); try scanner.value(depth: 0)
        scanner.whitespace()
        guard scanner.cursor == scanner.bytes.count else { throw PortableBackupError.invalidPayload }
    }
    private struct Scanner {
        let bytes: [UInt8]
        var cursor = 0
        var nodes = 0
        mutating func whitespace() {
            while cursor < bytes.count, [UInt8(0x20), 0x09, 0x0a, 0x0d].contains(bytes[cursor]) { cursor += 1 }
        }
        mutating func consume(_ byte: UInt8) throws {
            whitespace()
            guard cursor < bytes.count, bytes[cursor] == byte else { throw PortableBackupError.invalidPayload }
            cursor += 1
        }
        mutating func stringRange() throws -> Range<Int> {
            whitespace(); let start = cursor; try consume(0x22)
            while cursor < bytes.count {
                let byte = bytes[cursor]; cursor += 1
                if byte == 0x22 { return start..<cursor }
                if byte == 0x5c {
                    guard cursor < bytes.count else { throw PortableBackupError.invalidPayload }
                    cursor += 1
                }
            }
            throw PortableBackupError.invalidPayload
        }
        mutating func value(depth: Int) throws {
            nodes += 1
            guard depth <= 64, nodes <= 500_000 else { throw PortableBackupError.resourceLimit }
            whitespace()
            guard cursor < bytes.count else { throw PortableBackupError.invalidPayload }
            switch bytes[cursor] {
            case 0x7b:
                cursor += 1; whitespace(); var keys = Set<String>()
                if cursor < bytes.count, bytes[cursor] == 0x7d { cursor += 1; return }
                while true {
                    let range = try stringRange()
                    guard let key = try? JSONDecoder().decode(String.self, from: Data(bytes[range])),
                          keys.insert(key).inserted else { throw PortableBackupError.invalidPayload }
                    try consume(0x3a); try value(depth: depth + 1); whitespace()
                    guard cursor < bytes.count else { throw PortableBackupError.invalidPayload }
                    if bytes[cursor] == 0x7d { cursor += 1; return }
                    try consume(0x2c)
                }
            case 0x5b:
                cursor += 1; whitespace()
                if cursor < bytes.count, bytes[cursor] == 0x5d { cursor += 1; return }
                while true {
                    try value(depth: depth + 1); whitespace()
                    guard cursor < bytes.count else { throw PortableBackupError.invalidPayload }
                    if bytes[cursor] == 0x5d { cursor += 1; return }
                    try consume(0x2c)
                }
            case 0x22: _ = try stringRange()
            default:
                let start = cursor
                while cursor < bytes.count, ![UInt8(0x20), 0x09, 0x0a, 0x0d, 0x2c, 0x5d, 0x7d].contains(bytes[cursor]) { cursor += 1 }
                guard cursor > start else { throw PortableBackupError.invalidPayload }
            }
        }
    }
}
