//
//  EvaluationRunnerTests.swift
//  AIParsingTestKitTests
//
//  Tests for EvaluationRunner and related types.
//

import Foundation
import FoundationModels
import Testing
@testable import AIParsingTestKit

// MARK: - Test Fixtures

/// A simple generable type for testing.
@Generable
struct TestOutput {
    @Guide(description: "The category")
    var category: String

    @Guide(description: "Confidence score")
    var confidence: Double
}

/// Expected output for testing.
struct TestExpectedOutput: ExpectedOutput {
    typealias ActualOutput = TestOutput

    let expectedCategory: String
    let minimumConfidence: Double

    func compare(to actual: TestOutput) -> [String: MetricValue] {
        return [
            "category_correct": .boolean(actual.category.lowercased() == expectedCategory.lowercased()),
            "confidence": .double(actual.confidence)
        ]
    }
}

/// Test case for testing.
struct TestCase: EvaluatableTestCase {
    let input: String
    let expected: TestExpectedOutput
    let description: String
}

// MARK: - Tests

@Suite("EvaluationResult Tests")
struct EvaluationResultTests {

    @Test("Successful result has completed status")
    func testSuccessfulResult() {
        let testCase = TestCase(
            input: "test input",
            expected: TestExpectedOutput(expectedCategory: "test", minimumConfidence: 0.7),
            description: "Test case"
        )

        let output = TestOutput(category: "test", confidence: 0.85)

        let result = EvaluationResult(
            testCase: testCase,
            actualOutput: output,
            latencyMs: 100.0
        )

        #expect(result.status == .completed)
        #expect(result.error == nil)
        #expect(result.actualOutput != nil)
        #expect(result.latencyMs == 100.0)
    }

    @Test("Failed result has error status")
    func testFailedResult() {
        let testCase = TestCase(
            input: "test input",
            expected: TestExpectedOutput(expectedCategory: "test", minimumConfidence: 0.7),
            description: "Test case"
        )

        let result = EvaluationResult<TestCase>(
            testCase: testCase,
            error: "Something went wrong",
            latencyMs: 50.0
        )

        #expect(result.status == .error)
        #expect(result.error == "Something went wrong")
        #expect(result.actualOutput == nil)
    }

    @Test("Skipped result has skipped status")
    func testSkippedResult() {
        let testCase = TestCase(
            input: "test input",
            expected: TestExpectedOutput(expectedCategory: "test", minimumConfidence: 0.7),
            description: "Test case"
        )

        let result = EvaluationResult<TestCase>(skipped: testCase)

        #expect(result.status == .skipped)
        #expect(result.error == nil)
        #expect(result.actualOutput == nil)
    }

    @Test("Metrics are computed correctly")
    func testMetricsComputation() {
        let testCase = TestCase(
            input: "test input",
            expected: TestExpectedOutput(expectedCategory: "task", minimumConfidence: 0.7),
            description: "Test case"
        )

        let output = TestOutput(category: "task", confidence: 0.85)

        let result = EvaluationResult(
            testCase: testCase,
            actualOutput: output,
            latencyMs: 100.0
        )

        #expect(result.metrics["category_correct"]?.boolValue == true)
        #expect(result.metrics["confidence"]?.doubleValue == 0.85)
    }
}

@Suite("RunMetadata Tests")
struct RunMetadataTests {

    @Test("Current metadata has valid values")
    func testCurrentMetadata() {
        let metadata = RunMetadata.current(promptVersion: "v1.0", testCount: 10)

        #expect(!metadata.runId.isEmpty)
        #expect(!metadata.timestamp.isEmpty)
        #expect(metadata.promptVersion == "v1.0")
        #expect(metadata.testCount == 10)
        #expect(!metadata.deviceModel.isEmpty)
        #expect(!metadata.osVersion.isEmpty)
    }

    @Test("Metadata is Codable")
    func testCodable() throws {
        let metadata = RunMetadata.current(promptVersion: "v2.0", testCount: 5)

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RunMetadata.self, from: data)

        #expect(decoded.runId == metadata.runId)
        #expect(decoded.promptVersion == metadata.promptVersion)
        #expect(decoded.testCount == metadata.testCount)
    }
}

@Suite("MetricValue Tests")
struct MetricValueTests {

    @Test("Boolean metric CSV string")
    func testBooleanCsvString() {
        let trueMetric = MetricValue.boolean(true)
        let falseMetric = MetricValue.boolean(false)

        #expect(trueMetric.csvString == "true")
        #expect(falseMetric.csvString == "false")
    }

    @Test("Double metric CSV string")
    func testDoubleCsvString() {
        let metric = MetricValue.double(0.853)
        #expect(metric.csvString == "0.85")
    }

    @Test("Integer metric CSV string")
    func testIntegerCsvString() {
        let metric = MetricValue.integer(42)
        #expect(metric.csvString == "42")
    }

    @Test("String metric CSV string")
    func testStringCsvString() {
        let metric = MetricValue.string("hello")
        #expect(metric.csvString == "hello")
    }

    @Test("Optional metrics handle nil")
    func testOptionalMetrics() {
        let nilInt = MetricValue.optionalInteger(nil)
        let nilDouble = MetricValue.optionalDouble(nil)

        #expect(nilInt.csvString == "")
        #expect(nilDouble.csvString == "")
    }
}

@Suite("EvaluationSummary Tests")
struct EvaluationSummaryTests {

    @Test("F1 score calculation")
    func testF1Calculation() {
        let summary = EvaluationSummary(
            totalTests: 10,
            completedTests: 10,
            skippedTests: 0,
            errorTests: 0,
            entityTypeAccuracy: 0.9,
            entityTypePrecision: ["task": 0.8, "event": 0.6],
            entityTypeRecall: ["task": 0.9, "event": 0.7],
            titleKeywordOverlapAvg: 0.85,
            startTimePresenceAccuracy: 0.9,
            startHourAccuracy: 0.8,
            endTimePresenceAccuracy: 0.85,
            recurrencePresenceAccuracy: 0.9,
            timePreferencePresenceAccuracy: 0.8,
            confidenceCalibrationRate: 0.9,
            avgConfidence: 0.75,
            avgLatencyMs: 150,
            p50LatencyMs: 120,
            p95LatencyMs: 300
        )

        let f1Scores = summary.entityTypeF1

        // F1 = 2 * (P * R) / (P + R)
        // task: 2 * (0.8 * 0.9) / (0.8 + 0.9) = 1.44 / 1.7 ≈ 0.847
        #expect(f1Scores["task"]! > 0.84 && f1Scores["task"]! < 0.86)

        // event: 2 * (0.6 * 0.7) / (0.6 + 0.7) = 0.84 / 1.3 ≈ 0.646
        #expect(f1Scores["event"]! > 0.64 && f1Scores["event"]! < 0.66)
    }

    @Test("Completion rate calculation")
    func testCompletionRate() {
        let summary = EvaluationSummary(
            totalTests: 100,
            completedTests: 80,
            skippedTests: 15,
            errorTests: 5,
            entityTypeAccuracy: 0.9,
            entityTypePrecision: [:],
            entityTypeRecall: [:],
            titleKeywordOverlapAvg: 0.85,
            startTimePresenceAccuracy: 0.9,
            startHourAccuracy: 0.8,
            endTimePresenceAccuracy: 0.85,
            recurrencePresenceAccuracy: 0.9,
            timePreferencePresenceAccuracy: 0.8,
            confidenceCalibrationRate: 0.9,
            avgConfidence: 0.75,
            avgLatencyMs: 150,
            p50LatencyMs: 120,
            p95LatencyMs: 300
        )

        #expect(summary.completionRate == 0.8)
    }
}
