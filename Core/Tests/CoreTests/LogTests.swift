import Foundation
import Testing
@testable import Core

@Suite struct LogTests {
    @Test func ringKeepsOnlyTheNewestLines() {
        let ring = LogRing(capacity: 2000)
        for i in 0..<2500 { ring.append("e", ["i": Double(i)], t: Double(i)) }
        #expect(ring.count == 2000)
        let tail = ring.tail(2000)
        #expect(tail.first?.seq == 501)
        #expect(tail.last?.seq == 2500)
        #expect(tail.last?.f["i"] == 2499)
    }

    @Test func tailReturnsOldestFirst() {
        let ring = LogRing(capacity: 10)
        for i in 1...5 { ring.append("e\(i)", t: Double(i)) }
        #expect(ring.tail(3).map(\.e) == ["e3", "e4", "e5"])
        #expect(ring.tail(99).count == 5)
        #expect(ring.tail(0).isEmpty)
    }

    @Test func linesAfterReturnsOnlyNewLines() {
        let ring = LogRing(capacity: 10)
        for i in 1...4 { ring.append("e", t: Double(i)) }
        #expect(ring.lines(after: 0).map(\.seq) == [1, 2, 3, 4])
        #expect(ring.lines(after: 2).map(\.seq) == [3, 4])
        #expect(ring.lines(after: 4).isEmpty)
    }

    @Test func jsonLineRoundTrips() throws {
        let line = LogLine(seq: 7, t: 12.5, e: "shot \"fired\"", f: ["dmg": 10, "range": 4.25], m: "note\nnext")
        let text = line.jsonLine()
        #expect(!text.contains("\n"))
        let decoded = try JSONDecoder().decode(LogLine.self, from: Data(text.utf8))
        #expect(decoded == line)
    }

    @Test func nonFiniteFieldsStillEncode() {
        let line = LogLine(seq: 1, t: 0, e: "x", f: ["bad": .nan, "big": .infinity], m: nil)
        let text = line.jsonLine()
        #expect(text.contains("\"nan\""))
        #expect(text.contains("\"inf\""))
    }

    @Test func concurrentAppendsLoseNothing() async {
        let ring = LogRing(capacity: 5000)
        await withTaskGroup(of: Void.self) { group in
            for task in 0..<8 {
                group.addTask {
                    for i in 0..<500 { ring.append("t\(task)", ["i": Double(i)], t: 0) }
                }
            }
        }
        #expect(ring.count == 4000)
        #expect(Set(ring.tail(5000).map(\.seq)).count == 4000)
    }

    @Test func globalLogAppendsToTheSharedRing() {
        Log.event("log_test_marker", ["v": 1])
        #expect(Log.shared.tail(2000).contains { $0.e == "log_test_marker" && $0.f["v"] == 1 })
        #expect(Log.shared.capacity == 2000)
    }
}
