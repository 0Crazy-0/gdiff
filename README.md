# gdiff

> **An ultra-lightweight, 100% local, and free CLI tool to generate perfect, AI-assisted conventional commit messages using any LLM.**

---

[![Debian: APT](https://img.shields.io/badge/Debian-APT-A81D33.svg?logo=debian&logoColor=white)](#)
[![Fedora: COPR](https://img.shields.io/badge/Fedora-COPR-51A2DA.svg?logo=fedora&logoColor=white)](#)
[![Arch Linux: AUR](https://img.shields.io/badge/Arch_Linux-AUR-1793D1.svg?logo=archlinux&logoColor=white)](#)
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

You can install `gdiff` via your system's package manager.

| OS / Distro | Package Manager | Install Command | Update Command |
| :--- | :--- | :--- | :--- |
| **Arch Linux** | AUR | `yay -S gdiff` <br> `paru -S gdiff` | `yay -S gdiff` <br> `paru -S gdiff` <br> (or simply `yay` / `paru`) |
| **Fedora** | COPR (DNF) | `sudo dnf copr enable crazy/gdiff && sudo dnf install gdiff` | `sudo dnf upgrade gdiff` |
| **Debian / Ubuntu** | APT | `curl -fsSL https://raw.githubusercontent.com/0Crazy-0/gdiff/main/debian-setup.sh \| sudo bash` | `sudo apt update && sudo apt install gdiff` |

All the package managers above install the **Bash** version of `gdiff`. If you are a **Fish** user, see [Optional: Fish version (manual install)](#optional-fish-version-manual-install) below.

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
`gdiff` allows you to customize the instructions sent to the AI. On your very first run, `gdiff` automatically initializes a personal rule file at `~/.config/gdiff/rule.txt`.

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
| | `--restore-rule` | Re-create or restore the default conventional commit rule in `~/.config/gdiff/rule.txt`. |
| | `--rule-path` | Output the file path of the rule file currently chosen by the resolution engine. |
| `-v` | `--version` | Display the installed version. |
| `-h` | `--help` | Show usage instructions. |

### Rule Precedence Order
`gdiff` evaluates which rule file to use in the following strict hierarchy (from highest priority to lowest):

1. **Command-Line Override**: `--rule <file>` option.
2. **gdiff Dev Repository**: Only active when running `gdiff` directly from its own cloned source repository (e.g. `./bash/gdiff`). Uses the local `share/rule.txt` for developer convenience.
3. **User Config Plaintext**: `~/.config/gdiff/rule.txt`
4. **User Config Markdown**: `~/.config/gdiff/rule.md`
5. **System-Wide Default**: `/usr/share/gdiff/rule.txt`

### Supported Clipboard Managers
`gdiff` features smart fallback capability, detecting active desktop servers to automatically choose the correct command:
*   **Wayland**: `wl-copy` (from `wl-clipboard`)
*   **X11 (Xorg)**: `xclip` or `xsel`
*   **macOS**: `pbcopy` (built-in)
*   **WSL**: `clip.exe` (built-in)

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
