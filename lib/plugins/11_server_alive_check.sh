#!/bin/sh
#
# 11_server_alive_check - Execute server_alive_check.sh if available.
#
# Behavior:
#   - Check if /etc/cron.exec/server_alive_check.sh (or $SERVER_ALIVE_CHECK) is executable.
#   - If executable, run it and do not intercept or remap its exit status.
#   - If not executable, print a [WARN] message to stderr and exit without error handling.
#
# Note:
#   - This script assumes it is running on a POSIX-compliant system.

# Resolve target path (allow override via environment)
SERVER_ALIVE_CHECK="${SERVER_ALIVE_CHECK:-/etc/cron.exec/server_alive_check.sh}"

start_message() {
    printf -- "[INFO] Loading: get_resources has been loaded at "
    date "+%Y/%m/%d %T"
}

run_server_alive_check() {
    if [ -x "$SERVER_ALIVE_CHECK" ]; then
        echo "[INFO] Executing: $SERVER_ALIVE_CHECK"
        "$SERVER_ALIVE_CHECK"
        return $?
    fi
    echo "[WARN] Not executable or missing: $SERVER_ALIVE_CHECK" >&2
    return 0
}

main() {
    start_message
    run_server_alive_check
}

main "$@"
