import Testing
@testable import QRX

@Suite("Phone formatting")
struct PhoneFormatterTests {
    @Test(arguments: [
        ("5", "5"),
        ("555", "555"),
        ("5550", "555-0"),
        ("5550100", "555-0100"),
        ("55501001", "(555) 010-01"),
        ("5550100123", "(555) 010-0123"),
        ("15550100123", "+1 (555) 010-0123"),
        ("+15550100123", "+1 (555) 010-0123"),
        ("+445550100", "+445550100"),
        ("", ""),
        ("abc", ""),
    ])
    func formats(_ input: String, _ expected: String) {
        #expect(PhoneFormatter.format(input) == expected)
    }

    /// Reformatting an already-formatted string must be a no-op, or typing
    /// would fight the onChange loop.
    @Test(arguments: ["555-0100", "(555) 010-0123", "+1 (555) 010-0123", "+445550100"])
    func formattingIsIdempotent(_ value: String) {
        #expect(PhoneFormatter.format(PhoneFormatter.format(value)) == PhoneFormatter.format(value))
    }

    /// Deleting the trailing character never leaves a dangling separator that
    /// re-formatting would immediately re-add (the classic backspace trap).
    @Test func trailingDeletionMakesProgress() {
        var value = PhoneFormatter.format("5550100123")
        var lengths: [Int] = [value.count]
        while !value.isEmpty {
            value = PhoneFormatter.format(String(value.dropLast()))
            lengths.append(value.count)
        }
        #expect(lengths == lengths.sorted(by: >), "each backspace must shrink the value: \(lengths)")
    }
}
