//
//  AIParsingTestKit.swift
//  AIParsingTestKit
//
//  Main module file - re-exports all public types.
//

import Foundation
import FoundationModels

// MARK: - Core

// LLMService and error types are exported from Core/

// MARK: - Protocols

// EvaluatableTestCase, ExpectedOutput, and MetricProvider are exported from Protocols/

// MARK: - Evaluation

// EvaluationRunner, EvaluationResult, EvaluationSummary, RunMetadata, and MetricsCalculator
// are exported from Evaluation/

// MARK: - Export

// CSVWriter and JSONSummaryWriter are exported from Export/

// MARK: - Convenience Type Aliases

/// A type alias for the result of evaluating a test case.
public typealias TestResult<T: EvaluatableTestCase> = EvaluationResult<T>

// MARK: - Version

/// The current version of AIParsingTestKit.
public enum AIParsingTestKitVersion {
    public static let major = 1
    public static let minor = 0
    public static let patch = 0

    public static var string: String {
        "\(major).\(minor).\(patch)"
    }
}
