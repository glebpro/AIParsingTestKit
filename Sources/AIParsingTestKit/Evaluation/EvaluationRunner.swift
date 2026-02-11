//
//  EvaluationRunner.swift
//  AIParsingTestKit
//
//  Runs test cases against the LLM and collects results.
//

import Foundation
import FoundationModels

/// A runner that evaluates test cases against an LLM.
///
/// The runner handles:
/// - Session creation with custom instructions
/// - Timing measurements
/// - Error handling and recovery
/// - Result collection
///
/// Example:
/// ```swift
/// let service = LLMService()
/// let runner = EvaluationRunner<MyTestCase>(
///     service: service,
///     instructions: "Parse user input...",
///     promptBuilder: { testCase in
///         "Current date: \(Date())\nInput: \(testCase.input)"
///     }
/// )
///
/// let result = try await runner.evaluate(testCase: testCase)
/// ```
public struct EvaluationRunner<T: EvaluatableTestCase> {
    private let service: LLMService
    private let instructions: String?
    private let promptBuilder: (T) -> String

    /// Creates an evaluation runner.
    ///
    /// - Parameters:
    ///   - service: The LLM service to use for generation.
    ///   - instructions: Optional system instructions for the model.
    ///   - promptBuilder: A closure that builds the prompt from a test case.
    public init(
        service: LLMService,
        instructions: String? = nil,
        promptBuilder: @escaping (T) -> String
    ) {
        self.service = service
        self.instructions = instructions
        self.promptBuilder = promptBuilder
    }

    /// Evaluates a single test case.
    ///
    /// - Parameter testCase: The test case to evaluate.
    /// - Returns: The evaluation result.
    public func evaluate(testCase: T) async -> EvaluationResult<T> {
        guard service.isAvailable else {
            return EvaluationResult(
                testCase: testCase,
                error: "Apple Intelligence unavailable"
            )
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let prompt = promptBuilder(testCase)

        do {
            let session = try service.createSession(instructions: instructions)
            let result = try await service.respond(
                to: prompt,
                generating: T.Expected.ActualOutput.self,
                session: session,
                includeSchemaInPrompt: true,
                options: GenerationOptions()
            )

            let endTime = CFAbsoluteTimeGetCurrent()
            let latencyMs = (endTime - startTime) * 1000

            return EvaluationResult(
                testCase: testCase,
                actualOutput: result,
                latencyMs: latencyMs
            )
        } catch {
            let endTime = CFAbsoluteTimeGetCurrent()
            let latencyMs = (endTime - startTime) * 1000

            return EvaluationResult(
                testCase: testCase,
                error: String(describing: error),
                latencyMs: latencyMs
            )
        }
    }

    /// Evaluates multiple test cases sequentially.
    ///
    /// - Parameter testCases: The test cases to evaluate.
    /// - Returns: Array of evaluation results.
    public func evaluateAll(testCases: [T]) async -> [EvaluationResult<T>] {
        var results: [EvaluationResult<T>] = []

        for testCase in testCases {
            let result = await evaluate(testCase: testCase)
            results.append(result)
        }

        return results
    }
}
