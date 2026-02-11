//
//  CalendarData.swift
//  CalendarParsingTests
//
//  Test data and types for calendar parsing evaluation.
//

import Foundation
import FoundationModels
@testable import AIParsingTestKit

// MARK: - Generable Output Type

/// The output type that the LLM generates for calendar parsing.
@Generable
public struct CalendarEventOutput: Sendable {
    @Guide(description: "The type of calendar item: 'event' for time-bound events, 'task' for to-dos, or 'reminder' for simple reminders")
    public var entityType: String

    @Guide(description: "The title or name of the event/task")
    public var title: String

    @Guide(description: "Start date and time in ISO8601 format (e.g., '2024-03-15T14:00:00'), or nil if not specified")
    public var startDateTime: String?

    @Guide(description: "End date and time in ISO8601 format, or nil if not specified")
    public var endDateTime: String?

    @Guide(description: "Whether this is an all-day event")
    public var isAllDay: Bool

    @Guide(description: "Location of the event, or nil if not specified")
    public var location: String?

    @Guide(description: "Recurrence pattern: 'daily', 'weekly', 'monthly', 'yearly', or nil for one-time events")
    public var recurrence: String?

    @Guide(description: "Time preference when exact time not specified: 'morning', 'afternoon', 'evening', 'night', or nil")
    public var timePreference: String?

    @Guide(description: "Confidence score between 0.0 and 1.0")
    public var confidence: Double
}

// MARK: - Expected Output

/// Expected output for calendar parsing test cases.
public struct CalendarExpectedOutput: ExpectedOutput {
    public typealias ActualOutput = CalendarEventOutput

    public let entityType: String
    public let titleKeywords: [String]
    public let hasStartTime: Bool
    public let expectedStartHour: Int?
    public let hasEndTime: Bool
    public let isAllDay: Bool
    public let hasLocation: Bool
    public let expectedLocation: String?
    public let recurrence: String?
    public let timePreference: String?
    public let minimumConfidence: Double

    public init(
        entityType: String,
        titleKeywords: [String],
        hasStartTime: Bool = false,
        expectedStartHour: Int? = nil,
        hasEndTime: Bool = false,
        isAllDay: Bool = false,
        hasLocation: Bool = false,
        expectedLocation: String? = nil,
        recurrence: String? = nil,
        timePreference: String? = nil,
        minimumConfidence: Double = 0.7
    ) {
        self.entityType = entityType
        self.titleKeywords = titleKeywords
        self.hasStartTime = hasStartTime
        self.expectedStartHour = expectedStartHour
        self.hasEndTime = hasEndTime
        self.isAllDay = isAllDay
        self.hasLocation = hasLocation
        self.expectedLocation = expectedLocation
        self.recurrence = recurrence
        self.timePreference = timePreference
        self.minimumConfidence = minimumConfidence
    }

    public func compare(to actual: CalendarEventOutput) -> [String: MetricValue] {
        var metrics: [String: MetricValue] = [:]

        // Entity type accuracy
        metrics["entity_type_correct"] = .boolean(
            actual.entityType.lowercased() == entityType.lowercased()
        )
        metrics["entity_type_actual"] = .string(actual.entityType)

        // Title keyword overlap
        let titleLower = actual.title.lowercased()
        let matchedKeywords = titleKeywords.filter { titleLower.contains($0.lowercased()) }
        let overlap = titleKeywords.isEmpty ? 1.0 : Double(matchedKeywords.count) / Double(titleKeywords.count)
        metrics["title_keyword_overlap"] = .double(overlap)

        // Start time presence
        metrics["start_time_presence_correct"] = .boolean(
            (actual.startDateTime != nil) == hasStartTime
        )

        // Start hour accuracy (if expected)
        if let expectedHour = expectedStartHour, let startDateTime = actual.startDateTime {
            let actualHour = extractHour(from: startDateTime)
            metrics["start_hour_correct"] = .boolean(actualHour == expectedHour)
            metrics["start_hour_actual"] = .optionalInteger(actualHour)
        } else {
            metrics["start_hour_correct"] = .boolean(expectedStartHour == nil)
            metrics["start_hour_actual"] = .optionalInteger(nil)
        }

        // End time presence
        metrics["end_time_presence_correct"] = .boolean(
            (actual.endDateTime != nil) == hasEndTime
        )

        // All-day accuracy
        metrics["is_all_day_correct"] = .boolean(actual.isAllDay == isAllDay)

        // Location presence and accuracy
        metrics["location_presence_correct"] = .boolean(
            (actual.location != nil) == hasLocation
        )
        if let expectedLoc = expectedLocation, let actualLoc = actual.location {
            metrics["location_match"] = .boolean(
                actualLoc.lowercased().contains(expectedLoc.lowercased())
            )
        }

        // Recurrence accuracy
        metrics["recurrence_presence_correct"] = .boolean(
            (actual.recurrence != nil) == (recurrence != nil)
        )
        if let expectedRec = recurrence, let actualRec = actual.recurrence {
            metrics["recurrence_match"] = .boolean(
                actualRec.lowercased() == expectedRec.lowercased()
            )
        }

        // Time preference accuracy
        metrics["time_preference_presence_correct"] = .boolean(
            (actual.timePreference != nil) == (timePreference != nil)
        )
        if let expectedPref = timePreference, let actualPref = actual.timePreference {
            metrics["time_preference_match"] = .boolean(
                actualPref.lowercased() == expectedPref.lowercased()
            )
        }

        // Confidence
        metrics["confidence"] = .double(actual.confidence)
        metrics["confidence_calibrated"] = .boolean(actual.confidence >= minimumConfidence)

        return metrics
    }

    private func extractHour(from isoString: String) -> Int? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return Calendar.current.component(.hour, from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return Calendar.current.component(.hour, from: date)
        }
        // Try basic format
        if isoString.contains("T") {
            let parts = isoString.components(separatedBy: "T")
            if parts.count > 1 {
                let timePart = parts[1].prefix(2)
                return Int(timePart)
            }
        }
        return nil
    }
}

// MARK: - Test Case

/// A calendar parsing test case.
public struct CalendarTestCase: EvaluatableTestCase {
    public let input: String
    public let expected: CalendarExpectedOutput
    public let description: String

    public init(input: String, expected: CalendarExpectedOutput, description: String) {
        self.input = input
        self.expected = expected
        self.description = description
    }
}

// MARK: - Metric Provider

/// Metric provider for calendar parsing evaluation.
public struct CalendarMetricProvider: MetricProvider {
    public static let entityTypes = ["event", "task", "habit", "override", "unknown"]

    public static let csvHeaders = [
        "run_id", "timestamp", "input", "description",
        "expected_entity_type", "actual_entity_type", "entity_type_correct",
        "title_keyword_overlap", "start_time_presence_correct", "start_hour_correct",
        "end_time_presence_correct", "recurrence_presence_correct",
        "time_preference_presence_correct", "confidence", "confidence_calibrated",
        "latency_ms", "status"
    ]

    public static func csvRow<T: EvaluatableTestCase>(
        from result: EvaluationResult<T>,
        metadata: RunMetadata
    ) -> [String] {
        let testCase = result.testCase
        let input = testCase.input
        let description = testCase.description

        // Extract expected entity type if available
        let expectedEntityType: String
        if let calendarCase = testCase as? CalendarTestCase {
            expectedEntityType = calendarCase.expected.entityType
        } else {
            expectedEntityType = ""
        }

        return [
            metadata.runId,
            metadata.timestamp,
            input,
            description,
            expectedEntityType,
            result.metrics["entity_type_actual"]?.csvString ?? "",
            String(result.metrics["entity_type_correct"]?.boolValue ?? false),
            String(result.metrics["title_keyword_overlap"]?.doubleValue ?? 0),
            String(result.metrics["start_time_presence_correct"]?.boolValue ?? false),
            String(result.metrics["start_hour_correct"]?.boolValue ?? false),
            String(result.metrics["end_time_presence_correct"]?.boolValue ?? false),
            String(result.metrics["recurrence_presence_correct"]?.boolValue ?? false),
            String(result.metrics["time_preference_presence_correct"]?.boolValue ?? false),
            String(result.metrics["confidence"]?.doubleValue ?? 0),
            String(result.metrics["confidence_calibrated"]?.boolValue ?? false),
            String(format: "%.2f", result.latencyMs),
            result.status.rawValue
        ]
    }
}

// MARK: - Sample Test Data

/// Sample test cases for calendar parsing evaluation.
public enum CalendarTestData {

    /// Basic event parsing test cases.
    public static let basicEvents: [CalendarTestCase] = [
        CalendarTestCase(
            input: "Meeting with John tomorrow at 3pm",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["meeting", "john"],
                hasStartTime: true,
                expectedStartHour: 15
            ),
            description: "Simple meeting with person and time"
        ),
        CalendarTestCase(
            input: "Dentist appointment on Friday at 10:30am",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["dentist", "appointment"],
                hasStartTime: true,
                expectedStartHour: 10
            ),
            description: "Appointment with day and specific time"
        ),
        CalendarTestCase(
            input: "Team standup every morning at 9am",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["team", "standup"],
                hasStartTime: true,
                expectedStartHour: 9,
                recurrence: "daily"
            ),
            description: "Recurring daily event"
        ),
        CalendarTestCase(
            input: "Birthday party at Sarah's house on Saturday",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["birthday", "party"],
                hasLocation: true,
                expectedLocation: "sarah"
            ),
            description: "Event with location"
        ),
        CalendarTestCase(
            input: "Conference call from 2pm to 4pm",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["conference", "call"],
                hasStartTime: true,
                expectedStartHour: 14,
                hasEndTime: true
            ),
            description: "Event with start and end time"
        ),
    ]

    /// Task parsing test cases.
    public static let tasks: [CalendarTestCase] = [
        CalendarTestCase(
            input: "Buy groceries",
            expected: CalendarExpectedOutput(
                entityType: "task",
                titleKeywords: ["buy", "groceries"]
            ),
            description: "Simple task without time"
        ),
        CalendarTestCase(
            input: "Finish report by Friday",
            expected: CalendarExpectedOutput(
                entityType: "task",
                titleKeywords: ["finish", "report"]
            ),
            description: "Task with deadline"
        ),
        CalendarTestCase(
            input: "Call mom this evening",
            expected: CalendarExpectedOutput(
                entityType: "task",
                titleKeywords: ["call", "mom"],
                timePreference: "evening"
            ),
            description: "Task with time preference"
        ),
        CalendarTestCase(
            input: "Review pull requests in the morning",
            expected: CalendarExpectedOutput(
                entityType: "task",
                titleKeywords: ["review", "pull", "requests"],
                timePreference: "morning"
            ),
            description: "Task with morning preference"
        ),
    ]

    /// All-day event test cases.
    public static let allDayEvents: [CalendarTestCase] = [
        CalendarTestCase(
            input: "Vacation day on Monday",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["vacation"],
                isAllDay: true
            ),
            description: "All-day vacation"
        ),
        CalendarTestCase(
            input: "Company holiday December 25th",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["company", "holiday"],
                isAllDay: true
            ),
            description: "All-day holiday"
        ),
    ]

    /// Recurring event test cases.
    public static let recurringEvents: [CalendarTestCase] = [
        CalendarTestCase(
            input: "Weekly team meeting every Tuesday at 2pm",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["team", "meeting"],
                hasStartTime: true,
                expectedStartHour: 14,
                recurrence: "weekly"
            ),
            description: "Weekly recurring meeting"
        ),
        CalendarTestCase(
            input: "Monthly book club on the first Friday",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["book", "club"],
                recurrence: "monthly"
            ),
            description: "Monthly recurring event"
        ),
        CalendarTestCase(
            input: "Annual performance review in January",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["performance", "review"],
                recurrence: "yearly"
            ),
            description: "Yearly recurring event"
        ),
    ]

    /// Edge cases and ambiguous inputs.
    public static let edgeCases: [CalendarTestCase] = [
        CalendarTestCase(
            input: "Lunch",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["lunch"],
                timePreference: "afternoon"
            ),
            description: "Minimal input - just lunch"
        ),
        CalendarTestCase(
            input: "Something important next week",
            expected: CalendarExpectedOutput(
                entityType: "event",
                titleKeywords: ["important"]
            ),
            description: "Vague event description"
        ),
        CalendarTestCase(
            input: "Pick up kids at 3:30",
            expected: CalendarExpectedOutput(
                entityType: "task",
                titleKeywords: ["pick", "kids"],
                hasStartTime: true,
                expectedStartHour: 15
            ),
            description: "Task with specific time"
        ),
    ]

    /// All test cases combined.
    public static var allTestCases: [CalendarTestCase] {
        basicEvents + tasks + allDayEvents + recurringEvents + edgeCases
    }
}
