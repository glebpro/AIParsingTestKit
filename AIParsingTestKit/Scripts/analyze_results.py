#!/usr/bin/env python3
"""
LLM Evaluation Analysis Script

This script analyzes CSV results from LLM evaluation tests,
calculates comprehensive metrics, generates visualizations, and maintains
historical tracking of performance over time.

Configurable via config.json for different domains and entity types.

Usage:
    python analyze_results.py                    # Analyze latest CSV
    python analyze_results.py --file <path>     # Analyze specific CSV
    python analyze_results.py --history         # Show historical trends
    python analyze_results.py --compare v1 v2   # Compare prompt versions
"""

import argparse
import csv
import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

# Optional: matplotlib for visualizations
try:
    import matplotlib.patches as mpatches
    import matplotlib.pyplot as plt

    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Note: Install matplotlib for visualizations: pip install matplotlib")

# Optional: numpy for numerical operations
try:
    import numpy as np

    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False


# MARK: - Configuration

def load_config() -> dict:
    """Load configuration from config.json."""
    config_path = Path(__file__).parent / "config.json"
    default_config = {
        "entity_types": ["task", "event", "habit", "override", "unknown"],
        "file_prefix": "LLMEval",
        "output_directory": "ExportedData",
        "metrics_history_file": "metrics_history.json",
        "plot_directory": "plots"
    }

    if config_path.exists():
        try:
            with open(config_path, encoding="utf-8") as f:
                loaded = json.load(f)
                default_config.update(loaded)
        except Exception as e:
            print(f"Warning: Could not load config.json: {e}")

    return default_config


CONFIG = load_config()
ENTITY_TYPES = CONFIG["entity_types"]
FILE_PREFIX = CONFIG["file_prefix"]
EXPORTED_DATA_DIR = Path(__file__).parent.parent / CONFIG["output_directory"]
METRICS_HISTORY_FILE = EXPORTED_DATA_DIR / CONFIG["metrics_history_file"]
PROMPTS_DIR = EXPORTED_DATA_DIR / "prompts"


# MARK: - Data Loading


def find_latest_csv() -> Path | None:
    """Find the most recently modified CSV file in ExportedData."""
    csv_files = list(EXPORTED_DATA_DIR.glob("*.csv"))
    if not csv_files:
        return None
    return max(csv_files, key=lambda f: f.stat().st_mtime)


def load_csv(filepath: Path) -> list[dict]:
    """Load CSV file into list of dictionaries."""
    with open(filepath, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        return list(reader)


def load_metrics_history() -> list[dict]:
    """Load historical metrics from JSON file."""
    if not METRICS_HISTORY_FILE.exists():
        return []
    with open(METRICS_HISTORY_FILE, encoding="utf-8") as f:
        return json.load(f)


def save_metrics_history(history: list[dict]) -> None:
    """Save metrics history to JSON file."""
    EXPORTED_DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(METRICS_HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, indent=2)


# MARK: - Metrics Calculation


def calculate_metrics(results: list[dict]) -> dict[str, Any]:
    """Calculate comprehensive evaluation metrics from results."""

    # Filter to completed results only
    completed = [r for r in results if r.get("status") == "COMPLETED"]
    total = len(results)
    n_completed = len(completed)
    n_skipped = len([r for r in results if r.get("status") == "SKIPPED"])
    n_errors = len([r for r in results if r.get("status") == "ERROR"])

    if n_completed == 0:
        return {
            "total_tests": total,
            "completed_tests": 0,
            "skipped_tests": n_skipped,
            "error_tests": n_errors,
            "error": "No completed tests to analyze",
        }

    # Entity Type Classification Metrics
    entity_correct = sum(
        1 for r in completed if r.get("entity_type_correct", "").lower() == "true"
    )
    entity_type_accuracy = entity_correct / n_completed

    # Per-class precision, recall, F1
    entity_metrics = {}
    for entity_type in ENTITY_TYPES:
        # Predicted as this type
        predicted = [
            r
            for r in completed
            if r.get("actual_entity_type", "").lower() == entity_type
        ]
        # Actually this type
        actual = [
            r
            for r in completed
            if r.get("expected_entity_type", "").lower() == entity_type
        ]
        # True positives
        true_positives = [
            r for r in predicted if r.get("entity_type_correct", "").lower() == "true"
        ]

        precision = len(true_positives) / len(predicted) if predicted else 0.0
        recall = len(true_positives) / len(actual) if actual else 0.0
        f1 = (
            2 * (precision * recall) / (precision + recall)
            if (precision + recall) > 0
            else 0.0
        )

        entity_metrics[entity_type] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": len(actual),
            "predicted_count": len(predicted),
        }

    # Confusion Matrix
    confusion_matrix = defaultdict(lambda: defaultdict(int))
    for r in completed:
        expected = r.get("expected_entity_type", "unknown").lower()
        actual = r.get("actual_entity_type", "unknown").lower()
        confusion_matrix[expected][actual] += 1

    # Field Extraction Metrics
    def parse_float(val: str, default: float = 0.0) -> float:
        try:
            return float(val) if val else default
        except ValueError:
            return default

    def parse_bool(val: str) -> bool:
        return val.lower() == "true" if val else False

    title_overlaps = [
        parse_float(r.get("title_keyword_overlap", "0")) for r in completed
    ]
    title_overlap_avg = sum(title_overlaps) / len(title_overlaps)

    start_time_correct = sum(
        1 for r in completed if parse_bool(r.get("start_time_presence_correct", ""))
    )
    start_time_accuracy = start_time_correct / n_completed

    start_hour_correct = sum(
        1 for r in completed if parse_bool(r.get("start_hour_correct", ""))
    )
    start_hour_accuracy = start_hour_correct / n_completed

    # Calculate average hour error for cases where we have data
    hour_errors = []
    for r in completed:
        err = r.get("start_hour_error", "")
        if err and err.isdigit():
            hour_errors.append(int(err))
    avg_hour_error = sum(hour_errors) / len(hour_errors) if hour_errors else None

    end_time_correct = sum(
        1 for r in completed if parse_bool(r.get("end_time_presence_correct", ""))
    )
    end_time_accuracy = end_time_correct / n_completed

    recurrence_correct = sum(
        1 for r in completed if parse_bool(r.get("recurrence_presence_correct", ""))
    )
    recurrence_accuracy = recurrence_correct / n_completed

    time_pref_correct = sum(
        1
        for r in completed
        if parse_bool(r.get("time_preference_presence_correct", ""))
    )
    time_pref_accuracy = time_pref_correct / n_completed

    # Confidence Calibration
    confidences = [parse_float(r.get("confidence", "0")) for r in completed]
    avg_confidence = sum(confidences) / len(confidences)

    calibration_correct = sum(
        1 for r in completed if parse_bool(r.get("confidence_calibrated", ""))
    )
    calibration_rate = calibration_correct / n_completed

    # Confidence bins for calibration analysis
    confidence_bins = {
        "0.0-0.5": {"count": 0, "correct": 0},
        "0.5-0.7": {"count": 0, "correct": 0},
        "0.7-0.9": {"count": 0, "correct": 0},
        "0.9-1.0": {"count": 0, "correct": 0},
    }
    for r in completed:
        conf = parse_float(r.get("confidence", "0"))
        correct = parse_bool(r.get("entity_type_correct", ""))

        if conf < 0.5:
            bin_key = "0.0-0.5"
        elif conf < 0.7:
            bin_key = "0.5-0.7"
        elif conf < 0.9:
            bin_key = "0.7-0.9"
        else:
            bin_key = "0.9-1.0"

        confidence_bins[bin_key]["count"] += 1
        if correct:
            confidence_bins[bin_key]["correct"] += 1

    # Calculate expected calibration error (ECE)
    ece = 0.0
    for bin_key, bin_data in confidence_bins.items():
        if bin_data["count"] > 0:
            bin_acc = bin_data["correct"] / bin_data["count"]
            # Midpoint of bin as expected confidence
            if bin_key == "0.0-0.5":
                expected_conf = 0.25
            elif bin_key == "0.5-0.7":
                expected_conf = 0.6
            elif bin_key == "0.7-0.9":
                expected_conf = 0.8
            else:
                expected_conf = 0.95

            ece += abs(bin_acc - expected_conf) * (bin_data["count"] / n_completed)

    # Latency Metrics
    latencies = [parse_float(r.get("latency_ms", "0")) for r in completed]
    latencies_sorted = sorted(latencies)
    avg_latency = sum(latencies) / len(latencies)
    p50_latency = latencies_sorted[len(latencies) // 2]
    p95_idx = min(int(len(latencies) * 0.95), len(latencies) - 1)
    p95_latency = latencies_sorted[p95_idx]
    p99_idx = min(int(len(latencies) * 0.99), len(latencies) - 1)
    p99_latency = latencies_sorted[p99_idx]

    # Get run metadata
    first_result = results[0] if results else {}
    run_id = first_result.get("run_id", "unknown")
    timestamp = first_result.get("timestamp", datetime.now().isoformat())
    prompt_version = first_result.get("prompt_version", "unknown")

    return {
        "run_id": run_id,
        "timestamp": timestamp,
        "prompt_version": prompt_version,
        "total_tests": total,
        "completed_tests": n_completed,
        "skipped_tests": n_skipped,
        "error_tests": n_errors,
        "completion_rate": n_completed / total if total > 0 else 0,
        "entity_type_accuracy": entity_type_accuracy,
        "entity_type_metrics": entity_metrics,
        "confusion_matrix": dict(confusion_matrix),
        "title_keyword_overlap_avg": title_overlap_avg,
        "start_time_presence_accuracy": start_time_accuracy,
        "start_hour_accuracy": start_hour_accuracy,
        "avg_hour_error": avg_hour_error,
        "end_time_presence_accuracy": end_time_accuracy,
        "recurrence_presence_accuracy": recurrence_accuracy,
        "time_preference_presence_accuracy": time_pref_accuracy,
        "avg_confidence": avg_confidence,
        "confidence_calibration_rate": calibration_rate,
        "confidence_bins": confidence_bins,
        "expected_calibration_error": ece,
        "avg_latency_ms": avg_latency,
        "p50_latency_ms": p50_latency,
        "p95_latency_ms": p95_latency,
        "p99_latency_ms": p99_latency,
        "latencies": latencies,
    }


# MARK: - Visualization


def print_metrics_report(metrics: dict[str, Any]) -> None:
    """Print a formatted metrics report to console."""

    print("\n" + "=" * 80)
    print("📊 LLM EVALUATION REPORT")
    print("=" * 80)

    print(f"\n📋 RUN INFORMATION")
    print("-" * 40)
    print(f"  Run ID:         {metrics.get('run_id', 'N/A')[:8]}...")
    print(f"  Timestamp:      {metrics.get('timestamp', 'N/A')}")
    print(f"  Prompt Version: {metrics.get('prompt_version', 'N/A')}")

    print(f"\n📈 TEST SUMMARY")
    print("-" * 40)
    print(f"  Total Tests:    {metrics.get('total_tests', 0)}")
    print(f"  Completed:      {metrics.get('completed_tests', 0)}")
    print(f"  Skipped:        {metrics.get('skipped_tests', 0)}")
    print(f"  Errors:         {metrics.get('error_tests', 0)}")
    print(f"  Completion:     {metrics.get('completion_rate', 0) * 100:.1f}%")

    print(f"\n🎯 ENTITY TYPE CLASSIFICATION")
    print("-" * 40)
    print(f"  Overall Accuracy: {metrics.get('entity_type_accuracy', 0) * 100:.1f}%")
    print(f"\n  Per-Class Metrics:")
    print(f"  {'Type':<12} {'Precision':<12} {'Recall':<12} {'F1':<12} {'Support':<10}")
    print(f"  {'-' * 58}")

    entity_metrics = metrics.get("entity_type_metrics", {})
    macro_f1 = 0
    classes_with_support = 0
    for entity_type in ENTITY_TYPES:
        m = entity_metrics.get(entity_type, {})
        p = m.get("precision", 0)
        r = m.get("recall", 0)
        f1 = m.get("f1", 0)
        support = m.get("support", 0)
        print(f"  {entity_type:<12} {p:<12.2f} {r:<12.2f} {f1:<12.2f} {support:<10}")
        if support > 0:
            macro_f1 += f1
            classes_with_support += 1

    if classes_with_support > 0:
        macro_f1 /= classes_with_support
        print(f"\n  Macro F1 Score: {macro_f1:.2f}")

    # Confusion Matrix
    print(f"\n  Confusion Matrix:")
    confusion = metrics.get("confusion_matrix", {})
    if confusion:
        types_present = [
            t
            for t in ENTITY_TYPES
            if t in confusion or any(t in v for v in confusion.values())
        ]
        if types_present:
            header_label = "Actual/Pred"
            print(f"  {header_label:<12}", end="")
            for t in types_present:
                print(f"{t[:6]:<8}", end="")
            print()
            for actual in types_present:
                print(f"  {actual:<12}", end="")
                for pred in types_present:
                    count = confusion.get(actual, {}).get(pred, 0)
                    print(f"{count:<8}", end="")
                print()

    print(f"\n📝 FIELD EXTRACTION ACCURACY")
    print("-" * 40)
    print(
        f"  Title Keyword Overlap:     {metrics.get('title_keyword_overlap_avg', 0) * 100:.1f}%"
    )
    print(
        f"  Start Time Presence:       {metrics.get('start_time_presence_accuracy', 0) * 100:.1f}%"
    )
    print(
        f"  Start Hour Accuracy:       {metrics.get('start_hour_accuracy', 0) * 100:.1f}%"
    )
    if metrics.get("avg_hour_error") is not None:
        print(f"  Avg Hour Error:            {metrics.get('avg_hour_error'):.1f} hours")
    print(
        f"  End Time Presence:         {metrics.get('end_time_presence_accuracy', 0) * 100:.1f}%"
    )
    print(
        f"  Recurrence Presence:       {metrics.get('recurrence_presence_accuracy', 0) * 100:.1f}%"
    )
    print(
        f"  Time Preference Presence:  {metrics.get('time_preference_presence_accuracy', 0) * 100:.1f}%"
    )

    print(f"\n🔮 CONFIDENCE CALIBRATION")
    print("-" * 40)
    print(f"  Average Confidence:        {metrics.get('avg_confidence', 0):.2f}")
    print(
        f"  Calibration Rate:          {metrics.get('confidence_calibration_rate', 0) * 100:.1f}%"
    )
    print(
        f"  Expected Calibration Err:  {metrics.get('expected_calibration_error', 0):.3f}"
    )

    confidence_bins = metrics.get("confidence_bins", {})
    if confidence_bins:
        print(f"\n  Confidence vs Accuracy:")
        print(f"  {'Bin':<12} {'Count':<10} {'Accuracy':<10}")
        print(f"  {'-' * 32}")
        for bin_key in ["0.0-0.5", "0.5-0.7", "0.7-0.9", "0.9-1.0"]:
            bin_data = confidence_bins.get(bin_key, {})
            count = bin_data.get("count", 0)
            correct = bin_data.get("correct", 0)
            acc = (correct / count * 100) if count > 0 else 0
            print(f"  {bin_key:<12} {count:<10} {acc:.1f}%")

    print(f"\n⏱️  LATENCY")
    print("-" * 40)
    print(f"  Average:  {metrics.get('avg_latency_ms', 0):.0f}ms")
    print(f"  P50:      {metrics.get('p50_latency_ms', 0):.0f}ms")
    print(f"  P95:      {metrics.get('p95_latency_ms', 0):.0f}ms")
    print(f"  P99:      {metrics.get('p99_latency_ms', 0):.0f}ms")

    print("\n" + "=" * 80 + "\n")


def plot_metrics(metrics: dict[str, Any], output_dir: Path) -> None:
    """Generate visualization plots for the metrics."""

    if not HAS_MATPLOTLIB:
        print("Skipping plots (matplotlib not installed)")
        return

    output_dir.mkdir(parents=True, exist_ok=True)
    run_id = metrics.get("run_id", "unknown")[:8]

    # 1. Entity Type Accuracy Bar Chart
    fig, ax = plt.subplots(figsize=(10, 6))
    entity_metrics = metrics.get("entity_type_metrics", {})
    types = list(entity_metrics.keys())
    precisions = [entity_metrics[t].get("precision", 0) for t in types]
    recalls = [entity_metrics[t].get("recall", 0) for t in types]
    f1s = [entity_metrics[t].get("f1", 0) for t in types]

    x = range(len(types))
    width = 0.25

    ax.bar(
        [i - width for i in x], precisions, width, label="Precision", color="#2196F3"
    )
    ax.bar(x, recalls, width, label="Recall", color="#4CAF50")
    ax.bar([i + width for i in x], f1s, width, label="F1", color="#FF9800")

    ax.set_ylabel("Score")
    ax.set_title("Entity Type Classification Metrics")
    ax.set_xticks(x)
    ax.set_xticklabels(types)
    ax.legend()
    ax.set_ylim(0, 1.1)
    ax.grid(axis="y", alpha=0.3)

    plt.tight_layout()
    plt.savefig(output_dir / f"entity_type_metrics_{run_id}.png", dpi=150)
    plt.close()

    # 2. Confusion Matrix Heatmap
    confusion = metrics.get("confusion_matrix", {})
    if confusion:
        types_present = [
            t
            for t in ENTITY_TYPES
            if t in confusion or any(t in v for v in confusion.values())
        ]
        if len(types_present) > 1:
            fig, ax = plt.subplots(figsize=(8, 6))

            matrix = []
            for actual in types_present:
                row = []
                for pred in types_present:
                    row.append(confusion.get(actual, {}).get(pred, 0))
                matrix.append(row)

            im = ax.imshow(matrix, cmap="Blues")

            ax.set_xticks(range(len(types_present)))
            ax.set_yticks(range(len(types_present)))
            ax.set_xticklabels(types_present)
            ax.set_yticklabels(types_present)
            ax.set_xlabel("Predicted")
            ax.set_ylabel("Actual")
            ax.set_title("Entity Type Confusion Matrix")

            # Add text annotations
            for i in range(len(types_present)):
                for j in range(len(types_present)):
                    text = ax.text(
                        j,
                        i,
                        matrix[i][j],
                        ha="center",
                        va="center",
                        color="white"
                        if matrix[i][j] > max(max(matrix)) / 2
                        else "black",
                    )

            plt.colorbar(im)
            plt.tight_layout()
            plt.savefig(output_dir / f"confusion_matrix_{run_id}.png", dpi=150)
            plt.close()

    # 3. Confidence Calibration Plot
    confidence_bins = metrics.get("confidence_bins", {})
    if confidence_bins:
        fig, ax = plt.subplots(figsize=(8, 6))

        bin_labels = ["0.0-0.5", "0.5-0.7", "0.7-0.9", "0.9-1.0"]
        bin_midpoints = [0.25, 0.6, 0.8, 0.95]
        accuracies = []

        for bin_key in bin_labels:
            bin_data = confidence_bins.get(bin_key, {})
            count = bin_data.get("count", 0)
            correct = bin_data.get("correct", 0)
            acc = (correct / count) if count > 0 else 0
            accuracies.append(acc)

        ax.plot([0, 1], [0, 1], "k--", label="Perfect Calibration")
        ax.bar(
            bin_midpoints, accuracies, width=0.15, alpha=0.7, label="Actual Accuracy"
        )
        ax.scatter(bin_midpoints, accuracies, s=100, zorder=5)

        ax.set_xlabel("Confidence")
        ax.set_ylabel("Accuracy")
        ax.set_title("Confidence Calibration")
        ax.legend()
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)
        ax.grid(alpha=0.3)

        plt.tight_layout()
        plt.savefig(output_dir / f"calibration_{run_id}.png", dpi=150)
        plt.close()

    # 4. Latency Distribution
    latencies = metrics.get("latencies", [])
    if latencies:
        fig, ax = plt.subplots(figsize=(10, 6))

        ax.hist(latencies, bins=20, edgecolor="black", alpha=0.7)
        ax.axvline(
            metrics.get("p50_latency_ms", 0),
            color="green",
            linestyle="--",
            label=f"P50: {metrics.get('p50_latency_ms', 0):.0f}ms",
        )
        ax.axvline(
            metrics.get("p95_latency_ms", 0),
            color="orange",
            linestyle="--",
            label=f"P95: {metrics.get('p95_latency_ms', 0):.0f}ms",
        )
        ax.axvline(
            metrics.get("p99_latency_ms", 0),
            color="red",
            linestyle="--",
            label=f"P99: {metrics.get('p99_latency_ms', 0):.0f}ms",
        )

        ax.set_xlabel("Latency (ms)")
        ax.set_ylabel("Frequency")
        ax.set_title("Response Latency Distribution")
        ax.legend()
        ax.grid(alpha=0.3)

        plt.tight_layout()
        plt.savefig(output_dir / f"latency_distribution_{run_id}.png", dpi=150)
        plt.close()

    # 5. Field Extraction Summary
    fig, ax = plt.subplots(figsize=(10, 6))

    fields = [
        "Title Keywords",
        "Start Time Presence",
        "Start Hour",
        "End Time Presence",
        "Recurrence",
        "Time Preference",
    ]
    accuracies = [
        metrics.get("title_keyword_overlap_avg", 0),
        metrics.get("start_time_presence_accuracy", 0),
        metrics.get("start_hour_accuracy", 0),
        metrics.get("end_time_presence_accuracy", 0),
        metrics.get("recurrence_presence_accuracy", 0),
        metrics.get("time_preference_presence_accuracy", 0),
    ]

    colors = [
        "#4CAF50" if a >= 0.8 else "#FF9800" if a >= 0.6 else "#f44336"
        for a in accuracies
    ]

    bars = ax.barh(fields, [a * 100 for a in accuracies], color=colors)
    ax.set_xlabel("Accuracy (%)")
    ax.set_title("Field Extraction Accuracy")
    ax.set_xlim(0, 100)
    ax.axvline(80, color="green", linestyle="--", alpha=0.5, label="80% threshold")
    ax.axvline(60, color="orange", linestyle="--", alpha=0.5, label="60% threshold")
    ax.legend()
    ax.grid(axis="x", alpha=0.3)

    # Add value labels
    for bar, acc in zip(bars, accuracies):
        ax.text(
            bar.get_width() + 1,
            bar.get_y() + bar.get_height() / 2,
            f"{acc * 100:.1f}%",
            va="center",
        )

    plt.tight_layout()
    plt.savefig(output_dir / f"field_accuracy_{run_id}.png", dpi=150)
    plt.close()

    print(f"📊 Plots saved to {output_dir}/")


def plot_history(history: list[dict], output_dir: Path) -> None:
    """Plot historical trends of key metrics."""

    if not HAS_MATPLOTLIB:
        print("Skipping history plots (matplotlib not installed)")
        return

    if len(history) < 2:
        print("Not enough historical data for trend plots (need at least 2 runs)")
        return

    output_dir.mkdir(parents=True, exist_ok=True)

    # Sort by timestamp
    history = sorted(history, key=lambda x: x.get("timestamp", ""))

    timestamps = [h.get("timestamp", "")[:10] for h in history]  # Date only
    prompt_versions = [h.get("prompt_version", "unknown") for h in history]

    # 1. Entity Type Accuracy Over Time
    fig, ax = plt.subplots(figsize=(12, 6))

    accuracies = [h.get("entity_type_accuracy", 0) * 100 for h in history]
    ax.plot(range(len(timestamps)), accuracies, marker="o", linewidth=2, markersize=8)

    # Annotate with prompt versions
    for i, (acc, version) in enumerate(zip(accuracies, prompt_versions)):
        ax.annotate(
            version,
            (i, acc),
            textcoords="offset points",
            xytext=(0, 10),
            ha="center",
            fontsize=8,
        )

    ax.set_xticks(range(len(timestamps)))
    ax.set_xticklabels(timestamps, rotation=45, ha="right")
    ax.set_ylabel("Entity Type Accuracy (%)")
    ax.set_title("Entity Type Classification Accuracy Over Time")
    ax.grid(alpha=0.3)
    ax.set_ylim(0, 100)

    plt.tight_layout()
    plt.savefig(output_dir / "history_entity_accuracy.png", dpi=150)
    plt.close()

    # 2. Multiple Metrics Over Time
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # Entity accuracy
    axes[0, 0].plot(range(len(timestamps)), accuracies, marker="o")
    axes[0, 0].set_title("Entity Type Accuracy")
    axes[0, 0].set_ylabel("%")
    axes[0, 0].grid(alpha=0.3)
    axes[0, 0].set_ylim(0, 100)

    # Latency
    latencies = [h.get("avg_latency_ms", 0) for h in history]
    axes[0, 1].plot(range(len(timestamps)), latencies, marker="o", color="orange")
    axes[0, 1].set_title("Average Latency")
    axes[0, 1].set_ylabel("ms")
    axes[0, 1].grid(alpha=0.3)

    # Confidence calibration
    ece = [h.get("expected_calibration_error", 0) for h in history]
    axes[1, 0].plot(range(len(timestamps)), ece, marker="o", color="green")
    axes[1, 0].set_title("Expected Calibration Error (lower is better)")
    axes[1, 0].set_ylabel("ECE")
    axes[1, 0].grid(alpha=0.3)

    # Title overlap
    title_overlap = [h.get("title_keyword_overlap_avg", 0) * 100 for h in history]
    axes[1, 1].plot(range(len(timestamps)), title_overlap, marker="o", color="purple")
    axes[1, 1].set_title("Title Keyword Overlap")
    axes[1, 1].set_ylabel("%")
    axes[1, 1].grid(alpha=0.3)
    axes[1, 1].set_ylim(0, 100)

    for ax in axes.flat:
        ax.set_xticks(range(len(timestamps)))
        ax.set_xticklabels(timestamps, rotation=45, ha="right", fontsize=8)

    plt.tight_layout()
    plt.savefig(output_dir / "history_overview.png", dpi=150)
    plt.close()

    print(f"📊 History plots saved to {output_dir}/")


# MARK: - Historical Tracking


def add_to_history(metrics: dict[str, Any]) -> None:
    """Add current run metrics to historical tracking."""

    # Create a simplified record for history
    history_record = {
        "run_id": metrics.get("run_id"),
        "timestamp": metrics.get("timestamp"),
        "prompt_version": metrics.get("prompt_version"),
        "total_tests": metrics.get("total_tests"),
        "completed_tests": metrics.get("completed_tests"),
        "completion_rate": metrics.get("completion_rate"),
        "entity_type_accuracy": metrics.get("entity_type_accuracy"),
        "title_keyword_overlap_avg": metrics.get("title_keyword_overlap_avg"),
        "start_time_presence_accuracy": metrics.get("start_time_presence_accuracy"),
        "start_hour_accuracy": metrics.get("start_hour_accuracy"),
        "avg_confidence": metrics.get("avg_confidence"),
        "expected_calibration_error": metrics.get("expected_calibration_error"),
        "avg_latency_ms": metrics.get("avg_latency_ms"),
        "p95_latency_ms": metrics.get("p95_latency_ms"),
    }

    # Load existing history
    history = load_metrics_history()

    # Check if this run already exists
    existing_ids = {h.get("run_id") for h in history}
    if history_record["run_id"] not in existing_ids:
        history.append(history_record)
        save_metrics_history(history)
        print(
            f"✅ Added run {history_record['run_id'][:8]} to history ({len(history)} total runs)"
        )
    else:
        print(f"ℹ️ Run {history_record['run_id'][:8]} already in history")


def compare_prompt_versions(v1: str, v2: str, history: list[dict]) -> None:
    """Compare metrics between two prompt versions."""

    runs_v1 = [h for h in history if h.get("prompt_version") == v1]
    runs_v2 = [h for h in history if h.get("prompt_version") == v2]

    if not runs_v1:
        print(f"No runs found for prompt version: {v1}")
        return
    if not runs_v2:
        print(f"No runs found for prompt version: {v2}")
        return

    # Use most recent run for each version
    latest_v1 = max(runs_v1, key=lambda x: x.get("timestamp", ""))
    latest_v2 = max(runs_v2, key=lambda x: x.get("timestamp", ""))

    print("\n" + "=" * 60)
    print(f"📊 PROMPT VERSION COMPARISON: {v1} vs {v2}")
    print("=" * 60)

    metrics_to_compare = [
        ("entity_type_accuracy", "Entity Type Accuracy", True),
        ("title_keyword_overlap_avg", "Title Keyword Overlap", True),
        ("start_hour_accuracy", "Start Hour Accuracy", True),
        ("expected_calibration_error", "Calibration Error", False),
        ("avg_latency_ms", "Avg Latency (ms)", False),
    ]

    print(f"\n{'Metric':<25} {v1:>15} {v2:>15} {'Change':>15}")
    print("-" * 70)

    for key, label, higher_is_better in metrics_to_compare:
        val1 = latest_v1.get(key, 0)
        val2 = latest_v2.get(key, 0)

        if isinstance(val1, float) and val1 <= 1:
            # Percentage
            display1 = f"{val1 * 100:.1f}%"
            display2 = f"{val2 * 100:.1f}%"
            change = (val2 - val1) * 100
            change_str = f"{change:+.1f}%"
        else:
            display1 = f"{val1:.1f}"
            display2 = f"{val2:.1f}"
            change = val2 - val1
            change_str = f"{change:+.1f}"

        # Color indicator
        if higher_is_better:
            indicator = "✅" if change > 0 else "❌" if change < 0 else "➡️"
        else:
            indicator = "✅" if change < 0 else "❌" if change > 0 else "➡️"

        print(f"{label:<25} {display1:>15} {display2:>15} {change_str:>12} {indicator}")

    print("\n" + "=" * 60 + "\n")


# MARK: - Main


def main():
    parser = argparse.ArgumentParser(
        description="Analyze LLM evaluation results"
    )
    parser.add_argument("--file", "-f", type=str, help="Path to specific CSV file")
    parser.add_argument(
        "--history", "-H", action="store_true", help="Show historical trends"
    )
    parser.add_argument(
        "--compare",
        "-c",
        nargs=2,
        metavar=("V1", "V2"),
        help="Compare two prompt versions",
    )
    parser.add_argument("--no-plots", action="store_true", help="Skip generating plots")
    parser.add_argument(
        "--no-history-add", action="store_true", help="Do not add this run to history"
    )

    args = parser.parse_args()

    # Handle history comparison
    if args.compare:
        history = load_metrics_history()
        compare_prompt_versions(args.compare[0], args.compare[1], history)
        return

    # Handle history plots
    if args.history:
        history = load_metrics_history()
        if not history:
            print("No historical data found. Run some evaluations first!")
            return

        print(f"\n📜 Historical runs: {len(history)}")
        for h in sorted(history, key=lambda x: x.get("timestamp", ""), reverse=True)[
            :10
        ]:
            print(
                f"  {h.get('timestamp', 'N/A')[:19]} | {h.get('prompt_version', 'N/A'):<8} | Acc: {h.get('entity_type_accuracy', 0) * 100:.1f}%"
            )

        if not args.no_plots:
            plot_history(history, EXPORTED_DATA_DIR / "plots")
        return

    # Determine which CSV to analyze
    if args.file:
        csv_path = Path(args.file)
    else:
        csv_path = find_latest_csv()

    if not csv_path or not csv_path.exists():
        print(
            "❌ No CSV file found. Run the evaluation tests first, then copy data with copy_iphone_data.sh"
        )
        return

    print(f"📂 Analyzing: {csv_path}")

    # Load and analyze
    results = load_csv(csv_path)
    metrics = calculate_metrics(results)

    # Print report
    print_metrics_report(metrics)

    # Generate plots
    if not args.no_plots:
        plot_metrics(metrics, EXPORTED_DATA_DIR / "plots")

    # Add to history
    if not args.no_history_add:
        add_to_history(metrics)

    # Save detailed metrics JSON
    metrics_json_path = csv_path.with_suffix(".metrics.json")
    # Remove non-serializable items
    metrics_to_save = {k: v for k, v in metrics.items() if k != "latencies"}
    with open(metrics_json_path, "w", encoding="utf-8") as f:
        json.dump(metrics_to_save, f, indent=2)
    print(f"📁 Detailed metrics saved to: {metrics_json_path}")


if __name__ == "__main__":
    main()
