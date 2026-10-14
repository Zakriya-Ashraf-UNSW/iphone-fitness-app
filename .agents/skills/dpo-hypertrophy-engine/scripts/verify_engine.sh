#!/usr/bin/env bash
set -e

# ==============================================================================
# verify_engine.sh: Verification Runner for DPO Hypertrophy Engine & iOS App
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
echo "🚀 [1/2] Compiling and running DPO Mathematical Test Suite..."
swiftc \
  "${PROJECT_DIR}/Tests/DPOTestSuite.swift" \
  "${PROJECT_DIR}/ios/App/SharedWorkoutModels/Sources/DPOEngine.swift" \
  "${PROJECT_DIR}/ios/App/SharedWorkoutModels/Sources/Exercise.swift" \
  -o /tmp/dpo_test_runner

/tmp/dpo_test_runner
echo "✅ DPO Test Harness Passed Successfully."

echo ""
echo "📱 [2/2] Verifying Xcode project compilation for iOS Simulator..."
xcodebuild \
  -project "${PROJECT_DIR}/ios/App/App.xcodeproj" \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -quiet

echo "🎉 All DPO Engine & iOS App verification checks PASSED cleanly!"
