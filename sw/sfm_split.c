// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

#include <stdint.h>

#include "tinyprintf.h"
#include "hal_sfm.h"
#include "archi_sfm.h"

#include "golden-model/scores.h"
#include "golden-model/golden.h"

static uint16_t scores[LENGTH] = SCORES;

int main () {

    int acq_res,
        slot_id;

    hwpe_soft_clear();

    while ((slot_id = HWPE_READ(SFM_REQ_SLOT)) > 0) {

    }

    /**********ACCUMULATION**********/

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(scores, SFM_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH, SFM_TOT_LEN);
    HWPE_WRITE(SFM_CMD_ACC_ONLY | SFM_CMD_LAST | (slot_id << 16), SFM_COMMANDS);
    
    hwpe_trigger_job();

    /**********NORMALISATION**********/

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(scores, SFM_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH, SFM_TOT_LEN);
    HWPE_WRITE(0x1c010000, SFM_OUT_ADDR);
    HWPE_WRITE(SFM_CMD_DIV_ONLY | SFM_CMD_LAST | (slot_id << 16), SFM_COMMANDS);

    hwpe_trigger_job();

    asm volatile("wfi" ::: "memory");
    asm volatile("wfi" ::: "memory");

    //End the simulation
    *(volatile int *)(0x80000000) = 0;

	return 0;
}
