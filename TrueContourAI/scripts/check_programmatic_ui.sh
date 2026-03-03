#!/bin/sh
set -e

INFO_PLIST="${SRCROOT}/TrueContourAI/Info.plist"
MAIN_STORYBOARD="${SRCROOT}/TrueContourAI/Base.lproj/Main.storyboard"

if /usr/bin/grep -q "UIMainStoryboardFile" "$INFO_PLIST"; then
  echo "Error: UIMainStoryboardFile found in Info.plist. Programmatic UI only."
  exit 1
fi

if [ -f "$MAIN_STORYBOARD" ]; then
  echo "Error: Main.storyboard exists under TrueContourAI/. Programmatic UI only."
  exit 1
fi
