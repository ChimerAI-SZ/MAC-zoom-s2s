#!/bin/bash
# Test AEC functionality

echo "Starting BabelAI with AEC support..."
echo "==========================================="
echo ""

# Kill any existing BabelAI processes
pkill -f BabelAI 2>/dev/null

# Run the app in background and capture output
/tmp/BabelAI-build/Build/Products/Debug/BabelAI.app/Contents/MacOS/BabelAI 2>&1 | tee /tmp/babelai_test.log &
APP_PID=$!

echo "Application started with PID: $APP_PID"
echo ""

# Wait for initialization
sleep 3

# Check if SpeexDSP loaded
echo "Checking AEC status..."
if grep -q "SpeexDSP loaded; AEC active" /tmp/babelai_test.log; then
    echo "✅ SpeexDSP loaded successfully - AEC is ACTIVE"
    echo "   Frame size: 160 samples (10ms @ 16kHz)"
    echo "   Tail length: 3200 samples (200ms)"
elif grep -q "SpeexDSP not found" /tmp/babelai_test.log; then
    echo "⚠️  SpeexDSP not found - Running in pass-through mode"
else
    echo "❓ No AEC status message found yet"
fi

echo ""
echo "Current AEC configuration:"
grep "AEC_DELAY_MS" /Users/zoharhuang/Desktop/DEEP\ LEARNING/Coding\ learning/s2s/BabelAI/.env || echo "No AEC_DELAY_MS configured"

echo ""
echo "Application logs (last 20 lines):"
echo "----------------------------------"
tail -20 /tmp/babelai_test.log

echo ""
echo "Press Enter to stop the test..."
read

# Clean up
kill $APP_PID 2>/dev/null
echo "Test completed."