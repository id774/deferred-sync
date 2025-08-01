#!/bin/sh

########################################################################
# install.sh: Install deferred-sync
#
#  Description:
#  This script installs deferred-sync to the target path and sets up
#  necessary configurations including cron jobs, log rotation, and
#  permissions. It also conditionally links external configuration
#  files if requested via --link.
#
#  Author: id774 (More info: http://id774.net)
#  Source Code: https://github.com/id774/deferred-sync
#  License: The GPL version 3, or LGPL version 3 (Dual License).
#  Contact: idnanashi@gmail.com
#
#  Usage:
#      ./install.sh [target_path] [nosudo] [--link]
#
#  Options:
#      -h, --help       Show this help message and exit.
#      -u, --uninstall  Remove deferred-sync and all related files except logs.
#      -l, --link       Create symlinks under /etc/cron.config and /etc/cron.exec.
#
#  Notes:
#  - [target_path]: Path to the installation directory (default: /opt/deferred-sync).
#  - [nosudo]: If specified, the script runs without sudo.
#
#  Version History:
#  v3.0 2025-08-01
#       Add uninstall support via --uninstall to remove all components.
#       Add --link option to control whether cron.config/cron.exec links are created.
#       Add support for conditional symlinks:
#       - Link /etc/cron.config/{sync.conf,exclude.conf} to /etc/opt/deferred-sync/
#       - Link /etc/cron.exec/deferred-sync to /opt/deferred-sync/exec/
#       Unify all config link creation to be idempotent and silent unless modified.
#  v2.5 2025-06-23
#       Unified usage output to display full script header and support common help/version options.
#  v2.4 2025-04-27
#       Add strict error checking for all critical filesystem operations to prevent silent failures.
#       Remove backup restoration logic. Skip copying sync.conf and exclude.conf if they already exist.
#  v2.3 2025-04-23
#       Skip copying to /etc/cron.daily if /etc/cron.d/deferred-sync exists.
#  v2.2 2025-04-22
#       Improve log granularity with [INFO] and [ERROR] tags per execution step.
#  v2.1 2025-03-22
#       Unify usage information by extracting help text from header comments.
#  v2.0 2025-03-17
#       Standardized documentation format and added system checks.
#  [Further version history truncated for brevity]
#  v1.0 2014-06-23
#       Initial release.
#
########################################################################

# Display full script header information extracted from the top comment block
usage() {
    awk '
        BEGIN { in_header = 0 }
        /^#{10,}$/ { if (!in_header) { in_header = 1; next } else exit }
        in_header && /^# ?/ { print substr($0, 3) }
    ' "$0"
    exit 0
}

# Check if required commands are available and executable
check_commands() {
    for cmd in "$@"; do
        cmd_path=$(command -v "$cmd" 2>/dev/null)
        if [ -z "$cmd_path" ]; then
            echo "[ERROR] Command '$cmd' is not installed. Please install $cmd and try again." >&2
            exit 127
        elif [ ! -x "$cmd_path" ]; then
            echo "[ERROR] Command '$cmd' is not executable. Please check the permissions." >&2
            exit 126
        fi
    done
}

# Check if the user has sudo privileges (password may be required)
check_sudo() {
    if ! sudo -v 2>/dev/null; then
        echo "[ERROR] This script requires sudo privileges. Please run as a user with sudo access." >&2
        exit 1
    fi
}

# Set environment variables
set_environment() {
    echo "[INFO] Setting up environment..."
    export SCRIPT_HOME=$(dirname "$(realpath "$0" 2>/dev/null || readlink -f "$0")")

    if [ ! -d "$SCRIPT_HOME/lib/plugins" ]; then
        echo "[ERROR] Missing directory: $SCRIPT_HOME/lib/plugins" >&2
        exit 1
    fi

    case "$(uname)" in
        Darwin) OPTIONS=-pPRv; OWNER=root:wheel ;;
        *) OPTIONS=-Rvd; OWNER=root:adm ;;
    esac

    TARGET=${1:-/opt/deferred-sync}
    [ -n "$2" ] && SUDO="" || SUDO="sudo"

    echo "[INFO] Using sudo: ${SUDO:-no}"
    [ "$SUDO" = "sudo" ] && check_sudo || OWNER="$(id -un):$(id -gn)"
    echo "[INFO] Copy options: $OPTIONS"
    echo "[INFO] Owner: $OWNER"
}

deploy() {
    echo "[INFO] Deploying components: $*"
    for item in "$@"; do
        if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/$item" "$TARGET/"; then
            echo "[ERROR] Failed to copy $item to $TARGET." >&2
            exit 1
        fi
    done
}

deploy_to_target() {
    echo "[INFO] Deploying to $TARGET."
    if [ -d "$TARGET" ]; then
        if ! $SUDO rm -rf "$TARGET/"; then
            echo "[ERROR] Failed to remove existing $TARGET." >&2
            exit 1
        fi
    fi
    if ! $SUDO mkdir -p "$TARGET/"; then
        echo "[ERROR] Failed to create target directory: $TARGET" >&2
        exit 1
    fi
    deploy exec config lib
}

scheduling() {
    echo "[INFO] Setting up cron and configuration links..."
    if [ -f /etc/cron.d/deferred-sync ]; then
        echo "[INFO] Skipping /etc/cron.daily installation since /etc/cron.d/deferred-sync exists."
    else
        echo "[INFO] Installing to /etc/cron.daily"
        if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/cron/deferred-sync" /etc/cron.daily/deferred-sync; then
            echo "[ERROR] Failed to install to /etc/cron.daily." >&2
            exit 1
        fi
    fi

    if ! $SUDO mkdir -p /etc/opt/deferred-sync; then
        echo "[ERROR] Failed to create /etc/opt/deferred-sync." >&2
        exit 1
    fi

    echo "[INFO] Deploying configuration files..."
    for conf in sync.conf exclude.conf; do
        if [ -f "/etc/opt/deferred-sync/$conf" ]; then
            echo "[INFO] /etc/opt/deferred-sync/$conf already exists. Skipping copy."
        else
            echo "[INFO] Copying $conf to /etc/opt/deferred-sync/"
            if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/config/$conf" "/etc/opt/deferred-sync/$conf"; then
                echo "[ERROR] Failed to copy $conf to /etc/opt/deferred-sync" >&2
                exit 1
            fi
        fi
    done
    $SUDO chown $OWNER "/etc/opt/deferred-sync/$conf"
    $SUDO chmod 640 "/etc/opt/deferred-sync/$conf"

    create_config_symlinks
}

create_config_symlinks() {
    for conf in sync.conf exclude.conf; do
        src="/etc/opt/deferred-sync/$conf"
        link="$TARGET/config/$conf"
        if [ -f "$src" ]; then
            if [ "$(readlink -e "$link" 2>/dev/null)" != "$src" ]; then
                $SUDO ln -snf "$src" "$link" && echo "[INFO] Linked $link -> $src"
            fi
        fi
    done
}

link_configs_to_etc() {
    if [ -d /etc/cron.config ]; then
        for conf in sync.conf exclude.conf; do
            src="/etc/opt/deferred-sync/$conf"
            link="/etc/cron.config/$conf"
            if [ -f "$src" ]; then
                if [ "$(readlink -e "$link" 2>/dev/null)" != "$src" ]; then
                    $SUDO ln -snf "$src" "$link" && echo "[INFO] Linked $link -> $src"
                fi
            fi
        done
    fi

    if [ -d /etc/cron.exec ]; then
        src="/opt/deferred-sync/exec/deferred-sync"
        link="/etc/cron.exec/deferred-sync"
        if [ -f "$src" ]; then
            if [ "$(readlink -e "$link" 2>/dev/null)" != "$src" ]; then
                $SUDO ln -snf "$src" "$link" && echo "[INFO] Linked $link -> $src"
            fi
        fi
    fi
}

logrotate() {
    echo "[INFO] Setting up log rotation..."
    if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/cron/logrotate.d/deferred-sync" /etc/logrotate.d/deferred-sync; then
        echo "[ERROR] Failed to copy logrotate config." >&2
        exit 1
    fi

    $SUDO mkdir -p /var/log/deferred-sync
    $SUDO touch /var/log/deferred-sync/sync.log
    $SUDO chown $OWNER /var/log/deferred-sync/sync.log
    $SUDO chmod 640 /var/log/deferred-sync/sync.log
}

create_backupdir() {
    echo "[INFO] Creating backup directories..."
    for dir in /home/backup /home/remote; do
        [ -d "$dir" ] || $SUDO mkdir "$dir"
        $SUDO chown $OWNER "$dir"
        $SUDO chmod 750 "$dir"
    done
}

setup_cron() {
    if [ "$(uname -s)" = "Linux" ]; then
        echo "[INFO] Setting up scheduled jobs..."
        scheduling
        logrotate
        create_backupdir
    fi
}

set_permission() {
    echo "[INFO] Setting file ownership and permissions..."
    if ! $SUDO chown -R "$OWNER" "$TARGET"; then
        echo "[ERROR] Failed to recursively change ownership of $TARGET." >&2
        exit 1
    fi
}

uninstall() {
    echo "[INFO] Uninstalling deferred-sync..."

    [ "$(id -u)" -ne 0 ] && SUDO="sudo"

    $SUDO rm -rvf /opt/deferred-sync || {
        echo "[ERROR] Failed to remove /opt/deferred-sync" >&2
        exit 1
    }

    $SUDO rm -rvf /etc/opt/deferred-sync || {
        echo "[ERROR] Failed to remove /etc/opt/deferred-sync" >&2
        exit 1
    }

    $SUDO rm -vf /etc/cron.daily/deferred-sync
    $SUDO rm -vf /etc/logrotate.d/deferred-sync

    for link in /etc/cron.config/sync.conf /etc/cron.config/exclude.conf; do
        [ -L "$link" ] && $SUDO rm -vf "$link"
    done

    [ -L /etc/cron.exec/deferred-sync ] && $SUDO rm -vf /etc/cron.exec/deferred-sync

    echo "[INFO] deferred-sync uninstalled successfully."
    exit 0
}

install() {
    check_commands cp mkdir chmod chown ln rm id dirname uname readlink
    set_environment "$1" "$2"
    deploy_to_target
    [ -n "$1" ] || setup_cron
    [ -n "$2" ] || set_permission
    [ "$3" = "1" ] && link_configs_to_etc
    echo "[INFO] deferred-sync installation completed successfully."
}

# Main entry point of the script
main() {
    TARGET_PATH=""
    NOSUDO=""
    LINK_FLAG=0

    for arg in "$@"; do
        case "$arg" in
            -h|--help|-v|--version)
                usage
                ;;
            -u|--uninstall)
                uninstall
                ;;
            -l|--link)
                LINK_FLAG=1
                ;;
            --no-sudo)
                NOSUDO="nosudo"
                ;;
            /*)
                TARGET_PATH="$arg"
                ;;
            *)
                echo "[ERROR] Unknown option: $arg" >&2
                usage
                ;;
        esac
    done

    install "$TARGET_PATH" "$NOSUDO" "$LINK_FLAG"
    return 0
}

# Execute main function
main "$@"
exit $?
