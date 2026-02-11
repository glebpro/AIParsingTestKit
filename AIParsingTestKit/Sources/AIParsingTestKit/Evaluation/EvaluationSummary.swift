//
//  EvaluationSummary.swift
//  AIParsingTestKit
//
//  Aggregated metrics from an evaluation run.
//

import Foundation

/// Aggregated metrics from an evaluation run.
///
/// Provides summary statistics including:
/// - Test completion rates
/// - Entity classification accuracy and per-class metrics
/// - Field extraction accuracy
/// - Confidence calibration
/// - Latency percentiles
public struct EvaluationSummary: Sendable {
    // MARK: - Test Counts

    /// Total number of tests in the run.
    public let totalTests: Int

    /// Number of tests that completed successfully.
    public let completedTests: Int

    /// Number of tests that were skipped.
    public let skippedTests: Int

    /// Number of tests that failed with errors.
    public let errorTests: Int

    // MARK: - Entity Classification

    /// Overall accuracy of entity type classification.
    public let entityTypeAccuracy: Double

    /// Precision for each entity type.
    public let entityTypePrecision: [String: Double]

    /// Recall for each entity type.
    public let entityTypeRecall: [String: Double]

    // MARK: - Field Extraction

    /// Average overlap between actual and expected title keywords.
    public let titleKeywordOverlapAvg: Double

    /// Accuracy of start time presence detection.
    public let startTimePresenceAccuracy: Double

    /// Accuracy of start hour extraction.
    public let startHourAccuracy: Double

    /// Accuracy of end time presence detection.
    public let endTimePresenceAccuracy: Double

    /// Accuracy of recurrence pattern detection.
    public let recurrencePresenceAccuracy: Double

    /// Accuracy of time preference detection.
    public let timePreferencePresenceAccuracy: Double

    // MARK: - Confidence Calibration

    /// Rate at which confidence scores are well-calibrated.
    public let confidenceCalibrationRate: Double

    /// Average confidence score across all results.
    public let avgConfidence: Double

    // MARK: - Latency

    /// Average latency in milliseconds.
    public let avgLatencyMs: Double

    /// Median (50th percentile) latency.
    public let p50LatencyMs: Double

    /// 95th percentile latency.
    public let p95LatencyMs: Double

    // MARK: - Computed Properties

    /// F1 score for each entity type.
    public var entityTypeF1: [String: Double] {
        var f1Scores: [String: Double] = [:]
        for (entityType, precision) in entityTypePrecision {
            let recall = entityTypeRecall[entityType] ?? 0.0
            if precision + recall > 0 {
                f1Scores[entityType] = 2 * (precision * recall) / (precision + recall)
            } else {
                f1Scores[entityType] = 0.0
            }
        }
        return f1Scores
    }

    /// Completion rate as a percentage.
    public var completionRate: Double {
        totalTests > 0 ? Double(completedTests) / Double(totalTests) : 0.0
    }

    // MARK: - Initialization

    /// Creates an evaluation summary with the given metrics.
    public init(
        totalTests: Int,
        completedTests: Int,
        skippedTests: Int,
        errorTests: Int,
        entityTypeAccuracy: Double,
        entityTypePrecision: [String: Double],
        entityTypeRecall: [String: Double],
        titleKeywordOverlapAvg: Double,
        startTimePresenceAccuracy: Double,
        startHourAccuracy: Double,
        endTimePresenceAccuracy: Double,
        recurrencePresenceAccuracy: Double,
        timePreferencePresenceAccuracy: Double,
        confidenceCalibrationRate: Double,
        avgConfidence: Double,
        avgLatencyMs: Double,
        p50LatencyMs: Double,
        p95LatencyMs: Double
    ) {
        self.totalTests = totalTests
        self.completedTests = completedTests
        self.skippedTests = skippedTests
        self.errorTests = errorTests
        self.entityTypeAccuracy = entityTypeAccuracy
        self.entityTypePrecision = entityTypePrecision
        self.entityTypeRecall = entityTypeRecall
        self.titleKeywordOverlapAvg = titleKeywordOverlapAvg
        self.startTimePresenceAccuracy = startTimePresenceAccuracy
        self.startHourAccuracy = startHourAccuracy
        self.endTimePresenceAccuracy = endTimePresenceAccuracy
        self.recurrencePresenceAccuracy = recurrencePresenceAccuracy
        self.timePreferencePresenceAccuracy = timePreferencePresenceAccuracy
        self.confidenceCalibrationRate = confidenceCalibrationRate
        self.avgConfidence = avgConfidence
        self.avgLatencyMs = avgLatencyMs
        self.p50LatencyMs = p50LatencyMs
        self.p95LatencyMs = p95LatencyMs
    }
}
