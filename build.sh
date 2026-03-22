#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_ROOT="${ROOT_DIR}/dist"
ADDON_NAME="TuskUpLoot"
OUT_DIR="${OUT_ROOT}/${ADDON_NAME}"

required_files=(
  "${ROOT_DIR}/TuskUpLoot.toc"
  "${ROOT_DIR}/TuskUpLoot.lua"
)

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

for f in "${required_files[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "Missing required file: ${f}" >&2
    exit 1
  fi
done

cp -f "${ROOT_DIR}/TuskUpLoot.toc" "${OUT_DIR}/"

lua_files=(
  "${ROOT_DIR}"/TuskUpLoot*.lua
)
shopt -s nullglob
for f in "${lua_files[@]}"; do
  if [[ -f "${f}" ]]; then
    cp -f "${f}" "${OUT_DIR}/"
  fi
done
shopt -u nullglob

shopt -s nullglob
extra_files=(
  "${ROOT_DIR}"/README*
  "${ROOT_DIR}"/LICENSE*
  "${ROOT_DIR}"/CHANGELOG*
)
shopt -u nullglob

for f in "${extra_files[@]}"; do
  if [[ -f "${f}" ]]; then
    cp -f "${f}" "${OUT_DIR}/"
  fi
done

rm -f "${OUT_ROOT}/${ADDON_NAME}.zip"
(
  cd "${OUT_ROOT}"
  zip -r "${ADDON_NAME}.zip" "${ADDON_NAME}" >/dev/null
)

echo "Built folder: ${OUT_DIR}"
echo "Built archive: ${OUT_ROOT}/${ADDON_NAME}.zip"

