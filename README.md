# gdiff

> **An ultra-lightweight, 100% local, and free CLI tool to generate perfect, AI-assisted conventional commit messages using any LLM.**

---

[![Windows: PowerShell / Git Bash](https://img.shields.io/badge/Windows-PowerShell%20%2F%20Git%20Bash-0078D6.svg?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA4OCA4OCIgZmlsbD0iI2ZmZmZmZiI+PHBhdGggZD0iTTAgMTIuNDAybDM1LjY4Ny00Ljg3LjAxNiAzNC40MjMtMzUuNjcuMjAyem0zNS42NyAzMy41MjlsLjAyOCAzNC40NTNMLjAyOCA3NS40OC4wMjYgNDUuN3pNMzkuOTggNi44NzdMODcuMzE0IDB2NDEuNTI3bC00Ny4zMzQuMzc2em00Ny4zMzQgMzkuNDE2bC0uMDE0IDQxLjMxLTQ3LjMzNC02LjY3OC0uMDY2LTM0Ljd6Ii8+PC9zdmc+Cg==)](#windows-installation)
[![Debian: APT](https://img.shields.io/badge/Debian-APT-A81D33.svg?logo=debian&logoColor=white)](#debian)
[![Fedora: COPR](https://img.shields.io/badge/Fedora-COPR-51A2DA.svg?logo=fedora&logoColor=white)](#fedora)
[![Arch Linux: AUR](https://img.shields.io/badge/Arch_Linux-AUR-1793D1.svg?logo=archlinux&logoColor=white)](#arch)
[![Linux: Any Distro](https://img.shields.io/badge/Linux-Any_Distro-FCC624.svg?logo=linux&logoColor=black)](#linux--macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25.svg?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Local: No API Key Required](https://img.shields.io/badge/API--Key-Not%20Required-brightgreen.svg)](#)

Have you ever spent 10 minutes staring at a terminal, trying to figure out what to write in your commit message? `gdiff` is built to solve that exact problem—without the bloated dependencies, paid API keys, or heavy local setups that other commit-helpers force upon you.

---

## The Philosophy Behind gdiff

Most AI commit assistants are overly complicated. They demand:
*   **Heavy environments**: Large `npm` installations and heavy runtime processes.
*   **Paid API Keys**: Subscriptions to proprietary models (which can get expensive).
*   **Opaque and Static Prompts**: Prompts hardcoded behind the scenes that output generic, dry commit descriptions that do not truly capture the essence or tone of your work.

`gdiff` takes a completely different, **human-centric, ultra-lightweight approach**:

1.  **No API Keys & Completely Free**: It doesn't connect directly to any API. It streams your changes + prompt guidelines to your system clipboard, letting you leverage **any free web LLM interface** (like Gemini, ChatGPT, Claude) or your **IDE-integrated AI chat**.
2.  **100% Customizable Prompts**: Your rules live in an open text file. You can easily tweak the guidelines to match your company's rules, conventional commit formatting, or personal style.
3.  **Lightweight & Fast**: Written in a pure, highly-optimized shell script (**Bash**) with an optional native **Fish** version, and zero dependencies other than `git` and a system clipboard command.

---

## Visual Workflow

```text
 ┌──────────────┐      gdiff      ┌──────────────────────┐
 │ Staged Diffs │ ──────────────> │ Diff + Commit Rules  │
 └──────────────┘                 │ Copied to Clipboard  │
                                  └──────────────────────┘
                                             │
                                             ▼  (Paste)
                                  ┌──────────────────────┐
                                  │   Any LLM Chat UI    │
                                  │ (ChatGPT/Gemini/etc) │
                                  └──────────────────────┘
                                             │
                                             ▼  (Generates)
                                  ┌──────────────────────┐
                                  │   Perfect, Compliant │
                                  │    Commit Message!   │
                                  └──────────────────────┘
```

---

## Quick Start

### 1. Installation

You can install `gdiff` via your system's package manager or with the universal installer scripts.

| OS / Distro | Package Manager | Install Command | Update Command |
| :--- | :--- | :--- | :--- |
| <a id="windows-installation"></a>**Windows** (PowerShell / Git Bash) | Universal script | `irm https://raw.githubusercontent.com/0Crazy-0/gdiff/main/windows-setup.ps1 \| iex` <br> or from **Git Bash / MSYS2 / WSL**: `curl -fsSL https://raw.githubusercontent.com/0Crazy-0/gdiff/main/install.sh \| sh` | re-run the same command |
| <a id="debian"></a>**Debian / Ubuntu** | APT | `curl -fsSL https://raw.githubusercontent.com/0Crazy-0/gdiff/main/debian-setup.sh \| sudo bash` | `sudo apt update && sudo apt install gdiff` |
| <a id="fedora"></a>**Fedora** | COPR (DNF) | `sudo dnf copr enable crazy/gdiff && sudo dnf install gdiff` | `sudo dnf upgrade gdiff` |
| <a id="arch"></a>**Arch Linux** | AUR | `yay -S gdiff` <br> `paru -S gdiff` | `yay -S gdiff` <br> `paru -S gdiff` <br> (or simply `yay` / `paru`) |
| <a id="linux--macos"></a>**Linux / macOS** (any distro) | Universal script | `curl -fsSL https://raw.githubusercontent.com/0Crazy-0/gdiff/main/install.sh \| sh` <br> (also works on Windows via **Git Bash / MSYS2** — see [Windows Installation](#windows-installation)) | re-run the same command |

All the package managers above install the **Bash** version of `gdiff`. If you are a **Fish** user, see [Optional: Fish version (manual install)](#optional-fish-version-manual-install).

### Windows Installation (PowerShell / Git Bash)

`gdiff` fully supports Windows through three channels: native **PowerShell**, **Git Bash / MSYS2**, and **WSL**.

#### Windows Native (PowerShell) — Recommended

Open any PowerShell window and run:

```powershell
irm https://raw.githubusercontent.com/0Crazy-0/gdiff/main/windows-setup.ps1 | iex
```

The installer:
* Downloads the PowerShell port (`gdiff.ps1`) into `~\.gdiff` and adds it to your user `PATH`.
* Creates a `gdiff.cmd` shim so you can just type `gdiff` from any terminal — PowerShell, CMD, **Git Bash**, **Warp**, Windows Terminal, etc.
* Uses the native `Set-Clipboard` cmdlet — no extra dependencies, only `git` is required.
* Is **idempotent**: re-running it updates `gdiff` and never touches your custom rules at `%APPDATA%\gdiff\rule.txt`.

#### Git Bash on Windows

If you prefer working from **Git Bash** (bundled with Git for Windows), run the universal installer from a Git Bash terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/0Crazy-0/gdiff/main/install.sh | sh
```

This installs the **Bash** version with `clip.exe` clipboard support (no extra clipboard tools needed). It also works in MSYS2/Cygwin environments.

#### WSL

The recommended way inside WSL depends on the distro you installed:

* **Debian/Ubuntu, Fedora or Arch** → install `gdiff` from its package manager, exactly as on bare metal (see the [installation table](#1-installation) above). This way you get updates via `apt`/`dnf`/`yay` as usual.
* **Any other distro** (or if you prefer not to use a package manager) → use the universal installer:

```bash
curl -fsSL https://raw.githubusercontent.com/0Crazy-0/gdiff/main/install.sh | sh
```

In both cases the Bash version works as-is inside WSL and uses `clip.exe` through WSL interop — no extra clipboard tools needed.

### Optional: Fish Version (Manual Install)

The packages only ship the Bash version. If you prefer to use `gdiff` natively from **Fish**, you can install the Fish version manually. The same commands work on **Arch Linux, Fedora, and Debian/Ubuntu** — since `gdiff` is a pure shell script, there are no distro-specific steps:

```bash
git clone https://github.com/0Crazy-0/gdiff.git
cd gdiff
sudo install -Dm755 fish/gdiff /usr/local/bin/gdiff
sudo install -Dm644 share/rule.txt /usr/share/gdiff/rule.txt
```

> **Note:** This overwrites the packaged `gdiff` binary with the Fish version. The Bash version stays available inside the repository (`bash/gdiff`) if you ever want to switch back — just re-run the same commands with `bash/gdiff` instead of `fish/gdiff`.

Requirements for the Fish version: `fish` (obviously), `git`, and a clipboard command (`wl-clipboard`, `xclip`, or `xsel`).

> **Platform note:** the Fish version is **Linux/macOS/WSL only** — there is no native Fish build for Windows. On Windows, use the [PowerShell version](#windows-installation) or the Bash version (Git Bash/MSYS2). Inside WSL, Fish works exactly like on Linux.

### 2. Prepare Your Changes
Stage the code changes you want to commit:
```bash
git add src/my-feature.js
```

### 3. Run gdiff
Execute the CLI tool in the root of your Git repository:
```bash
gdiff
```
*Output:*
```text
✓ Diff + rule copied to clipboard
```

### 4. Ask the AI and Commit!
Paste the clipboard contents into any AI chat, copy the suggested message, and commit:
```bash
git commit -m "feat(core): add authentication gateway"
```
---

## How-To Guides (Recipes)

### How to Customize the Default Prompt Rule
`gdiff` allows you to customize the instructions sent to the AI. On your very first run, `gdiff` automatically initializes a personal rule file at `~/.config/gdiff/rule.txt` (on Windows: `%APPDATA%\gdiff\rule.txt`).

To write your own instructions:

1. Open the configuration file:
   ```bash
   nano ~/.config/gdiff/rule.txt
   ```
2. Edit the file to describe your preferred commit format, writing guidelines, or project constraints. The next time you run `gdiff`, your customized prompt will automatically be appended.

*(Note: If you ever want to reset your configuration back to the factory defaults, you can run `gdiff --restore-rule`.)*

### How to Use a One-off Rule
To use a custom prompt file for a single execution:
```bash
gdiff --rule ./custom-rules.md
# or
gdiff -r ./custom-rules.txt
```

### How to Print Output Without Copying
If you want to view the exact prompt content that would be copied to the clipboard, or if you want to pipe the prompt output directly to a local terminal command, use the `--print` flag:
```bash
gdiff --print
```

---

## Reference

### CLI Flags

| Flag | Long Option | Description |
| :--- | :--- | :--- |
| `-r <file>` | `--rule <file>` | Path to a custom rules file (`.txt` or `.md`) to append instead of the default. |
| `-p` | `--print` | Stream the output directly to `stdout` rather than saving it to the clipboard. |
| `-d` | `--diff-only` | Copy only the diff to clipboard, without appending the rule. |
| | `--restore-rule` | Re-create or restore the default conventional commit rule in `~/.config/gdiff/rule.txt` (on Windows: `%APPDATA%\gdiff\rule.txt`). |
| | `--rule-path` | Output the file path of the rule file currently chosen by the resolution engine. |
| `-v` | `--version` | Display the installed version. |
| `-h` | `--help` | Show usage instructions. |

### Rule Precedence Order
`gdiff` evaluates which rule file to use in the following strict hierarchy (from highest priority to lowest):

1. **Command-Line Override**: `--rule <file>` option.
2. **gdiff Dev Repository**: Only active when running `gdiff` directly from its own cloned source repository (e.g. `./bash/gdiff`). Uses the local `share/rule.txt` for developer convenience.
3. **User Config Plaintext**: `~/.config/gdiff/rule.txt` (on Windows: `%APPDATA%\gdiff\rule.txt`)
4. **User Config Markdown**: `~/.config/gdiff/rule.md` (on Windows: `%APPDATA%\gdiff\rule.md`)
5. **System-Wide Default**: `/usr/share/gdiff/rule.txt` (no system-wide default on Windows)

### Supported Clipboard Managers
`gdiff` features smart fallback capability, detecting active desktop servers to automatically choose the correct command:
*   **Wayland**: `wl-copy` (from `wl-clipboard`)
*   **X11 (Xorg)**: `xclip` or `xsel`
*   **macOS**: `pbcopy` (built-in)
*   **Windows (PowerShell)**: `Set-Clipboard` (built-in)
*   **WSL / Git Bash**: `clip.exe` (built-in)

---

## Explanation

### Why Separating Prompt Logic from API Orchestration is Better
Many tools in the modern ecosystem execute API requests directly. While convenient, this introduces several flaws:
*   **Privacy & API Keys**: It forces the user to buy API credits, expose sensitive credentials in configuration environments, or trust the CLI tool not to leak keys.
*   **Obsolescence**: As models are deprecated, the client must be continuously updated.
*   **Ineffective Prompts**: Hardcoded prompts cannot easily adapt to diverse workspaces.

By decoupling context gathering (`git diff`) and instruction formatting (`rule.txt`) from AI querying, `gdiff` remains incredibly resilient. The clipboard acts as a universal bridge, allowing you to use cutting-edge web models, local desktop clients, or corporate AI endpoints seamlessly and at zero cost.

### Optional Fish Implementation
`gdiff` also provides a native **Fish** implementation (`fish/gdiff`), written from scratch in Fish to avoid unnecessary subprocess invocations and guarantee fast startup times. Since it is not shipped by the packages, it must be installed manually — see [Optional: Fish version (manual install)](#optional-fish-version-manual-install).

---

## License

This project is licensed under the [MIT License](LICENSE).
