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
            echo "Error: Command '$cmd' is not installed. Please install $cmd and try again." >&2
            exit 127
        elif [ ! -x "$cmd_path" ]; then
            echo "Error: Command '$cmd' is not executable. Please check the permissions." >&2
            exit 126
        fi
    done
}

# Check if the user has sudo privileges (password may be required)
check_sudo() {
    if ! sudo -v 2>/dev/null; then
        echo "Error: This script requires sudo privileges. Please run as a user with sudo access." >&2
        exit 1
    fi
}

# Function to set environment variables
set_environment() {
    echo "[INFO] Setting up environment..."
    export SCRIPT_HOME=$(dirname "$(realpath "$0" 2>/dev/null || readlink -f "$0")")

    if [ ! -d "$SCRIPT_HOME/lib/plugins" ]; then
        echo "[ERROR] $SCRIPT_HOME/lib/plugins directory does not exist." >&2
        exit 1
    fi

    case "$(uname)" in
        Darwin)
            OPTIONS=-pPRv
            OWNER=root:wheel
            ;;
        *)
            OPTIONS=-Rvd
            OWNER=root:adm
            ;;
    esac

    if [ -n "$1" ]; then
        TARGET=$1
    else
        TARGET=/opt/deferred-sync
    fi

    if [ -n "$2" ]; then
        SUDO=""
    else
        SUDO="sudo"
    fi
    echo "[INFO] Using sudo: ${SUDO:-no}"

    if [ "$SUDO" = "sudo" ]; then
        check_sudo
    else
        OWNER="$(id -un):$(id -gn)"
    fi
    echo "[INFO] Copy options: $OPTIONS"
    echo "[INFO] Owner: $OWNER"
}

deploy() {
    echo "[INFO] Deploying components: $*"
    while [ $# -gt 0 ]; do
        if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/$1" "$TARGET/"; then
            echo "[ERROR] Failed to deploy $1 to $TARGET" >&2
            exit 1
        fi
        shift
    done
}

deploy_to_target() {
    echo "[INFO] Deploying to $TARGET"
    if [ -d "$TARGET" ]; then
        if ! $SUDO rm -rf "$TARGET/"; then
            echo "[ERROR] Failed to remove existing $TARGET" >&2
            exit 1
        fi
    fi

    if ! $SUDO mkdir -p "$TARGET/"; then
        echo "[ERROR] Failed to create target directory: $TARGET" >&2
        exit 1
    fi

    deploy exec config lib
    remove_obsolete_files
}

remove_obsolete_files() {
    echo "[INFO] Removing obsolete plugin files..."
    remove_obsolete "$TARGET/lib/plugins/11_show_version"
}

remove_obsolete() {
    if [ -f "$1" ]; then
        if ! $SUDO rm -vf "$1"; then
            echo "[ERROR] Failed to remove obsolete file: $1" >&2
            exit 1
        fi
    fi
}

scheduling() {
    echo "[INFO] Setting up cron and configuration links..."
    if [ -f /etc/cron.d/deferred-sync ]; then
        echo "[INFO] Skipping /etc/cron.daily installation since /etc/cron.d/deferred-sync exists."
    else
        echo "[INFO] Installing deferred-sync to /etc/cron.daily"
        if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/cron/deferred-sync" /etc/cron.daily/deferred-sync; then
            echo "[ERROR] Failed to copy cron.daily script." >&2
            exit 1
        fi
    fi

    if [ ! -d /etc/opt/deferred-sync ]; then
        if ! $SUDO mkdir -p /etc/opt/deferred-sync; then
            echo "[ERROR] Failed to create /etc/opt/deferred-sync" >&2
            exit 1
        fi
    fi

    if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/config/"*.conf /etc/opt/deferred-sync/; then
        echo "[ERROR] Failed to copy configuration files." >&2
        exit 1
    fi

    if ! $SUDO chown $OWNER /etc/opt/deferred-sync/*.conf; then
        echo "[ERROR] Failed to change ownership of configuration files." >&2
        exit 1
    fi

    if ! $SUDO chmod 640 /etc/opt/deferred-sync/*.conf; then
        echo "[ERROR] Failed to set permissions on configuration files." >&2
        exit 1
    fi

    if ! $SUDO rm "$TARGET/config/"*.conf; then
        echo "[ERROR] Failed to remove old configuration symlinks." >&2
        exit 1
    fi

    if ! $SUDO ln -snf /etc/opt/deferred-sync/sync.conf "$TARGET/config/sync.conf"; then
        echo "[ERROR] Failed to link sync.conf." >&2
        exit 1
    fi

    if ! $SUDO ln -snf /etc/opt/deferred-sync/exclude.conf "$TARGET/config/exclude.conf"; then
        echo "[ERROR] Failed to link exclude.conf." >&2
        exit 1
    fi
}

logrotate() {
    echo "[INFO] Setting up log rotation..."
    if ! $SUDO cp $OPTIONS "$SCRIPT_HOME/cron/logrotate.d/deferred-sync" /etc/logrotate.d/deferred-sync; then
        echo "[ERROR] Failed to copy logrotate configuration." >&2
        exit 1
    fi

    if ! $SUDO mkdir -p /var/log/deferred-sync; then
        echo "[ERROR] Failed to create log directory." >&2
        exit 1
    fi

    if ! $SUDO touch /var/log/deferred-sync/sync.log; then
        echo "[ERROR] Failed to create sync.log file." >&2
        exit 1
    fi

    if ! $SUDO chown $OWNER /var/log/deferred-sync/sync.log; then
        echo "[ERROR] Failed to change ownership of sync.log." >&2
        exit 1
    fi

    if ! $SUDO chmod 640 /var/log/deferred-sync/sync.log; then
        echo "[ERROR] Failed to set permissions on sync.log." >&2
        exit 1
    fi
}

create_backupdir() {
    echo "[INFO] Creating backup directories..."
    for dir in /home/backup /home/remote; do
        if [ ! -d "$dir" ]; then
            if ! $SUDO mkdir "$dir"; then
                echo "[ERROR] Failed to create directory: $dir" >&2
                exit 1
            fi
        fi

        if ! $SUDO chown $OWNER "$dir"; then
            echo "[ERROR] Failed to change ownership of $dir" >&2
            exit 1
        fi

        if ! $SUDO chmod 750 "$dir"; then
            echo "[ERROR] Failed to set permissions on $dir" >&2
            exit 1
        fi
    done
}

restore_config_from_backup() {
    echo "[INFO] Restoring config files from backup if available..."
    for file in sync.conf exclude.conf; do
        if [ -f "/home/backup/etc/opt/deferred-sync/$file" ]; then
            if ! $SUDO cp $OPTIONS "/home/backup/etc/opt/deferred-sync/$file" "/etc/opt/deferred-sync/$file"; then
                echo "[ERROR] Failed to restore $file from backup." >&2
                exit 1
            fi
        fi
    done
}

setup_cron() {
    if [ "$(uname -s)" = "Linux" ]; then
        echo "[INFO] Setting up scheduled jobs..."
        scheduling
        logrotate
        create_backupdir
        restore_config_from_backup
    fi
}

set_permission() {
    echo "[INFO] Setting file ownership and permissions..."
    if ! $SUDO chown -R "$OWNER" "$TARGET"; then
        echo "[ERROR] Failed to recursively change ownership of $TARGET" >&2
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
