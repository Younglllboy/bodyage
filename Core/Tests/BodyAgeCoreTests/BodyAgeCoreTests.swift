import XCTest
@testable import BodyAgeCore

final class BodyAgeCoreTests: XCTestCase {
    func testAgeDifferenceHasExplicitPlusForOlderReference() {
        let display = AgePresentation(position: AgePosition(years: 43.2, boundary: .within), chronologicalAge: 40)
        XCTAssertEqual(display.ageLabel, "43")
        XCTAssertEqual(display.differenceLabel, "+3 岁")
    }

    func testAgeDifferenceIsNegativeForYoungerReference() {
        let display = AgePresentation(position: AgePosition(years: 37.2, boundary: .within), chronologicalAge: 42)
        XCTAssertEqual(display.differenceLabel, "-5 岁")
    }

    func testAgeDifferenceMatchesDisplayedRoundingWithoutNegativeZero() {
        let display = AgePresentation(position: AgePosition(years: 39.5, boundary: .within), chronologicalAge: 40)
        XCTAssertEqual(display.ageLabel, "40")
        XCTAssertEqual(display.differenceLabel, "0 岁")
    }

    func testCensoredAgeCannotCreateExactDifference() {
        for boundary in [AgeBoundary.younger, .older] {
            let display = AgePresentation(position: AgePosition(years: 24.5, boundary: boundary), chronologicalAge: 40)
            XCTAssertNil(display.difference)
            XCTAssertEqual(display.differenceLabel, "已到参考边界")
        }
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ day: Int, hour: Int = 13) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
    }
    private func vo2Snapshot(_ readings: [(Int, Double)], now: Date? = nil) -> Snapshot {
        Snapshot(fetchedAt: now ?? date(30), values: [.vo2Max: readings.map {
            DailyValue(date: calendar.startOfDay(for: date($0.0)), value: $0.1, latestSample: date($0.0))
        }])
    }

    func testPublishedMedianKnotsForBothReferenceGroups() {
        for (sex, table) in [(ReferenceSex.male, FitnessAge.maleMedians), (.female, FitnessAge.femaleMedians)] {
            for (index, value) in table.enumerated() {
                XCTAssertEqual(FitnessAge.position(vo2Max: value, sex: sex)!.years,
                               FitnessAge.ages[index], accuracy: 0.000001)
            }
        }
    }

    func testMidpointInterpolation() {
        XCTAssertEqual(FitnessAge.position(vo2Max: 40.1, sex: .male)!.years, 39.5, accuracy: 0.000001)
        XCTAssertEqual(FitnessAge.position(vo2Max: 28.45, sex: .female)!.years, 39.5, accuracy: 0.000001)
    }

    func testHigherFitnessCannotIncreaseReferenceAge() {
        for sex in [ReferenceSex.male, .female] {
            var previous = Double.infinity
            for step in 140...650 {
                let position = FitnessAge.position(vo2Max: Double(step) / 10, sex: sex)!
                XCTAssertLessThanOrEqual(position.years, previous)
                previous = position.years
            }
        }
    }

    func testBoundariesAreCensoredRatherThanExtrapolated() {
        XCTAssertEqual(FitnessAge.position(vo2Max: 65, sex: .female)?.boundary, .younger)
        XCTAssertEqual(FitnessAge.position(vo2Max: 14, sex: .male)?.boundary, .older)
        XCTAssertNil(FitnessAge.position(vo2Max: .nan, sex: .male))
        XCTAssertNil(FitnessAge.position(vo2Max: .infinity, sex: .female))
        XCTAssertNil(FitnessAge.position(vo2Max: -1, sex: .male))
        XCTAssertNil(FitnessAge.position(vo2Max: 40, sex: .unspecified))
    }

    func testMissingReadingsDoNotReturnChronologicalAge() {
        let result = FitnessAge.assess(profile: Profile(age: 50, referenceSex: .male),
            snapshot: vo2Snapshot([]), calendar: calendar)
        XCTAssertNil(result.result)
    }

    func testDistinctDaysAndFreshnessRequired() {
        let profile = Profile(age: 50, referenceSex: .male)
        XCTAssertNil(FitnessAge.assess(profile: profile,
            snapshot: vo2Snapshot([(25, 40), (25, 41), (25, 42)]), calendar: calendar).result)
        XCTAssertNil(FitnessAge.assess(profile: profile,
            snapshot: vo2Snapshot([(5, 40), (7, 41), (9, 42)]), calendar: calendar).result)
        XCTAssertNotNil(FitnessAge.assess(profile: profile,
            snapshot: vo2Snapshot([(20, 40), (25, 41), (29, 42)]), calendar: calendar).result)
    }

    func testApplicabilityGates() {
        let snapshot = vo2Snapshot([(20, 40), (25, 41), (29, 42)])
        for age in [19, 80] {
            XCTAssertNil(FitnessAge.assess(profile: Profile(age: age, referenceSex: .male),
                snapshot: snapshot, calendar: calendar).result)
        }
        XCTAssertNil(FitnessAge.assess(profile: Profile(age: 40), snapshot: snapshot, calendar: calendar).result)
        XCTAssertNil(FitnessAge.assess(profile: Profile(age: 40, referenceSex: .male, referenceNotApplicable: true),
            snapshot: snapshot, calendar: calendar).result)
    }

    func testSensitivityDirectionAndNoArbitraryContextWeights() {
        let base = vo2Snapshot([(20, 40), (25, 41), (29, 42)])
        let profile = Profile(age: 42, referenceSex: .male)
        let reference = FitnessAge.assess(profile: profile, snapshot: base, calendar: calendar).result!
        XCTAssertLessThan(reference.sensitivityLow.years, reference.position.years)
        XCTAssertGreaterThan(reference.sensitivityHigh.years, reference.position.years)
        var values = base.values
        values[.sleepHours] = [DailyValue(date: date(29), value: 2, latestSample: date(29))]
        values[.restingHeartRate] = [DailyValue(date: date(29), value: 100, latestSample: date(29))]
        let changed = FitnessAge.assess(profile: profile,
            snapshot: Snapshot(fetchedAt: base.fetchedAt, values: values), calendar: calendar).result!
        XCTAssertEqual(reference.position.years, changed.position.years)
    }

    func testRobustMedianAndInvalidValues() {
        XCTAssertEqual(Statistics.median([1, 2, 3, 1000]), 2.5)
        XCTAssertEqual(Statistics.median([.nan, 4, .infinity]), 4)
        XCTAssertNil(Statistics.median([]))
    }

    func testUUIDDeduplicationAndNoSamplingFrequencyWeighting() {
        let day = date(25)
        let a = Reading(id: "same", start: day, end: day, value: 40)
        let b = Reading(id: "another", start: day, end: day, value: 42)
        let result = Aggregation.dailyMedians([a, a, b], now: date(30), calendar: calendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.value, 41)
    }

    func testSleepUnionAcrossMidnightAndDuplicates() {
        let start = date(28, hour: 22)
        let end = date(29, hour: 6)
        let a = Reading(start: start, end: end, value: 1)
        let b = Reading(start: date(29, hour: 0), end: date(29, hour: 7), value: 1)
        let values = Aggregation.sleep([a, a, b], now: date(29), calendar: calendar)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.value, 9)
    }

    func testAwakeGapsAreNotFilled() {
        let a = DateInterval(start: date(28, hour: 22), end: date(29, hour: 2))
        let b = DateInterval(start: date(29, hour: 3), end: date(29, hour: 6))
        XCTAssertEqual(Aggregation.unionDuration([a, b]), 7 * 3600)
    }

    func testIncompleteSleepWindowExcluded() {
        let sample = Reading(start: date(28, hour: 22), end: date(29, hour: 6), value: 1)
        XCTAssertTrue(Aggregation.sleep([sample], now: date(29, hour: 8), calendar: calendar).isEmpty)
    }

    func testSleepHonorsDaylightSavingCalendarBoundaries() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = local.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 22))!
        let end = local.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 7))!
        let now = local.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 13))!
        let result = Aggregation.sleep([Reading(start: start, end: end, value: 1)], now: now, calendar: local)
        XCTAssertEqual(result.first?.value, 8)
    }

    func testExerciseOverlapsAndCrossMidnightAreNotDoubleCounted() {
        let start = date(28, hour: 23)
        let a = Reading(start: start, end: date(29, hour: 1), value: 120)
        let b = Reading(start: date(29, hour: 0), end: date(29, hour: 2), value: 120)
        let result = Aggregation.exercise([a, b], now: date(30), calendar: calendar)
        XCTAssertEqual(result.map(\.value), [60, 120])
    }

    func testExerciseZeroIsPreservedButMissingDaysAreAbsent() {
        let a = Reading(start: date(28, hour: 10), end: date(28, hour: 11), value: 0)
        let result = Aggregation.exercise([a], now: date(30), calendar: calendar)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.value, 0)
    }

    func testExerciseUniformRateIntegration() {
        let a = Reading(start: date(28, hour: 10), end: date(28, hour: 12), value: 60)
        let b = Reading(start: date(28, hour: 11), end: date(28, hour: 12), value: 60)
        let result = Aggregation.exercise([a, b], now: date(30), calendar: calendar)
        XCTAssertEqual(result.first?.value, 90)
    }

    func testFutureInvalidAndReversedSamplesRejected() {
        let readings = [
            Reading(start: date(29), end: date(29), value: .nan),
            Reading(start: date(29), end: date(28), value: 40),
            Reading(start: date(30), end: date(30), value: 40)
        ]
        XCTAssertTrue(Aggregation.dailyMedians(readings, now: date(29), calendar: calendar).isEmpty)
    }

    func testContextWindowsAreDisjointAndExcludeCurrentDay() {
        let points = (2...30).map {
            DailyValue(date: calendar.startOfDay(for: date($0)), value: Double($0), latestSample: date($0))
        }
        let snapshot = Snapshot(fetchedAt: date(30), values: [.hrv: points])
        let result = ContextAnalysis.summarize(.hrv, snapshot: snapshot, calendar: calendar)
        XCTAssertEqual(result.currentDays, 7)
        XCTAssertEqual(result.baselineDays, 21)
        XCTAssertEqual(result.current, 26)
        XCTAssertEqual(result.baseline, 12)
        XCTAssertEqual(result.change, 14)
    }

    func testInsufficientBaselineDoesNotFabricateChange() {
        let day = calendar.startOfDay(for: date(29))
        let snapshot = Snapshot(fetchedAt: date(30), values: [.hrv: [DailyValue(date: day, value: 40, latestSample: date(29))]])
        XCTAssertNil(ContextAnalysis.summarize(.hrv, snapshot: snapshot, calendar: calendar).change)
    }
}
