#!/bin/sh

########################################################################
# install.sh: Install deferred-sync
#
#  Description:
#  This script installs deferred-sync to the target path and sets up
#  necessary configurations including cron jobs, log rotation, and
#  permissions.
#
#  Author: id774 (More info: http://id774.net)
#  Source Code: https://github.com/id774/deferred-sync
#  License: The GPL version 3, or LGPL version 3 (Dual License).
#  Contact: idnanashi@gmail.com
#
#  Version History:
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
#  Usage:
#      ./install.sh [target_path] [nosudo]
#
#  Options:
#      -h, --help    Show this help message and exit.
#
#  Notes:
#  - [target_path]: Path to the installation directory (default: /opt/deferred-sync).
#  - [nosudo]: If specified, the script runs without sudo.
#
########################################################################

# Display script usage information
usage() {
    awk '
        BEGIN { in_usage = 0 }
        /^#  Usage:/ { in_usage = 1; print substr($0, 4); next }
        /^#{10}/ { if (in_usage) exit }
        in_usage && /^#/ { print substr($0, 4) }
    ' "$0"
    exit 0
}

# Function to check required commands
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

# Function to set environment variables
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

    if ! $SUDO ln -snf /etc/opt/deferred-sync/sync.conf "$TARGET/config/sync.conf"; then
        echo "[ERROR] Failed to create symlink for sync.conf." >&2
        exit 1
    fi

    if ! $SUDO ln -snf /etc/opt/deferred-sync/exclude.conf "$TARGET/config/exclude.conf"; then
        echo "[ERROR] Failed to create symlink for exclude.conf." >&2
        exit 1
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

installer() {
    check_commands cp mkdir chmod chown ln rm id dirname uname
    set_environment "$@"
    deploy_to_target
    [ -n "$1" ] || setup_cron
    [ -n "$2" ] || set_permission
    echo "[INFO] deferred-sync installation completed successfully."
}

# Main function to execute the script
main() {
    case "$1" in
        -h|--help) usage ;;
    esac

    installer "$@"
}

# Execute main function
main "$@"
