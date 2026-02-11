//
//  LLMServiceError.swift
//  AIParsingTestKit
//
//  Error types for LLM service operations.
//

import Foundation
import FoundationModels

/// Errors that can occur when using the LLM service.
public enum LLMServiceError: LocalizedError, Sendable {
    /// The model is not available on this device.
    case modelUnavailable(SystemLanguageModel.Availability)

    /// The session is already processing a request.
    case sessionBusy

    /// The request exceeded the timeout duration.
    case timeout

    /// The context window was exceeded.
    case contextWindowExceeded(String)

    /// The language or locale is not supported.
    case unsupportedLanguage(String)

    /// The content was flagged as sensitive.
    case sensitiveContent(String)

    /// The request was cancelled.
    case cancelled

    /// Generation failed with the given details.
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable(let availability):
            switch availability {
            case .available:
                return "Model is available but reported as unavailable."
            case .unavailable(.deviceNotEligible):
                return "This device doesn't support Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence is not enabled. Please enable it in Settings."
            case .unavailable(.modelNotReady):
                return "The model isn't ready yet. It may still be downloading."
            case .unavailable:
                return "The model is currently unavailable."
            }
        case .sessionBusy:
            return "The session is already processing a request. Please wait for it to complete."
        case .timeout:
            return "The request timed out. Please try again."
        case .contextWindowExceeded(let details):
            return "Context window size exceeded: \(details). Try creating a new session with a shorter prompt."
        case .unsupportedLanguage(let details):
            return "Unsupported language or locale: \(details)"
        case .sensitiveContent(let details):
            return "Sensitive content detected: \(details)"
        case .cancelled:
            return "The request was cancelled."
        case .generationFailed(let details):
            return "Generation failed: \(details)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelUnavailable(.unavailable(.appleIntelligenceNotEnabled)):
            return "Go to Settings > Apple Intelligence & Siri to enable Apple Intelligence."
        case .modelUnavailable(.unavailable(.modelNotReady)):
            return "Wait a few moments and try again."
        case .sessionBusy:
            return "Wait for the current request to complete before starting a new one."
        case .contextWindowExceeded:
            return "Break your task into smaller parts or create a new session."
        case .timeout:
            return "Check your prompt length and try again with a shorter prompt."
        default:
            return nil
        }
    }
}
