/******************************************************************************
 *  eb-eca-lm32-poll
 *
 *  created : 2018
 *  author  : Dietrich Beck, GSI-Darmstadt
 *  version : 19-Jan-2018
 *
 * Command-line interface for polling the lm32 channel of the ECA. The channel
 * muss be configured using the saft-ecpu-ctl.
 *
 * -------------------------------------------------------------------------------------------
 * License Agreement for this software:
 *
 * Copyright (C) 2013  Dietrich Beck
 * GSI Helmholtzzentrum für Schwerionenforschung GmbH
 * Planckstraße 1
 * D-64291 Darmstadt
 * Germany
 *
 * Contact: d.beck@gsi.de
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *
 * For all questions and ideas contact: d.beck@gsi.de
 * Last update: 25-April-2015
 ********************************************************************************************/
#define EB_ECALM32POLL_VERSION "0.0.1"

/* standard includes */
#include <unistd.h> /* getopt */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <sys/time.h>

/* Etherbone */
#include <etherbone.h>

/* Wishbone api */
#include <wb_slaves.h>

/* ECA */
#include "../ip_cores/wr-cores/modules/wr_eca/eca_queue_regs.h"    // register layout ECA queue
#include "../ip_cores/saftlib/drivers/eca_flags.h"                 // defitions for ECA queueu


#define ECAQMAX           4     // max number of ECA channels in the system
#define ECACHANNELFORLM32 2     // this is a hack! suggest implementing finding via sdb-record and info

const char* program;
static int verbose=0;

eb_device_t deviceOther;   /* other EB device for comparing timestamps */


static void die(const char* where, eb_status_t status) {
  fprintf(stderr, "%s: %s failed: %s\n",
          program, where, eb_status(status));
  exit(1);
}

static void help(void) {
  fprintf(stderr, "Usage: %s [OPTION] <etherbone-device>\n", program);
  fprintf(stderr, "\n");
  fprintf(stderr, "  -e               display etherbone version\n");
  fprintf(stderr, "  -f<familyCode>   specify family code of 1-wire slave (0x43: EEPROM; 0x28,0x42: temperature)\n");
  fprintf(stderr, "  -h               display this help and exit\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Use this tool to retrieve data from the ECA lm32 action channel. Use saft-ecpu-ctl to configure the ECA.\n");
  fprintf(stderr, "This tool is highly experimental and prevents using the lm32\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Report software bugs to <d.beck@gsi.de>\n");
  fprintf(stderr, "Version %s. Licensed under the LGPL v3.\n", EB_ECALM32POLL_VERSION);
}


int main(int argc, char** argv) {
  eb_status_t       status;
  eb_socket_t       socket;
  eb_device_t       device;         
  int               devIndex=-1;  // 0,1,2... - there may be more than 1 device on the WB bus 
  int               nDevices;     // number of WB devices to check
  struct sdb_device sdbDevice[ECAQMAX];
  eb_address_t      ecaQ, tmp;
  eb_data_t         data;
  eb_data_t         ecaFlag;
  eb_cycle_t        cycle;
  int               pMode=0;
  
  unsigned int      busIndex=-1;  // index of 1-wire bus connected to a controller
  

  int               i;            /* counter for comparing WR time with other device */
  int               nCompare = 5; /* number of compares                              */
  uint64_t          nsecsDiff64;
  int               diffIsPositive;               

  const char* devName;
  const char* devNameOther;

  int         getEBVersion=0;
  int         getBoardTemp=0;
  int         exitCode=0;

  unsigned int family = 0;

  eb_data_t   evtIdHigh;           // high 32bit of eventID   
  eb_data_t   evtIdLow;            // low 32bit of eventID    
  eb_data_t   evtDeadlHigh;        // high 32bit of deadline  
  eb_data_t   evtDeadlLow;         // low 32bit of deadline   
  eb_data_t   evtExeHigh;          // high 32bit of execution time
  eb_data_t   evtExeLow;           // low 32bit of execution time
  eb_data_t   evtParamHigh;        // high 32 bit of parameter field
  eb_data_t   evtParamLow ;        // low 32 bit of parameter field
  eb_data_t   actTag;              // tag of action           

  uint64_t   evtID;                // evtID of timing message
  uint64_t   evtDeadl;             // deadline of timing message
  uint64_t   evtExe;               // execution time of timing message
  uint64_t   evtDelay;             // delay time of execution (0: no delay)
  uint64_t   evtParam;             // param of timing message

  uint64_t   nEvents=20;
  uint64_t   evtDelayMax=0;

  uint64_t    nsecs64, nsecsOther64;
  uint64_t    nsecsSum64, nsecsSumOther64;
  uint64_t    nsecsRound64, nsecsRoundOther64;
  uint64_t    tmpa64, tmpb64;
  uint64_t    msecs64;
  uint64_t    hostmsecs64;
  int64_t     offset;
  uint64_t    mac;
  int         link;
  int         syncState;
  int         ip;
  uint64_t    id;
  double      temp;
  char linkStr[64];
  char syncStr[64];
  char timestr[60];
  time_t secs;
  const struct tm* tm;
  struct timeval htm;

  unsigned long pollInterval=10;
  int opt, error=0;
  char *tail;

  program = argv[0];

  while ((opt = getopt(argc, argv, "f:eh")) != -1) {
    switch (opt) {
    case 'f':
      family = strtol(optarg, &tail, 0);
      if (*tail != 0) {
        fprintf(stderr, "Specify a proper number, not '%s'!\n", optarg);
        exit(1);
      } /* if *tail */
      break;
    case 'e':
      getEBVersion=1;
      break;
    case 'h':
      help();
      return 0;
      case ':':
      case '?':
        error = 1;
      break;
    default:
      fprintf(stderr, "%s: bad getopt result\n", program);
      return 1;
    } /* switch opt */
  } /* while opt */

  if (error) {
    help();
    return 1;
  }
  
  if (optind >= argc) {
    fprintf(stderr, "%s: expecting one non-optional argument: <etherbone-device>\n", program);
    fprintf(stderr, "\n");
    help();
    return 1;
  }

  devName = argv[optind];
  if (devIndex < 0) devIndex = 0; // default: grab first device of the requested type on the wishbone bus 

  // open EB socket and device
  if ((status = eb_socket_open(EB_ABI_CODE, 0, EB_ADDR32|EB_DATA32, &socket)) != EB_OK)
    die("eb_socket_open", status);
  if ((status = eb_device_open(socket, devName, EB_ADDR32|EB_DATA32, 3, &device)) != EB_OK)
    die("eb_device_open", status);

  // find ECA Q for lm32 channel
  nDevices = ECAQMAX;
  ecaQ     = 0x0;
  // get sdb records of all ECA Qs
  if ((status = eb_sdb_find_by_identity(device, ECA_QUEUE_SDB_VENDOR_ID, ECA_QUEUE_SDB_DEVICE_ID, sdbDevice, &nDevices)) != EB_OK)
    die("ECAQ for lm32 eb_sdb_find_by_identity", status);
  // walk through ECA Qs and find the one for lm32
  for (i=0; i < nDevices; i++) {
    tmp = sdbDevice[i].sdb_component.addr_first;
    if ((status = eb_device_read(device, tmp + ECA_QUEUE_QUEUE_ID_GET,  EB_BIG_ENDIAN|EB_DATA32, &data, 0, eb_block)) != EB_OK)
      die("ECAQ eb_device_read", status);
    if (data ==  ECACHANNELFORLM32) ecaQ = tmp;
  } // for i

  if (!ecaQ) printf("FATAL: can't find ECA queue for lm32! \n");
  else printf("ECA queue found at: %08x. Waiting for actions ...\n", ecaQ);

  if (getEBVersion) {
    if (verbose) fprintf(stdout, "EB version / EB source: ");
    fprintf(stdout, "%s / %s\n", eb_source_version(), eb_build_info());
  }

 if (getBoardTemp) {
   if (!family) die("family code not specified (1-wire)", EB_OOM);
   fprintf(stdout, "%.4f\n", (float)temp);
 }

 evtDelayMax=0;
 while (nEvents > 0) {
   if ((status = eb_device_read(device, ecaQ + ECA_QUEUE_FLAGS_GET, EB_BIG_ENDIAN|EB_DATA32, &ecaFlag, 0, eb_block)) != EB_OK)
      die("ECAQ eb_device_read", status);
   if (ecaFlag & (0x0001 << ECA_VALID)) { // data is valid?

     nEvents--;

     
     if ((status = eb_cycle_open(device, 0, eb_block, &cycle)) != EB_OK)
       die("EP eb_cycle_open", status);
     
     /* Queueing operations to a cycle never fails (EB_OOM is reported later) */
     eb_cycle_read(cycle, ecaQ + ECA_QUEUE_EVENT_ID_HI_GET, EB_BIG_ENDIAN|EB_DATA32, &evtIdHigh);
     eb_cycle_read(cycle, ecaQ + ECA_QUEUE_EVENT_ID_LO_GET, EB_BIG_ENDIAN|EB_DATA32, &evtIdLow);
     eb_cycle_read(cycle, ecaQ + ECA_QUEUE_DEADLINE_HI_GET, EB_BIG_ENDIAN|EB_DATA32, &evtDeadlHigh);
     eb_cycle_read(cycle, ecaQ + ECA_QUEUE_DEADLINE_LO_GET, EB_BIG_ENDIAN|EB_DATA32, &evtDeadlLow);
     eb_cycle_read(cycle, ecaQ + ECA_QUEUE_EXECUTED_HI_GET, EB_BIG_ENDIAN|EB_DATA32, &evtExeHigh);
     eb_cycle_read(cycle, ecaQ + ECA_QUEUE_EXECUTED_LO_GET, EB_BIG_ENDIAN|EB_DATA32, &evtExeLow);
     //eb_cycle_read(cycle, ecaQ + ECA_QUEUE_PARAM_HI_GET, EB_BIG_ENDIAN|EB_DATA32, &evtParamHigh);
     //eb_cycle_read(cycle, ecaQ + ECA_QUEUE_PARAM_LO_GET, EB_BIG_ENDIAN|EB_DATA32, &evtParamLow);
     eb_cycle_write(cycle, ecaQ + ECA_QUEUE_POP_OWR, EB_BIG_ENDIAN|EB_DATA32, 0x1);
     if ((status = eb_cycle_close(cycle)) != EB_OK)
       die("EP eb_cycle_close", status);

     evtID = ((uint64_t)evtIdHigh << 32);
     evtID += evtIdLow;

     evtDeadl = ((uint64_t)evtDeadlHigh << 32);
     evtDeadl += evtDeadlLow;

     evtExe  = ((uint64_t)evtExeHigh << 32);
     evtExe  += evtExeLow;

     evtDelay = evtExe - evtDeadl;
     if (evtDelay > evtDelayMax) evtDelayMax = evtDelay;
     
     evtParam = ((uint64_t)evtParamHigh << 32);
     evtParam += evtParamLow;

     /*
     printf("tDeadline: %"PRIu64", ", evtDeadl);
     printf("EvtID: 0x%"PRIx64", ", evtID);
     printf("Param: 0x%"PRIx64"", evtParam);
     printf("delay: %f us", (double)evtDelay/1000.0); 
     printf("\n");
     */
  
   }
   usleep(pollInterval);
 } //poll ECA Q

 printf("evtDelayMax: %f [us]\n", (double)evtDelayMax / 1000.0);

 /* close handler cleanly */
 if ((status = eb_device_close(device)) != EB_OK)
   die("eb_device_close", status);
 if ((status = eb_socket_close(socket)) != EB_OK)
   die("eb_socket_close", status);
 


 return exitCode;
}
