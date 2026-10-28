
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

  # Preserve normal paste behavior, including terminal escape handling.
  zle .bracketed-paste || return

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

  if (( $+commands[code] )) && [[ "$CURL_EDIT_EDITOR" == code ]]; then
    code --wait "$file"
    editor_status=$?
  elif [[ "$CURL_EDIT_EDITOR" != code ]] &&
       (( $+commands[${CURL_EDIT_EDITOR%% *}] )); then
    # Supports simple editor commands such as "vim".
    # VS Code should use the default "code" setting above.
    ${=CURL_EDIT_EDITOR} "$file"
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

# Register the widget, replacing the default bracketed-paste widget.
zle -N bracketed-paste _curl_edit_bracketed_paste
