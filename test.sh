#!/bin/sh

bin/run test/test_1.conf
cat test/test_1.log
rm test/test_1.log

bin/run test/test_2.conf
cat test/test_2.log
rm test/test_2.log

bin/run test/test_3.conf
cat test/test_3.log
rm test/test_3.log

