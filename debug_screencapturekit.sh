#!/bin/bash

echo "🔍 ScreenCaptureKit System Diagnostic"
echo "===================================="

echo
echo "📱 System Info:"
echo "macOS Version: $(sw_vers -productVersion)"
echo "Build: $(sw_vers -buildVersion)"
echo "Arch: $(uname -m)"

echo
echo "🔐 TCC Database Status:"
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, auth_value, last_modified FROM access WHERE service='kTCCServiceScreenCapture' ORDER BY last_modified DESC;" 2>/dev/null || echo "Cannot access system TCC database"

echo
echo "🔐 User TCC Database Status:"
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, auth_value, last_modified FROM access WHERE service='kTCCServiceScreenCapture' ORDER BY last_modified DESC;" 2>/dev/null || echo "Cannot access user TCC database"

echo
echo "🖥️ Display Configuration:"
system_profiler SPDisplaysDataType | grep -E "(Resolution|Display Type|Main Display)"

echo
echo "🧹 Window Server Status:"
pgrep WindowServer > /dev/null && echo "WindowServer: Running" || echo "WindowServer: NOT RUNNING!"

echo
echo "🔍 Core Graphics Errors (last 5 minutes):"
log show --last 5m --predicate 'subsystem == "com.apple.CoreGraphics"' --style compact 2>/dev/null | head -10 || echo "No CoreGraphics logs found"

echo
echo "🎥 ScreenCaptureKit Process Status:"
pgrep -l screencaptured || echo "No screencaptured process found"

echo
echo "📁 ScreenCaptureKit Framework:"
ls -la /System/Library/Frameworks/ScreenCaptureKit.framework/ 2>/dev/null || echo "ScreenCaptureKit framework not found at expected location"

echo
echo "🛡️ System Integrity Protection:"
csrutil status 2>/dev/null || echo "Cannot check SIP status"

echo
echo "🔄 Recommendations:"
echo "1. Restart WindowServer: sudo killall WindowServer (logout required)"
echo "2. Reset TCC completely: tccutil reset All"
echo "3. Reboot system"
echo "4. Check Console.app for CoreGraphics/WindowServer errors"