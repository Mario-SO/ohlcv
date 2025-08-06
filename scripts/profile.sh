#!/bin/bash

# OHLCV Library Profiling Script
# Usage: ./scripts/profile.sh [benchmark|memory|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/profiling_results"

# Create results directory
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🔍 OHLCV Library Profiling Suite"
echo "================================="
echo "Timestamp: $TIMESTAMP"
echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Function to run benchmarks
run_benchmarks() {
    echo "🚀 Running Performance Benchmarks..."
    echo "------------------------------------"
    
    cd "$PROJECT_DIR"
    
    # Build and run benchmarks
    echo "Building benchmark executable..."
    zig build benchmark --summary none
    
    # Run with timing
    echo "Running benchmarks..."
    
    # Create header
    {
        echo "OHLCV Performance Benchmark Results"
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo "Zig Version: $(zig version)"
        echo ""
        echo "=== Benchmark Results ==="
    } > "$RESULTS_DIR/benchmark_$TIMESTAMP.txt"
    
    # Run benchmark and append results
    zig build benchmark >> "$RESULTS_DIR/benchmark_$TIMESTAMP.txt" 2>&1
    
    # Add timing information
    {
        echo ""
        echo "=== Timing Information ==="
        echo "Running timing test..."
    } >> "$RESULTS_DIR/benchmark_$TIMESTAMP.txt"
    
    # Run timing test and append
    { time zig build benchmark >/dev/null 2>&1; } 2>> "$RESULTS_DIR/benchmark_$TIMESTAMP.txt"
    
    echo "✅ Benchmarks completed. Results saved to benchmark_$TIMESTAMP.txt"
}

# Function to run memory profiling
run_memory_profiling() {
    echo "🧠 Running Memory Profiling..."
    echo "------------------------------"
    
    cd "$PROJECT_DIR"
    
    echo "Building memory profiler..."
    zig build profile-memory --summary none
    
    echo "Running memory profiler..."
    
    # Create header
    {
        echo "OHLCV Memory Profile Results"
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo "Zig Version: $(zig version)"
        echo ""
        echo "=== Memory Profile Results ==="
    } > "$RESULTS_DIR/memory_profile_$TIMESTAMP.txt"
    
    # Run memory profiler and append results
    zig build profile-memory >> "$RESULTS_DIR/memory_profile_$TIMESTAMP.txt" 2>&1
    
    echo "✅ Memory profiling completed. Results saved to memory_profile_$TIMESTAMP.txt"
}

# Function to run system monitoring
run_system_monitoring() {
    echo "📊 System Information..."
    echo "------------------------"
    
    {
        echo "System Information Report"
        echo "Generated: $(date)"
        echo ""
        echo "=== Hardware ==="
        if command -v system_profiler >/dev/null 2>&1; then
            # macOS
            system_profiler SPHardwareDataType | head -20
        elif command -v lscpu >/dev/null 2>&1; then
            # Linux
            lscpu
            echo ""
            echo "Memory:"
            free -h
        fi
        echo ""
        
        echo "=== Compiler Information ==="
        zig version
        zig env
        echo ""
        
        echo "=== Build Configuration ==="
        cd "$PROJECT_DIR"
        zig build --help | head -20
        
    } > "$RESULTS_DIR/system_info_$TIMESTAMP.txt"
    
    echo "✅ System info saved to system_info_$TIMESTAMP.txt"
}

# Function to generate comparison report
generate_comparison() {
    echo "📈 Generating Comparison Report..."
    echo "----------------------------------"
    
    # Find the last two benchmark files
    LATEST_BENCHMARKS=($(ls -t "$RESULTS_DIR"/benchmark_*.txt 2>/dev/null | head -2))
    
    if [ ${#LATEST_BENCHMARKS[@]} -ge 2 ]; then
        {
            echo "OHLCV Performance Comparison Report"
            echo "Generated: $(date)"
            echo ""
            echo "Comparing:"
            echo "  Current: ${LATEST_BENCHMARKS[0]}"
            echo "  Previous: ${LATEST_BENCHMARKS[1]}"
            echo ""
            echo "=== Performance Metrics Comparison ==="
            echo ""
            echo "--- Current Results ---"
            grep -E "(SMA-|EMA-|RSI-|Bollinger-|MACD:|ATR-)" "${LATEST_BENCHMARKS[0]}" | head -20
            echo ""
            echo "--- Previous Results ---"  
            grep -E "(SMA-|EMA-|RSI-|Bollinger-|MACD:|ATR-)" "${LATEST_BENCHMARKS[1]}" | head -20
            echo ""
            echo "=== Performance Delta Analysis ==="
            
            # Extract and compare performance metrics
            echo "Calculating performance deltas..."
            echo ""
            
            # Create temporary files for processing
            local temp_current=$(mktemp)
            local temp_previous=$(mktemp)
            
            # Extract metrics from both files
            grep -E "(SMA-|EMA-|RSI-|Bollinger-|MACD:|ATR-)" "${LATEST_BENCHMARKS[0]}" | sed 's/.*: *\([0-9.]*\) ms/\1/' > "$temp_current"
            grep -E "(SMA-|EMA-|RSI-|Bollinger-|MACD:|ATR-)" "${LATEST_BENCHMARKS[1]}" | sed 's/.*: *\([0-9.]*\) ms/\1/' > "$temp_previous"
            
            # Get indicator names
            local indicators=($(grep -E "(SMA-|EMA-|RSI-|Bollinger-|MACD:|ATR-)" "${LATEST_BENCHMARKS[0]}" | sed 's/:.*$//' | head -12))
            
            # Calculate deltas
            echo "Performance Changes:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            local i=0
            while IFS= read -r current_time && IFS= read -r previous_time <&3; do
                if [ $i -lt ${#indicators[@]} ] && [ -n "$current_time" ] && [ -n "$previous_time" ]; then
                    local indicator="${indicators[i]}"
                    
                    # Calculate percentage change using awk for floating point math
                    local delta_ms=$(awk "BEGIN {printf \"%.3f\", $current_time - $previous_time}")
                    local delta_percent=$(awk "BEGIN {if($previous_time != 0) printf \"%.1f\", (($current_time - $previous_time) / $previous_time) * 100; else print \"N/A\"}")
                    
                    # Determine if it's an improvement or regression
                    local status=""
                    if awk "BEGIN {exit ($delta_ms < -0.001) ? 0 : 1}"; then
                        status="🟢 IMPROVED"
                    elif awk "BEGIN {exit ($delta_ms > 0.001) ? 0 : 1}"; then
                        status="🔴 SLOWER"
                    else
                        status="⚪ UNCHANGED"
                    fi
                    
                    printf "%-20s %8s ms → %8s ms  (%+6s ms, %+5s%%) %s\n" \
                        "$indicator" "$previous_time" "$current_time" "$delta_ms" "$delta_percent" "$status"
                fi
                ((i++))
            done < "$temp_current" 3< "$temp_previous"
            
            # Clean up temp files
            rm -f "$temp_current" "$temp_previous"
            
            echo ""
            echo "Legend:"
            echo "🟢 IMPROVED  - Performance got better (faster)"
            echo "🔴 SLOWER    - Performance got worse (slower)" 
            echo "⚪ UNCHANGED - No significant change (<0.001ms)"
            
        } > "$RESULTS_DIR/comparison_$TIMESTAMP.txt"
        
        echo "✅ Comparison report saved to comparison_$TIMESTAMP.txt"
    else
        echo "ℹ️  Not enough benchmark files for comparison (need at least 2)"
    fi
}

# Main execution
case "${1:-all}" in
    "benchmark")
        run_benchmarks
        ;;
    "memory")  
        run_memory_profiling
        ;;
    "system")
        run_system_monitoring
        ;;
    "compare")
        generate_comparison
        ;;
    "all")
        run_system_monitoring
        run_benchmarks
        run_memory_profiling
        generate_comparison
        ;;
    *)
        echo "Usage: $0 [benchmark|memory|system|compare|all]"
        echo ""
        echo "Commands:"
        echo "  benchmark - Run performance benchmarks"
        echo "  memory    - Run memory profiling"
        echo "  system    - Collect system information"
        echo "  compare   - Generate comparison report from last two benchmark runs"
        echo "  all       - Run all profiling tasks (default)"
        exit 1
        ;;
esac

echo ""
echo "🎉 Profiling completed!"
echo "📁 Check results in: $RESULTS_DIR"
echo ""
echo "Next steps:"
echo "  - Review the generated reports"
echo "  - Compare with previous results" 
echo "  - Identify performance bottlenecks"
echo "  - Consider optimization opportunities"