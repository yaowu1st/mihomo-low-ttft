#!/usr/bin/env bash
# Back up existing Clash Verge Rev global configs and deploy Universal Low-TTFT Mihomo configs (macOS & Linux)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_SRC="${REPO_ROOT}/config"
CONFIG_DIR="${1:-}"

if [[ -z "${CONFIG_DIR}" ]]; then
  CANDIDATES=(
    "${HOME}/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
    "${XDG_DATA_HOME:-${HOME}/.local/share}/io.github.clash-verge-rev.clash-verge-rev"
    "${HOME}/.config/clash-verge"
  )
  for c in "${CANDIDATES[@]}"; do
    if [[ -d "${c}" ]]; then
      CONFIG_DIR="${c}"
      break
    fi
  done
fi

if [[ -z "${CONFIG_DIR}" || ! -d "${CONFIG_DIR}" ]]; then
  echo "[ERROR] Clash Verge Rev config directory not found. Usage: $0 [/path/to/config_dir]" >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${CONFIG_DIR}/clash-verge-rev-backup/low-ttft-backup-${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}" "${CONFIG_DIR}/profiles"

for item in "profiles/Merge.yaml:Merge.yaml" "profiles/Script.js:Script.js" "dns_config.yaml:dns_config.yaml"; do
  rel_dst="${item%%:*}"
  base_name="${item##*:}"
  if [[ -f "${CONFIG_DIR}/${rel_dst}" ]]; then
    cp -f "${CONFIG_DIR}/${rel_dst}" "${BACKUP_DIR}/${base_name}"
  fi
  cp -f "${CONFIG_SRC}/${base_name}" "${CONFIG_DIR}/${rel_dst}"
done

echo "[OK] Backed up previous configs to: ${BACKUP_DIR}"
echo "[OK] Deployed Merge.yaml, Script.js, and dns_config.yaml to: ${CONFIG_DIR}"

MIHOMO_BIN=""
for bin in \
  "/Applications/Clash Verge.app/Contents/MacOS/verge-mihomo" \
  "$(command -v verge-mihomo 2>/dev/null || true)" \
  "$(command -v mihomo 2>/dev/null || true)"; do
  if [[ -n "${bin}" && -x "${bin}" ]]; then
    MIHOMO_BIN="${bin}"
    break
  fi
done

if [[ -n "${MIHOMO_BIN}" ]]; then
  TMP_TEST="${CONFIG_DIR}/low-ttft-validate-tmp.yaml"
  trap 'rm -f "${TMP_TEST}"' EXIT
  {
    cat "${CONFIG_SRC}/Merge.yaml"
    echo ""
    cat "${CONFIG_SRC}/dns_config.yaml"
    printf "\nproxies: []\nrules:\n  - MATCH,DIRECT\n"
  } > "${TMP_TEST}"
  "${MIHOMO_BIN}" -t -d "${CONFIG_DIR}" -f "${TMP_TEST}"
  echo "[OK] Kernel validation passed! Reload your active profile in Clash Verge Rev to apply."
else
  echo "[INFO] mihomo binary not found in standard paths; skipped CLI check. Reload profile in GUI to apply."
fi
