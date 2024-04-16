// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

#ifndef __HAL_SFM__
#define __HAL_SFM__

#include "archi_sfm.h"

#define HWPE_WRITE(value, offset) *(volatile int *)(SFM_BASE_ADD + offset) = value
#define HWPE_READ(offset) *(volatile int *)(SFM_BASE_ADD + offset)

static inline void hwpe_trigger_job() {
    HWPE_WRITE(0, SFM_TRIGGER);
}

static inline int hwpe_acquire_job() {
    return HWPE_READ(SFM_ACQUIRE);
}

static inline unsigned int hwpe_get_status() {
    return HWPE_READ(SFM_STATUS);
}

static inline void hwpe_soft_clear() {
  HWPE_WRITE(0, SFM_SOFT_CLEAR);
}

#endif