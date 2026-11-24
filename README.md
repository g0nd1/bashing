# Flyline · Bash Setup

A lightweight installer for [Flyline](https://github.com/HalFrgrd/flyline), custom Bash integrations and an OpenAI-compatible AI backend on Linux.

![Platform](https://img.shields.io/badge/platform-Linux-blue) ![Shell](https://img.shields.io/badge/installer-POSIX%20sh-4EAA25) ![API](https://img.shields.io/badge/API-OpenAI--compatible-412991)

## Features

- Builds Flyline from source using Cargo and installs it as a Bash loadable builtin.
- Installs custom shell integrations and helper scripts (`flyline-git-branch`, `flyline-openai`).
- Extends the existing Bash configuration without replacing `.bashrc`.
- Connects to an OpenAI-compatible API and retrieves available model IDs automatically.
- Provides interactive model selection with a manual fallback.
- Stores AI credentials locally with restricted file permissions.
- Runs without root privileges and avoids duplicate Bash configuration entries on repeated installations.

## Quick start

Run the following command in a terminal as your regular user:

```sh
curl -fsSL https://raw.githubusercontent.com/g0nd1/bashing/main/script.sh | sh
```

Alternatively, download and inspect the installer before executing it:

```sh
curl -fsSL https://raw.githubusercontent.com/g0nd1/bashing/main/script.sh -o script.sh
less script.sh
sh script.sh
```

Once installation is complete, open a new Bash session or reload your configuration:

```bash
source ~/.bashrc
```

> [!IMPORTANT]
> The installer is interactive and requires a terminal (`/dev/tty`). Do not run it with `sudo`. Only execute installation scripts from sources you trust.

## Requirements

- Linux with Bash and a terminal
- Cargo and a Rust toolchain
- Git, curl and jq
- A C compiler and any additional build dependencies required by upstream Flyline
- Network access to GitHub and your AI API endpoint

If Cargo is missing, the installer detects your Linux distribution and suggests an appropriate installation command. It does not install system packages automatically.

| Distribution | Install dependencies |
| --- | --- |
| Fedora / RHEL-compatible | `sudo dnf install cargo rust gcc git curl jq bash` |
| Debian / Ubuntu | `sudo apt install cargo rustc build-essential git curl jq bash` |
| Arch Linux / Manjaro | `sudo pacman -S --needed rust base-devel git curl jq bash` |
| openSUSE | `sudo zypper install cargo rust gcc git curl jq bash` |
| Alpine Linux | `sudo apk add cargo rust build-base git curl jq bash` |

For other distributions, see [rustup.rs](https://rustup.rs/) and install the remaining dependencies through your package manager. Depending on your distribution, additional development packages or a newer Rust toolchain may be necessary.

## AI configuration

The installer prompts for the API base URL and API key, then requests the model list from the provider using `GET <base-url>/models` with Bearer authentication.

```text
FLYLINE_AI_BASE_URL: https://api.example.org/v1
FLYLINE_AI_API_KEY:

Verfügbare KI-Modelle:

  1) model-alpha
  2) model-beta
  3) model-gamma

  0) Modell manuell eingeben

Modell auswählen [0-3]: 2
Ausgewähltes Modell: model-beta
```

The API key is not displayed while typing. The model IDs above are illustrative; the actual list depends on your provider and credentials. If the endpoint is unavailable or does not return models, you can enter a model ID manually.

### Environment variables

| Variable | Description | Example |
| --- | --- | --- |
| `FLYLINE_AI_BASE_URL` | OpenAI-compatible API base URL, including any required version prefix | `https://api.example.org/v1` |
| `FLYLINE_AI_API_KEY` | API authentication token | Provider-issued key |
| `FLYLINE_AI_MODEL` | Selected model ID | `model-beta` |

The configuration is saved in `~/.config/flyline-ai.env` as shell-compatible exports, with permissions set to `600`.

> [!NOTE]
> The base URL must not include `/models` or `/chat/completions`. The model listing endpoint may also return embedding or other non-chat models. Select a model compatible with the AI helper's intended use.

To change the configuration, rerun the installer and confirm that you want to replace the existing configuration, or edit the environment file locally. Reload Bash afterwards. Never commit this file or share its contents with others.

## Installed files

```text
~/.bashrc                       # Existing file, extended with a source block
~/.bashrc-extend                # Custom Bash configuration
~/.config/
└── flyline-ai.env              # AI configuration (0600)
~/.local/
├── bin/
│   ├── flyline-git-branch       # Executable helper
│   └── flyline-openai           # Executable helper
└── lib/bash/
    └── libflyline.so            # Flyline loadable builtin
```

The installer adds the following block to `.bashrc` only if its start marker is not already present:

```bash
# BEGIN FLYLINE EXTENSION
if [ -f "$HOME/.bashrc-extend" ]; then
    . "$HOME/.bashrc-extend"
fi
# END FLYLINE EXTENSION
```

The supplied `.bashrc-extend` is responsible for loading Flyline, sourcing the AI configuration and making the helper scripts available to Bash.

## Repository structure

```text
.
├── README.md
├── script.sh
├── .bashrc-extend
├── flyline-git-branch
└── flyline-openai
```

| File | Purpose |
| --- | --- |
| `script.sh` | Interactive installation and AI configuration |
| `.bashrc-extend` | Additional Bash configuration |
| `flyline-git-branch` | Git branch integration |
| `flyline-openai` | AI integration using an OpenAI-compatible backend |

## Updating

Rerun the installation command to rebuild Flyline and reinstall the integrations. The existing AI configuration can be retained when prompted.

> [!WARNING]
> The installer replaces the installed `.bashrc-extend`, helper scripts and Flyline library. Back up any local modifications before updating. Flyline is built from the upstream repository's current default branch rather than a pinned release.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Cargo is not found | Install Rust/Cargo and ensure `~/.cargo/bin` is accessible. |
| Build fails | Check the compiler, Rust version and upstream build requirements. |
| Model list cannot be loaded | Verify the base URL, API key and availability of the `/models` endpoint. |
| Flyline is unavailable | Open a new Bash session and check whether `.bashrc-extend` loads the builtin. |
| Helper scripts cannot be found | Ensure `~/.local/bin` is included in `PATH`. |

Check whether Flyline has been loaded into Bash:

```bash
type flyline
```

## Uninstallation

Remove the marked Flyline extension block from `~/.bashrc` using a text editor. Then remove the installed files you no longer need:

```bash
rm -f ~/.bashrc-extend \
      ~/.local/bin/flyline-git-branch \
      ~/.local/bin/flyline-openai \
      ~/.local/lib/bash/libflyline.so
```

Only remove `.bashrc-extend` if it does not contain other configuration you wish to keep. To delete the stored AI credentials as well:

```bash
rm -f ~/.config/flyline-ai.env
```

Open a new Bash session to finish the removal. Cargo and other system dependencies are left untouched.

## Upstream project

This repository provides a setup and integration layer for **[HalFrgrd/flyline](https://github.com/HalFrgrd/flyline)**. Flyline itself is developed and maintained upstream; its own licensing terms apply.
