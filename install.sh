#!/bin/sh

########################################################################
# install_deferred_sync.sh: Install deferred-sync
#
#  Description:
#  This script installs deferred-sync to the target path and sets up
#  necessary configurations including cron jobs, log rotation, and
#  permissions.
#
#  Author: id774 (More info: http://id774.net)
#  Source Code: https://github.com/id774/scripts
#  License: LGPLv3 (Details: https://www.gnu.org/licenses/lgpl-3.0.html)
#  Contact: idnanashi@gmail.com
#
#  Version History:
#  v1.2 2025-03-17
#       - Standardized documentation format
#       - Added check_system, check_commands, and check_sudo functions
#       - Renamed setup() to set_environment() for clarity
#  v1.1 2016-06-13
#       - Remove obsolete, restore exclude.conf from backup.
#  v1.0 2014-06-23
#       - Stable.
#
#  Usage:
#  ./install_deferred_sync.sh [target_path] [nosudo]
#
########################################################################

# Function to check if the system is Linux
check_system() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "Error: This script is intended for Linux systems only." >&2
        exit 1
    fi
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

# Function to extract directory name from a given path
dir_name() {
    echo "${1%/*}"
}

# Function to set environment variables
set_environment() {
    SCRIPT_HOME=$(cd "$(dir_name "$0")" && pwd)
    EXECDIR="${0%/*}"

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

    if [ -z "$2" ]; then
        SUDO=sudo
    elif [ "$2" = "sudo" ]; then
        SUDO=sudo
    else
        SUDO=
    fi
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
    ln -s /etc/opt/deferred-sync/sync.conf "$TARGET/config/sync.conf"
    ln -s /etc/opt/deferred-sync/exclude.conf "$TARGET/config/exclude.conf"
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
    check_system
    check_commands
    check_sudo
    set_environment "$@"
    deploy_to_target
    [ -n "$1" ] || setup_cron
    [ -n "$2" ] || set_permission
}

# Main function to execute the script
main() {
    installer "$@"
}

# Execute main function
main "$@"
