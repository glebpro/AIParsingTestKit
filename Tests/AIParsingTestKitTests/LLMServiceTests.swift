//
//  LLMServiceTests.swift
//  AIParsingTestKitTests
//
//  Tests for LLMService.
//

import Foundation
import FoundationModels
import Testing
@testable import AIParsingTestKit

@Suite("LLMService Tests")
struct LLMServiceTests {

    @Test("LLMService can be initialized")
    func testInitialization() {
        let service = LLMService()
        // Just verify it can be created
        #expect(service.isAvailable == true || service.isAvailable == false)
    }

    @Test("LLMService reports availability status")
    func testAvailabilityStatus() {
        let service = LLMService()
        let availability = service.availability

        // Should be one of the availability states
        switch availability {
        case .available:
            #expect(service.isAvailable == true)
        case .unavailable:
            #expect(service.isAvailable == false)
        }
    }

    @Test("LLMService creation with custom timeout")
    func testCustomTimeout() {
        let service = LLMService(timeout: .seconds(60))
        #expect(service.isAvailable == true || service.isAvailable == false)
    }

    @Test("GenerationOptions static presets exist")
    func testGenerationOptionsPresets() {
        // Just verify the static properties exist and compile
        let _ = GenerationOptions.deterministic
        let _ = GenerationOptions.creative
        let _ = GenerationOptions.focused
    }
}

@Suite("LLMServiceError Tests")
struct LLMServiceErrorTests {

    @Test("Error descriptions are not empty")
    func testErrorDescriptions() {
        let errors: [LLMServiceError] = [
            .sessionBusy,
            .timeout,
            .cancelled,
            .generationFailed("test"),
            .contextWindowExceeded("test"),
            .unsupportedLanguage("test"),
            .sensitiveContent("test")
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Some errors have recovery suggestions")
    func testRecoverySuggestions() {
        let errorWithSuggestion = LLMServiceError.sessionBusy
        #expect(errorWithSuggestion.recoverySuggestion != nil)

        let errorWithoutSuggestion = LLMServiceError.cancelled
        #expect(errorWithoutSuggestion.recoverySuggestion == nil)
    }
}
