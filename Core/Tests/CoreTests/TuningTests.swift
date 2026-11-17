import Foundation
import Testing
@testable import Core

@Suite struct TuningTests {
    private func data(_ text: String) -> Data { Data(text.utf8) }

    @Test func defaultsMatchThePlan() {
        let t = Tuning()
        #expect(t.revision == 0)
        #expect(t.gunBaseDamage == 10)
        #expect(t.gunMagSize == 6)
        #expect(t.aimSigmaZRad == 0.004)
        #expect(t.predictMaxMs == 250)
        #expect(t.hitSphereRadiusM == 0.25)
        #expect(t.devTuningPollS == 2.0)
        #expect(t.devLogUploadS == 5.0)
    }

    @Test func gunConfigFromTuningMatchesThePortedDefaults() {
        #expect(GunTriggerConfig(tuning: Tuning()) == GunTriggerConfig())
        var t = Tuning()
        t.gunTriggerPull = 0.25
        t.gunHandLostMs = 400
        t.gunArmFrames = 0
        let config = GunTriggerConfig(tuning: t)
        #expect(config.triggerPull == 0.25)
        #expect(config.handLostSec == 0.4)
        #expect(config.armFrames == 1)
    }

    @Test func emptyObjectKeepsEveryDefault() {
        var store = TuningStore()
        let result = store.apply(json: data("{}"))
        #expect(result == TuningStore.ApplyResult(applied: true, unknownKeys: [], error: nil))
        #expect(store.current == Tuning())
    }

    @Test func presentKeysOverrideAndOthersStayDefault() {
        var store = TuningStore()
        let result = store.apply(json: data(#"{"revision": 7, "gunBaseDamage": 12.5, "gunMagSize": 8}"#))
        #expect(result.applied)
        var expected = Tuning()
        expected.revision = 7
        expected.gunBaseDamage = 12.5
        expected.gunMagSize = 8
        #expect(store.current == expected)
    }

    @Test func integerJsonIsAcceptedForADoubleField() {
        var store = TuningStore()
        #expect(store.apply(json: data(#"{"maxRangeM": 25}"#)).applied)
        #expect(store.current.maxRangeM == 25)
    }

    @Test func unknownKeysAreReportedNotFatal() {
        var store = TuningStore()
        let result = store.apply(json: data(#"{"zzz": 1, "notAField": 2, "resistFloor": 0.4}"#))
        #expect(result.applied)
        #expect(result.unknownKeys == ["notAField", "zzz"])
        #expect(store.current.resistFloor == 0.4)
    }

    @Test func aKeyRemovedFromTheFileReturnsToItsDefault() {
        var store = TuningStore()
        _ = store.apply(json: data(#"{"gunBaseDamage": 99}"#))
        _ = store.apply(json: data(#"{"revision": 2}"#))
        #expect(store.current.gunBaseDamage == 10)
        #expect(store.current.revision == 2)
    }

    @Test(arguments: [
        "not json",
        "[1, 2]",
        #"{"gunMagSize": 2.5}"#,
        #"{"gunBaseDamage": "ten"}"#,
    ])
    func badFilesAreRejectedWhole(text: String) {
        var store = TuningStore()
        _ = store.apply(json: data(#"{"revision": 3, "gunBaseDamage": 11}"#))
        let before = store.current
        let result = store.apply(json: data(text))
        #expect(!result.applied)
        #expect(result.error != nil)
        #expect(store.current == before)
    }
}
