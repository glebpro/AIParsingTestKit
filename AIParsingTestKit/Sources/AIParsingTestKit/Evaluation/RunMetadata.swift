//
//  RunMetadata.swift
//  AIParsingTestKit
//
//  Metadata about an evaluation run for tracking and comparison.
//

import Foundation

/// Metadata about an evaluation run.
///
/// This structure captures context about the test run for:
/// - Historical tracking and comparison
/// - CSV export with run identification
/// - JSON summary generation
public struct RunMetadata: Codable, Sendable {
    /// Unique identifier for this run.
    public let runId: String

    /// ISO8601 timestamp of when the run started.
    public let timestamp: String

    /// Version identifier for the prompt being evaluated.
    public let promptVersion: String

    /// Device model identifier (e.g., "iPhone17,1").
    public let deviceModel: String

    /// Operating system version string.
    public let osVersion: String

    /// Total number of test cases in this run.
    public let testCount: Int

    /// Creates metadata manually.
    ///
    /// - Parameters:
    ///   - runId: Unique identifier for this run.
    ///   - timestamp: ISO8601 timestamp string.
    ///   - promptVersion: Version of the prompt being evaluated.
    ///   - deviceModel: Device model identifier.
    ///   - osVersion: Operating system version.
    ///   - testCount: Number of test cases.
    public init(
        runId: String,
        timestamp: String,
        promptVersion: String,
        deviceModel: String,
        osVersion: String,
        testCount: Int
    ) {
        self.runId = runId
        self.timestamp = timestamp
        self.promptVersion = promptVersion
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.testCount = testCount
    }

    /// Creates metadata for the current environment.
    ///
    /// Automatically captures:
    /// - A new UUID for the run
    /// - Current timestamp in ISO8601 format
    /// - Device model from system information
    /// - OS version from ProcessInfo
    ///
    /// - Parameters:
    ///   - promptVersion: Version identifier for the prompt being tested.
    ///   - testCount: Number of test cases in this run.
    /// - Returns: Configured metadata for the current run.
    public static func current(promptVersion: String, testCount: Int) -> RunMetadata {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var systemInfo = utsname()
        uname(&systemInfo)
        let deviceModel = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "Unknown"
            }
        }

        return RunMetadata(
            runId: UUID().uuidString,
            timestamp: formatter.string(from: Date()),
            promptVersion: promptVersion,
            deviceModel: deviceModel,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            testCount: testCount
        )
    }
}
