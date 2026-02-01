#!/usr/bin/env bash
set -euo pipefail

# scripts/ios.sh
# -------------
# Convenience wrapper around `xcodebuild` for this repo:
# - auto-detects the .xcodeproj/.xcworkspace
# - auto-picks a scheme (or use --scheme)
# - auto-selects an available iPhone Simulator device (or use --destination)
# - runs list/resolve/build/test in a consistent way locally and in CI
#
# Usage examples:
#   bash scripts/ios.sh list
#   bash scripts/ios.sh test
#   bash scripts/ios.sh test --scheme Lifting --project Lifting/Lifting.xcodeproj

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/ios.sh [list|resolve|build|test|all] [--scheme NAME] [--project PATH | --workspace PATH] [--destination DEST]

Examples:
  scripts/ios.sh list
  scripts/ios.sh test --scheme Lifting --project ios/Lifting.xcodeproj
  scripts/ios.sh all --destination "platform=iOS Simulator,OS=latest,name=iPhone 15"

Notes:
  - Does NOT require sudo.
  - If you haven't created/committed an .xcodeproj/.xcworkspace yet, this will error with guidance.
USAGE
}

ACTION="${1:-all}"
shift || true

SCHEME="${SCHEME:-}"
PROJECT_PATH=""
WORKSPACE_PATH=""
DESTINATION="${DESTINATION:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="${2:-}"; shift 2 ;;
    --project)
      PROJECT_PATH="${2:-}"; shift 2 ;;
    --workspace)
      WORKSPACE_PATH="${2:-}"; shift 2 ;;
    --destination)
      DESTINATION="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

detect_container() {
  if [[ -n "${WORKSPACE_PATH}" ]]; then
    echo "workspace:${WORKSPACE_PATH}"
    return 0
  fi
  if [[ -n "${PROJECT_PATH}" ]]; then
    echo "project:${PROJECT_PATH}"
    return 0
  fi

  local ws proj
  # Ignore the internal workspace that Xcode keeps inside an .xcodeproj
  # (e.g. MyApp.xcodeproj/project.xcworkspace) which is not meant to be used as a top-level container.
  ws="$(find . -maxdepth 3 -name "*.xcworkspace" -not -path "*/.xcodeproj/*" -not -path "*.xcodeproj/*" -print -quit || true)"
  proj="$(find . -maxdepth 3 -name "*.xcodeproj" -print -quit || true)"

  if [[ -n "${ws}" ]]; then
    echo "workspace:${ws}"
    return 0
  fi
  if [[ -n "${proj}" ]]; then
    echo "project:${proj}"
    return 0
  fi

  cat >&2 <<'ERR'
ERROR: No .xcworkspace or .xcodeproj found in this repo.

Fix:
  - In Xcode: File -> New -> Project -> iOS App
  - Save it INSIDE this repo (e.g., ./ios/Lifting.xcodeproj)
  - Share the scheme (Product -> Scheme -> Manage Schemes -> Shared)
  - Commit the generated project files

Then re-run:
  scripts/ios.sh list
ERR
  exit 1
}

pick_destination_if_empty() {
  if [[ -n "${DESTINATION}" ]]; then
    return 0
  fi

  if command -v xcrun >/dev/null 2>&1; then
    local json udid
    json="$(xcrun simctl list -j devices available 2>/dev/null || true)"
    if [[ -n "${json}" ]]; then
      udid="$(
        printf '%s' "${json}" | python3 -c 'import json,sys,re; data=json.load(sys.stdin); devices=(data.get("devices",{}) or {}); devs=[]; [devs.extend(v or []) for v in devices.values()]; iph=[d for d in devs if d.get("isAvailable") and d.get("udid") and str(d.get("name","")).startswith("iPhone")]; pref=[d for d in iph if re.match(r"^iPhone\\s+\\d", str(d.get("name","")))]; use=(pref or iph); use.sort(key=lambda d:(("Pro Max" in d.get("name","")), re.search(r"\\bPro\\b", d.get("name","")) is not None, d.get("name",""))); print(use[-1]["udid"] if use else "")'
      )"
      if [[ -n "${udid}" ]]; then
        DESTINATION="platform=iOS Simulator,id=${udid}"
        return 0
      fi
    fi
  fi

  echo "WARN: Could not auto-detect an iPhone simulator. Set --destination explicitly." >&2
  echo "      Example: --destination \"platform=iOS Simulator,OS=26.2,name=iPhone 17\"" >&2
  DESTINATION="platform=iOS Simulator,name=iPhone"
}

pick_scheme_if_empty() {
  if [[ -n "${SCHEME}" ]]; then
    return 0
  fi

  local container_type="$1"
  local container_path="$2"
  local json
  if [[ "${container_type}" == "workspace" ]]; then
    json="$(xcodebuild -list -json -workspace "${container_path}")"
  else
    json="$(xcodebuild -list -json -project "${container_path}")"
  fi

  SCHEME="$(
    printf '%s' "${json}" | python3 -c 'import json,sys; data=json.load(sys.stdin); root=(data.get("workspace") or data.get("project") or {}); schemes=(root.get("schemes") or []); print(schemes[0] if schemes else "")'
  )"

  if [[ -z "${SCHEME}" ]]; then
    echo "ERROR: No schemes found. In Xcode: Product -> Scheme -> Manage Schemes -> ensure at least one scheme is Shared." >&2
    exit 1
  fi
}

main() {
  local container
  container="$(detect_container)"
  local container_type="${container%%:*}"
  local container_path="${container#*:}"

  pick_destination_if_empty
  pick_scheme_if_empty "${container_type}" "${container_path}"

  # Now that scheme is known, finalize COMMON_ARGS
  COMMON_ARGS=(
    -scheme "${SCHEME}"
    -destination "${DESTINATION}"
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=""
  )

  local container_args=()
  if [[ "${container_type}" == "workspace" ]]; then
    container_args=(-workspace "${container_path}")
  else
    container_args=(-project "${container_path}")
  fi

  case "${ACTION}" in
    list)
      xcodebuild -list "${container_args[@]}"
      ;;
    resolve)
      xcodebuild -resolvePackageDependencies "${container_args[@]}" -scheme "${SCHEME}"
      ;;
    build)
      xcodebuild build "${container_args[@]}" "${COMMON_ARGS[@]}"
      ;;
    test)
      xcodebuild test "${container_args[@]}" "${COMMON_ARGS[@]}"
      ;;
    all)
      xcodebuild -resolvePackageDependencies "${container_args[@]}" -scheme "${SCHEME}"
      xcodebuild build "${container_args[@]}" "${COMMON_ARGS[@]}"
      xcodebuild test "${container_args[@]}" "${COMMON_ARGS[@]}"
      ;;
    *)
      echo "Unknown action: ${ACTION}" >&2
      usage
      exit 2
      ;;
  esac
}

main
