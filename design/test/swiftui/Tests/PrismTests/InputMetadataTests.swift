import Foundation
import Prism
import Testing

struct InputMetadataTests {
    @Test func disabledAndInclusiveBounds() throws {
        #expect(try PrismTextFieldInputMetadata().debounceMs == nil)
        #expect(try PrismTextAreaInputMetadata().debounceMs == nil)
        for value in [1, 500, 2_147_483_647] {
            #expect(try PrismTextFieldInputMetadata(debounceMs: value).debounceMs == value)
            #expect(try PrismTextAreaInputMetadata(debounceMs: value).debounceMs == value)
        }
        for value in [0, -1, 2_147_483_648] {
            #expect(throws: PrismInputMetadataError.self) {
                try PrismTextFieldInputMetadata(debounceMs: value)
            }
            #expect(throws: PrismInputMetadataError.self) {
                try PrismTextAreaInputMetadata(debounceMs: value)
            }
        }
    }

    @Test func decodingValidatesTheWireContract() throws {
        let decoder = JSONDecoder()
        for json in ["{}", #"{"debounce_ms":null}"#] {
            let data = Data(json.utf8)
            #expect(try decoder.decode(PrismTextFieldInputMetadata.self, from: data).debounceMs == nil)
            #expect(try decoder.decode(PrismTextAreaInputMetadata.self, from: data).debounceMs == nil)
        }
        for value in ["1", "500", "2147483647"] {
            let data = Data("{\"debounce_ms\":\(value)}".utf8)
            #expect(try decoder.decode(PrismTextFieldInputMetadata.self, from: data).debounceMs == Int(value))
            #expect(try decoder.decode(PrismTextAreaInputMetadata.self, from: data).debounceMs == Int(value))
        }
        for value in ["0", "-1", "2147483648", "1.5", "true", "false", #""500""#] {
            let data = Data("{\"debounce_ms\":\(value)}".utf8)
            #expect(throws: (any Error).self) {
                try decoder.decode(PrismTextFieldInputMetadata.self, from: data)
            }
            #expect(throws: (any Error).self) {
                try decoder.decode(PrismTextAreaInputMetadata.self, from: data)
            }
        }
        let enabled = try PrismTextFieldInputMetadata(debounceMs: 500)
        let data = try JSONEncoder().encode(enabled)
        #expect(try decoder.decode(PrismTextFieldInputMetadata.self, from: data) == enabled)
        let wire = try JSONSerialization.jsonObject(with: data) as? [String: Int]
        #expect(wire == ["debounce_ms": 500])
    }
}
