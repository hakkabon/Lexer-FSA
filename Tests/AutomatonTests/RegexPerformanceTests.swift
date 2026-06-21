import XCTest
@testable import LexerFSA

class RegexPerformanceTests: XCTestCase {
    
    func testMaliciousExpressionNFA() throws {
        let re = try Regex("(0|00)*1")
        self.measure {
            XCTAssertFalse(re.recognize(string: "000000000000000000000000000000000000000000000000000000000000"))
        }
    }
    func testMaliciousExpressionDFA() throws {
        let re = try Regex("(0|00)*1")
        self.measure {
            XCTAssertFalse(re.recognize(string: "000000000000000000000000000000000000000000000000000000000000"))
        }
    }
    func testComplexExpressionNFA() throws {
        let re = try Regex("(0|(1(01*(00)*0)*1)*)*")
        self.measure {
            for _ in 0..<10 {
                _ = re.recognize(string: "001011101001000011101101110011111111111")
            }
        }
    }
    func testComplexExpressionDFA() throws {
        let re = try Regex("(0|(1(01*(00)*0)*1)*)*")
        self.measure {
            for _ in 0..<10 {
                _ = re.recognize(string: "001011101001000011101101110011111111111")
            }
        }
    }
}
