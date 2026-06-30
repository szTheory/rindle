#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$ROOT_DIR"

PACKAGE="${RINDLE_HEX_PACKAGE:-rindle}"
VERSION="${1:-${VERSION:-}}"
EXPECTED_OWNER="${RINDLE_HEX_OWNER:-sztheory}"
SOURCE_URL="${RINDLE_SOURCE_URL:-https://github.com/szTheory/rindle}"

if [ -z "$VERSION" ]; then
  echo "verify_hex_package_metadata: requires a published version as \$1 or VERSION" >&2
  exit 1
fi

PACKAGE_JSON="$(mktemp "${TMPDIR:-/tmp}/rindle-hex-package.XXXXXX.json")"
RELEASE_JSON="$(mktemp "${TMPDIR:-/tmp}/rindle-hex-release.XXXXXX.json")"

cleanup() {
  rm -f "$PACKAGE_JSON" "$RELEASE_JSON"
}

trap cleanup EXIT

curl --fail --location --silent --show-error --retry 5 --retry-delay 2 \
  "https://hex.pm/api/packages/${PACKAGE}" > "$PACKAGE_JSON"

curl --fail --location --silent --show-error --retry 5 --retry-delay 2 \
  "https://hex.pm/api/packages/${PACKAGE}/releases/${VERSION}" > "$RELEASE_JSON"

python3 - "$PACKAGE_JSON" "$RELEASE_JSON" "$PACKAGE" "$VERSION" "$EXPECTED_OWNER" "$SOURCE_URL" <<'PY'
import json
import sys

package_path, release_path, package, version, expected_owner, source_url = sys.argv[1:]
expected_owner = expected_owner.lower()

with open(package_path, encoding="utf-8") as handle:
    package_data = json.load(handle)

with open(release_path, encoding="utf-8") as handle:
    release_data = json.load(handle)

errors = []


def require(condition, message):
    if not condition:
        errors.append(message)


require(package_data.get("name") == package, f"expected package name {package!r}")
require(release_data.get("version") == version, f"expected release version {version!r}")
require(
    any(release.get("version") == version for release in package_data.get("releases", [])),
    f"package API does not list release {version}",
)

links = (package_data.get("meta") or {}).get("links") or {}
expected_links = {
    "GitHub": source_url,
    "Changelog": f"{source_url}/blob/main/CHANGELOG.md",
    "Docs": "https://hexdocs.pm/rindle",
}

for name, expected_url in expected_links.items():
    require(
        links.get(name) == expected_url,
        f"expected package link {name}={expected_url!r}, got {links.get(name)!r}",
    )

owners = [
    str(owner.get("username", "")).lower()
    for owner in package_data.get("owners", [])
]

require(
    expected_owner in owners,
    f"expected Hex package owner {expected_owner!r}, got {owners!r}",
)

publisher = str((release_data.get("publisher") or {}).get("username", "")).lower()
require(publisher, "release API did not include a publisher username")

if errors:
    for error in errors:
        print(f"verify_hex_package_metadata: {error}", file=sys.stderr)
    sys.exit(1)

print(
    "Hex package metadata OK: "
    f"{package} {version}, links={sorted(expected_links)}, owners={owners}, publisher={publisher}"
)
PY
