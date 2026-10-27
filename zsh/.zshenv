# Retire the Node path inherited by apps opened before the security update.
# Keep this file silent and free of external commands: every zsh reads it.
() {
  local retired_bin="$HOME/.nvm/versions/node/v24.20.0/bin"
  local patched_bin="$HOME/.nvm/versions/node/v24.22.1/bin"
  [[ -x "$patched_bin/node" ]] || return 0

  local path_index replaced=0
  for (( path_index=1; path_index<=${#path}; path_index++ )); do
    if [[ "${path[$path_index]}" == "$retired_bin" ]]; then
      path[$path_index]="$patched_bin"
      replaced=1
    fi
  done
  if (( replaced )); then
    export PATH
    [[ "${NVM_BIN:-}" == "$retired_bin" ]] && export NVM_BIN="$patched_bin"
    [[ "${NVM_INC:-}" == "${retired_bin%/bin}/include/node" ]] && export NVM_INC="${patched_bin%/bin}/include/node"
  fi
  return 0
}
