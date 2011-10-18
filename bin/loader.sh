#!/bin/sh

load_module() {
    while [ $# -gt 0 ]
    do
        . $SCRIPT_HOME/../lib/$1.sh
        shift
    done
}

load_modules_by_config() {
    load_module $MODULES
}

load_modules_all() {
    for MODULE in $SCRIPT_HOME/../lib/*.sh
    do
        . $MODULE
    done
    unset MODULE
}

load_modules() {
    if [ -n $LOAD_MODULES_ALL ]; then
        load_modules_all
    elif [ -n $MODULES ]; then
        load_modules_by_config
    else
        load_modules_all
    fi
}

load_modules
