// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

#include <stdint.h>
#include <stdatomic.h> 

#include "tinyprintf.h"
#include "hal_sfm.h"
#include "archi_sfm.h"

#include "golden-model/scores.h"
#include "golden-model/golden.h"

static uint16_t scores[LENGTH * N_VECTORS] = SCORES;

int main () {

    int acq_res;

    hwpe_soft_clear();

    while ((acq_res = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(((int) scores) + LENGTH * FMT_WIDTH * N_VECTORS, SFM_CACHE_BASE_ADDR);
    HWPE_WRITE(SFM_CMD_SET_CACHE_ADDR | SFM_CMD_NO_OP, SFM_COMMANDS);
    
    hwpe_trigger_job();

    /**********ACCUMULATION**********/

    for (int i = 0; i < N_VECTORS; i += 2) {
        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + i * LENGTH * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(SFM_CMD_ACC_ONLY | SFM_CMD_ACQUIRE_SLOT | (i << 16), SFM_COMMANDS);

        hwpe_trigger_job();

        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + (i + 1) * LENGTH * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(SFM_CMD_ACC_ONLY | SFM_CMD_ACQUIRE_SLOT | ((i + 1) << 16), SFM_COMMANDS);

        hwpe_trigger_job();

        asm volatile("wfi" ::: "memory");
        asm volatile("wfi" ::: "memory");
    }

    for (int i = 0; i < N_VECTORS; i += 2) {
        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + i * LENGTH * FMT_WIDTH + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH - LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(SFM_CMD_ACC_ONLY | SFM_CMD_LAST | (i << 16), SFM_COMMANDS);
    
        hwpe_trigger_job();

        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + (i + 1) * LENGTH * FMT_WIDTH + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH - LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(SFM_CMD_ACC_ONLY | SFM_CMD_LAST | ((i + 1) << 16), SFM_COMMANDS);
    
        hwpe_trigger_job();

        asm volatile("wfi" ::: "memory");
        asm volatile("wfi" ::: "memory");
    }

    /**********NORMALISATION**********/

    for (int i = 0; i < N_VECTORS; i += 2) {
        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + i * LENGTH * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(0x1c010000 + i * LENGTH * FMT_WIDTH, SFM_OUT_ADDR);
        HWPE_WRITE(SFM_CMD_DIV_ONLY | (i << 16), SFM_COMMANDS);

        hwpe_trigger_job();

        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + (i + 1) * LENGTH * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(0x1c010000 + (i + 1) * LENGTH * FMT_WIDTH, SFM_OUT_ADDR);
        HWPE_WRITE(SFM_CMD_DIV_ONLY | ((i + 1) << 16), SFM_COMMANDS);

        hwpe_trigger_job();

        asm volatile("wfi" ::: "memory");
        asm volatile("wfi" ::: "memory");
    }

    for (int i = 0; i < N_VECTORS; i += 2) {
        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + i * LENGTH * FMT_WIDTH + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH - LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(0x1c010000 + i * LENGTH * FMT_WIDTH + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_OUT_ADDR);
        HWPE_WRITE(SFM_CMD_DIV_ONLY | SFM_CMD_LAST | (i << 16), SFM_COMMANDS);

        hwpe_trigger_job();

        while ((acq_res = hwpe_acquire_job()) < 0) {

        }

        HWPE_WRITE(((int) scores) + (i + 1) * LENGTH * FMT_WIDTH + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_IN_ADDR);
        HWPE_WRITE(LENGTH * FMT_WIDTH - LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_TOT_LEN);
        HWPE_WRITE(0x1c010000 + (i + 1) * LENGTH * FMT_WIDTH + LENGTH * FMT_WIDTH / (2 * FMT_WIDTH) * FMT_WIDTH, SFM_OUT_ADDR);
        HWPE_WRITE(SFM_CMD_DIV_ONLY | SFM_CMD_LAST | ((i + 1) << 16), SFM_COMMANDS);

        hwpe_trigger_job();

        asm volatile("wfi" ::: "memory");
        asm volatile("wfi" ::: "memory");
    }

    //End the simulation
    *(volatile int *)(0x80000000) = 0;

	return 0;
}
