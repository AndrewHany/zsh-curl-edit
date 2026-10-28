#!/usr/bin/env zsh
# Behavioral tests for zsh-curl-edit. Drives a real interactive zsh inside a
# pty (via script(1)) and types a bracketed paste into it.
#
# Usage: zsh tests/run.zsh

emulate -L zsh

local root=${0:A:h:h}
local tmp
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zsh-curl-edit-test.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT

(( $+commands[script] )) || { print -u2 "script(1) is required"; exit 2 }

# Editor stubs. Used as absolute paths, which also covers that code path.
print -r -- '#!/bin/sh
for f; do :; done   # file is the last argument
printf " -H x" >> "$f"' > $tmp/ed-append
print -r -- '#!/bin/sh
exit 1' > $tmp/ed-fail
print -r -- '#!/bin/sh
echo called > "$EDITOR_MARKER"' > $tmp/ed-marker
chmod +x $tmp/ed-*

local pass=0 fail=0

# Run an interactive zsh under a pty, feeding it stdin from a function.
# BSD script: script -q file cmd...   util-linux script: script -qc "cmd" file
pty_run() {
  local input_fn=$1
  if [[ $OSTYPE == darwin* ]]; then
    $input_fn | script -q /dev/null env TERM=xterm zsh -f -i >/dev/null 2>&1
  else
    $input_fn | script -qc "env TERM=xterm zsh -f -i" /dev/null >/dev/null 2>&1
  fi
}

# run_case <name> <editor> <typed-prefix> <paste> <expected-buffer> [<extra-rc>]
run_case() {
  local name=$1 editor=$2 prefix=$3 paste=$4 expected=$5 extra_rc=${6:-}
  rm -f $tmp/buf $tmp/marker $tmp/hook $tmp/zsh-curl-edit.*(N)

  cat > $tmp/rc <<EOF
PS1='> '
export EDITOR_MARKER='$tmp/marker' TMPDIR='$tmp'
export CURL_EDIT_EDITOR='$editor'
$extra_rc
source '$root/zsh-curl-edit.plugin.zsh'
_dump() { print -rn -- "\$BUFFER" > '$tmp/buf' }
zle -N _dump
bindkey '^X^D' _dump
EOF

  typed() {
    sleep 2
    print -r -- "source '$tmp/rc'"
    sleep 2
    [[ -n $prefix ]] && { print -rn -- "$prefix"; sleep 0.3 }
    print -rn -- $'\e[200~'"$paste"$'\e[201~'
    sleep 3
    print -rn -- $'\x18\x04'   # ^X^D: dump BUFFER to a file
    sleep 0.5
    print -rn -- $'\x03'; print -r -- 'exit'
    sleep 0.3
  }
  pty_run typed

  local actual="<no output>"
  [[ -e $tmp/buf ]] && actual=$(<$tmp/buf)
  local leftovers=($tmp/zsh-curl-edit.*(N))
  local invoked=0
  [[ $editor == $tmp/ed-marker && -e $tmp/marker ]] && invoked=1

  if [[ $actual == "$expected" && ${#leftovers} -eq 0 && $invoked -eq 0 ]]; then
    print "PASS  $name"; (( pass++ ))
  else
    print "FAIL  $name"
    print "      expected: ${(q+)expected}"
    print "      actual:   ${(q+)actual}"
    (( ${#leftovers} )) && print "      leftover temp files: $leftovers"
    (( invoked )) && print "      editor ran but should not have"
    (( fail++ ))
  fi
}

run_case "curl paste is edited and returned to prompt" \
  $tmp/ed-append "" "curl https://example.com" "curl https://example.com -H x"

run_case "multiline curl paste is edited" \
  $tmp/ed-append "" $'curl https://example.com \\\n  -H a:b' $'curl https://example.com \\\n  -H a:b -H x'

run_case "editor failure restores original paste" \
  $tmp/ed-fail "" "curl https://example.com" "curl https://example.com"

run_case "missing editor restores original paste" \
  /nonexistent/editor "" "curl https://example.com" "curl https://example.com"

run_case "editor with arguments is supported" \
  "$tmp/ed-append --ignored" "" "curl https://example.com" "curl https://example.com -H x"

run_case "non-curl paste is left alone" \
  $tmp/ed-marker "" "echo hello" "echo hello"

run_case "word starting with curl is not matched" \
  $tmp/ed-marker "" "curling is fun" "curling is fun"

run_case "paste into non-empty prompt is left alone" \
  $tmp/ed-marker "echo " "curl https://example.com" "echo curl https://example.com"

# A pre-existing bracketed-paste widget (like Oh My Zsh's bracketed-paste-magic)
# must still run, and sourcing the plugin twice must not recurse.
run_case "chains to a pre-existing bracketed-paste widget" \
  $tmp/ed-append "" "curl https://example.com" "curl https://example.com -H x" \
  "_prev_paste() { print -r -- ran > '$tmp/hook'; zle .bracketed-paste }
zle -N bracketed-paste _prev_paste"
[[ -e $tmp/hook ]] || { print "FAIL  pre-existing widget was not called"; (( fail++ )) }

run_case "re-sourcing the plugin does not recurse" \
  $tmp/ed-append "" "curl https://example.com" "curl https://example.com -H x" \
  "source '$root/zsh-curl-edit.plugin.zsh'"

print "\n$pass passed, $fail failed"
(( fail == 0 ))
