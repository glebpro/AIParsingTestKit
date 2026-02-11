//
//  LLMServiceProtocol.swift
//  AIParsingTestKit
//
//  Protocol defining the interface for LLM service implementations.
//

import Foundation
import FoundationModels

/// Protocol defining the interface for LLM service implementations.
///
/// This protocol abstracts the LLM service interface to enable dependency injection,
/// testing with mock implementations, and alternative service implementations.
public protocol LLMServiceProtocol: Sendable {
    // MARK: - Properties

    /// Indicates whether the on-device model is currently available.
    var isAvailable: Bool { get }

    /// The current availability status of the model.
    var availability: SystemLanguageModel.Availability { get }

    /// Indicates if the model is currently processing a request.
    var isResponding: Bool { get }

    /// Checks if the current locale is supported by the model.
    var supportsCurrentLocale: Bool { get }

    /// Returns a list of all supported languages.
    var supportedLanguages: Set<Locale.Language> { get }

    // MARK: - Session Management

    /// Creates a new session with optional instructions and tools.
    ///
    /// - Parameters:
    ///   - instructions: Instructions that define the model's behavior.
    ///   - tools: Custom tools the model can call during generation.
    /// - Returns: A configured language model session.
    /// - Throws: `LLMServiceError.modelUnavailable` if the model is not available.
    func createSession(
        instructions: String?,
        tools: [any Tool]
    ) throws -> LanguageModelSession

    /// Creates a session from an existing transcript to continue a conversation.
    ///
    /// - Parameters:
    ///   - transcript: The transcript to restore.
    ///   - tools: Custom tools the model can call during generation.
    /// - Returns: A configured language model session.
    /// - Throws: `LLMServiceError.modelUnavailable` if the model is not available.
    func createSession(
        from transcript: Transcript,
        tools: [any Tool]
    ) throws -> LanguageModelSession

    /// Preloads the model resources for faster response times.
    ///
    /// - Parameter promptPrefix: Optional prefix to cache for reduced latency.
    func prewarmSession(with promptPrefix: Prompt?)

    // MARK: - Simple Text Generation

    /// Generates a text response to a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - options: Generation options to control the response.
    /// - Returns: The generated text response.
    /// - Throws: `LLMServiceError` on failure.
    func respond(
        to prompt: String,
        session: LanguageModelSession?,
        options: GenerationOptions
    ) async throws -> String

    // MARK: - Structured Data Generation

    /// Generates a structured response conforming to a Generable type.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - type: The Generable type to generate.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - includeSchema: Whether to include the schema in the prompt.
    ///   - options: Generation options to control the response.
    /// - Returns: An instance of the specified Generable type.
    /// - Throws: `LLMServiceError` on failure.
    func respond<T: Generable & Sendable>(
        to prompt: String,
        generating type: T.Type,
        session: LanguageModelSession?,
        includeSchemaInPrompt includeSchema: Bool,
        options: GenerationOptions
    ) async throws -> T

    // MARK: - Streaming Responses

    /// Streams a text response to a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - options: Generation options to control the response.
    /// - Returns: An async stream of partial responses.
    /// - Throws: `LLMServiceError` on failure.
    func streamResponse(
        to prompt: String,
        session: LanguageModelSession?,
        options: GenerationOptions
    ) throws -> LanguageModelSession.ResponseStream<String>

    /// Streams a structured response conforming to a Generable type.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - type: The Generable type to generate.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - includeSchema: Whether to include the schema in the prompt.
    ///   - options: Generation options to control the response.
    /// - Returns: An async stream of partial responses.
    /// - Throws: `LLMServiceError` on failure.
    func streamResponse<T: Generable>(
        to prompt: String,
        generating type: T.Type,
        session: LanguageModelSession?,
        includeSchemaInPrompt includeSchema: Bool,
        options: GenerationOptions
    ) throws -> LanguageModelSession.ResponseStream<T>

    // MARK: - Feedback

    /// Logs feedback for a model response.
    ///
    /// - Parameters:
    ///   - sentiment: The sentiment of the feedback.
    ///   - issues: Specific issues with the response.
    ///   - desiredOutput: The desired output (optional).
    ///   - session: The session to log feedback for.
    /// - Returns: Serialized feedback data for reporting.
    func logFeedback(
        sentiment: LanguageModelFeedback.Sentiment?,
        issues: [LanguageModelFeedback.Issue],
        desiredOutput: Transcript.Entry?,
        session: LanguageModelSession?
    ) -> Data?

    // MARK: - Locale Support

    /// Checks if a specific locale is supported by the model.
    ///
    /// - Parameter locale: The locale to check.
    /// - Returns: Whether the locale is supported.
    func supports(locale: Locale) -> Bool
}

// MARK: - Default Parameter Extensions

public extension LLMServiceProtocol {
    /// Creates a new session with default parameters.
    func createSession() throws -> LanguageModelSession {
        try createSession(instructions: nil, tools: [])
    }

    /// Creates a new session with instructions only.
    func createSession(instructions: String) throws -> LanguageModelSession {
        try createSession(instructions: instructions, tools: [])
    }

    /// Creates a session from a transcript with default tools.
    func createSession(from transcript: Transcript) throws -> LanguageModelSession {
        try createSession(from: transcript, tools: [])
    }

    /// Preloads the model resources with no prefix.
    func prewarmSession() {
        prewarmSession(with: nil)
    }

    /// Generates a text response with default options.
    func respond(to prompt: String) async throws -> String {
        try await respond(to: prompt, session: nil, options: GenerationOptions())
    }

    /// Generates a text response with a session.
    func respond(to prompt: String, session: LanguageModelSession) async throws -> String {
        try await respond(to: prompt, session: session, options: GenerationOptions())
    }

    /// Generates a structured response with default options.
    func respond<T: Generable & Sendable>(
        to prompt: String,
        generating type: T.Type
    ) async throws -> T {
        try await respond(
            to: prompt,
            generating: type,
            session: nil,
            includeSchemaInPrompt: false,
            options: GenerationOptions()
        )
    }

    /// Generates a structured response with a session.
    func respond<T: Generable & Sendable>(
        to prompt: String,
        generating type: T.Type,
        session: LanguageModelSession
    ) async throws -> T {
        try await respond(
            to: prompt,
            generating: type,
            session: session,
            includeSchemaInPrompt: false,
            options: GenerationOptions()
        )
    }

    /// Streams a text response with default options.
    func streamResponse(to prompt: String) throws -> LanguageModelSession.ResponseStream<String> {
        try streamResponse(to: prompt, session: nil, options: GenerationOptions())
    }

    /// Streams a structured response with default options.
    func streamResponse<T: Generable>(
        to prompt: String,
        generating type: T.Type
    ) throws -> LanguageModelSession.ResponseStream<T> {
        try streamResponse(
            to: prompt,
            generating: type,
            session: nil,
            includeSchemaInPrompt: false,
            options: GenerationOptions()
        )
    }

    /// Logs feedback with minimal parameters.
    func logFeedback(
        sentiment: LanguageModelFeedback.Sentiment?,
        issues: [LanguageModelFeedback.Issue]
    ) -> Data? {
        logFeedback(sentiment: sentiment, issues: issues, desiredOutput: nil, session: nil)
    }
}
