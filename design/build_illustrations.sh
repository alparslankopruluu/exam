#!/bin/bash
# Exports the code-drawn illustrations in design/illustrations/*.svg to both apps:
#   iOS     -> ios/Exam/Assets.xcassets/Illustrations/<name>.imageset (vector preserved)
#   Android -> android/app/src/main/res/drawable/illu_<name>.xml (VectorDrawable)
# Usage: design/build_illustrations.sh
set -euo pipefail
cd "$(dirname "$0")/.."
IOS=ios/Exam/Assets.xcassets/Illustrations
AND=android/app/src/main/res/drawable
mkdir -p "$IOS"
[ -f "$IOS/Contents.json" ] || printf '{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n' > "$IOS/Contents.json"
for svg in design/illustrations/*.svg; do
  name=$(basename "$svg" .svg)
  set_dir="$IOS/$name.imageset"
  mkdir -p "$set_dir"
  cp "$svg" "$set_dir/$name.svg"
  cat > "$set_dir/Contents.json" <<JSON
{
  "images" : [ { "filename" : "$name.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true }
}
JSON
  tmp=$(mktemp -t "$name").svg
  python3 design/svg_shapes_to_paths.py "$svg" "$tmp"
  npx --yes svg2vectordrawable@2 -i "$tmp" -o "$AND/illu_$name.xml" >/dev/null
  rm -f "$tmp"
  echo "exported $name"
done
