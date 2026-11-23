#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "This build script requires macOS." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
identity_name="${KUROCAT_SIGNING_IDENTITY:-KuroCat Local Signing}"
identity_hash="$(security find-identity -v -p codesigning | awk -F '"' -v name="$identity_name" '
  $2 == name { split($1, fields, " "); print fields[2] }
')"
if [[ ! "$identity_hash" =~ ^[[:xdigit:]]{40}$ ]]; then
  echo "Expected one valid code-signing identity named '$identity_name' in Keychain." >&2
  exit 1
fi

KUROCAT_LOCAL_SIGNING=1 npm run tauri:build -- --bundles app --no-sign
target_dir="$(cargo metadata --manifest-path src-tauri/Cargo.toml --format-version 1 --no-deps |
  node -e 'process.stdout.write(JSON.parse(require("node:fs").readFileSync(0, "utf8")).target_directory)')"
app="$target_dir/release/bundle/macos/KuroCat.app"
requirement="identifier \"com.kurocat.pet\" and certificate leaf = H\"$identity_hash\""
codesign --force --sign "$identity_hash" --timestamp=none -r "=designated => $requirement" "$app"
codesign --verify --all-architectures --strict -R="$requirement" "$app"
printf 'Signed KuroCat app: %s\n' "$app"
