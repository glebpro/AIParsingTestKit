//
//  MockLLMService.swift
//  AIParsingTestKitTests
//
//  Mock LLM service for testing without Apple Intelligence.
//

import Foundation
import FoundationModels
@testable import AIParsingTestKit

/// A mock response generator for testing.
public protocol MockResponseGenerator: Sendable {
    associatedtype Output: Generable & Sendable
    func generate(from prompt: String) -> Output
}

/// A basic mock that always returns a fixed value.
public struct FixedResponseGenerator<T: Generable & Sendable>: MockResponseGenerator {
    public typealias Output = T

    private let response: T

    public init(response: T) {
        self.response = response
    }

    public func generate(from prompt: String) -> T {
        return response
    }
}

// Note: A full MockLLMService would require significant setup with FoundationModels.
// For unit testing, consider using protocol-based dependency injection
// in your domain code and providing test doubles there.
