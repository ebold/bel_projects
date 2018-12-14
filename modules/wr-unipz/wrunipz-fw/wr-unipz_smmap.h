#ifndef _WRUNIPZ__REGS_
#define _WRUNIPZ_REGS_

#include "wrunipz_shared_mmap.h"
#include "wr-unipz.h"

#define WRUNIPZ_SHARED_DATA_4EB_SIZE  68     // size of shared memory used to receive EB return values; size is in bytes

// the following values must be added to the offset of the shared memory
#define WRUNIPZ_SHARED_STATUS         0x00   // error status                       
#define WRUNIPZ_SHARED_CMD            0x04   // input of 32bit command
#define WRUNIPZ_SHARED_STATE          0x08   // state of state machine
#define WRUNIPZ_SHARED_TCYCLEAVG      0x0C   // period of UNILAC cycle [us] (average over one second)
#define WRUNIPZ_SHARED_VERSION        0x10   // version of firmware
#define WRUNIPZ_SHARED_MACHI          0x14   // WR MAC of wrunipz, bits 31..16 unused
#define WRUNIPZ_SHARED_MACLO          0x18   // WR MAC of wrunipz
#define WRUNIPZ_SHARED_IP             0x20   // IP of wrunipz
#define WRUNIPZ_SHARED_NBADSTATUS     0x24   // # of bad status (=error) incidents
#define WRUNIPZ_SHARED_NBADSTATE      0x28   // # of bad state (=FATAL, ERROR, UNKNOWN) incidents
#define WRUNIPZ_SHARED_NCYCLE         0x2C   // # of UNILAC cycles
#define WRUNIPZ_SHARED_NMESSAGEHI     0x30   // # of messsages, high bits
#define WRUNIPZ_SHARED_NMESSAGELO     0x34   // # of messsages, low bits
#define WRUNIPZ_SHARED_MSGFREQAVG     0x38   // message rate (average over one second)
#define WRUNIPZ_SHARED_DTAVG          0x3C   // delta T between message time of dispatching and deadline
#define WRUNIPZ_SHARED_DTMAX          0x40   // delta T max
#define WRUNIPZ_SHARED_DTMIN          0x44   // delta T min
// reserved: more defines here
#define WRUNIPZ_SHARED_DATA_4EB_START 0x90    // start of shared memory for EB return values
#define WRUNIPZ_SHARED_DATA_4EB_END   WRUNIPZ_SHARED_DATA_4EB_START + WRUNIPZ_SHARED_DATA_4EB_SIZE   // end of shared memory area for EB return values

#define WRUNIPZ_SHARED_CONF_VACC      WRUNIPZ_SHARED_DATA_4EB_END   + 4                              // vACC for config data
#define WRUNIPZ_SHARED_CONF_STAT      WRUNIPZ_SHARED_CONF_VACC  + 4                                  // status of config transaction
#define WRUNIPZ_SHARED_CONFDATA_START WRUNIPZ_SHARED_CONF_STAT  + 4                                  // start of config data
#define WRUNIPZ_SHARED_CONFDATA_END   WRUNIPZ_SHARED_CONFDATA_START + (WRUNIPZ_CONFDATASIZE << 2)    // end of config data
#define WRUNIPZ_SHARED_CONFFLAG_START WRUNIPZ_SHARED_CONFDATA_END + 4                                // start of config flags
#define WRUNIPZ_SHARED_CONFFLAG_END   WRUNIPZ_SHARED_CONFFLAG_START + (WRUNIPZ_CONFFLAGSIZE << 2)    // end of config flags

#define WRUNIPZ_SHARED_SIZEUSED       WRUNIPZ_SHARED_CONFFLAG_END + 4                                                     // used size of shared area

#endif
