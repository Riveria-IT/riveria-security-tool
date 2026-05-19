#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="Riveria-IT"
REPO_NAME="riveria-security-tool"
DEFAULT_REF="main"
REPO_REF="${RIVERIA_REF:-$DEFAULT_REF}"
REPO_REF_TYPE="${RIVERIA_REF_TYPE:-branch}"

TMP_DIR="$(mktemp -d)"
ARCHIVE_FILE="$TMP_DIR/${REPO_NAME}.tar.gz"
EXTRACT_DIR="$TMP_DIR/extract"
CONFIG_BACKUP_FILE="$TMP_DIR/config.conf.backup"
LOCAL_LAUNCHER_DIR="$HOME/.local/bin"
SYSTEM_LAUNCHER_DIR="/usr/local/bin"
INSTALL_LAUNCHER_MODE="${INSTALL_LAUNCHER_MODE:-auto}"
RAW_TARGET_DIR="${1:-$HOME/riveria-security-tool}"
TARGET_DIR=""
ARCHIVE_URL=""
EXTRACTED_DIR=""

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
    printf 'Fehler: %s\n' "$1" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Benoetigter Befehl fehlt: $1"
}

validate_ref_type() {
    case "$REPO_REF_TYPE" in
        branch|tag) ;;
        *) fail "RIVERIA_REF_TYPE muss 'branch' oder 'tag' sein." ;;
    esac
}

configure_archive_source() {
    validate_ref_type

    case "$REPO_REF_TYPE" in
        branch)
            ARCHIVE_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REPO_REF}"
            EXTRACTED_DIR="$EXTRACT_DIR/${REPO_NAME}-${REPO_REF}"
            ;;
        tag)
            ARCHIVE_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/tags/${REPO_REF}"
            EXTRACTED_DIR="$EXTRACT_DIR/${REPO_NAME}-${REPO_REF}"
            ;;
    esac
}

normalize_target_dir() {
    local raw_target="$1"
    case "$raw_target" in
        "~") printf '%s\n' "$HOME" ;;
        "~/"*) printf '%s/%s\n' "$HOME" "${raw_target#~/}" ;;
        *) printf '%s\n' "$raw_target" ;;
    esac
}

assert_safe_target_dir() {
    local target="$1"

    [ -n "$target" ] || fail "Leerer Zielordner ist nicht erlaubt."

    case "$target" in
        /|/root|/home|/usr|/var|/etc|/opt)
            fail "Unsicherer Zielordner blockiert: $target"
            ;;
    esac
}

prepare_environment() {
    TARGET_DIR="$(normalize_target_dir "$RAW_TARGET_DIR")"
    assert_safe_target_dir "$TARGET_DIR"
    configure_archive_source

    require_command tar
    require_command mktemp

    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        fail "Weder wget noch curl ist verfuegbar."
    fi
}

download_archive() {
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$ARCHIVE_FILE" "$ARCHIVE_URL"
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_FILE"
        return 0
    fi
    fail "Weder wget noch curl ist verfuegbar."
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

verify_installation() {
    local required_path

    for required_path in \
        "$TARGET_DIR/riveria-security-tool.sh" \
        "$TARGET_DIR/lib/core.sh" \
        "$TARGET_DIR/lib/ui.sh" \
        "$TARGET_DIR/checks/system.sh" \
        "$TARGET_DIR/fixes/fixes.sh"
    do
        if [ ! -f "$required_path" ]; then
            printf 'Fehler: Installation unvollstaendig, Datei fehlt: %s\n' "$required_path" >&2
            return 1
        fi
    done
}

can_write_dir() {
    local dir="$1"
    [ -d "$dir" ] && [ -w "$dir" ]
}

write_launcher() {
    local launcher_target="$1"

    cat >"$launcher_target" <<EOF
#!/usr/bin/env bash
exec "$TARGET_DIR/riveria-security-tool.sh" "\$@"
EOF
    chmod +x "$launcher_target"
}

install_launcher() {
    local launcher_target launcher_mode

    case "$INSTALL_LAUNCHER_MODE" in
        auto)
            if can_write_dir "$SYSTEM_LAUNCHER_DIR"; then
                launcher_target="$SYSTEM_LAUNCHER_DIR/riveria-security-tool"
                launcher_mode="system"
            else
                mkdir -p "$LOCAL_LAUNCHER_DIR"
                launcher_target="$LOCAL_LAUNCHER_DIR/riveria-security-tool"
                launcher_mode="local"
            fi
            ;;
        system)
            can_write_dir "$SYSTEM_LAUNCHER_DIR" || fail "System-Launcher in $SYSTEM_LAUNCHER_DIR nicht schreibbar. Installer mit sudo starten oder INSTALL_LAUNCHER_MODE=local nutzen."
            launcher_target="$SYSTEM_LAUNCHER_DIR/riveria-security-tool"
            launcher_mode="system"
            ;;
        local)
            mkdir -p "$LOCAL_LAUNCHER_DIR"
            launcher_target="$LOCAL_LAUNCHER_DIR/riveria-security-tool"
            launcher_mode="local"
            ;;
        *)
            fail "INSTALL_LAUNCHER_MODE muss 'auto', 'system' oder 'local' sein."
            ;;
    esac

    write_launcher "$launcher_target"

    printf '\nLauncher erstellt: %s\n' "$launcher_target" >&2
    if [ "$launcher_mode" = "local" ]; then
        printf 'Hinweis: sudo uebernimmt ~/.local/bin oft nicht in den PATH.\n' >&2
        printf 'Fuer sudo riveria-security-tool ist ein System-Launcher unter %s professioneller.\n' "$SYSTEM_LAUNCHER_DIR" >&2
    fi

    printf '%s' "$launcher_target"
}

main() {
    local launcher_path

    prepare_environment

    printf 'Riveria wird jetzt heruntergeladen und eingerichtet...\n'
    if [ "$REPO_REF" = "$DEFAULT_REF" ] && [ "$REPO_REF_TYPE" = "branch" ]; then
        printf 'Hinweis: Es wird der Branch %s installiert. Dieser Stand ist aktuell Alpha.\n' "$REPO_REF"
    else
        printf 'Quelle: %s (%s)\n' "$REPO_REF" "$REPO_REF_TYPE"
    fi

    download_archive

    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$ARCHIVE_FILE" -C "$EXTRACT_DIR"
    prepare_target

    [ -d "$EXTRACTED_DIR" ] || fail "Archiv-Inhalt unerwartet. Verzeichnis fehlt: $EXTRACTED_DIR"
    mv "$EXTRACTED_DIR" "$TARGET_DIR"
    chmod +x "$TARGET_DIR/riveria-security-tool.sh" "$TARGET_DIR/install.sh" "$TARGET_DIR/tests/"*.sh 2>/dev/null || true
    restore_local_config
    verify_installation

    printf '\nInstallation abgeschlossen.\n'
    printf 'Zielordner: %s\n' "$TARGET_DIR"

    launcher_path="$(install_launcher)"

    printf '\nEmpfohlener Start:\n'
    if [ "$launcher_path" = "$SYSTEM_LAUNCHER_DIR/riveria-security-tool" ]; then
        printf '1. sudo riveria-security-tool\n'
    else
        printf '1. sudo "%s"\n' "$launcher_path"
        printf '   oder Installer mit sudo und INSTALL_LAUNCHER_MODE=system erneut ausfuehren.\n'
    fi
    printf '2. im Menue: 20) Einsteiger-Modus (einfach gefuehrt)\n'
    printf '3. bei der Vorschau-Frage zuerst Ja waehlen\n'

    printf '\nWenn du lieber direkt im Projektordner startest:\n'
    printf '1. cd "%s"\n' "$TARGET_DIR"
    printf '2. cp config.example.conf config.conf\n'
    printf '3. sudo -E bash ./riveria-security-tool.sh\n'

    printf '\nSicherer Vorschau-Start ohne echte Aenderungen:\n'
    printf 'DRY_RUN_MODE=1 RESULT_VIEW_MODE=simple sudo -E "%s"\n' "$launcher_path"
}

main "$@"
