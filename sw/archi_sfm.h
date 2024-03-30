#ifndef __ARCHI_SFM__
#define __ARCHI_SFM__

#define SFM_BASE_ADD    0x00100000

// Commands
#define SFM_TRIGGER     0x00
#define SFM_ACQUIRE     0x04
#define SFM_FINISHED    0x08
#define SFM_STATUS      0x0C
#define SFM_RUNNING_JOB 0x10
#define SFM_SOFT_CLEAR  0x14

#define SFM_REG_OFFS    0x20

#define SFM_IN_ADDR     SFM_REG_OFFS + 0x00
#define SFM_OUT_ADDR    SFM_REG_OFFS + 0x04
#define SFM_TOT_LEN     SFM_REG_OFFS + 0x08

#endif