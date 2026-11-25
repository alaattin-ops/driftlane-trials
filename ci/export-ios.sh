#!/usr/bin/env bash
set -euo pipefail

version=4.7.2
cache="$HOME/.cache/driftlane-godot/$version"
templates="$HOME/Library/Application Support/Godot/export_templates/$version.stable"
godot="$cache/Godot.app/Contents/MacOS/Godot"
download="https://downloads.godotengine.org/?flavor=stable&version=$version"
temp_dir=$(mktemp -d)
trap 'rm -f "$temp_dir/editor.zip" "$temp_dir/templates.tpz" "$temp_dir/ios.zip"; rmdir "$temp_dir"' EXIT
mkdir -p "$cache" "$templates" _xcode
if [[ ! -x "$godot" ]]; then
  curl -fL --retry 3 "$download&platform=macos.universal&slug=macos.universal.zip" -o "$temp_dir/editor.zip"
  ditto -x -k "$temp_dir/editor.zip" "$cache"
fi
if [[ ! -s "$cache/ios.zip" ]]; then
  curl -fL --retry 3 "$download&platform=templates&slug=export_templates.tpz" -o "$temp_dir/templates.tpz"
  unzip -p "$temp_dir/templates.tpz" templates/ios.zip > "$temp_dir/ios.zip"
  mv "$temp_dir/ios.zip" "$cache/ios.zip"
fi
ln -sf "$cache/ios.zip" "$templates/ios.zip"

build_number=${PROJECT_BUILD_NUMBER:?Missing Codemagic build number}
[[ "$build_number" =~ ^[1-9][0-9]*$ ]]
sed -i '' "s/^application\/version=.*/application\/version=\"$build_number\"/" export_presets.cfg
"$godot" --headless --path . --editor --import
"$godot" --headless --path . --export-release iOS "$PWD/_xcode/DriftlaneTrials.ipa"
test -s _xcode/DriftlaneTrials.xcodeproj/project.pbxproj
