#!/usr/bin/env bash
set -eu

REPO_OWNER="Riveria-IT"
REPO_NAME="riveria-security-tool"
REPO_BRANCH="main"
ARCHIVE_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REPO_BRANCH}"

TARGET_DIR="${1:-$HOME/riveria-security-tool}"
TMP_DIR="$(mktemp -d)"
ARCHIVE_FILE="$TMP_DIR/${REPO_NAME}.tar.gz"
EXTRACT_DIR="$TMP_DIR/extract"
CONFIG_BACKUP_FILE="$TMP_DIR/config.conf.backup"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

download_archive() {
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$ARCHIVE_FILE" "$ARCHIVE_URL"
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_FILE"
        return 0
    fi

    printf 'Fehler: weder wget noch curl ist verfuegbar.\n' >&2
    return 1
}

prepare_target() {
    if [ -f "$TARGET_DIR/config.conf" ]; then
        cp -f "$TARGET_DIR/config.conf" "$CONFIG_BACKUP_FILE"
    fi

    if [ -e "$TARGET_DIR" ]; then
        printf 'Bestehende Installation gefunden, Zielordner wird ersetzt: %s\n' "$TARGET_DIR"
        rm -rf "$TARGET_DIR"
    fi

    mkdir -p "$(dirname "$TARGET_DIR")"
}

restore_local_config() {
    if [ -f "$CONFIG_BACKUP_FILE" ]; then
        cp -f "$CONFIG_BACKUP_FILE" "$TARGET_DIR/config.conf"
        printf 'Vorhandene config.conf wurde wiederhergestellt.\n'
    fi
}

install_launcher() {
    local bin_dir launcher_target
    bin_dir="$HOME/.local/bin"
    launcher_target="$bin_dir/riveria-security-tool"

    mkdir -p "$bin_dir"
    ln -sf "$TARGET_DIR/riveria-security-tool.sh" "$launcher_target"

    printf '\nLauncher erstellt: %s\n' "$launcher_target"
    printf 'Falls ~/.local/bin noch nicht im PATH ist, kannst du das spaeter ergaenzen.\n'
}

main() {
    printf 'Riveria Server Audit & Hardening Tool wird heruntergeladen...\n'
    download_archive

    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$ARCHIVE_FILE" -C "$EXTRACT_DIR"
    prepare_target

    mv "$EXTRACT_DIR/${REPO_NAME}-${REPO_BRANCH}" "$TARGET_DIR"
    chmod +x "$TARGET_DIR/riveria-security-tool.sh" "$TARGET_DIR/install.sh" "$TARGET_DIR/tests/"*.sh 2>/dev/null || true
    restore_local_config

    printf '\nInstallation abgeschlossen.\n'
    printf 'Zielordner: %s\n' "$TARGET_DIR"

    install_launcher

    printf '\nNaechste Schritte:\n'
    printf '1. cd "%s"\n' "$TARGET_DIR"
    printf '2. cp config.example.conf config.conf\n'
    printf '3. sudo bash ./riveria-security-tool.sh\n'
    printf '\nOder direkt ueber den Launcher:\n'
    printf 'sudo riveria-security-tool\n'
}

main "$@"
