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
#  v2.0 2025-03-17
#       Standardized documentation format and added system checks.
#  [Further version history truncated for brevity]
#  v1.0 2014-06-23
#       Initial release.
#
#  Usage:
#  ./install.sh [target_path] [nosudo]
#
#  Notes:
#  - [target_path]: Path to the installation directory (default: /opt/deferred-sync).
#  - [nosudo]: If specified, the script runs without sudo.
#
########################################################################

# Display help message
show_help() {
    cat <<EOF
Usage: $(basename "$0") [target_path] [nosudo]

Options:
  -h, --help    Show this help message and exit.

Description:
  This script installs deferred-sync to the target path and sets up
  necessary configurations including cron jobs, log rotation, and
  permissions.
EOF
}

# Function to check required commands
check_commands() {
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Command '$cmd' is not installed. Please install $cmd and try again." >&2
            exit 127
        elif ! [ -x "$(command -v "$cmd")" ]; then
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
    export SCRIPT_HOME=$(dirname "$(realpath "$0" 2>/dev/null || readlink -f "$0")")

    if [ ! -d "$SCRIPT_HOME/lib/plugins" ]; then
        echo "Error: $SCRIPT_HOME/lib/plugins directory does not exist." >&2
        exit 1
    fi

    case $OSTYPE in
        *darwin*)
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
    echo "Using sudo: ${SUDO:-no}"

    if [ "$SUDO" = "sudo" ]; then
        check_sudo
    else
        OWNER="$(id -un):$(id -gn)"
    fi
    echo "Copy options: $OPTIONS, Owner: $OWNER"
}

deploy() {
    while [ $# -gt 0 ]; do
        $SUDO cp $OPTIONS "$SCRIPT_HOME/$1" "$TARGET/"
        shift
    done
}

deploy_to_target() {
    echo "Installing from $SCRIPT_HOME to $TARGET/"
    [ -d "$TARGET" ] && $SUDO rm -rf "$TARGET/"
    [ -d "$TARGET" ] || $SUDO mkdir -p "$TARGET/"
    deploy exec config lib
    remove_obsolete_files
}

remove_obsolete_files() {
    remove_obsolete "$TARGET/lib/plugins/11_show_version"
}

remove_obsolete() {
    [ -f "$1" ] && $SUDO rm -vf "$1"
}

scheduling() {
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
    $SUDO cp $OPTIONS "$SCRIPT_HOME/cron/logrotate.d/deferred-sync" /etc/logrotate.d/deferred-sync
    $SUDO mkdir -p /var/log/deferred-sync
    $SUDO touch /var/log/deferred-sync/sync.log
    $SUDO chown $OWNER /var/log/deferred-sync/sync.log
    $SUDO chmod 640 /var/log/deferred-sync/sync.log
}

create_backupdir() {
    for dir in /home/backup /home/remote; do
        [ -d "$dir" ] || $SUDO mkdir "$dir"
        $SUDO chown $OWNER "$dir"
        $SUDO chmod 750 "$dir"
    done
}

restore_config_from_backup() {
    for file in sync.conf exclude.conf; do
        if [ -f "/home/backup/etc/opt/deferred-sync/$file" ]; then
            $SUDO cp $OPTIONS "/home/backup/etc/opt/deferred-sync/$file" "/etc/opt/deferred-sync/$file"
        fi
    done
}

setup_cron() {
    echo "Setting up for cron job"
    scheduling
    logrotate
    create_backupdir
    restore_config_from_backup
}

set_permission() {
    $SUDO chown -R "$OWNER" "$TARGET"
}

installer() {
    check_commands cp mkdir chmod chown ln rm id dirname
    set_environment "$@"
    deploy_to_target
    [ -n "$1" ] || setup_cron
    [ -n "$2" ] || set_permission
}

# Main function to execute the script
main() {
    # Parse command-line arguments
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                show_help
                exit 0
                ;;
        esac
    done

    installer "$@"
}

# Execute main function
main "$@"
