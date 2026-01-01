#!/bin/bash
#
# Benchmark all CoreML models in coreml-conversion/compiled
#
# Usage:
#   ./scripts/benchmark-models.sh                    # Benchmark all models with default iterations
#   ./scripts/benchmark-models.sh --iterations 50   # Custom iteration count
#   ./scripts/benchmark-models.sh --model SaT_fp16  # Benchmark specific model only
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$PROJECT_DIR/coreml-conversion/compiled"

# Default values
ITERATIONS=100
SPECIFIC_MODEL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --iterations|-i)
            ITERATIONS="$2"
            shift 2
            ;;
        --model|-m)
            SPECIFIC_MODEL="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -i, --iterations N   Number of iterations per benchmark (default: 100)"
            echo "  -m, --model NAME     Benchmark specific model only (e.g., SaT_fp16)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Available models:"
            for model in "$MODELS_DIR"/*.mlmodelc; do
                if [[ -d "$model" ]]; then
                    basename "$model" .mlmodelc
                fi
            done
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=============================================="
echo "  CoreML Model Benchmark Suite"
echo "=============================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Models directory: $MODELS_DIR"
echo "Iterations per model: $ITERATIONS"
echo ""

# Check models directory exists
if [[ ! -d "$MODELS_DIR" ]]; then
    echo "Error: Models directory not found: $MODELS_DIR"
    echo "Run the conversion script first to generate compiled models."
    exit 1
fi

# Find all models
MODELS=()
if [[ -n "$SPECIFIC_MODEL" ]]; then
    MODEL_PATH="$MODELS_DIR/${SPECIFIC_MODEL}.mlmodelc"
    if [[ -d "$MODEL_PATH" ]]; then
        MODELS+=("$MODEL_PATH")
    else
        echo "Error: Model not found: $MODEL_PATH"
        exit 1
    fi
else
    for model in "$MODELS_DIR"/*.mlmodelc; do
        if [[ -d "$model" ]]; then
            MODELS+=("$model")
        fi
    done
fi

if [[ ${#MODELS[@]} -eq 0 ]]; then
    echo "Error: No .mlmodelc models found in $MODELS_DIR"
    exit 1
fi

echo "Found ${#MODELS[@]} model(s) to benchmark:"
for model in "${MODELS[@]}"; do
    echo "  - $(basename "$model" .mlmodelc)"
done
echo ""

# Build the project
echo "Building project..."
cd "$PROJECT_DIR"
swift build -c release --quiet
echo "Build complete."
echo ""

# Get the executable path
EXECUTABLE="$PROJECT_DIR/.build/release/segmenttext"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "Error: Executable not found: $EXECUTABLE"
    exit 1
fi

# Create results file
RESULTS_FILE="$PROJECT_DIR/benchmark-results-$(date +%Y%m%d-%H%M%S).txt"
echo "Results will be saved to: $RESULTS_FILE"
echo ""

# Header for results
{
    echo "CoreML Model Benchmark Results"
    echo "=============================="
    echo "Date: $(date)"
    echo "Iterations: $ITERATIONS"
    echo ""
} | tee "$RESULTS_FILE"

# Run benchmarks
for model in "${MODELS[@]}"; do
    MODEL_NAME=$(basename "$model" .mlmodelc)

    echo "----------------------------------------------"
    echo "Benchmarking: $MODEL_NAME"
    echo "----------------------------------------------"

    {
        echo ""
        echo "Model: $MODEL_NAME"
        echo "Path: $model"
        echo ""
    } >> "$RESULTS_FILE"

    # Run benchmark and capture output
    "$EXECUTABLE" benchmark --iterations "$ITERATIONS" --model-path "$model" 2>&1 | tee -a "$RESULTS_FILE"

    echo "" | tee -a "$RESULTS_FILE"
done

echo "=============================================="
echo "Benchmark complete!"
echo "Results saved to: $RESULTS_FILE"
echo "=============================================="
