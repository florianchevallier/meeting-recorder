#!/bin/bash

# Script pour voir les logs de debug
# Usage: ./view_logs.sh

LOG_FILE="$HOME/Documents/MeetingRecorder_debug.log"

if [ -f "$LOG_FILE" ]; then
    echo "📋 MeetingRecorder Debug Logs:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📁 Log file location: $LOG_FILE"
    echo "🔄 To monitor live: tail -f '$LOG_FILE'"
else
    echo "❌ No log file found at: $LOG_FILE"
    echo "💡 Run the app first to generate logs"
fi