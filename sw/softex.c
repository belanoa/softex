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

static uint16_t scores[LENGTH] = SCORES;

int main () {

    int acq_res,
        slot_id;

    hwpe_soft_clear();

    /**********ACCUMULATION**********/

    slot_id = 1;

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(scores, SOFTEX_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SOFTEX_TOT_LEN);
    HWPE_WRITE(((int) scores) + LENGTH * FMT_WIDTH, SOFTEX_CACHE_BASE_ADDR);
    HWPE_WRITE(SOFTEX_CMD_ACC_ONLY | SOFTEX_CMD_ACQUIRE_SLOT | SOFTEX_CMD_SET_CACHE_ADDR | (slot_id << 16), SOFTEX_COMMANDS);
    
    hwpe_trigger_job();

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(((int) scores) + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SOFTEX_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH - LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SOFTEX_TOT_LEN);
    HWPE_WRITE(SOFTEX_CMD_ACC_ONLY | SOFTEX_CMD_LAST | (slot_id << 16), SOFTEX_COMMANDS);
    
    hwpe_trigger_job();

    asm volatile("wfi" ::: "memory");
    asm volatile("wfi" ::: "memory");

    /**********NORMALISATION**********/

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(scores, SOFTEX_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SOFTEX_TOT_LEN);
    HWPE_WRITE(0x1c010000, SOFTEX_OUT_ADDR);
    HWPE_WRITE(SOFTEX_CMD_DIV_ONLY | (slot_id << 16), SOFTEX_COMMANDS);

    hwpe_trigger_job();

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(((int) scores) + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SOFTEX_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH - LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SOFTEX_TOT_LEN);
    HWPE_WRITE(0x1c010000 + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SOFTEX_OUT_ADDR);
    HWPE_WRITE(SOFTEX_CMD_DIV_ONLY | SOFTEX_CMD_LAST | (slot_id << 16), SOFTEX_COMMANDS);

    hwpe_trigger_job();

    asm volatile("wfi" ::: "memory");
    asm volatile("wfi" ::: "memory");

    //End the simulation
    *(volatile int *)(0x80000000) = 0;

	return 0;
}
