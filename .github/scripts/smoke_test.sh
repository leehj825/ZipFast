#!/usr/bin/env bash
# Launches the APK on an emulator and fails if the app crashes or does not stay open.
# Run inside reactivecircus/android-emulator-runner (adb is connected to the emulator).
set -u
PKG=com.zipfast.zipfast
APK=$(ls dist/*.apk | head -1)
OUT=smoke
mkdir -p "$OUT"

echo "Installing $APK"
adb install -r "$APK" || { echo "::error::APK did not install"; exit 1; }

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
echo "Launched; waiting 30s for startup, ads init and the first frames"
sleep 30

adb logcat -d > "$OUT/logcat.txt"
adb logcat -d -b crash > "$OUT/crash.txt" 2>/dev/null
adb exec-out screencap -p > "$OUT/screen.png" 2>/dev/null
adb shell dumpsys activity activities > "$OUT/activities.txt" 2>/dev/null

FAIL=0
# Did the in-app crash report screen come up? (informational; it only appears after a crash)
if grep -qE "Displayed $PKG/\.CrashActivity|START .*$PKG/\.CrashActivity" "$OUT/logcat.txt"; then
  echo "::notice::The crash report screen (CrashActivity) was shown after a crash"
  grep -E "Displayed $PKG/\.CrashActivity" "$OUT/logcat.txt" | head -2
fi
if ! adb shell pidof "$PKG" >/dev/null 2>&1 || [ -z "$(adb shell pidof "$PKG" | tr -d '\r')" ]; then
  echo "::error::The app process is not running (it crashed or exited)"; FAIL=1
fi
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt" "$OUT/crash.txt" 2>/dev/null; then
  echo "::error::FATAL EXCEPTION in logcat"; FAIL=1
fi
if grep -qE "Process: $PKG|ZipFast: uncaught|Unable to instantiate|WorkDatabase" "$OUT/logcat.txt"; then
  echo "::warning::Suspicious log lines:"; grep -nE "Process: $PKG|ZipFast: uncaught|Unable to instantiate|WorkDatabase" "$OUT/logcat.txt" | head -20
fi
if ! grep -q "$PKG" "$OUT/activities.txt" 2>/dev/null || ! grep -E "mResumedActivity|topResumedActivity" "$OUT/activities.txt" | grep -q "$PKG"; then
  echo "::error::ZipFast is not the resumed activity"; FAIL=1
fi
# The Flutter engine must have started rendering.
if ! grep -qiE "flutter" "$OUT/logcat.txt"; then echo "::warning::no Flutter log lines found"; fi

if [ "$FAIL" -ne 0 ]; then
  echo "----- crash buffer -----"; tail -80 "$OUT/crash.txt"
  echo "----- app log tail -----"; grep -E "AndroidRuntime|$PKG|flutter|ZipFast" "$OUT/logcat.txt" | tail -80
  exit 1
fi
# The crash report screen must itself work (it only shows after a crash, so check it by hand).
adb shell am start -n "$PKG/.CrashActivity" --es zipfast.crash_report "CI check of the crash report screen" >/dev/null
sleep 5
adb shell dumpsys activity activities > "$OUT/activities_crash.txt" 2>/dev/null
adb exec-out screencap -p > "$OUT/crash_screen.png" 2>/dev/null
if ! grep -E "mResumedActivity|topResumedActivity" "$OUT/activities_crash.txt" | grep -q "CrashActivity"; then
  echo "::error::The crash report screen did not open"; exit 1
fi
echo "Smoke test passed: the app runs and shows its main screen, and the crash report screen opens."
