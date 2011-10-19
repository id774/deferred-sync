#!/bin/sh

load_module() {
    while [ $# -gt 0 ]
    do
        . $SCRIPT_HOME/lib/*$1.sh
        shift
    done
}

load_modules_by_config() {
    load_module $MODULES
}

load_modules_all() {
    for MODULE in $SCRIPT_HOME/lib/*.sh
    do
        . $MODULE
    done
    unset MODULE
}

load_modules() {
    if [ $LOAD_MODULES_ALL = "true" ]; then
        load_modules_all
    else
        load_modules_by_config
    fi
}

load_modules
