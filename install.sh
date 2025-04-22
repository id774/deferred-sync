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
        $SUDO cp $OPTIONS "$SCRIPT_HOME/$1" "$TARGET/"
        shift
    done
}

deploy_to_target() {
    echo "[INFO] Deploying to $TARGET"
    [ -d "$TARGET" ] && $SUDO rm -rf "$TARGET/"
    [ -d "$TARGET" ] || $SUDO mkdir -p "$TARGET/"
    deploy exec config lib
    remove_obsolete_files
}

remove_obsolete_files() {
    echo "[INFO] Removing obsolete plugin files..."
    remove_obsolete "$TARGET/lib/plugins/11_show_version"
}

remove_obsolete() {
    [ -f "$1" ] && $SUDO rm -vf "$1"
}

scheduling() {
    echo "[INFO] Setting up cron and configuration links..."
    $SUDO cp $OPTIONS "$SCRIPT_HOME/cron/deferred-sync" /etc/cron.daily/deferred-sync
    [ -d /etc/opt/deferred-sync ] || $SUDO mkdir -p /etc/opt/deferred-sync
    $SUDO cp $OPTIONS "$SCRIPT_HOME/config/"*.conf /etc/opt/deferred-sync/
    $SUDO chown $OWNER /etc/opt/deferred-sync/*.conf
    $SUDO chmod 640 /etc/opt/deferred-sync/*.conf
    $SUDO rm "$TARGET/config/"*.conf
    $SUDO ln -snf /etc/opt/deferred-sync/sync.conf "$TARGET/config/sync.conf"
    $SUDO ln -snf /etc/opt/deferred-sync/exclude.conf "$TARGET/config/exclude.conf"
}

logrotate() {
    echo "[INFO] Setting up log rotation..."
    $SUDO cp $OPTIONS "$SCRIPT_HOME/cron/logrotate.d/deferred-sync" /etc/logrotate.d/deferred-sync
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

restore_config_from_backup() {
    echo "[INFO] Restoring config files from backup if available..."
    for file in sync.conf exclude.conf; do
        if [ -f "/home/backup/etc/opt/deferred-sync/$file" ]; then
            $SUDO cp $OPTIONS "/home/backup/etc/opt/deferred-sync/$file" "/etc/opt/deferred-sync/$file"
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
    $SUDO chown -R "$OWNER" "$TARGET"
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
