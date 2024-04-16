#!/bin/bash

# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Andrea Belano <andrea.belano@studio.unibo.it>
#

export N_PROC=1
TIMEOUT=60

# Declare a string array with type
declare -a test_list=(
    "scripts/test/basic.yml"
)

# Read the list values with space
for val in "${test_list[@]}"; do
    nice -n10 scripts/bwruntests.py --disable_results_pp --report_junit -t ${TIMEOUT} --yaml -o sfm_tests.xml -p${N_PROC} $val
    if test $? -ne 0; then
        echo "Error in test $val"
        exit 1
    fi
done
