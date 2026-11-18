#!/usr/bin/env bash
# Restore Clash Verge Rev global configs from the latest (or specified) low-ttft backup (macOS & Linux)

set -euo pipefail

CONFIG_DIR="${1:-}"
BACKUP_FOLDER="${2:-}"

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

BACKUP_ROOT="${CONFIG_DIR}/clash-verge-rev-backup"
if [[ -z "${BACKUP_FOLDER}" ]]; then
  BACKUP_FOLDER="$(ls -1dt "${BACKUP_ROOT}"/low-ttft-backup-* 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${BACKUP_FOLDER}" || ! -d "${BACKUP_FOLDER}" ]]; then
  echo "[ERROR] No low-ttft backup found under: ${BACKUP_ROOT}" >&2
  exit 1
fi

[[ -f "${BACKUP_FOLDER}/Merge.yaml" ]]      && cp -f "${BACKUP_FOLDER}/Merge.yaml" "${CONFIG_DIR}/profiles/Merge.yaml"
[[ -f "${BACKUP_FOLDER}/Script.js" ]]       && cp -f "${BACKUP_FOLDER}/Script.js" "${CONFIG_DIR}/profiles/Script.js"
[[ -f "${BACKUP_FOLDER}/dns_config.yaml" ]] && cp -f "${BACKUP_FOLDER}/dns_config.yaml" "${CONFIG_DIR}/dns_config.yaml"

echo "[OK] Restored from backup: ${BACKUP_FOLDER} . Reload your active profile in Clash Verge Rev."
