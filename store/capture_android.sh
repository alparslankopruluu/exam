#!/bin/bash
# Captures raw Android screenshots for every language using the debug
# screenshot mode. Requires a running emulator and a debug build installed.
# Usage: store/capture_android.sh [lang ...]
set -euo pipefail
cd "$(dirname "$0")"
OUT=screenshots/raw/android
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

# Clean status bar: 9:41, full battery, no notification icons.
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null

for lang in "${LANGS[@]}"; do
  mkdir -p "$OUT/$lang"
  for screen in "${SCREENS[@]}"; do
    case "$screen" in today) n=1 ;; session) n=2 ;; practice) n=3 ;; tutor) n=4 ;; esac
    file="$OUT/$lang/${n}_${screen}.png"
    for attempt in 1 2 3; do
      adb shell pm clear com.techtactoe.examly >/dev/null
      adb shell am start -n com.techtactoe.examly/com.kprl.exam.MainActivity \
        --es screenshotLanguage "$lang" --es screenshotExam "$(exam_for "$lang")" \
        --es screenshotScreen "$screen" >/dev/null
      sleep $((4 + attempt * 2))
      adb exec-out screencap -p > "$file"
      python3 is_blank.py "$file" || break
      echo "  retry $lang/$screen (blank frame)"
    done
  done
  echo "captured $lang"
done
adb shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
