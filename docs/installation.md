# Installation Guide

## Prerequisites

Before installing `gdiff`, make sure your environment meets the following requirements:

1. **Git**: Installed and configured on your system.
2. **A Shell**: Bash (v4+) or Fish Shell.
3. **A Clipboard Utility**: `gdiff` automatically detects and uses your system's clipboard engine. Ensure you have at least one of the following installed:

| Environment / OS | Clipboard Engine | Install Command Examples |
| :--- | :--- | :--- |
| **Wayland** (Linux) | `wl-clipboard` (`wl-copy`) | `sudo pacman -S wl-clipboard` <br> `sudo apt install wl-clipboard` |
| **X11** (Linux) | `xclip` or `xsel` | `sudo apt install xclip` <br> `sudo dnf install xclip` |
| **macOS** | `pbcopy` | *Built-in (no installation needed)* |
| **WSL** (Windows) | `clip.exe` | *Built-in (no installation needed)* |

---

## Method 1: Arch Linux (AUR)
If you are using Arch Linux, you can easily install gdiff from the **Arch User Repository (AUR)**. It is available under the package name `gdiff`.

### Option A: Using an AUR Helper (Recommended)

Use your favorite AUR helper to fetch, build, and install the package automatically:

```bash
# Using yay
yay -S gdiff

# Using paru
paru -S gdiff
```

### Option B: Manual AUR Compilation

If you prefer to build the AUR package manually:

1. Clone the AUR repository:
```bash
   git clone https://aur.archlinux.org/gdiff.git
   cd gdiff
```
2. Build and install using `makepkg`:
   ```bash
   makepkg -si
   ```

---

## Method 2: Manual Installation (Linux & macOS)

If you are on another Linux distribution (like Debian, Ubuntu, Fedora) or macOS, you can install `gdiff` manually in just a few steps.

### Step 1: Clone the Repository
Clone the codebase to a temporary directory:
```bash
git clone https://github.com/0Crazy-0/gdiff.git
cd gdiff
```

### Step 2: Choose and Install your Shell Script

`gdiff` provides native implementations for both **Bash** and **Fish** shells. Choose the script that corresponds to your environment:

#### Option A: Bash Script (Default)
1. Copy the script to a folder in your system `$PATH` (e.g., `/usr/local/bin`):
   ```bash
   sudo cp bash/gdiff /usr/local/bin/gdiff
   sudo chmod +x /usr/local/bin/gdiff
   ```

2. Copy the default rule file to the system-wide sharing directory:
   ```bash
   sudo mkdir -p /usr/share/gdiff
   sudo cp share/rule.txt /usr/share/gdiff/rule.txt
   ```

#### Option B: Fish (Native Implementation)
If you use the Fish Shell and want a native Fish implementation:
1. Copy the Fish script to a folder in your `$PATH`:
   ```bash
   sudo cp fish/gdiff /usr/local/bin/gdiff
   sudo chmod +x /usr/local/bin/gdiff
   ```

2. Copy the default rule file as shown in the Bash step:
   ```bash
   sudo mkdir -p /usr/share/gdiff
   sudo cp share/rule.txt /usr/share/gdiff/rule.txt
   ```

---

## Post-Installation Verification

To verify that `gdiff` has been successfully installed and can locate its core resources, run the following verification checks:

### 1. Check the Version
```bash
gdiff --version
```
*Expected Output:*
```text
gdiff v1.0.0
```

### 2. Verify Rule File Discovery
Ensure `gdiff` can locate its rule template:
```bash
gdiff --rule-path
```
*Expected Output (if system-installed):*
```text
/usr/share/gdiff/rule.txt
```

### 3. Customize your Personal Rules
On its very first execution, `gdiff` automatically creates your personal configuration folder and initializes the rule file under your home directory.

You can immediately open and edit this file:
```bash
nano ~/.config/gdiff/rule.txt
```

*(Note: If you ever want to force-reset your rule file back to factory defaults, you can run `gdiff --restore-rule`.)*
