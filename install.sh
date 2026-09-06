#!/bin/sh
# ==============================================================================
#  gdiff universal installer (Linux, macOS, and Git Bash / MSYS2 on Windows)
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/0Crazy-0/gdiff/main/install.sh | sh
#
#  Re-running this script updates gdiff. Your custom rule file
#  (%APPDATA%/gdiff/rule.txt on Git Bash, ~/.config/gdiff/rule.txt on unix)
#  is never overwritten.
# ==============================================================================

set -u

abort() {
  printf '%s\n' "$@" >&2
  exit 1
}

ohai() {
  printf '==> %s\n' "$1"
}

download() {
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget > /dev/null 2>&1; then
    wget -qO- "$1"
  else
    abort "Error: neither curl nor wget is installed." \
          "Install one of them and re-run this script."
  fi
}

REPO_URL='https://github.com/0Crazy-0/gdiff'
RAW_URL='https://raw.githubusercontent.com/0Crazy-0/gdiff/main'

detect_platform() {
  case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    mingw*|msys*|cygwin*) printf 'win32' ;;
    *) printf 'unix' ;;
  esac
}

# Resolve a writable prefix for the gdiff executable.
# On unix we try /usr/local/bin first; if it is not writable and there is
# no sudo, we fall back to ~/.local/bin (assumed to be on PATH on modern
# setups; the script prints a hint otherwise).
resolve_install_dir() {
  if [ "$(detect_platform)" = 'win32' ]; then
    # Git Bash: /usr/local/bin maps inside the MSYS root, which is writable
    # by the user and on PATH by default.
    printf '%s' '/usr/local/bin'
    return 0
  fi

  if [ -w /usr/local/bin ] || [ "$(id -u)" = '0' ]; then
    printf '%s' '/usr/local/bin'
  elif command -v sudo > /dev/null 2>&1; then
    printf '%s' '/usr/local/bin'
  elif [ -d "$HOME/.local/bin" ]; then
    printf '%s' "$HOME/.local/bin"
  else
    printf '%s' '/usr/local/bin'
  fi
}

# Warn if an existing package-manager install is detected, so the user does
# not end up with two installations shadowing each other.
check_existing_install() {
  if [ "$(detect_platform)" = 'win32' ]; then
    return 0
  fi

  if command -v apt-get > /dev/null 2>&1 && dpkg -s gdiff > /dev/null 2>&1; then
    ohai "Warning: gdiff is already installed via APT."
    printf 'The manually installed version will take precedence or conflict.\n'
    printf 'Consider removing it first:  sudo apt remove gdiff\n\n'
  elif command -v dnf > /dev/null 2>&1 && dnf list installed gdiff > /dev/null 2>&1; then
    ohai "Warning: gdiff is already installed via DNF."
    printf 'Consider removing it first:  sudo dnf remove gdiff\n\n'
  fi
}

download_and_install() {
  local platform install_dir tmp_dir
  platform="$(detect_platform)"
  install_dir="$(resolve_install_dir)"

  check_existing_install

  tmp_dir="$(mktemp -d)" || abort "Error: could not create a temporary directory."
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" EXIT INT TERM HUP

  ohai "Downloading gdiff (bash script + default rule)"
  download "$RAW_URL/bash/gdiff" > "$tmp_dir/gdiff" || abort "Download Error!"
  download "$RAW_URL/share/rule.txt" > "$tmp_dir/rule.txt" || abort "Download Error!"
  chmod +x "$tmp_dir/gdiff"

  ohai "Installing gdiff to $install_dir"
  if [ "$install_dir" = '/usr/local/bin' ] && [ "$(detect_platform)" = 'unix' ] && [ "$(id -u)" != '0' ]; then
    sudo install -Dm755 "$tmp_dir/gdiff" "$install_dir/gdiff" || abort "Install Error"
  else
    mkdir -p "$install_dir" || abort "Install Error"
    install -m755 "$tmp_dir/gdiff" "$install_dir/gdiff" || abort "Install Error"
  fi

  # ------------------------------------------------------------------
  # Default rule:
  #   unix   -> /usr/share/gdiff/rule.txt (system-wide default)
  #   win32  -> %APPDATA%/gdiff/rule.txt  (Git Bash has no usable /usr/share)
  # The user rule (win32: %APPDATA%/gdiff, unix: ~/.config/gdiff) is NEVER
  # overwritten: re-running this script only updates the executable.
  # re-running this script only updates the executable.
  # ------------------------------------------------------------------
  if [ "$platform" = 'win32' ]; then
    # On Windows the user config lives at %APPDATA%\gdiff (Git Bash exposes
    # APPDATA); fall back to ~/.config/gdiff if APPDATA is unavailable.
    # tr normalizes backslashes to forward slashes (POSIX-safe, unlike the
    # ${var//\\//} bashism, so the same code runs in any sh).
    win_config_base="${GDIFF_CONFIG_HOME:-${APPDATA:-$HOME/.config}/gdiff}"
    win_config_base="$(printf '%s' "$win_config_base" | tr '\\' '/')"
    if [ ! -f "$win_config_base/rule.txt" ]; then
      ohai "Installing default rule to $win_config_base/rule.txt"
      mkdir -p "$win_config_base" || abort "Install Error"
      cp "$tmp_dir/rule.txt" "$win_config_base/rule.txt" || abort "Install Error"
    else
      ohai "Existing user rule found at $win_config_base/rule.txt (left untouched)"
    fi
  else
    if [ ! -f /usr/share/gdiff/rule.txt ]; then
      ohai "Installing default rule to /usr/share/gdiff/rule.txt"
      if [ "$(id -u)" = '0' ]; then
        install -Dm644 "$tmp_dir/rule.txt" /usr/share/gdiff/rule.txt || abort "Install Error"
      elif command -v sudo > /dev/null 2>&1; then
        sudo install -Dm644 "$tmp_dir/rule.txt" /usr/share/gdiff/rule.txt || abort "Install Error"
      else
        printf 'Warning: could not write /usr/share/gdiff/rule.txt (no sudo).\n' >&2
        printf 'The default rule will be installed to ~/.config/gdiff/ instead.\n' >&2
        mkdir -p "$HOME/.config/gdiff"
        cp "$tmp_dir/rule.txt" "$HOME/.config/gdiff/rule.txt"
      fi
    else
      ohai "Existing default rule found at /usr/share/gdiff/rule.txt (left untouched)"
    fi
  fi

  # Sanity check: is the installed executable on PATH?
  case ":$PATH:" in
    *":$install_dir:"*) ;;
    *)
      printf '\nWarning: %s is not on your PATH.\n' "$install_dir" >&2
      printf 'Add this to your shell profile and restart your shell:\n' >&2
      printf '  export PATH="%s:$PATH"\n' "$install_dir" >&2
      ;;
  esac

  printf '\n'
  ohai "gdiff installed successfully!"
  printf 'Run "gdiff --help" to get started.\n'
}

download_and_install || abort "Install Error"