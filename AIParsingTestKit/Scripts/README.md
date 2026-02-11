# Analysis Scripts

Python scripts for analyzing LLM evaluation results.

## Requirements

```bash
pip install matplotlib numpy
```

Note: matplotlib and numpy are optional - the scripts will work without them but won't generate visualizations.

## Configuration

Edit `config.json` to customize:

- `entity_types`: The classification categories for your domain
- `file_prefix`: Prefix for CSV/JSON files (default: "LLMEval")
- `output_directory`: Where exported data is stored
- `metrics_history_file`: Historical metrics JSON file
- `plot_directory`: Where to save visualizations

## Usage

### Analyze Latest Results

```bash
python3 analyze_results.py
```

### Analyze Specific File

```bash
python3 analyze_results.py --file /path/to/results.csv
```

### View Historical Trends

```bash
python3 analyze_results.py --history
```

### Compare Prompt Versions

```bash
python3 analyze_results.py --compare v1.0 v2.0
```

### Skip Plot Generation

```bash
python3 analyze_results.py --no-plots
```

### Skip Adding to History

```bash
python3 analyze_results.py --no-history-add
```

## Output

The script produces:

1. **Console Report**: Formatted metrics summary
2. **Plots** (if matplotlib installed):
   - Entity type precision/recall/F1
   - Confusion matrix heatmap
   - Confidence calibration curve
   - Latency distribution
   - Field extraction accuracy
3. **metrics.json**: Detailed metrics for the run
4. **metrics_history.json**: Historical tracking across runs

## Workflow

1. Run tests on device (XCTest)
2. Copy results from device: `./copy_iphone_data.sh`
3. Analyze: `python3 analyze_results.py`
4. Compare versions: `python3 analyze_results.py --compare v1.0 v2.0`
