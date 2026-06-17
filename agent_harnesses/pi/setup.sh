#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${ROOT}/agent"
DST="${HOME}/.pi/agent"

mkdir -p "${DST}/bin"

link() {
  local rel="$1"
  local src="${SRC}/${rel}"
  local dst="${DST}/${rel}"

  [ -e "${src}" ] || return 0
  mkdir -p "$(dirname "${dst}")"

  if [ -e "${dst}" ] && [ ! -L "${dst}" ]; then
    echo "Refusing to replace non-symlink: ${dst}" >&2
    exit 1
  fi

  rm -f "${dst}"
  ln -s "${src}" "${dst}"
  echo "Linked ${rel}"
}

for rel in \
  settings.json \
  models.json \
  keybindings.json \
  prompts \
  extensions \
  skills \
  themes \
  extensions-disabled
  do
  link "${rel}"
done

if [ -d "${SRC}/bin" ]; then
  for path in "${SRC}/bin"/*; do
    [ -e "${path}" ] || continue
    link "bin/$(basename "${path}")"
  done
fi

echo "Pi dotfiles linked from ${SRC}"
