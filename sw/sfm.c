#include <stdint.h>

#include "tinyprintf.h"
#include "hal_sfm.h"
#include "archi_sfm.h"

int main () {

    int ol_id;

    hwpe_soft_clear();

    while ((ol_id = hwpe_acquire_job()) < 0) {

    }

    HWPE_WRITE(0x1c010000, SFM_IN_ADDR);
    HWPE_WRITE(0x10, SFM_TOT_LEN);
    HWPE_WRITE(0x1c010000, SFM_OUT_ADDR);

    hwpe_trigger_job();

    asm volatile("wfi" ::: "memory");

	return 0;
}
