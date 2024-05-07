// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

#ifndef __HAL_SOFTEX__
#define __HAL_SOFTEX__

#include "archi_softex.h"

#define HWPE_WRITE(value, offset) *(volatile int *)(SOFTEX_BASE_ADD + offset) = value
#define HWPE_READ(offset) *(volatile int *)(SOFTEX_BASE_ADD + offset)

static inline void hwpe_trigger_job() {
    HWPE_WRITE(0, SOFTEX_TRIGGER);
}

static inline int hwpe_acquire_job() {
    return HWPE_READ(SOFTEX_ACQUIRE);
}

static inline unsigned int hwpe_get_status() {
    return HWPE_READ(SOFTEX_STATUS);
}

static inline void hwpe_soft_clear() {
  HWPE_WRITE(0, SOFTEX_SOFT_CLEAR);
}

#endif