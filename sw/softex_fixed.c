// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

#include <stdint.h>

#include "tinyprintf.h"
#include "hal_softex.h"
#include "archi_softex.h"

#include "golden-model/scores.h"
#include "golden-model/golden.h"

static uint8_t scores[LENGTH] = SCORES;

int main () {

    int acq_res;

    hwpe_soft_clear();

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(scores, SOFTEX_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH, SOFTEX_TOT_LEN);
    HWPE_WRITE(0x1c010000, SOFTEX_OUT_ADDR);
    HWPE_WRITE(0x00000000 | SOFTEX_CMD_INT_INPUT | SOFTEX_CMD_INT_OUTPUT, SOFTEX_COMMANDS);
    HWPE_WRITE(INPUT_INT_BITS | (INPUT_SIGNED << 7) | (((OUTPUT_INT_BITS) & 0b01111111) << 8) | (OUTPUT_SIGNED << 15), SOFTEX_CAST_CTRL);

    hwpe_trigger_job();

    asm volatile("wfi" ::: "memory");

    //End the simulation
    *(volatile int *)(0x80000000) = 0;

	return 0;
}
