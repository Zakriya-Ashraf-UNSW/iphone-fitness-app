#!/usr/bin/env bash
set -e

# ==============================================================================
# build_ipa.sh: Build and Package Signed iOS IPA for iPhone Fitness App
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
ARCHIVE_PATH="/tmp/FitnessApp.xcarchive"
PAYLOAD_DIR="/tmp/FitnessApp_Payload"
OUTPUT_IPA="${PROJECT_DIR}/FitnessApp.ipa"

echo "================================================================="
echo "  DPO HYPERTROPHY ENGINE: AUTOMATED IPA BUILD & PACKAGE"
echo "================================================================="

echo "🚀 [1/4] Running mathematical invariant test suite..."
swiftc \
  "${PROJECT_DIR}/Tests/DPOTestSuite.swift" \
  "${PROJECT_DIR}/ios/App/SharedWorkoutModels/Sources/DPOEngine.swift" \
  "${PROJECT_DIR}/ios/App/SharedWorkoutModels/Sources/Exercise.swift" \
  -o /tmp/dpo_test_runner

/tmp/dpo_test_runner
echo "✅ Mathematical invariants passed."

echo ""
echo "📦 [2/4] Archiving Xcode project (Release, iOS Generic Platform)..."
rm -rf "${ARCHIVE_PATH}"
xcodebuild archive \
  -project "${PROJECT_DIR}/ios/App/App.xcodeproj" \
  -scheme App \
  -archivePath "${ARCHIVE_PATH}" \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -quiet

echo "✅ Archive created at ${ARCHIVE_PATH}"

echo ""
echo "🔏 [3/4] Staging payload & applying code signatures..."
rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}/Payload"
cp -R "${ARCHIVE_PATH}/Products/Applications/App.app" "${PAYLOAD_DIR}/Payload/"

APP_BUNDLE="${PAYLOAD_DIR}/Payload/App.app"

# Sign embedded app extensions
if [ -d "${APP_BUNDLE}/PlugIns/WorkoutWidgetsExtension.appex" ]; then
  codesign --force --sign - --timestamp=none "${APP_BUNDLE}/PlugIns/WorkoutWidgetsExtension.appex"
fi

# Sign embedded frameworks if present
if [ -d "${APP_BUNDLE}/Frameworks" ]; then
  find "${APP_BUNDLE}/Frameworks" -type d -name "*.framework" | while read fw; do
    codesign --force --sign - --timestamp=none "$fw"
  done
fi

# Sign main application bundle
codesign --force --sign - --timestamp=none "${APP_BUNDLE}"

echo "✅ App bundle and extensions signed (Mach-O ARM64 thin)."

echo ""
echo "🗜️ [4/4] Compressing into IPA package..."
rm -f "${OUTPUT_IPA}"
(cd "${PAYLOAD_DIR}" && zip -qr -9 "${OUTPUT_IPA}" Payload)

IPA_SIZE=$(du -h "${OUTPUT_IPA}" | awk '{print $1}')
echo "================================================================="
echo "🎉 SUCCESS: IPA Package Created!"
echo "   File: ${OUTPUT_IPA} (${IPA_SIZE})"
echo "   Bundle ID: com.overload.fitnessapp"
echo "   Architecture: arm64"
echo "   Dynamic Island Widget: Included (WorkoutWidgetsExtension.appex)"
echo "================================================================="
