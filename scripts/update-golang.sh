#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# update-golang.sh
#
# Detect the latest stable Go release from go.dev, compute the SHA256 of the
# source tarball, and update the local OpenWrt golang package Makefile by
# changing only these variables:
#   - GO_VERSION_MAJOR_MINOR
#   - GO_VERSION_PATCH
#   - PKG_HASH (or PKG_SOURCE_HASH if present)
#
# Usage:
#   ./scripts/update-golang.sh [OPENWRT_ROOT]
# If OPENWRT_ROOT is omitted, the script uses the current working directory.
#
# Notes:
#  - Requires: bash, curl, python3, sha256sum, awk, sed, grep
#  - Does NOT perform git commit/push. It only modifies the Makefile in-place.
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="${1:-$(pwd)}"
echo "Searching for golang Makefile under: ${ROOT}"

# Candidate paths (common OpenWrt layout). We'll expand globs when checking.
CANDIDATES=(
  "${ROOT}/feeds/packages/lang/golang/Makefile"
  "${ROOT}/feeds/packages/lang/golang/Makefile.in"
  "${ROOT}/feeds/packages/lang/golang/*/Makefile"
  "${ROOT}/package/feeds/packages/golang/Makefile"
  "${ROOT}/package/feeds/packages/golang/*/Makefile"
  "${ROOT}/package/*/golang/Makefile"
  "${ROOT}/feeds/packages/*/golang/Makefile"
)

MAKEFILE=""
for p in "${CANDIDATES[@]}"; do
  # expand possible globs
  for f in $(eval echo "$p" 2>/dev/null); do
    if [ -f "$f" ]; then
      MAKEFILE="$f"
      break 2
    fi
  done
done

# Fallback: scan for a Makefile that looks like golang package (may be slower).
if [ -z "$MAKEFILE" ]; then
  echo "Fallback: scanning for a golang package Makefile (this may be slower)..."
  MAKEFILE=$(
    find "${ROOT}" -type f -name Makefile -print 2>/dev/null \
      | grep -Ei '/golang/Makefile|/packages/.*/golang|/packages/lang/golang' \
      | head -n 1 || true
  )
fi

if [ -z "$MAKEFILE" ]; then
  echo "No golang Makefile found in the workspace. Nothing to update."
  exit 0
fi

echo "Found Makefile: ${MAKEFILE}"

# Get latest stable Go release using go.dev JSON feed.
# We will choose the highest numeric stable semantic version (ignore beta/rc).
read LATEST_MAJOR_MINOR LATEST_PATCH LATEST_TAG LATEST_SRC_FILENAME < <(python3 - <<'PY'
import json, re, urllib.request, sys

# Fetch JSON list of releases
URL = 'https://go.dev/dl/?mode=json'
data = json.loads(urllib.request.urlopen(URL, timeout=30).read().decode())

def is_stable(tag):
    # stable tags look like 'go1.25.1' or 'go1.25' (no rc/beta)
    return re.match(r'^go\d+\.\d+(?:\.\d+)?$', tag) is not None

versions = []
for entry in data:
    v = entry.get('version', '')
    if not is_stable(v):
        continue
    # find source tarball filename
    files = entry.get('files', []) or []
    srcname = None
    for f in files:
        if f.get('kind') == 'source' or (f.get('filename') and f.get('filename').endswith('.src.tar.gz')):
            srcname = f.get('filename')
            break
    # fallback to first file filename if none matched
    if not srcname and files:
        srcname = files[0].get('filename')
    m = re.match(r'^go(\d+)\.(\d+)(?:\.(\d+))?$', v)
    if m:
        major = int(m.group(1)); minor = int(m.group(2)); patch = int(m.group(3) or 0)
        versions.append((major, minor, patch, v, srcname))

if not versions:
    # no stable versions found
    sys.exit(2)

# pick the largest semantic version
versions.sort()
major, minor, patch, tag, src = versions[-1]
print(f"{major}.{minor} {patch} {tag} {src}")
PY
)

if [ -z "${LATEST_TAG}" ]; then
  echo "Failed to detect latest Go release from go.dev/dl. Aborting."
  exit 1
fi

echo "Latest Go release detected: ${LATEST_TAG} (major.minor: ${LATEST_MAJOR_MINOR}, patch: ${LATEST_PATCH}), src file: ${LATEST_SRC_FILENAME}"

# Compute sha256 of source tarball (download and stream to sha256sum)
SRC_URL="https://go.dev/dl/${LATEST_SRC_FILENAME}"
echo "Downloading source tarball to compute SHA256 (streaming): ${SRC_URL}"
NEW_HASH=$(curl -fsSL "${SRC_URL}" | sha256sum | awk '{print $1}') || {
  echo "Failed to download or compute hash for ${SRC_URL}"
  exit 1
}
echo "Computed sha256: ${NEW_HASH}"

# Read current values from the Makefile (if present)
cur_major_minor=$(grep -E '^GO_VERSION_MAJOR_MINOR' "${MAKEFILE}" 2>/dev/null | head -n1 | awk -F'[:=]' '{print $2}' | tr -d ' \t' || true)
cur_patch=$(grep -E '^GO_VERSION_PATCH' "${MAKEFILE}" 2>/dev/null | head -n1 | awk -F'[:=]' '{print $2}' | tr -d ' \t' || true)
cur_hash=$(grep -E '^PKG_HASH' "${MAKEFILE}" 2>/dev/null | head -n1 | awk -F'[:=]' '{print $2}' | tr -d ' \t' || true)

echo "Current in Makefile: GO_VERSION_MAJOR_MINOR='${cur_major_minor}' GO_VERSION_PATCH='${cur_patch}' PKG_HASH='${cur_hash}'"

# Determine whether update is needed
need_update=0
if [ "${cur_major_minor}" != "${LATEST_MAJOR_MINOR}" ] || [ "${cur_patch}" != "${LATEST_PATCH}" ] || [ "${cur_hash}" != "${NEW_HASH}" ]; then
  need_update=1
fi

if [ "${need_update}" -eq 0 ]; then
  echo "Makefile already up-to-date. No changes made."
  exit 0
fi

echo "Updating Makefile variables..."

# Replace or append GO_VERSION_MAJOR_MINOR
if grep -qE '^GO_VERSION_MAJOR_MINOR' "${MAKEFILE}"; then
  sed -i -E "s/^(GO_VERSION_MAJOR_MINOR\s*[:=]\s*).*/\1${LATEST_MAJOR_MINOR}/" "${MAKEFILE}"
else
  echo "GO_VERSION_MAJOR_MINOR:=${LATEST_MAJOR_MINOR}" >> "${MAKEFILE}"
fi

# Replace or append GO_VERSION_PATCH
if grep -qE '^GO_VERSION_PATCH' "${MAKEFILE}"; then
  sed -i -E "s/^(GO_VERSION_PATCH\s*[:=]\s*).*/\1${LATEST_PATCH}/" "${MAKEFILE}"
else
  echo "GO_VERSION_PATCH:=${LATEST_PATCH}" >> "${MAKEFILE}"
fi

# Replace PKG_HASH or PKG_SOURCE_HASH (prefer PKG_HASH)
if grep -qE '^PKG_HASH' "${MAKEFILE}"; then
  sed -i -E "s/^(PKG_HASH\s*[:=]\s*).*/\1${NEW_HASH}/" "${MAKEFILE}"
elif grep -qE '^PKG_SOURCE_HASH' "${MAKEFILE}"; then
  sed -i -E "s/^(PKG_SOURCE_HASH\s*[:=]\s*).*/\1${NEW_HASH}/" "${MAKEFILE}"
else
  # append PKG_HASH if not present
  echo "PKG_HASH:=${NEW_HASH}" >> "${MAKEFILE}"
fi

echo "Makefile updated: ${MAKEFILE}"
echo "New values: GO_VERSION_MAJOR_MINOR=${LATEST_MAJOR_MINOR}, GO_VERSION_PATCH=${LATEST_PATCH}, PKG_HASH=${NEW_HASH}"
exit 0
