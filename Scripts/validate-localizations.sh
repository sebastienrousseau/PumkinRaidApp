#!/bin/bash
set -euo pipefail

REFERENCE="Sources/PumkinRaidApp/Resources/en.lproj/Localizable.strings"
LOCALES=(de en es fr it ja ko pt-BR zh-Hans)

extract_keys() {
  sed -n 's/^"\([^"]*\)"[[:space:]]*=.*/\1/p' "$1" | LC_ALL=C sort
}

for locale in "${LOCALES[@]}"; do
  candidate="Sources/PumkinRaidApp/Resources/${locale}.lproj/Localizable.strings"
  plutil -lint "$candidate" >/dev/null
  if ! diff -u <(extract_keys "$REFERENCE") <(extract_keys "$candidate"); then
    echo "Localization keys differ for ${locale}" >&2
    exit 1
  fi
done

echo "Localization key parity passed for ${#LOCALES[@]} locales."
