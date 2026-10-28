# zsh-curl-edit
# Intercept pasted cURL commands and open them in an editor.
# Pasted commands are returned to the prompt, never executed automatically.

: "${CURL_EDIT_EDITOR:=code}"

_curl_edit_bracketed_paste() {
  local original_buffer="$BUFFER"
  local pasted
  local file
  local edited
  local editor_status
  local -a editor_cmd

  # Preserve normal paste behavior, including any widget that was already
  # bound (e.g. Oh My Zsh's bracketed-paste-magic).
  zle _curl_edit_orig_bracketed_paste || return

  # Only inspect pastes into an empty command line.
  [[ -z "$original_buffer" ]] || return

  pasted="$BUFFER"

  # Detect a cURL command, including multiline DevTools output.
  [[ "$pasted" =~ '^[[:space:]]*curl([[:space:]]|$)' ]] || return

  file=$(mktemp "${TMPDIR:-/tmp}/zsh-curl-edit.XXXXXX") || {
    zle -M "zsh-curl-edit: could not create temporary file"
    return
  }

  chmod 600 "$file"
  print -rn -- "$pasted" > "$file"

  # Clear the pasted text while the editor is open.
  BUFFER=""
  CURSOR=0
  zle -I

  # "code" needs --wait so the widget blocks until the file is closed.
  if [[ "$CURL_EDIT_EDITOR" == code ]]; then
    editor_cmd=(code --reuse-window --wait)
  else
    editor_cmd=(${=CURL_EDIT_EDITOR})
  fi

  # whence -p resolves both bare command names and absolute paths.
  if (( $#editor_cmd )) && whence -p -- "${editor_cmd[1]}" >/dev/null; then
    "${editor_cmd[@]}" "$file"
    editor_status=$?
  else
    editor_status=127
  fi

  if (( editor_status == 0 )) && [[ -f "$file" ]]; then
    edited=$(<"$file")
    BUFFER="$edited"
    CURSOR=${#BUFFER}
  else
    # Restore the original paste if the editor failed.
    BUFFER="$pasted"
    CURSOR=${#BUFFER}
    zle -M "zsh-curl-edit: editor failed; original command restored"
  fi

  rm -f "$file"
  zle redisplay
}

# Keep a handle on the current bracketed-paste widget so we can chain to it.
# The guard makes re-sourcing the plugin safe (no self-aliasing / recursion).
if [[ "${widgets[bracketed-paste]}" != user:_curl_edit_bracketed_paste ]]; then
  zle -A bracketed-paste _curl_edit_orig_bracketed_paste
fi

zle -N bracketed-paste _curl_edit_bracketed_paste
