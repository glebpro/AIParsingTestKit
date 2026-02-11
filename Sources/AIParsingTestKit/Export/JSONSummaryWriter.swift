//
//  JSONSummaryWriter.swift
//  AIParsingTestKit
//
//  Writes evaluation summaries to JSON files.
//

import Foundation

/// A writer for exporting evaluation summaries to JSON files.
///
/// Produces JSON files suitable for:
/// - Historical tracking and comparison
/// - Integration with analysis scripts
/// - Dashboard consumption
public struct JSONSummaryWriter {
    /// File prefix for exported files.
    public var filePrefix: String = "LLMEval"

    /// Whether to delete old summary files before writing.
    public var deleteOldFiles: Bool = true

    /// Creates a new JSON summary writer.
    public init() {}

    /// Writes an evaluation summary to a JSON file.
    ///
    /// - Parameters:
    ///   - summary: The evaluation summary to write.
    ///   - metadata: Run metadata for identification.
    /// - Returns: The URL of the written file.
    /// - Throws: If serialization or file writing fails.
    public func writeToFile(
        summary: EvaluationSummary,
        metadata: RunMetadata
    ) throws -> URL {
        let summaryDict: [String: Any] = [
            "run_id": metadata.runId,
            "timestamp": metadata.timestamp,
            "prompt_version": metadata.promptVersion,
            "device_model": metadata.deviceModel,
            "os_version": metadata.osVersion,
            "metrics": [
                "total_tests": summary.totalTests,
                "completed_tests": summary.completedTests,
                "skipped_tests": summary.skippedTests,
                "error_tests": summary.errorTests,
                "completion_rate": summary.completionRate,
                "entity_type_accuracy": summary.entityTypeAccuracy,
                "entity_type_precision": summary.entityTypePrecision,
                "entity_type_recall": summary.entityTypeRecall,
                "entity_type_f1": summary.entityTypeF1,
                "title_keyword_overlap_avg": summary.titleKeywordOverlapAvg,
                "start_time_presence_accuracy": summary.startTimePresenceAccuracy,
                "start_hour_accuracy": summary.startHourAccuracy,
                "end_time_presence_accuracy": summary.endTimePresenceAccuracy,
                "recurrence_presence_accuracy": summary.recurrencePresenceAccuracy,
                "time_preference_presence_accuracy": summary.timePreferencePresenceAccuracy,
                "confidence_calibration_rate": summary.confidenceCalibrationRate,
                "avg_confidence": summary.avgConfidence,
                "avg_latency_ms": summary.avgLatencyMs,
                "p50_latency_ms": summary.p50LatencyMs,
                "p95_latency_ms": summary.p95LatencyMs,
            ],
        ]

        let jsonData = try JSONSerialization.data(
            withJSONObject: summaryDict,
            options: [.prettyPrinted, .sortedKeys]
        )

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Delete old files if requested
        if deleteOldFiles {
            try? deleteExistingFiles(in: documentsURL)
        }

        let jsonURL = documentsURL.appendingPathComponent(
            "\(filePrefix)_\(metadata.runId.prefix(8))_summary.json"
        )

        try jsonData.write(to: jsonURL)

        return jsonURL
    }

    /// Deletes existing summary files.
    private func deleteExistingFiles(in directory: URL) throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        for fileURL in files {
            if fileURL.lastPathComponent.hasPrefix("\(filePrefix)_")
                && fileURL.lastPathComponent.hasSuffix("_summary.json")
            {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
