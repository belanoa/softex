#include <stdint.h>

#include "tinyprintf.h"
#include "hal_sfm.h"
#include "archi_sfm.h"

#include "golden-model/scores.h"
#include "golden-model/golden.h"

static uint16_t scores[LENGTH] = SCORES;

int main () {

    int ol_id;

    hwpe_soft_clear();

    while ((ol_id = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(scores, SFM_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH / (DATA_WIDTH / 8), SFM_TOT_LEN);
    HWPE_WRITE(0x1c010000, SFM_OUT_ADDR);
    HWPE_WRITE(SFM_CMD_ACC_ONLY, SFM_COMMANDS);

    hwpe_trigger_job();

    asm volatile("wfi" ::: "memory");

    HWPE_WRITE(scores, SFM_IN_ADDR);
    HWPE_WRITE(LENGTH * FMT_WIDTH / (DATA_WIDTH / 8), SFM_TOT_LEN);
    HWPE_WRITE(0x1c010000, SFM_OUT_ADDR);
    HWPE_WRITE(SFM_CMD_DIV_ONLY, SFM_COMMANDS);

    hwpe_trigger_job();

    asm volatile("wfi" ::: "memory");

    //End the simulation
    *(volatile int *)(0x80000000) = 0;

	return 0;
}
