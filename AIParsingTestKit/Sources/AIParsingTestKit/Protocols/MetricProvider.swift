//
//  MetricProvider.swift
//  AIParsingTestKit
//
//  Protocol defining how to format evaluation results for export.
//

import Foundation

/// A protocol for providing domain-specific metrics and CSV formatting.
///
/// Implementations define:
/// - Entity types for classification (e.g., ["task", "event", "habit"])
/// - CSV column headers
/// - How to format each result row for CSV export
///
/// Example:
/// ```swift
/// struct MyMetricProvider: MetricProvider {
///     static let entityTypes = ["category_a", "category_b", "unknown"]
///
///     static let csvHeaders = [
///         "run_id", "timestamp", "input", "expected_category",
///         "actual_category", "correct", "latency_ms"
///     ]
///
///     static func csvRow<T: EvaluatableTestCase>(
///         from result: EvaluationResult<T>,
///         metadata: RunMetadata
///     ) -> [String] {
///         // Build row from result data
///     }
/// }
/// ```
public protocol MetricProvider: Sendable {
    /// The entity types used for classification (e.g., ["task", "event", "habit"]).
    static var entityTypes: [String] { get }

    /// The CSV header columns for detailed result export.
    static var csvHeaders: [String] { get }

    /// Formats an evaluation result as a CSV row.
    ///
    /// - Parameters:
    ///   - result: The evaluation result to format.
    ///   - metadata: Run metadata for context (run ID, timestamp, etc.).
    /// - Returns: An array of strings representing the CSV row.
    static func csvRow<T: EvaluatableTestCase>(
        from result: EvaluationResult<T>,
        metadata: RunMetadata
    ) -> [String]
}
