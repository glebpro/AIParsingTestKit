//
//  MetricsCalculator.swift
//  AIParsingTestKit
//
//  Utility for calculating aggregated metrics from evaluation results.
//

import Foundation

/// Utility for calculating aggregated metrics from evaluation results.
///
/// This calculator works with any collection of evaluation results
/// and produces an `EvaluationSummary` with comprehensive metrics.
public struct MetricsCalculator<T: EvaluatableTestCase, M: MetricProvider> {
    private let entityTypes: [String]

    /// Creates a metrics calculator.
    ///
    /// - Parameter entityTypes: The entity types to track (defaults to `M.entityTypes`).
    public init(entityTypes: [String] = M.entityTypes) {
        self.entityTypes = entityTypes
    }

    /// Calculates summary metrics from a collection of results.
    ///
    /// - Parameters:
    ///   - results: The evaluation results to summarize.
    ///   - entityTypeKeyPath: Key path to the "entity type correct" metric.
    ///   - expectedEntityType: Closure to extract expected entity type from test case.
    ///   - actualEntityType: Closure to extract actual entity type from result.
    /// - Returns: An `EvaluationSummary` with aggregated metrics.
    public func calculateSummary(
        from results: [EvaluationResult<T>],
        entityTypeCorrectKey: String = "entity_type_correct",
        titleOverlapKey: String = "title_keyword_overlap",
        startTimeCorrectKey: String = "start_time_presence_correct",
        startHourCorrectKey: String = "start_hour_correct",
        endTimeCorrectKey: String = "end_time_presence_correct",
        recurrenceCorrectKey: String = "recurrence_presence_correct",
        timePreferenceCorrectKey: String = "time_preference_presence_correct",
        confidenceCalibratedKey: String = "confidence_calibrated",
        confidenceKey: String = "confidence",
        expectedEntityTypeExtractor: (T) -> String,
        actualEntityTypeExtractor: (T.Expected.ActualOutput) -> String
    ) -> EvaluationSummary {
        let completedResults = results.filter { $0.status == .completed }
        let total = results.count
        let completed = completedResults.count
        let skipped = results.filter { $0.status == .skipped }.count
        let errors = results.filter { $0.status == .error }.count

        guard completed > 0 else {
            return emptySummary(
                totalTests: total,
                skippedTests: skipped,
                errorTests: errors
            )
        }

        // Entity type metrics
        let entityTypeCorrectCount = completedResults.filter {
            $0.metrics[entityTypeCorrectKey]?.boolValue == true
        }.count
        let entityTypeAccuracy = Double(entityTypeCorrectCount) / Double(completed)

        // Per-class precision/recall
        var entityTypePrecision: [String: Double] = [:]
        var entityTypeRecall: [String: Double] = [:]

        for entityType in entityTypes {
            let predicted = completedResults.filter { result in
                guard let actual = result.actualOutput else { return false }
                return actualEntityTypeExtractor(actual).lowercased() == entityType.lowercased()
            }
            let actual = completedResults.filter { result in
                expectedEntityTypeExtractor(result.testCase).lowercased() == entityType.lowercased()
            }
            let truePositives = predicted.filter {
                $0.metrics[entityTypeCorrectKey]?.boolValue == true
            }

            entityTypePrecision[entityType] = predicted.isEmpty
                ? 0.0
                : Double(truePositives.count) / Double(predicted.count)
            entityTypeRecall[entityType] = actual.isEmpty
                ? 0.0
                : Double(truePositives.count) / Double(actual.count)
        }

        // Field accuracy metrics
        let titleOverlapSum = completedResults.compactMap {
            $0.metrics[titleOverlapKey]?.doubleValue
        }.reduce(0, +)
        let titleOverlapAvg = titleOverlapSum / Double(completed)

        let startTimeAccuracy = Double(
            completedResults.filter {
                $0.metrics[startTimeCorrectKey]?.boolValue == true
            }.count
        ) / Double(completed)

        let startHourAccuracy = Double(
            completedResults.filter {
                $0.metrics[startHourCorrectKey]?.boolValue == true
            }.count
        ) / Double(completed)

        let endTimeAccuracy = Double(
            completedResults.filter {
                $0.metrics[endTimeCorrectKey]?.boolValue == true
            }.count
        ) / Double(completed)

        let recurrenceAccuracy = Double(
            completedResults.filter {
                $0.metrics[recurrenceCorrectKey]?.boolValue == true
            }.count
        ) / Double(completed)

        let timePreferenceAccuracy = Double(
            completedResults.filter {
                $0.metrics[timePreferenceCorrectKey]?.boolValue == true
            }.count
        ) / Double(completed)

        // Confidence calibration
        let confidenceCalibrationCount = completedResults.filter {
            $0.metrics[confidenceCalibratedKey]?.boolValue == true
        }.count
        let confidenceCalibrationRate = Double(confidenceCalibrationCount) / Double(completed)

        let confidenceSum = completedResults.compactMap {
            $0.metrics[confidenceKey]?.doubleValue
        }.reduce(0, +)
        let avgConfidence = confidenceSum / Double(completed)

        // Latency metrics
        let latencies = completedResults.map { $0.latencyMs }.sorted()
        let avgLatency = latencies.reduce(0, +) / Double(completed)
        let p50Latency = latencies[completed / 2]
        let p95Index = min(Int(Double(completed) * 0.95), completed - 1)
        let p95Latency = latencies[p95Index]

        return EvaluationSummary(
            totalTests: total,
            completedTests: completed,
            skippedTests: skipped,
            errorTests: errors,
            entityTypeAccuracy: entityTypeAccuracy,
            entityTypePrecision: entityTypePrecision,
            entityTypeRecall: entityTypeRecall,
            titleKeywordOverlapAvg: titleOverlapAvg,
            startTimePresenceAccuracy: startTimeAccuracy,
            startHourAccuracy: startHourAccuracy,
            endTimePresenceAccuracy: endTimeAccuracy,
            recurrencePresenceAccuracy: recurrenceAccuracy,
            timePreferencePresenceAccuracy: timePreferenceAccuracy,
            confidenceCalibrationRate: confidenceCalibrationRate,
            avgConfidence: avgConfidence,
            avgLatencyMs: avgLatency,
            p50LatencyMs: p50Latency,
            p95LatencyMs: p95Latency
        )
    }

    private func emptySummary(
        totalTests: Int,
        skippedTests: Int,
        errorTests: Int
    ) -> EvaluationSummary {
        EvaluationSummary(
            totalTests: totalTests,
            completedTests: 0,
            skippedTests: skippedTests,
            errorTests: errorTests,
            entityTypeAccuracy: 0,
            entityTypePrecision: [:],
            entityTypeRecall: [:],
            titleKeywordOverlapAvg: 0,
            startTimePresenceAccuracy: 0,
            startHourAccuracy: 0,
            endTimePresenceAccuracy: 0,
            recurrencePresenceAccuracy: 0,
            timePreferencePresenceAccuracy: 0,
            confidenceCalibrationRate: 0,
            avgConfidence: 0,
            avgLatencyMs: 0,
            p50LatencyMs: 0,
            p95LatencyMs: 0
        )
    }
}
