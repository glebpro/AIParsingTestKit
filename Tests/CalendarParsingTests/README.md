# Calendar Parsing Tests

Evaluation tests for calendar event/task parsing using the AIParsingTestKit framework.

## Running Tests

### Run all calendar parsing tests

```bash
swift test --filter CalendarParsingTests
```

### Run specific test suites

```bash
# Basic event parsing
swift test --filter BasicEventTests

# Task parsing
swift test --filter TaskParsingTests

# All-day events
swift test --filter AllDayEventTests

# Recurring events
swift test --filter RecurringEventTests

# Edge cases
swift test --filter EdgeCaseTests

# Full evaluation with metrics
swift test --filter FullEvaluationTests
```

### Run tests by tag

```bash
# All parsing tests
swift test --filter CalendarParsingTests --tags parsing

# Evaluation tests only
swift test --filter CalendarParsingTests --tags evaluation

# Edge case tests
swift test --filter CalendarParsingTests --tags edgeCase
```

## Requirements

- macOS 26+ or iOS 26+
- Swift 6.2+
- On-device language model availability (Apple Intelligence)

## Test Structure

- **CalendarData.swift** - Test fixtures, expected outputs, and sample test cases
- **CalendarParsingTests.swift** - Test suites using Swift Testing framework

## Test Categories

| Category | Description |
|----------|-------------|
| Basic Events | Simple meetings, appointments with times |
| Tasks | To-do items with/without deadlines |
| All-Day Events | Vacations, holidays without specific times |
| Recurring Events | Daily, weekly, monthly, yearly patterns |
| Edge Cases | Minimal input, ambiguous descriptions |
