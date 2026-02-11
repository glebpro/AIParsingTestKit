//
//  LLMService.swift
//  AIParsingTestKit
//
//  A generic service for interacting with Apple's on-device language model.
//  Implements FoundationModels best practices for robust LLM integration.
//

import Foundation
import FoundationModels
import Observation

/// A generic AI service that implements Foundation Models best practices.
///
/// This service provides a robust, reusable interface for interacting with
/// the on-device language model across different use cases.
///
/// Example:
/// ```swift
/// let service = LLMService()
/// if service.isAvailable {
///     let session = try service.createSession(instructions: "Parse user input...")
///     let result = try await service.respond(
///         to: userInput,
///         generating: MyGenerableType.self,
///         session: session
///     )
/// }
/// ```
@Observable
public final class LLMService: LLMServiceProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let model: SystemLanguageModel
    private let timeout: Duration
    private var currentSession: LanguageModelSession?

    /// Indicates whether the on-device model is currently available.
    public var isAvailable: Bool {
        model.isAvailable
    }

    /// The current availability status of the model.
    public var availability: SystemLanguageModel.Availability {
        model.availability
    }

    /// Indicates if the model is currently processing a request.
    public var isResponding: Bool {
        currentSession?.isResponding ?? false
    }

    // MARK: - Initialization

    /// Creates a new LLM service.
    ///
    /// - Parameters:
    ///   - useCase: The specific use case for the model (default is `.general`).
    ///   - timeout: Maximum duration to wait for responses (default is 30 seconds).
    public init(
        useCase: SystemLanguageModel.UseCase = .general,
        timeout: Duration = .seconds(30)
    ) {
        self.model = SystemLanguageModel(useCase: useCase)
        self.timeout = timeout
    }

    // MARK: - Session Management

    /// Creates a new session with optional instructions and tools.
    ///
    /// - Parameters:
    ///   - instructions: Instructions that define the model's behavior.
    ///   - tools: Custom tools the model can call during generation.
    /// - Returns: A configured language model session.
    /// - Throws: `LLMServiceError.modelUnavailable` if the model is not available.
    public func createSession(
        instructions: String? = nil,
        tools: [any Tool] = []
    ) throws -> LanguageModelSession {
        guard isAvailable else {
            throw LLMServiceError.modelUnavailable(availability)
        }

        let session: LanguageModelSession

        if let instructions = instructions {
            session = LanguageModelSession(
                model: model,
                tools: tools,
                instructions: Instructions {
                    instructions

                    // Add locale-specific instructions
                    localeInstructions()
                }
            )
        } else {
            session = LanguageModelSession(
                model: model,
                tools: tools
            )
        }

        self.currentSession = session
        return session
    }

    /// Creates a session from an existing transcript to continue a conversation.
    ///
    /// - Parameters:
    ///   - transcript: The transcript to restore.
    ///   - tools: Custom tools the model can call during generation.
    /// - Returns: A configured language model session.
    /// - Throws: `LLMServiceError.modelUnavailable` if the model is not available.
    public func createSession(
        from transcript: Transcript,
        tools: [any Tool] = []
    ) throws -> LanguageModelSession {
        guard isAvailable else {
            throw LLMServiceError.modelUnavailable(availability)
        }

        let session = LanguageModelSession(
            model: model,
            tools: tools,
            transcript: transcript
        )

        self.currentSession = session
        return session
    }

    /// Preloads the model resources for faster response times.
    ///
    /// - Parameter promptPrefix: Optional prefix to cache for reduced latency.
    public func prewarmSession(with promptPrefix: Prompt? = nil) {
        guard let session = currentSession else { return }
        session.prewarm(promptPrefix: promptPrefix)
    }

    // MARK: - Simple Text Generation

    /// Generates a text response to a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - options: Generation options to control the response.
    /// - Returns: The generated text response.
    /// - Throws: `LLMServiceError` on failure.
    public func respond(
        to prompt: String,
        session: LanguageModelSession? = nil,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> String {
        let activeSession = try session ?? createSession()

        guard !activeSession.isResponding else {
            throw LLMServiceError.sessionBusy
        }

        do {
            let response = try await withTimeout(timeout) {
                try await activeSession.respond(to: prompt, options: options).content
            }
            return response
        } catch let error as LanguageModelSession.GenerationError {
            throw handleGenerationError(error)
        }
    }

    // MARK: - Structured Data Generation

    /// Generates a structured response conforming to a Generable type.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - type: The Generable type to generate.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - includeSchema: Whether to include the schema in the prompt (default: false).
    ///   - options: Generation options to control the response.
    /// - Returns: An instance of the specified Generable type.
    /// - Throws: `LLMServiceError` on failure.
    public func respond<T: Generable & Sendable>(
        to prompt: String,
        generating type: T.Type,
        session: LanguageModelSession? = nil,
        includeSchemaInPrompt includeSchema: Bool = false,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> T {
        let activeSession = try session ?? createSession()

        guard !activeSession.isResponding else {
            throw LLMServiceError.sessionBusy
        }

        do {
            let response = try await withTimeout(timeout) {
                try await activeSession.respond(
                    to: prompt,
                    generating: type,
                    includeSchemaInPrompt: includeSchema,
                    options: options
                ).content
            }
            return response
        } catch let error as LanguageModelSession.GenerationError {
            throw handleGenerationError(error)
        }
    }

    // MARK: - Streaming Responses

    /// Streams a text response to a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - options: Generation options to control the response.
    /// - Returns: An async stream of partial responses.
    /// - Throws: `LLMServiceError` on failure.
    public func streamResponse(
        to prompt: String,
        session: LanguageModelSession? = nil,
        options: GenerationOptions = GenerationOptions()
    ) throws -> LanguageModelSession.ResponseStream<String> {
        let activeSession = try session ?? createSession()

        guard !activeSession.isResponding else {
            throw LLMServiceError.sessionBusy
        }

        return activeSession.streamResponse(to: prompt, options: options)
    }

    /// Streams a structured response conforming to a Generable type.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - type: The Generable type to generate.
    ///   - session: Optional existing session. If nil, creates a new one.
    ///   - includeSchema: Whether to include the schema in the prompt (default: false).
    ///   - options: Generation options to control the response.
    /// - Returns: An async stream of partial responses.
    /// - Throws: `LLMServiceError` on failure.
    public func streamResponse<T: Generable>(
        to prompt: String,
        generating type: T.Type,
        session: LanguageModelSession? = nil,
        includeSchemaInPrompt includeSchema: Bool = false,
        options: GenerationOptions = GenerationOptions()
    ) throws -> LanguageModelSession.ResponseStream<T> {
        let activeSession = try session ?? createSession()

        guard !activeSession.isResponding else {
            throw LLMServiceError.sessionBusy
        }

        return activeSession.streamResponse(
            to: prompt,
            generating: type,
            includeSchemaInPrompt: includeSchema,
            options: options
        )
    }

    // MARK: - Feedback

    /// Logs feedback for a model response.
    ///
    /// - Parameters:
    ///   - sentiment: The sentiment of the feedback.
    ///   - issues: Specific issues with the response.
    ///   - desiredOutput: The desired output (optional).
    ///   - session: The session to log feedback for.
    /// - Returns: Serialized feedback data for reporting.
    public func logFeedback(
        sentiment: LanguageModelFeedback.Sentiment?,
        issues: [LanguageModelFeedback.Issue],
        desiredOutput: Transcript.Entry? = nil,
        session: LanguageModelSession? = nil
    ) -> Data? {
        guard let activeSession = session ?? currentSession else {
            return nil
        }

        return activeSession.logFeedbackAttachment(
            sentiment: sentiment,
            issues: issues,
            desiredOutput: desiredOutput
        )
    }

    // MARK: - Helper Methods

    /// Generates locale-specific instructions for better response quality.
    private func localeInstructions(for locale: Locale = .current) -> String {
        // Skip locale phrase for U.S. English as per best practices
        if Locale.Language(identifier: "en_US").isEquivalent(to: locale.language) {
            return ""
        } else {
            // Use the exact phrase format recommended in documentation
            return "The locale is \(locale.identifier)."
        }
    }

    /// Handles generation errors and converts them to service-specific errors.
    private func handleGenerationError(_ error: LanguageModelSession.GenerationError) -> Error {
        let errorDescription = error.localizedDescription

        // Check error description for known patterns
        if errorDescription.contains("context window")
            || errorDescription.contains("Context window")
        {
            return LLMServiceError.contextWindowExceeded(errorDescription)
        } else if errorDescription.contains("language") || errorDescription.contains("locale") {
            return LLMServiceError.unsupportedLanguage(errorDescription)
        } else if errorDescription.contains("sensitive") || errorDescription.contains("policy")
            || errorDescription.contains("content")
        {
            return LLMServiceError.sensitiveContent(errorDescription)
        } else if errorDescription.contains("cancel") {
            return LLMServiceError.cancelled
        } else {
            return LLMServiceError.generationFailed(errorDescription)
        }
    }

    /// Executes an async operation with a timeout.
    private func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: duration)
                throw LLMServiceError.timeout
            }

            guard let result = try await group.next() else {
                throw LLMServiceError.timeout
            }

            group.cancelAll()
            return result
        }
    }
}

// MARK: - Generation Options Extensions

extension GenerationOptions {
    /// Creates options optimized for consistent, deterministic responses.
    /// Uses greedy sampling to always produce the same output for a given input.
    public static var deterministic: GenerationOptions {
        GenerationOptions(sampling: .greedy)
    }

    /// Creates options optimized for creative text generation.
    /// Uses higher temperature for more varied and creative responses.
    public static var creative: GenerationOptions {
        GenerationOptions(temperature: 1.5)
    }

    /// Creates options optimized for factual, focused responses.
    /// Uses lower temperature for more predictable outputs.
    public static var focused: GenerationOptions {
        GenerationOptions(temperature: 0.5)
    }
}

// MARK: - Locale Support

extension LLMService {
    /// Checks if the current locale is supported by the model.
    public var supportsCurrentLocale: Bool {
        model.supportsLocale()
    }

    /// Checks if a specific locale is supported by the model.
    ///
    /// - Parameter locale: The locale to check.
    /// - Returns: Whether the locale is supported.
    public func supports(locale: Locale) -> Bool {
        model.supportsLocale(locale)
    }

    /// Returns a list of all supported languages.
    public var supportedLanguages: Set<Locale.Language> {
        model.supportedLanguages
    }
}
