#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-}"
receipt="$(pwd)/results/testflight"
archive="$receipt/ApolloHack.xcarchive"
mkdir -p "$receipt"
case "$mode" in
archive)
  test -z "$(git status --porcelain --untracked-files=all)" || { echo 'Release requires a clean source tree.'; exit 1; }
  git rev-parse HEAD > "$receipt/source-sha.txt"
  xcodegen generate --spec ios/project.yml
  xcodebuild -project ios/ApolloHack.xcodeproj -scheme ApolloHack -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive" -derivedDataPath /private/tmp/apollo-hack-release-derived DEVELOPMENT_TEAM=6GB3JDVN8D CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=Apple Distribution: GYM NYC LEXINGTON LLC (6GB3JDVN8D)' 'PROVISIONING_PROFILE_SPECIFIER=Apollo Hack TestFlight 20261017' archive -quiet
  ;;
export)
  test "$(git rev-parse HEAD)" = "$(cat "$receipt/source-sha.txt")"
  xcodebuild -exportArchive -archivePath "$archive" -exportPath "$receipt/export" -exportOptionsPlist ios/ExportOptions.plist -quiet
  ;;
*) echo 'Usage: tools/testflight.sh archive|export'; exit 64;;
esac
