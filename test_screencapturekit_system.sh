#!/bin/bash

echo "🔧 Testing ScreenCaptureKit System Recovery"
echo "========================================="

echo "1. Checking screencaptured process..."
pgrep -l screencaptured || echo "❌ screencaptured not running"

echo
echo "2. Attempting to trigger screencaptured startup..."
echo "   (This should start the process automatically)"

# Create a minimal Swift test to trigger ScreenCaptureKit
cat > /tmp/test_sck.swift << 'EOF'
import Foundation
import ScreenCaptureKit

@available(macOS 12.3, *)
@main
struct SCKTest {
    static func main() async {
        print("🔬 Testing ScreenCaptureKit system...")
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            print("✅ ScreenCaptureKit working: \(content.displays.count) displays")
        } catch {
            print("❌ ScreenCaptureKit failed: \(error)")
        }
    }
}
EOF

echo "3. Running minimal ScreenCaptureKit test..."
swift /tmp/test_sck.swift

echo
echo "4. Checking if screencaptured started..."
pgrep -l screencaptured && echo "✅ screencaptured now running!" || echo "❌ screencaptured still not running"

echo
echo "5. If still failing, you need to:"
echo "   • Reboot your Mac completely"
echo "   • Check Console.app for WindowServer/CoreGraphics errors"
echo "   • Possibly reinstall macOS if ScreenCaptureKit is corrupted"

rm -f /tmp/test_sck.swift