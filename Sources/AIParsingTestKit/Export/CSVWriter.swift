//
//  CSVWriter.swift
//  AIParsingTestKit
//
//  Thread-safe actor for writing evaluation results to CSV files.
//

import Foundation

/// A thread-safe actor for accumulating evaluation results and writing them to CSV.
///
/// Uses the actor model to ensure thread safety when results are added
/// concurrently from parallel test execution.
///
/// Example:
/// ```swift
/// let writer = CSVWriter<MyTestCase, MyMetricProvider>()
/// await writer.setMetadata(metadata)
///
/// for result in results {
///     await writer.addResult(result)
/// }
///
/// let csvURL = try await writer.writeToFile()
/// ```
public actor CSVWriter<T: EvaluatableTestCase, M: MetricProvider> {
    private var results: [EvaluationResult<T>] = []
    private var metadata: RunMetadata?

    /// File prefix for exported files.
    public var filePrefix: String = "LLMEval"

    /// Whether to delete old files before writing new ones.
    public var deleteOldFiles: Bool = true

    /// Creates a new CSV writer.
    public init() {}

    /// Sets the metadata for this evaluation run.
    ///
    /// - Parameter metadata: The run metadata.
    public func setMetadata(_ metadata: RunMetadata) {
        self.metadata = metadata
    }

    /// Adds a result to the collection.
    ///
    /// - Parameter result: The evaluation result to add.
    public func addResult(_ result: EvaluationResult<T>) {
        results.append(result)
    }

    /// Returns the current number of results.
    public var resultCount: Int {
        results.count
    }

    /// Writes all accumulated results to a CSV file.
    ///
    /// - Returns: The URL of the written file.
    /// - Throws: If metadata is not set or file writing fails.
    public func writeToFile() throws -> URL {
        guard let metadata = metadata else {
            throw CSVWriterError.metadataNotSet
        }

        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Delete old files if requested
        if deleteOldFiles {
            try? deleteExistingFiles(in: documentsURL, withPrefix: "\(filePrefix)_", extension: "csv")
        }

        // Build CSV content
        let header = M.csvHeaders.joined(separator: ",") + "\n"
        var csvContent = header

        for result in results {
            let row = M.csvRow(from: result, metadata: metadata)
            let escapedRow = row.map { escapeCSVField($0) }
            csvContent += escapedRow.joined(separator: ",") + "\n"
        }

        // Write to file
        let timestamp = Date().timeIntervalSince1970
        let csvURL = documentsURL.appendingPathComponent(
            "\(filePrefix)_\(metadata.runId.prefix(8))_\(timestamp).csv"
        )

        try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)

        return csvURL
    }

    /// Escapes a field value for CSV format.
    private func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    /// Deletes existing files matching the prefix and extension.
    private func deleteExistingFiles(
        in directory: URL,
        withPrefix prefix: String,
        extension ext: String
    ) throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        for fileURL in files {
            if fileURL.lastPathComponent.hasPrefix(prefix)
                && fileURL.pathExtension == ext
            {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}

/// Errors that can occur during CSV writing.
public enum CSVWriterError: LocalizedError {
    case metadataNotSet

    public var errorDescription: String? {
        switch self {
        case .metadataNotSet:
            return "Metadata must be set before writing CSV"
        }
    }
}
