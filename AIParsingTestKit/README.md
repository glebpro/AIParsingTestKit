# AIParsingTestKit

A Swift package for evaluating `@Generable` types using Apple's FoundationModels framework. This framework provides a protocol-based, generic approach to running LLM evaluations with comprehensive metrics tracking.

## Features

- **Generic Protocol-Based Design**: Works with any `@Generable` type
- **Comprehensive Metrics**: Entity classification, field extraction accuracy, confidence calibration
- **CSV Export**: Detailed per-test results for analysis
- **JSON Summary**: Aggregated metrics for historical tracking
- **Python Analysis Scripts**: Visualization and trend analysis

## Requirements

- iOS 26.0+ / macOS 26.0+
- Swift 6.0+
- Xcode 26.0+
- Device with Apple Intelligence support

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../AIParsingTestKit")
]
```

Or add via Xcode:
1. File → Add Package Dependencies
2. Click "Add Local..."
3. Select the `AIParsingTestKit` directory

## Usage

### 1. Define Your Test Case Type

```swift
import AIParsingTestKit

struct MyTestCase: EvaluatableTestCase {
    let input: String
    let expected: MyExpectedOutput
    let description: String
}
```

### 2. Define Your Expected Output

```swift
struct MyExpectedOutput: ExpectedOutput {
    typealias ActualOutput = MyGenerableType

    let expectedField: String
    let minimumConfidence: Double

    func compare(to actual: MyGenerableType) -> [String: MetricValue] {
        return [
            "field_correct": .boolean(actual.field == expectedField),
            "confidence": .double(actual.confidence)
        ]
    }
}
```

### 3. Define Your Metric Provider

```swift
struct MyMetricProvider: MetricProvider {
    static let entityTypes = ["type1", "type2", "type3"]

    static let csvHeaders = [
        "run_id", "timestamp", "input", "expected", "actual", "correct", "latency_ms"
    ]

    static func csvRow<T: EvaluatableTestCase>(
        from result: EvaluationResult<T>,
        metadata: RunMetadata
    ) -> [String] {
        // Build CSV row from result
    }
}
```

### 4. Run Evaluations

```swift
let service = LLMService()
let runner = EvaluationRunner<MyTestCase>(service: service)
let csvWriter = CSVWriter<MyTestCase, MyMetricProvider>()

for testCase in testCases {
    let result = try await runner.evaluate(testCase: testCase)
    await csvWriter.addResult(result)
}

let csvURL = try await csvWriter.writeToFile()
```

## Python Analysis

The `Scripts/` directory contains Python scripts for analyzing results:

```bash
# Analyze latest CSV
python3 Scripts/analyze_results.py

# Show historical trends
python3 Scripts/analyze_results.py --history

# Compare prompt versions
python3 Scripts/analyze_results.py --compare v1.0 v2.0
```

## Architecture

```
AIParsingTestKit/
├── Core/
│   ├── LLMService.swift         # FoundationModels wrapper
│   └── LLMServiceError.swift    # Error types
├── Evaluation/
│   ├── EvaluationRunner.swift   # Runs test cases
│   ├── EvaluationResult.swift   # Per-test results
│   ├── EvaluationSummary.swift  # Aggregated metrics
│   └── RunMetadata.swift        # Run metadata
├── Export/
│   ├── CSVWriter.swift          # CSV export
│   └── JSONSummaryWriter.swift  # JSON summary export
├── Protocols/
│   ├── EvaluatableTestCase.swift
│   ├── ExpectedOutput.swift
│   └── MetricProvider.swift
└── Scripts/
    ├── analyze_results.py
    └── config.json
```

## License

MIT License
