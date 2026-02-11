//
//  EvaluatableTestCase.swift
//  AIParsingTestKit
//
//  Protocol defining a test case that can be evaluated against an LLM.
//

import Foundation

/// A protocol defining a test case that can be evaluated against an LLM.
///
/// Test cases encapsulate:
/// - The input string to send to the LLM
/// - The expected output for comparison
/// - A human-readable description
///
/// Example:
/// ```swift
/// struct MyTestCase: EvaluatableTestCase {
///     let input: String
///     let expected: MyExpectedOutput
///     let description: String
/// }
/// ```
public protocol EvaluatableTestCase: Sendable {
    /// The type representing the expected output for comparison.
    associatedtype Expected: ExpectedOutput

    /// The input string to send to the LLM for parsing.
    var input: String { get }

    /// The expected output structure used for comparison.
    var expected: Expected { get }

    /// A human-readable description of this test case.
    var description: String { get }
}
