#!/bin/bash
# Captures raw iOS screenshots (6.9" iPhone) for every language using the
# debug screenshot mode. Build the Debug app first (see README in store/).
# Usage: store/capture_ios.sh [lang ...]
set -euo pipefail
cd "$(dirname "$0")"
DEVICE="${DEVICE:-Examly Shots}"
APP="../ios/build/Build/Products/Debug-iphonesimulator/Exam.app"
BUNDLE=com.techtactoe.examly
OUT=screenshots/raw/ios
read -r -a SCREENS <<< "${SCREENS:-today session practice tutor}"

exam_for() {
  case "$1" in
    en) echo us_sat ;; tr) echo tr_yks ;; de) echo de_abitur ;; fr) echo fr_bac ;;
    es) echo es_pau ;; pt) echo br_enem ;; hi) echo in_jee_main ;; ja) echo jp_common_test ;;
    ko) echo kr_csat ;; zh-Hant) echo intl_toefl ;; *) echo intl_ielts ;;
  esac
}

LANGS=("$@")
[ ${#LANGS[@]} -eq 0 ] && LANGS=(en tr de fr es it pt pt-PT nl sv nb pl ru ar hi id ja ko zh-Hans zh-Hant)

UDID=$(xcrun simctl list devices available | grep "    $DEVICE (" | head -1 | grep -oE '[0-9A-F-]{36}')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" >/dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi

for lang in "${LANGS[@]}"; do
  mkdir -p "$OUT/$lang"
  # Fresh install per language so SwiftData plans from another exam don't leak in.
  xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$UDID" "$APP"
  for screen in "${SCREENS[@]}"; do
    case "$screen" in today) n=1 ;; session) n=2 ;; practice) n=3 ;; tutor) n=4 ;; esac
    file="$OUT/$lang/${n}_${screen}.png"
    for attempt in 1 2 3; do
      xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" \
        -screenshotLanguage "$lang" -screenshotExam "$(exam_for "$lang")" -screenshotScreen "$screen" >/dev/null
      sleep $((${WAIT:-4} + attempt * 2))
      xcrun simctl io "$UDID" screenshot "$file" >/dev/null 2>&1
      python3 is_blank.py "$file" || break
      echo "  retry $lang/$screen (blank frame)"
    done
  done
  echo "captured $lang"
done
xcrun simctl status_bar "$UDID" clear
