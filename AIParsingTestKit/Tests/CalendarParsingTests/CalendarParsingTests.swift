//
//  CalendarParsingTests.swift
//  CalendarParsingTests
//
//  Evaluation tests for calendar parsing using the AIParsingTestKit framework.
//

import Foundation
import FoundationModels
import Testing
@testable import AIParsingTestKit

// MARK: - Calendar Parsing Instructions

private let calendarParsingInstructions = """
Parse this user input into a structured entity for a task management app.

Entity Classification Rules:

1. EVENT (entityType: "event")
    - External calendar items: meetings, appointments, events with others
    - Fixed time slots that user doesn't control (set by others or external systems)
    - Examples: "Meeting with John at 2pm", "Doctor appointment Tuesday", "Conference call 3-4pm"
    - Set source: "external" for calendar imports, "internal" for user-created events

2. TASK (entityType: "task")
    - User-controlled items: things to do that user schedules themselves
    - Can have specific times OR be unscheduled (just needs to get done)
    - Examples: "Buy groceries", "Finish report by Friday", "Call mom tomorrow at 5pm"
    - Set priority: "low", "medium", "high", or "urgent" based on language cues

3. HABIT (entityType: "habit")
    - Recurring activities the scheduling engine finds time for
    - User specifies duration and frequency, NOT specific times
    - Examples: "Exercise 30 min daily", "Meditate 10 minutes every morning", "Read for an hour 3x/week"
    - Set timePreference: "morning", "afternoon", "evening", or specific like "early mornings"

4. OVERRIDE (entityType: "override")
    - Time blocks that constrain what CAN or CANNOT be scheduled
    - Context/constraint blocks, NOT tasks themselves
    - Examples: "I sleep 11pm-7am", "Commute 8-9am weekdays", "Work hours 9-5 Mon-Fri"
    - These describe when user is unavailable or in specific contexts

5. UNKNOWN (entityType: "unknown")
    - Ambiguous input needing clarification
    - Could fit multiple categories
    - Missing critical information

Date/Time Rules:
- Convert relative dates ("Tuesday", "tomorrow") to ISO8601 format
- Time-only inputs ("2pm") = today at that time
- No time specified = leave startTime/endTime as nil

Priority Detection (for tasks):
- "urgent", "ASAP", "immediately" → "urgent"
- "important", "high priority" → "high"
- "when you can", "low priority" → "low"
- Default → "medium"

Confidence scoring (0.0-1.0):
- 0.9-1.0: Very confident, all key information present
- 0.7-0.89: Confident, minor inference needed
- 0.5-0.69: Moderate, some ambiguity
- Below 0.5: Low confidence, may need clarification
"""


// MARK: - Test Suites

@Suite("Calendar Parsing - Basic Events")
struct BasicEventTests {

    @Test("Parse simple meeting with time", .tags(.parsing))
    func testSimpleMeeting() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.basicEvents[0]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["entity_type_correct"]?.boolValue == true)
        #expect((result.metrics["title_keyword_overlap"]?.doubleValue ?? 0) > 0.5)
    }

    @Test("Parse appointment with day and time", .tags(.parsing))
    func testAppointment() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.basicEvents[1]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["entity_type_correct"]?.boolValue == true)
    }

    @Test("Parse event with location", .tags(.parsing))
    func testEventWithLocation() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.basicEvents[3]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["location_presence_correct"]?.boolValue == true)
    }

    @Test("Parse event with start and end time", .tags(.parsing))
    func testEventWithDuration() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.basicEvents[4]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["start_time_presence_correct"]?.boolValue == true)
        #expect(result.metrics["end_time_presence_correct"]?.boolValue == true)
    }
}

@Suite("Calendar Parsing - Tasks")
struct TaskParsingTests {

    @Test("Parse simple task", .tags(.parsing))
    func testSimpleTask() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.tasks[0]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["entity_type_correct"]?.boolValue == true)
    }

    @Test("Parse task with time preference", .tags(.parsing))
    func testTaskWithTimePreference() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.tasks[2]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["time_preference_presence_correct"]?.boolValue == true)
    }
}

@Suite("Calendar Parsing - All Day Events")
struct AllDayEventTests {

    @Test("Parse vacation day", .tags(.parsing))
    func testVacationDay() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.allDayEvents[0]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["is_all_day_correct"]?.boolValue == true)
    }

    @Test("Parse holiday", .tags(.parsing))
    func testHoliday() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.allDayEvents[1]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["is_all_day_correct"]?.boolValue == true)
    }
}

@Suite("Calendar Parsing - Recurring Events")
struct RecurringEventTests {

    @Test("Parse weekly recurring event", .tags(.parsing))
    func testWeeklyRecurrence() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.recurringEvents[0]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["recurrence_presence_correct"]?.boolValue == true)
    }

    @Test("Parse monthly recurring event", .tags(.parsing))
    func testMonthlyRecurrence() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.recurringEvents[1]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["recurrence_presence_correct"]?.boolValue == true)
    }

    @Test("Parse daily recurring event", .tags(.parsing))
    func testDailyRecurrence() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.basicEvents[2] // Team standup every morning
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.metrics["recurrence_presence_correct"]?.boolValue == true)
    }
}

@Suite("Calendar Parsing - Edge Cases")
struct EdgeCaseTests {

    @Test("Parse minimal input", .tags(.parsing, .edgeCase))
    func testMinimalInput() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.edgeCases[0]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.actualOutput != nil)
    }

    @Test("Parse vague description", .tags(.parsing, .edgeCase))
    func testVagueDescription() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let testCase = CalendarTestData.edgeCases[1]
        let result = await runner.evaluate(testCase: testCase)

        #expect(result.status == .completed)
        #expect(result.actualOutput != nil)
    }
}

@Suite("Calendar Parsing - Full Evaluation")
struct FullEvaluationTests {

    @Test("Evaluate all test cases", .tags(.evaluation))
    func testFullEvaluation() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let results = await runner.evaluateAll(testCases: CalendarTestData.allTestCases)

        let completed = results.filter { $0.status == .completed }
        let errors = results.filter { $0.status == .error }

        // At least 80% should complete successfully
        let completionRate = Double(completed.count) / Double(results.count)
        #expect(completionRate >= 0.8, "Completion rate should be at least 80%")

        // Calculate entity type accuracy
        let entityTypeCorrect = completed.filter {
            $0.metrics["entity_type_correct"]?.boolValue == true
        }
        let entityAccuracy = Double(entityTypeCorrect.count) / Double(completed.count)
        #expect(entityAccuracy >= 0.7, "Entity type accuracy should be at least 70%")

        // Log summary for debugging
        print("=== Calendar Parsing Evaluation Summary ===")
        print("Total: \(results.count)")
        print("Completed: \(completed.count)")
        print("Errors: \(errors.count)")
        print("Entity Type Accuracy: \(String(format: "%.1f", entityAccuracy * 100))%")

        if !errors.isEmpty {
            print("\nErrors:")
            for result in errors {
                print("  - \(result.testCase.description): \(result.error ?? "unknown")")
            }
        }
    }

    @Test("Generate evaluation summary", .tags(.evaluation))
    func testEvaluationSummary() async throws {
        let service = LLMService()
        guard service.isAvailable else {
            throw TestSkipError("Model not available")
        }

        let runner = createRunner(service: service)
        let results = await runner.evaluateAll(testCases: CalendarTestData.basicEvents)

        let calculator = MetricsCalculator<CalendarTestCase, CalendarMetricProvider>()
        let summary = calculator.calculateSummary(
            from: results,
            expectedEntityTypeExtractor: { $0.expected.entityType },
            actualEntityTypeExtractor: { $0.entityType }
        )

        #expect(summary.totalTests == CalendarTestData.basicEvents.count)
        #expect(summary.completionRate > 0)

        print("=== Metrics Summary ===")
        print("Entity Type Accuracy: \(String(format: "%.1f", summary.entityTypeAccuracy * 100))%")
        print("Avg Latency: \(String(format: "%.0f", summary.avgLatencyMs))ms")
        print("P50 Latency: \(String(format: "%.0f", summary.p50LatencyMs))ms")
        print("P95 Latency: \(String(format: "%.0f", summary.p95LatencyMs))ms")
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var parsing: Self
    @Tag static var evaluation: Self
    @Tag static var edgeCase: Self
}

// MARK: - Test Skip Error

struct TestSkipError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}

// MARK: - Helper Functions

private func createRunner(service: LLMService) -> EvaluationRunner<CalendarTestCase> {
    EvaluationRunner(
        service: service,
        instructions: calendarParsingInstructions,
        promptBuilder: { testCase in
            """
            Parse the following natural language input into a calendar event or task.

            Input: \(testCase.input)
            """
        }
    )
}
