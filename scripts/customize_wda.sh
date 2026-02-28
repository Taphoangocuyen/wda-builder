#!/bin/bash
# ============================================================
# customize_wda.sh - Tuỳ chỉnh WebDriverAgent trước khi build
# ============================================================

DISPLAY_NAME="${DISPLAY_NAME:-Panda Helper}"
BUNDLE_PREFIX="${BUNDLE_PREFIX:-com.panda}"
MIN_IOS="${MIN_IOS:-15.0}"

WDA_DIR="WebDriverAgent"
RUNNER_PLIST="$WDA_DIR/WebDriverAgentRunner/Info.plist"

echo "========================================"
echo "🔧 Tuỳ chỉnh WebDriverAgent"
echo "========================================"
echo "  Tên: $DISPLAY_NAME"
echo "  Bundle prefix: $BUNDLE_PREFIX"
echo "  Min iOS: $MIN_IOS"
echo ""

# ------------------------------------------
# 1. ĐỔI TÊN HIỂN THỊ
# ------------------------------------------
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$RUNNER_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $DISPLAY_NAME" "$RUNNER_PLIST"
echo "✅ Tên hiển thị: $DISPLAY_NAME"

# ------------------------------------------
# 2. ĐỔI BUNDLE ID TRONG PBXPROJ
# ------------------------------------------
PBXPROJ="$WDA_DIR/WebDriverAgent.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
    # Thay đổi bundle ID prefix
    sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.facebook/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_PREFIX}/g" "$PBXPROJ"
    echo "✅ Bundle ID prefix: $BUNDLE_PREFIX"
fi

# ------------------------------------------
# 3. ĐỔI MINIMUM iOS VERSION
# ------------------------------------------
/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion $MIN_IOS" "$RUNNER_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string $MIN_IOS" "$RUNNER_PLIST"
echo "✅ Min iOS: $MIN_IOS"

# ------------------------------------------
# 4. THÊM BACKGROUND MODE
# ------------------------------------------
/usr/libexec/PlistBuddy -c "Delete :UIBackgroundModes" "$RUNNER_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$RUNNER_PLIST"
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string continuous" "$RUNNER_PLIST"
echo "✅ Background Mode: continuous"

# ------------------------------------------
# 5. THÊM TẤT CẢ QUYỀN TRUY CẬP
# ------------------------------------------
PERMISSIONS=(
    "NSCameraUsageDescription"
    "NSPhotoLibraryUsageDescription"
    "NSMicrophoneUsageDescription"
    "NSLocationWhenInUseUsageDescription"
    "NSLocationAlwaysAndWhenInUseUsageDescription"
    "NSContactsUsageDescription"
    "NSCalendarsUsageDescription"
    "NSRemindersUsageDescription"
    "NSBluetoothAlwaysUsageDescription"
    "NSBluetoothPeripheralUsageDescription"
    "NSHealthShareUsageDescription"
    "NSHealthUpdateUsageDescription"
    "NSHealthClinicalHealthRecordsShareUsageDescription"
    "NSHomeKitUsageDescription"
    "NSMotionUsageDescription"
    "NSSpeechRecognitionUsageDescription"
    "NSSiriUsageDescription"
    "NSFaceIDUsageDescription"
    "NSLocalNetworkUsageDescription"
    "NSUserTrackingUsageDescription"
    "NSAppleMusicUsageDescription"
    "NSVideoSubscriberAccountUsageDescription"
    "NFCReaderUsageDescription"
    "NSSensorKitUsageDescription"
)

PERM_TEXT="Access is necessary for automated testing."
for perm in "${PERMISSIONS[@]}"; do
    /usr/libexec/PlistBuddy -c "Set :$perm $PERM_TEXT" "$RUNNER_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :$perm string $PERM_TEXT" "$RUNNER_PLIST"
done
echo "✅ Đã thêm ${#PERMISSIONS[@]} quyền truy cập"

# ------------------------------------------
# 6. CHO PHÉP HTTP KHÔNG BẢO MẬT
# ------------------------------------------
/usr/libexec/PlistBuddy -c "Delete :NSAppTransportSecurity" "$RUNNER_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$RUNNER_PLIST"
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$RUNNER_PLIST"
echo "✅ NSAllowsArbitraryLoads: true"

# ------------------------------------------
# 7. CÀI ĐẶT BỔ SUNG
# ------------------------------------------
# Cho phép full screen
/usr/libexec/PlistBuddy -c "Set :UIRequiresFullScreen true" "$RUNNER_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool true" "$RUNNER_PLIST"

# Cho phép chạy khi setup
/usr/libexec/PlistBuddy -c "Set :SBIsLaunchableDuringSetup true" "$RUNNER_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :SBIsLaunchableDuringSetup bool true" "$RUNNER_PLIST"

# Hỗ trợ cả iPhone và iPad
/usr/libexec/PlistBuddy -c "Delete :UIDeviceFamily" "$RUNNER_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIDeviceFamily array" "$RUNNER_PLIST"
/usr/libexec/PlistBuddy -c "Add :UIDeviceFamily:0 integer 1" "$RUNNER_PLIST"
/usr/libexec/PlistBuddy -c "Add :UIDeviceFamily:1 integer 2" "$RUNNER_PLIST"

echo "✅ Full screen, launch during setup, iPhone + iPad"

echo ""
echo "========================================"
echo "🎉 Tuỳ chỉnh hoàn tất!"
echo "========================================"
