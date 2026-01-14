#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

KUBECTL_VER="v1.32.11"
LANG="EN"

# configure_ubuntu_rootless_podman.sh
# Rootless installer for Ubuntu - Podman only, no kind, no nerdctl
# Installs tools into $HOME/.local/bin and uses translations.json in the same directory
# Usage: ./configure_ubuntu_rootless_podman.sh

# --- Configuration utilisateur ---
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSLATIONS_JSON="$SCRIPT_DIR/translations.json"

# --- Helpers ---
log() { printf '%s %s\n' "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')]" "$*"; }
ensure_dir() { mkdir -p "$1"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# --- Load translations from translations.json if present ---
load_translations() {
  DEFAULT_LANG="${LANG%%_*}"
  LANG_KEY="${DEFAULT_LANG:-fr}"

  # defaults
  MSG_INSTALL="Installing..."
  MSG_OK="OK"
  MSG_WARN="Warning"
  MSG_ERR="Error"
  MSG_RELOGIN="You may need to re-login for group changes to take effect."

  if [ -f "$TRANSLATIONS_JSON" ]; then
    if has_cmd jq; then
      # Use jq to read keys with fallback to en then hardcoded default
      MSG_INSTALL="$(jq -r --arg k "$LANG_KEY" '.[$k].install // .en.install // "Installing..."' "$TRANSLATIONS_JSON" 2>/dev/null || echo "$MSG_INSTALL")"
      MSG_OK="$(jq -r --arg k "$LANG_KEY" '.[$k].ok // .en.ok // "OK"' "$TRANSLATIONS_JSON" 2>/dev/null || echo "$MSG_OK")"
      MSG_WARN="$(jq -r --arg k "$LANG_KEY" '.[$k].warn // .en.warn // "Warning"' "$TRANSLATIONS_JSON" 2>/dev/null || echo "$MSG_WARN")"
      MSG_ERR="$(jq -r --arg k "$LANG_KEY" '.[$k].err // .en.err // "Error"' "$TRANSLATIONS_JSON" 2>/dev/null || echo "$MSG_ERR")"
      MSG_RELOGIN="$(jq -r --arg k "$LANG_KEY" '.[$k].relogin // .en.relogin // "You may to re-login for group changes to take effect."' "$TRANSLATIONS_JSON" 2>/dev/null || echo "$MSG_RELOGIN")"
    else
      # jq missing: fallback to minimal built-in FR/EN
      case "$LANG_KEY" in
        fr)
          MSG_INSTALL="Installation en cours..."
          MSG_OK="OK"
          MSG_WARN="Attention"
          MSG_ERR="Erreur"
          MSG_RELOGIN="Vous devrez peut-être vous reconnecter pour appliquer les changements de groupe."
          ;;
        en|*)
          MSG_INSTALL="Installing..."
          MSG_OK="OK"
          MSG_WARN="Warning"
          MSG_ERR="Error"
          MSG_RELOGIN="You may need to re-login for group changes to take effect."
          ;;
      esac
      log "$MSG_WARN jq not found; using built-in translations."
    fi
  else
    # translations.json absent: built-in minimal translations
    case "$LANG_KEY" in
      fr)
        MSG_INSTALL="Installation en cours..."
        MSG_OK="OK"
        MSG_WARN="Attention"
        MSG_ERR="Erreur"
        MSG_RELOGIN="Vous devrez peut-être vous reconnecter pour appliquer les changements de groupe."
        ;;
      en|*)
        MSG_INSTALL="Installing..."
        MSG_OK="OK"
        MSG_WARN="Warning"
        MSG_ERR="Error"
        MSG_RELOGIN="You may need to re-login for group changes to take effect."
        ;;
    esac
  fi
}

# --- Ensure local bin in PATH ---
ensure_local_bin() {
  ensure_dir "$LOCAL_BIN"
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    export PATH="$LOCAL_BIN:$PATH"
    # Persist for interactive shells if writable
    if [ -w "$HOME/.profile" ]; then
      grep -qx "export PATH=\"$LOCAL_BIN:\$PATH\"" "$HOME/.profile" || echo "export PATH=\"$LOCAL_BIN:\$PATH\"" >> "$HOME/.profile"
    fi
  fi
}

# --- Apt helper for required system packages (sudo required) ---
install_system_packages() {
  PKGS=(curl ca-certificates tar gzip jq python3 uidmap dbus-user-session slirp4netns fuse-overlayfs)
  log "$MSG_INSTALL apt packages: ${PKGS[*]}"
  sudo apt-get update -y
  sudo apt-get install -y "${PKGS[@]}"
}

# --- Install Podman rootless ---
install_podman() {
  if has_cmd podman; then
    log "podman already installed at $(command -v podman)"
    return
  fi
  log "$MSG_INSTALL podman (rootless)"
  . /etc/os-release || true
  if [ -n "${VERSION_CODENAME:-}" ]; then
    # add upstream repo for stable podman builds on Ubuntu
    sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/Ubuntu_${VERSION_CODENAME}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
    curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/Ubuntu_${VERSION_CODENAME}/Release.key" | sudo apt-key add - || true
    sudo apt-get update -y
    sudo apt-get install -y podman
  else
    sudo apt-get install -y podman || true
  fi
  # enable lingering so user systemd services can run (useful for rootless containers)
  if has_cmd loginctl; then
    loginctl enable-linger "$USER" || true
  fi
}

# --- Install kubectl into LOCAL_BIN ---
install_kubectl() {
  if has_cmd kubectl; then
    log "kubectl already installed at $(command -v kubectl)"
    return
  fi
  log "$MSG_INSTALL kubectl"
  KUBECTL_VER="$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null || echo '')"
  if [ -z "$KUBECTL_VER" ]; then
    KUBECTL_VER="v1.28.0"
  fi
  tmpf="$(mktemp)"
  curl -fsSL -o "$tmpf" "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl"
  install -m 0755 "$tmpf" "$LOCAL_BIN/kubectl"
  rm -f "$tmpf"
}

# --- Install minikube into LOCAL_BIN (optional) ---
install_minikube() {
  if has_cmd minikube; then
    log "minikube already installed at $(command -v minikube)"
    return
  fi
  log "$MSG_INSTALL minikube"
  tmpf="$(mktemp)"
  curl -fsSL -o "$tmpf" "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
  install -m 0755 "$tmpf" "$LOCAL_BIN/minikube"
  rm -f "$tmpf"
}

# --- Install Helm into LOCAL_BIN ---
install_helm() {
  if has_cmd helm; then
    log "helm already installed at $(command -v helm)"
    return
  fi
  log "$MSG_INSTALL helm"
  HELM_VER="${HELM_VER:-v3.12.0}"
  ARCH_DL="amd64"
  case "$(uname -m)" in
    x86_64|amd64) ARCH_DL="amd64" ;;
    aarch64|arm64) ARCH_DL="arm64" ;;
  esac
  tmpd="$(mktemp -d)"
  curl -fsSL -o "$tmpd/helm.tar.gz" "https://get.helm.sh/helm-${HELM_VER}-linux-${ARCH_DL}.tar.gz"
  tar -xzf "$tmpd/helm.tar.gz" -C "$tmpd"
  HELM_BIN="$(find "$tmpd" -type f -name helm | head -n1)"
  if [ -n "$HELM_BIN" ]; then
    install -m 0755 "$HELM_BIN" "$LOCAL_BIN/helm"
  else
    log "$MSG_WARN helm binary not found in archive"
  fi
  rm -rf "$tmpd"
}

# --- Install CircleCI CLI into LOCAL_BIN ---
install_circleci_cli() {
  if has_cmd circleci; then
    log "circleci already installed at $(command -v circleci)"
    return
  fi
  log "$MSG_INSTALL CircleCI CLI"
  ARCH_DL="amd64"
  case "$(uname -m)" in
    x86_64|amd64) ARCH_DL="amd64" ;;
    aarch64|arm64) ARCH_DL="arm64" ;;
  esac
  tmpd="$(mktemp -d)"
  URL="https://github.com/CircleCI-Public/circleci-cli/releases/latest/download/circleci-cli_linux_${ARCH_DL}.tar.gz"
  if curl -fsSL -o "$tmpd/circleci.tar.gz" "$URL"; then
    tar -xzf "$tmpd/circleci.tar.gz" -C "$tmpd"
    if [ -f "$tmpd/circleci" ]; then
      install -m 0755 "$tmpd/circleci" "$LOCAL_BIN/circleci"
    else
      BIN="$(find "$tmpd" -type f -perm /111 -name circleci -print -quit || true)"
      if [ -n "$BIN" ]; then
        install -m 0755 "$BIN" "$LOCAL_BIN/circleci"
      else
        log "$MSG_WARN circleci binary not found in archive"
      fi
    fi
  else
    log "$MSG_WARN Could not download CircleCI CLI from $URL"
  fi
  rm -rf "$tmpd"
}

# --- Install jq into LOCAL_BIN if missing (fallback) ---
install_jq_local() {
  if has_cmd jq; then
    return
  fi
  log "$MSG_INSTALL jq"
  tmpf="$(mktemp)"
  curl -fsSL -o "$tmpf" "https://github.com/stedolan/jq/releases/latest/download/jq-linux64"
  install -m 0755 "$tmpf" "$LOCAL_BIN/jq"
  rm -f "$tmpf"
}

# --- Main flow ---
main() {
  ensure_dir "$LOCAL_BIN"
  ensure_local_bin
  load_translations

  log "$MSG_INSTALL Starting rootless Podman configuration"

  # Install system packages required for rootless runtimes and parsing translations
  install_system_packages

  # Ensure jq available for parsing translations.json
  install_jq_local

  # Install Podman rootless
  install_podman

  # Kubernetes tooling (kubectl and optional minikube)
  install_kubectl
  install_minikube

  # Helm and CircleCI CLI into user bin
  install_helm
  install_circleci_cli

  # Final checks
  log "----"
  for cmd in podman kubectl minikube helm circleci jq; do
    if has_cmd "$cmd"; then
      log "$MSG_OK $cmd -> $(command -v "$cmd")"
    else
      log "$MSG_WARN $cmd not found"
    fi
  done

  log "$MSG_RELOGIN"
  log "Done."
}

main "$@"
main
