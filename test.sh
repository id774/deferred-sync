#!/bin/sh

run() {
    bin/exec test/$1.conf
    cat test/$1.log
    rm test/$1.log

}

load() {
    while [ $# -gt 0 ]
    do
        run $1
        shift
    done
}

load test_1 test_2 test_3
