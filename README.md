# zsh-curl-edit

[![CI](https://github.com/AndrewHany/zsh-curl-edit/actions/workflows/ci.yml/badge.svg)](https://github.com/AndrewHany/zsh-curl-edit/actions/workflows/ci.yml)

Automatically open pasted cURL commands in an editor before executing them.

Designed for Zsh and Oh My Zsh, especially for requests copied with **Copy as cURL (bash)** from Chrome DevTools. Those commands are long, multiline, and full of headers you usually want to trim or tweak before running them.

## Features

- Detects pasted cURL commands at an empty prompt
- Opens requests in VS Code by default, or in any editor you choose
- Returns the edited command to the prompt so you can review it
- Never executes a request automatically
- Restores the original command if the editor fails or is missing
- Chains to any existing `bracketed-paste` widget (such as Oh My Zsh's `bracketed-paste-magic`)
- Uses temporary files with restricted permissions (`0600`) that are removed afterwards

## How it works

The plugin replaces Zsh's `bracketed-paste` widget. When you paste:

1. The paste is handled normally (by the widget that was previously bound).
2. If the prompt was **empty** and the pasted text **starts with `curl`** (leading whitespace allowed), the text is written to a temporary file and the prompt is cleared.
3. Your editor opens that file and the shell waits until you close it.
4. If the editor exits successfully, the file's contents are placed on the prompt. Nothing is run; you press Enter yourself.
5. If the editor fails (non-zero exit, not installed), the original pasted command is put back on the prompt and a message is shown.

Anything else is left alone: pastes into a non-empty prompt, text that doesn't start with `curl` (e.g. `curling`, `sudo curl ...`), and normal typing.

## Requirements

- Zsh 5.1+ with bracketed-paste support (macOS, Linux). Your terminal must support bracketed paste, which all common terminals do.
- An editor that can block until the file is closed. The default is [Visual Studio Code](https://code.visualstudio.com/) with the `code` CLI in your `PATH`. See [Using your own editor](#using-your-own-editor).
- [Oh My Zsh](https://ohmyz.sh/) is recommended but not required; see [Without Oh My Zsh](#without-oh-my-zsh).

## Installation

### Oh My Zsh

#### 1. Clone the repository

```zsh
git clone https://github.com/AndrewHany/zsh-curl-edit.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-curl-edit"
```

#### 2. Enable the plugin

Open your Zsh configuration:

```zsh
code ~/.zshrc
```

Add `zsh-curl-edit` to your existing `plugins` array and keep your other plugins:

```zsh
plugins=(
  git
  zsh-curl-edit
)
```

#### 3. Reload Zsh

```zsh
source ~/.zshrc
```

The plugin entry point is `zsh-curl-edit.plugin.zsh`, and it must live inside a directory named `zsh-curl-edit` for Oh My Zsh to find it.

### Without Oh My Zsh

Clone the repository anywhere and source the entry point from `~/.zshrc`:

```zsh
git clone https://github.com/AndrewHany/zsh-curl-edit.git ~/.zsh/zsh-curl-edit
echo 'source ~/.zsh/zsh-curl-edit/zsh-curl-edit.plugin.zsh' >> ~/.zshrc
```

Plugin managers that support the `*.plugin.zsh` convention (zinit, antigen, sheldon, zplug, ...) can load `AndrewHany/zsh-curl-edit` directly.

### Uninstall

Remove `zsh-curl-edit` from your `plugins` array (or the `source` line), delete the cloned directory, and open a new shell.

## Usage

1. Open Chrome DevTools → Network.
2. Right-click a request and select **Copy → Copy as cURL (bash)**.
3. In an empty terminal prompt, paste the command.
4. Edit the request in your editor.
5. Save and close the file to return to the terminal.
6. Review the edited command and press Enter when ready.

If you want a paste to go straight to the prompt without opening the editor, type a space first. The plugin only acts on an empty prompt.

Closing the editor with an empty file leaves an empty prompt. Trailing newlines in the file are stripped.

## Configuration

| Variable            | Default | Description                                                    |
| ------------------- | ------- | -------------------------------------------------------------- |
| `CURL_EDIT_EDITOR`  | `code`  | Editor command used to edit the pasted request. See below.     |
| `TMPDIR`            | `/tmp`  | Directory used for the temporary file (standard system variable). |

Set variables in `~/.zshrc`. `CURL_EDIT_EDITOR` is read each time you paste, so changing it takes effect immediately in the current shell.

## Using your own editor

VS Code is the default. When `CURL_EDIT_EDITOR` is `code`, the plugin runs `code --reuse-window --wait <file>` for you. To use something else, set `CURL_EDIT_EDITOR` in `~/.zshrc`:

```zsh
export CURL_EDIT_EDITOR=nvim
```

The value can be:

- a command name found in `PATH` (`vim`)
- an absolute path (`/opt/homebrew/bin/nvim`)
- a command with arguments (`"nvim -n"`, `"subl --wait"`)

The plugin runs `<your command> <temp file>`, i.e. the file path is appended as the **last argument**.

### Examples

```zsh
export CURL_EDIT_EDITOR=vim                  # terminal editors work as-is
export CURL_EDIT_EDITOR=nvim
export CURL_EDIT_EDITOR=nano
export CURL_EDIT_EDITOR="emacs -nw"
export CURL_EDIT_EDITOR="code-insiders --wait"
export CURL_EDIT_EDITOR="cursor --wait"
export CURL_EDIT_EDITOR="subl --wait"
export CURL_EDIT_EDITOR="zed --wait"
```

### Requirements for a custom editor

1. **It must block until you are done.** Terminal editors do this naturally. GUI editors usually launch and return immediately unless you pass their "wait" flag (`--wait`, `-w`, ...). An editor that returns immediately makes the plugin read the file back unedited, so you'd get your original command back.
2. **It must exit with status 0 on success.** A non-zero exit is treated as failure and the original command is restored.
3. **It must edit the file in place** (the path given as the last argument).

Arguments are split on whitespace, so shell quoting is not supported. If your editor path contains spaces, or you need quoting, use a small wrapper script instead.

### Using a wrapper script

A script gives you full control (quoting, extra flags, custom behavior). For example `~/bin/curl-editor`:

```zsh
#!/bin/sh
# $1 is the temporary file containing the pasted curl command.
exec code --wait --new-window "$1"
```

```zsh
chmod +x ~/bin/curl-editor
export CURL_EDIT_EDITOR=$HOME/bin/curl-editor
```

The temporary file has no extension. If your editor doesn't pick a syntax automatically, set the language manually (for example, VS Code: **Change Language Mode → Shell Script**).

## Compatibility with other plugins

The plugin saves whichever `bracketed-paste` widget is active when it loads and calls it for every paste, so Oh My Zsh's `bracketed-paste-magic` and similar keep working. Load `zsh-curl-edit` **after** other plugins that replace `bracketed-paste` so those plugins are the ones it chains to. Re-sourcing the plugin is safe.

## Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| `zsh-curl-edit: editor failed; original command restored` | The editor isn't installed or isn't in `PATH`, or it exited non-zero. Check `command -v <editor>`. |
| `code: command not found` | In VS Code run **Shell Command: Install 'code' command in PATH**, or set `CURL_EDIT_EDITOR` to another editor. |
| The editor opens but my edits are ignored | The editor returned before you finished. Use its wait flag (e.g. `--wait`). |
| Nothing happens when I paste | The prompt wasn't empty, the text doesn't start with `curl`, or your terminal doesn't support bracketed paste. |
| Paste behavior changed after enabling another plugin | Check plugin order; this plugin should load after others that bind `bracketed-paste`. |

## Security

Copied requests may contain session cookies, bearer tokens, authorization headers, or other credentials.

- Review requests before executing or sharing them.
- Never commit real credentials or copied authenticated requests.
- The temporary file is created with mode `0600` and deleted once the command has been read back. It may remain in `TMPDIR` if the shell or editor is killed unexpectedly, so remove any stray `zsh-curl-edit.*` files from your temp directory.
- Your editor may keep its own recent-files history, backups, or swap files that contain the request.
- The plugin does not execute requests automatically, but the command you eventually run can still modify remote systems.

## Development

Check the plugin's Zsh syntax:

```zsh
zsh -n zsh-curl-edit.plugin.zsh
```

Run the behavioral tests. They drive a real interactive Zsh in a pty, so they need `script(1)` and take about a minute:

```zsh
zsh tests/run.zsh
```

The tests cover edited and multiline pastes, editor failure and a missing editor, editors given as absolute paths or with arguments, non-curl pastes, pastes into a non-empty prompt, chaining to an existing `bracketed-paste` widget, and re-sourcing.

After editing the plugin, open a new terminal session or reload your configuration:

```zsh
source ~/.zshrc
```

## Contributing

Issues and pull requests are welcome. Please run `zsh tests/run.zsh` before submitting and add a test for behavior changes.

## License

MIT. See [LICENSE](LICENSE).
