# zsh-curl-edit

Automatically open pasted cURL commands in an editor before executing them.

Designed for Zsh and Oh My Zsh, especially when copying **Copy as cURL (bash)** requests from Chrome DevTools.

## Features

- Detects pasted cURL commands at an empty prompt
- Opens requests in VS Code by default
- Returns edited commands to the terminal prompt
- Never executes a request automatically
- Restores the original command if the editor fails
- Uses temporary files with restricted permissions

## Requirements

- macOS or another environment with Zsh and bracketed-paste support
- [Oh My Zsh](https://ohmyz.sh/)
- [Visual Studio Code](https://code.visualstudio.com/) with the `code` CLI available in `PATH`

## Installation

### 1. Clone the repository

```zsh
git clone https://github.com/YOUR_USERNAME/zsh-curl-edit.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-curl-edit"
```

Replace `YOUR_USERNAME` with your GitHub username.

### 2. Enable the plugin

Open your Zsh configuration:

```zsh
code ~/.zshrc
```

Add `zsh-curl-edit` to your existing `plugins` array. For example:

```zsh
plugins=(
  git
  zsh-curl-edit
)
```

Keep your other existing plugins.

### 3. Reload Zsh

```zsh
source ~/.zshrc
```

The plugin entry point is:

```text
zsh-curl-edit.plugin.zsh
```

It must be located inside the `zsh-curl-edit` plugin directory.

## Usage

1. Open Chrome DevTools → Network.
2. Right-click a request and select **Copy → Copy as cURL (bash)**.
3. In an empty terminal prompt, paste the command.
4. Edit the request in VS Code.
5. Close the file to return to the terminal.
6. Review the edited command and press Enter when ready.

The plugin does not automatically execute the request.

## Configuration

VS Code is the default editor. Set `CURL_EDIT_EDITOR` before loading the plugin to select another supported editor:

```zsh
export CURL_EDIT_EDITOR=vim
```

For VS Code, ensure the `code` CLI is available in your `PATH`.

## Security

Copied requests may contain session cookies, bearer tokens, authorization headers, or other credentials.

- Review requests before executing or sharing them.
- Never commit real credentials or copied authenticated requests.
- Temporary files are deleted after the command is read back, but may remain if the shell or editor terminates unexpectedly.
- The plugin does not execute requests automatically, but the command you eventually run can still modify remote systems.

## Development

Check the plugin's Zsh syntax:

```zsh
zsh -n zsh-curl-edit.plugin.zsh
```

After editing the plugin, open a new terminal session or reload your configuration:

```zsh
source ~/.zshrc
```

## License

MIT. See [LICENSE](LICENSE).
