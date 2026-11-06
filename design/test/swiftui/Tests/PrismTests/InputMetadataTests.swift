import Foundation
import Prism
import Testing

struct InputMetadataTests {
    @Test func disabledAndInclusiveBounds() throws {
        #expect(try PrismTextFieldInputMetadata().autoSubmitDelayMs == nil)
        #expect(try PrismTextAreaInputMetadata().autoSubmitDelayMs == nil)
        for value in [1, 500, 2_147_483_647] {
            #expect(try PrismTextFieldInputMetadata(autoSubmitDelayMs: value).autoSubmitDelayMs == value)
            #expect(try PrismTextAreaInputMetadata(autoSubmitDelayMs: value).autoSubmitDelayMs == value)
        }
        for value in [0, -1, 2_147_483_648] {
            #expect(throws: PrismInputMetadataError.self) {
                try PrismTextFieldInputMetadata(autoSubmitDelayMs: value)
            }
            #expect(throws: PrismInputMetadataError.self) {
                try PrismTextAreaInputMetadata(autoSubmitDelayMs: value)
            }
        }
    }

    @Test func decodingValidatesTheWireContract() throws {
        let decoder = JSONDecoder()
        for json in ["{}", #"{"auto_submit_delay_ms":null}"#] {
            let data = Data(json.utf8)
            #expect(try decoder.decode(PrismTextFieldInputMetadata.self, from: data).autoSubmitDelayMs == nil)
            #expect(try decoder.decode(PrismTextAreaInputMetadata.self, from: data).autoSubmitDelayMs == nil)
        }
        for value in ["1", "500", "2147483647"] {
            let data = Data("{\"auto_submit_delay_ms\":\(value)}".utf8)
            #expect(try decoder.decode(PrismTextFieldInputMetadata.self, from: data).autoSubmitDelayMs == Int(value))
            #expect(try decoder.decode(PrismTextAreaInputMetadata.self, from: data).autoSubmitDelayMs == Int(value))
        }
        for value in ["0", "-1", "2147483648", "1.5", "true", "false", #""500""#] {
            let data = Data("{\"auto_submit_delay_ms\":\(value)}".utf8)
            #expect(throws: (any Error).self) {
                try decoder.decode(PrismTextFieldInputMetadata.self, from: data)
            }
            #expect(throws: (any Error).self) {
                try decoder.decode(PrismTextAreaInputMetadata.self, from: data)
            }
        }
        let enabled = try PrismTextFieldInputMetadata(autoSubmitDelayMs: 500)
        let data = try JSONEncoder().encode(enabled)
        #expect(try decoder.decode(PrismTextFieldInputMetadata.self, from: data) == enabled)
        let wire = try JSONSerialization.jsonObject(with: data) as? [String: Int]
        #expect(wire == ["auto_submit_delay_ms": 500])
    }
}
