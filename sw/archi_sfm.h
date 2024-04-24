// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Andrea Belano <andrea.belano@studio.unibo.it>
//

#ifndef __ARCHI_SFM__
#define __ARCHI_SFM__

#define DATA_WIDTH      128

#define SFM_BASE_ADD    0x00100000

// Commands
#define SFM_TRIGGER     0x00
#define SFM_ACQUIRE     0x04
#define SFM_FINISHED    0x08
#define SFM_STATUS      0x0C
#define SFM_RUNNING_JOB 0x10
#define SFM_SOFT_CLEAR  0x14

#define SFM_REG_OFFS    0x20

#define SFM_IN_ADDR         SFM_REG_OFFS + 0x00
#define SFM_OUT_ADDR        SFM_REG_OFFS + 0x04
#define SFM_TOT_LEN         SFM_REG_OFFS + 0x08
#define SFM_COMMANDS        SFM_REG_OFFS + 0x0C
#define SFM_CACHE_BASE_ADDR SFM_REG_OFFS + 0x10


#define SFM_CMD_ACC_ONLY        0x00000001
#define SFM_CMD_DIV_ONLY        0x00000002
#define SFM_CMD_ACQUIRE_SLOT    0x00000004
#define SFM_CMD_LAST            0x00000008
#define SFM_CMD_SET_CACHE_ADDR  0x00000010
#define SFM_CMD_NO_OP           0x00000020

#endif