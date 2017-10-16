#include <stdint.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "syscon.h"
#include "hw/memlayout.h"
#include "mprintf.h"
#include "display.h"
#include "irq.h"
#include "scu_bus.h"
#include "aux.h"
#include "mini_sdb.h"
#include "board.h"
#include "uart.h"
#include "w1.h"
#include "fg.h"
#include "cb.h"
#include "scu_mil.h"

#define MSI_SLAVE 0
#define MSI_WB_FG 2
#define SEND_SIG(SIG)     *(volatile unsigned int *)(char*)(pCpuMsiBox + fg_regs[channel].mbx_slot * 2) = SIG
#define SIG_REFILL      0
#define SIG_START       1
#define SIG_STOP_EMPTY  2
#define SIG_STOP_NEMPTY 3
#define SIG_ARMED       4
#define SIG_DISARMED    5

#define QUEUE_CNT 4
#define IRQ       0
#define SCUBUS    1
#define DEVBUS    2
#define DEVSIO    3

#define DEVB_MSI      0xdeb50000
#define SCUB_MSI      0x5cb50000

#define MIL_DRQ       0x2
#define MIL_DRY       0x1
#define MIL_INL       0x0


#define CLK_PERIOD (1000000 / USRCPUCLK) // USRCPUCLK in KHz
#define OFFS(SLOT) ((SLOT) * (1 << 16))

#define INTERVAL_1000MS 1000000000ULL
#define INTERVAL_2000MS 2000000000ULL
#define INTERVAL_10MS   10000000ULL
#define ALWAYS          0ULL


extern struct w1_bus wrpc_w1_bus;
extern inline int cbisEmpty(volatile struct channel_regs*, int);
extern inline int cbRead(volatile struct channel_buffer*, volatile struct channel_regs*, int, struct param_set*);
extern inline int cbisFull(volatile struct channel_regs*, int);
extern int cbgetCount(volatile struct channel_regs*, int); 
extern int scub_write_mil(volatile unsigned short *base, int slot, short data, short fc_ifc_addr);
extern int scub_write_mil_blk(volatile unsigned short *base, int slot, short *data, short fc_ifc_addr);
extern struct msi remove_msg(volatile struct message_buffer *mb, int queue);
extern int add_msg(volatile struct message_buffer *mb, int queue, struct msi m); 
extern int has_msg(volatile struct message_buffer *mb, int queue);

/* task prototypes */
void dev_sio_handler(int);
void dev_bus_handler(int);
void scu_bus_handler(int);
void cleanup_sio_dev(int);

#define SHARED __attribute__((section(".shared")))
uint64_t SHARED board_id           = -1;
uint64_t SHARED ext_id             = -1;
uint64_t SHARED backplane_id       = -1;
uint32_t SHARED board_temp         = -1;
uint32_t SHARED ext_temp           = -1;
uint32_t SHARED backplane_temp     = -1;
uint32_t SHARED fg_magic_number    = 0xdeadbeef;
uint32_t SHARED fg_version         = 0x3; // 0x2 saftlib,
                                          // 0x3 new msi system with mailbox
uint32_t SHARED fg_mb_slot         = -1;
uint32_t SHARED fg_num_channels    = MAX_FG_CHANNELS;
uint32_t SHARED fg_buffer_size     = BUFFER_SIZE;
uint32_t SHARED fg_macros[MAX_FG_MACROS] = {0}; // hi..lo bytes: slot, device, version, output-bits
struct channel_regs SHARED fg_regs[MAX_FG_CHANNELS]; 
struct channel_buffer SHARED fg_buffer[MAX_FG_CHANNELS];

volatile unsigned short* scub_base     = 0;
volatile unsigned int* scub_irq_base   = 0;
volatile unsigned int* scu_mil_base    = 0;
volatile unsigned int* mil_irq_base    = 0;
volatile unsigned int* wr_1wire_base   = 0;
volatile unsigned int* user_1wire_base = 0;
volatile unsigned int* cpu_info_base   = 0;

volatile unsigned int param_sent[MAX_FG_CHANNELS];
volatile int initialized[MAX_SCU_SLAVES] = {0};

void sw_irq_handler(unsigned int, unsigned int);

volatile struct message_buffer msg_buf[QUEUE_CNT] = {0};



uint64_t timeout[MAX_SCU_SLAVES] = {0}; 


void dev_failure(int status, int slot) {
  char err_message0[20] = "OKAY";
  char err_message1[20] = "TRM NOT FREE";
  char err_message2[20] = "RCV ERROR";
  char err_message3[20] = "RCV TIMEOUT"; 
  char err_message4[20] = "RCV_TASK_ERR";

  if (status == OKAY) 
    mprintf("dev bus access in slot %d failed with message %s\n", slot, err_message0);
  else if (status == TRM_NOT_FREE) 
    mprintf("dev bus access in slot %d failed with message %s\n", slot, err_message1);
  else if (status == RCV_ERROR) 
    mprintf("dev bus access in slot %d failed with message %s\n", slot, err_message2);
  else if(status == RCV_TIMEOUT) 
    mprintf("dev bus access in slot %d failed with message %s\n", slot, err_message3);
  else if(status == RCV_TASK_ERR)
    mprintf("dev bus access in slot %d failed with message %s\n", slot, err_message4);
  else
    mprintf("dev bus access in slot %d failed with code %d\n", slot, status);
}


void show_msi()
{
  mprintf(" Msg:\t%08x\nAdr:\t%08x\nSel:\t%01x\n", global_msi.msg, global_msi.adr, global_msi.sel);

}

void isr0()
{
   mprintf("ISR0\n");
   show_msi();
}


void enable_scub_msis(int channel) {
  int slot;
  slot = fg_macros[fg_regs[channel].macro_number] >> 24;  //dereference slot number
  
  if (channel >= 0 && channel < MAX_FG_CHANNELS) {

    if (((slot & 0xf0) == 0) || (slot & DEV_SIO)){
      //SCU Bus Master
      scub_base[GLOBAL_IRQ_ENA] = 0x20;              // enable slave irqs in scu bus master
      scub_irq_base[8]  = (slot & 0xf)-1;            // channel select
      scub_irq_base[9]  = (slot & 0xf)-1;            // msg: slot number
      scub_irq_base[10] = (uint32_t)pMyMsi + 0x0;    // msi queue destination address of this cpu
      scub_irq_base[2]  = (1 << ((slot & 0xf) - 1)); // enable slave
      //mprintf("IRQs for slave %d enabled.\n", (slot & 0xf));
    } else if (slot & DEV_MIL_EXT) {
      mil_irq_base[8]   = MIL_DRQ;
      mil_irq_base[9]   = MIL_DRQ;
      mil_irq_base[10]  = (uint32_t)pMyMsi + 0x20;

      //mil_irq_base[8]   = MIL_DRY;
      //mil_irq_base[9]   = MIL_DRY;
      //mil_irq_base[10]  = (uint32_t)pMyMsi + 0x20;
      
      //mil_irq_base[8]   = MIL_INL;
      //mil_irq_base[9]   = MIL_INL;
      //mil_irq_base[10]  = (uint32_t)pMyMsi + 0x20;
      //mil_irq_base[2]   = (1 << MIL_INL) | (1 << MIL_DRY) | (1 << MIL_DRQ);
      mil_irq_base[2]   = (1 << MIL_DRQ);
    }
  }
}

void disable_slave_irq(int channel) {
  int slot, dev;
  int status;
  if (channel >= 0 && channel < MAX_FG_CHANNELS) {
    slot = fg_macros[fg_regs[channel].macro_number] >> 24;          //slot number
    dev = (fg_macros[fg_regs[channel].macro_number] >> 16) & 0xff;  //dev number
    
    if ((slot & 0xf0) == 0) {
      if (dev == 0)
        scub_base[OFFS(slot) + SLAVE_INT_ENA] &= ~(0x8000);       //disable fg1 irq
      else if (dev == 1)
        scub_base[OFFS(slot) + SLAVE_INT_ENA] &= ~(0x4000);       //disable fg2 irq
    } else if (slot & DEV_MIL_EXT) {
      //write_mil(scu_mil_base, 0x0, FC_COEFF_A_WR | dev);            //ack drq
      if ((status = write_mil(scu_mil_base, 0x0, FC_IRQ_MSK | dev)) != OKAY) dev_failure(status, slot & 0xf);  //mask drq
    } else if (slot & DEV_SIO) {
      if ((status = scub_write_mil(scub_base, slot & 0xf, 0x0, FC_IRQ_MSK | dev)) != OKAY) dev_failure(status, slot & 0xf);  //mask drq
    }

    //mprintf("IRQs for slave %d disabled.\n", slot);
  }
}

void msDelayBig(uint64_t ms)
{
  uint64_t later = getSysTime() + ms * 1000000ULL / 8;
  while(getSysTime() < later) {asm("# noop");}
}

void msDelay(uint32_t msecs) {
  usleep(1000 * msecs);
}


inline void send_fg_param(int slot, int fg_base, unsigned short cntrl_reg) {
  struct param_set pset;
  int fg_num;
  unsigned short cntrl_reg_wr;
  int status;
  short blk_data[6];
  
  fg_num = (cntrl_reg & 0x3f0) >> 4; // virtual fg number Bits 9..4
  if (cbRead(&fg_buffer[0], &fg_regs[0], fg_num, &pset)) {
    cntrl_reg_wr = cntrl_reg & ~(0xfc00); // clear freq and step select
    cntrl_reg_wr = cntrl_reg & ~(0x7);    // clear fg_running and fg_enabled
    cntrl_reg_wr |= ((pset.control & 0x38) << 10) | ((pset.control & 0x7) << 10);
    blk_data[0] = cntrl_reg_wr;
    blk_data[1] = pset.coeff_a;
    blk_data[2] = pset.coeff_b;
    blk_data[3] = (pset.control & 0x3ffc0) >> 6;     // shift a 17..12 shift b 11..6
    blk_data[4] = pset.coeff_c & 0xffff;
    blk_data[5] = (pset.coeff_c & 0xffff0000) >> 16; // data written with high word

    if ((slot & 0xf0) == 0) {
      scub_base[OFFS(slot) + fg_base + FG_CNTRL]  = blk_data[0];
      scub_base[OFFS(slot) + fg_base + FG_A]      = blk_data[1];
      scub_base[OFFS(slot) + fg_base + FG_B]      = blk_data[2];
      scub_base[OFFS(slot) + fg_base + FG_SHIFT]  = blk_data[3];
      scub_base[OFFS(slot) + fg_base + FG_STARTL] = blk_data[4];
      scub_base[OFFS(slot) + fg_base + FG_STARTH] = blk_data[5];
    } else if (slot & DEV_MIL_EXT) {
      // transmit in one block transfer over the dev bus
      if((status = write_mil_blk(scu_mil_base, &blk_data[0], FC_BLK_WR | fg_base)) != OKAY) dev_failure(status, slot & 0xf);
      // still in block mode !
    } else if (slot & DEV_SIO) {
      // transmit in one block transfer over the dev bus
      if((status = scub_write_mil_blk(scub_base, slot & 0xf, &blk_data[0], FC_BLK_WR | fg_base)) != OKAY) {
        dev_failure(status, slot & 0xf);
        mprintf("send_fg_param\n");
      }
      // still in block mode !
    }
    param_sent[fg_num]++;
  }
}

inline void handle(int slot, unsigned fg_base, short irq_act_reg) {
    unsigned short cntrl_reg = 0;
    int status;
    int channel;

    if ((slot & 0xf0) == 0){
      cntrl_reg = scub_base[OFFS(slot) + fg_base + FG_CNTRL];
      channel = (cntrl_reg & 0x3f0) >> 4;     // virtual fg number Bits 9..4
    } else if ((slot & DEV_MIL_EXT) || (slot & DEV_SIO)) {
      channel = (irq_act_reg & 0x3f0) >> 4;   // virtual fg number Bits 9..4
    } 
    
    if ((slot & 0xf0) == 0) {
      /* last cnt from from fg macro, read from LO address copies hardware counter to shadow reg */
      fg_regs[channel].ramp_count = scub_base[OFFS(slot) + fg_base + FG_RAMP_CNT_LO];
      fg_regs[channel].ramp_count |= scub_base[OFFS(slot) + fg_base + FG_RAMP_CNT_HI] << 16;
    } else if ((slot & DEV_MIL_EXT) || (slot & DEV_SIO)) {
      /* count in software only */
      fg_regs[channel].ramp_count++;
    }
      
    if ((slot & 0xf0) == 0) {
      if (!(cntrl_reg  & FG_RUNNING)) {       // fg stopped
        if (cbisEmpty(&fg_regs[0], channel))
          SEND_SIG(SIG_STOP_EMPTY);           // normal stop
        else
          SEND_SIG(SIG_STOP_NEMPTY);          // something went wrong
        disable_slave_irq(channel);
        fg_regs[channel].state = 0;
      }
    } else {
      if (!(irq_act_reg  & FG_RUNNING)) {     // fg stopped
        fg_regs[channel].ramp_count--;
        if (cbisEmpty(&fg_regs[0], channel))
          SEND_SIG(SIG_STOP_EMPTY);           // normal stop
        else
          SEND_SIG(SIG_STOP_NEMPTY);          // something went wrong
        disable_slave_irq(channel);
        fg_regs[channel].state = 0;
      }
    }

    if ((slot & 0xf0) == 0) {
      if ((cntrl_reg & FG_RUNNING) && !(cntrl_reg & FG_DREQ)) {
        fg_regs[channel].state = 1; 
        SEND_SIG(SIG_START); // fg has received the tag or brc message
        if (cbgetCount(&fg_regs[0], channel) == THRESHOLD)
          SEND_SIG(SIG_REFILL);
        send_fg_param(slot, fg_base, cntrl_reg);
      } else if ((cntrl_reg & FG_RUNNING) && (cntrl_reg & FG_DREQ)) {
        if (cbgetCount(&fg_regs[0], channel) == THRESHOLD)
          SEND_SIG(SIG_REFILL);
        send_fg_param(slot, fg_base, cntrl_reg);
      }
    } else {
      if ((irq_act_reg & FG_RUNNING) && (irq_act_reg & DEV_STATE_IRQ)){
        fg_regs[channel].state = 1; 
        SEND_SIG(SIG_START); // fg has received the tag or brc message
        if (cbgetCount(&fg_regs[0], channel) == THRESHOLD)
          SEND_SIG(SIG_REFILL);
        send_fg_param(slot, fg_base, irq_act_reg);
      } else if (irq_act_reg & (FG_RUNNING | DEV_DRQ)) {
        if (cbgetCount(&fg_regs[0], channel) == THRESHOLD)
          SEND_SIG(SIG_REFILL);
        send_fg_param(slot, fg_base, irq_act_reg);
      }
    }
}

void irq_handler() {
  struct msi m;

  // send msi threadsafe to main loop
  m.msg = global_msi.msg;
  m.adr = global_msi.adr;
  add_msg(&msg_buf[0], IRQ, m);
}


int configure_fg_macro(int channel) {
  int i = 0;
  int slot, dev, fg_base, dac_base;
  unsigned short cntrl_reg_wr;
  struct param_set pset;
  short blk_data[6];
  int status;
  
  if (channel >= 0 && channel < MAX_FG_CHANNELS) {
    /* actions per slave card */
    slot = fg_macros[fg_regs[channel].macro_number] >> 24;          //dereference slot number
    dev =  (fg_macros[fg_regs[channel].macro_number] >> 16) & 0xff; //dereference dev number

    /* enable irqs */
    if ((slot & 0xf0) == 0) {                                      //scu bus slave
      scub_base[SRQ_ENA] |= (1 << (slot-1));                // enable irqs for the slave
      scub_base[OFFS(slot) + SLAVE_INT_ACT] = 0xc000;  // clear all irqs
      scub_base[OFFS(slot) + SLAVE_INT_ENA] |= 0xc000; // enable fg1 and fg2 irq
    } else if (slot & DEV_MIL_EXT) {
      if ((status = write_mil(scu_mil_base, 1 << 13, FC_IRQ_MSK | dev)) != OKAY) dev_failure(status, slot & 0xf); //enable Data-Request
    } else if (slot & DEV_SIO) {
      scub_base[SRQ_ENA] |= (1 << ((slot & 0xf)-1));            // enable irqs for the slave
      scub_base[OFFS(slot & 0xf) + SLAVE_INT_ENA] = 0x0010; // enable receiving of drq
      if ((status = scub_write_mil(scub_base, slot & 0xf, 1 << 13, FC_IRQ_MSK | dev)) != OKAY) dev_failure(status, slot & 0xf); //enable sending of drq
    }

    /* which macro are we? */
    if ((slot & 0xf0) == 0) {                                      //scu bus slave
      if (dev == 0) {
        fg_base = FG1_BASE;
        dac_base = DAC1_BASE;
      } else if (dev == 1) {
        fg_base = FG2_BASE;
        dac_base = DAC2_BASE;
      } else
        return -1;
    }     
    
    /* fg mode and reset */    
    if ((slot & 0xf0) == 0) {                                      //scu bus slave
      scub_base[OFFS(slot) + dac_base + DAC_CNTRL] = 0x10;        // set FG mode
      scub_base[OFFS(slot) + fg_base + FG_CNTRL] = 0x1;           // reset fg
    } else if (slot & DEV_MIL_EXT) {
      if ((status = write_mil(scu_mil_base, 0x1, FC_IFAMODE_WR | dev)) != OKAY)   dev_failure (status, 0); // set FG mode
      if ((status = write_mil(scu_mil_base, 0x1, FC_CNTRL_WR | dev)) != OKAY) dev_failure (status, 0); // reset fg
    } else if (slot & DEV_SIO) {
      if ((status = scub_write_mil(scub_base, slot & 0xf, 0x1, FC_IFAMODE_WR | dev)) != OKAY)   dev_failure (status, slot & 0xf); // set FG mode
      if ((status = scub_write_mil(scub_base, slot & 0xf, 0x1, FC_CNTRL_WR | dev)) != OKAY) dev_failure (status, slot & 0xf); // reset fg
    }

    //fetch first parameter set from buffer
    if (cbRead(&fg_buffer[0], &fg_regs[0], channel, &pset)) {
      cntrl_reg_wr = ((pset.control & 0x38) << 10) | ((pset.control & 0x7) << 10) | channel << 4;
      blk_data[0] = cntrl_reg_wr;
      blk_data[1] = pset.coeff_a;
      blk_data[2] = pset.coeff_b;
      blk_data[3] = (pset.control & 0x3ffc0) >> 6;     // shift a 17..12 shift b 11..6
      blk_data[4] = pset.coeff_c & 0xffff;
      blk_data[5] = (pset.coeff_c & 0xffff0000) >> 16; // data written with high word

      if ((slot & 0xf0) == 0) {
        //set virtual fg number Bit 9..4
        scub_base[OFFS(slot) + fg_base + FG_CNTRL]  = blk_data[0];
        scub_base[OFFS(slot) + fg_base + FG_A]      = blk_data[1];
        scub_base[OFFS(slot) + fg_base + FG_B]      = blk_data[2];
        scub_base[OFFS(slot) + fg_base + FG_SHIFT]  = blk_data[3];
        scub_base[OFFS(slot) + fg_base + FG_STARTL] = blk_data[4];
        scub_base[OFFS(slot) + fg_base + FG_STARTH] = blk_data[5];

      } else if (slot & DEV_MIL_EXT) {
        // transmit in one block transfer over the dev bus
        if((status = write_mil_blk(scu_mil_base, &blk_data[0], FC_BLK_WR | dev)) != OKAY) dev_failure (status, 0);
        // still in block mode !
        if((status = write_mil(scu_mil_base, cntrl_reg_wr, FC_CNTRL_WR | dev)) != OKAY)   dev_failure (status, 0);

      } else if (slot & DEV_SIO) {
        // transmit in one block transfer over the dev bus
        if((status = scub_write_mil_blk(scub_base, slot & 0xf, &blk_data[0], FC_BLK_WR | dev))  != OKAY) dev_failure (status, slot & 0xf);
        // still in block mode !
        if((status = scub_write_mil(scub_base, slot & 0xf, cntrl_reg_wr, FC_CNTRL_WR | dev))  != OKAY)   dev_failure (status, slot & 0xf);

      }

      param_sent[i]++;
    }

    /* configure and enable macro */
    if ((slot & 0xf0) == 0) {
      scub_base[OFFS(slot) + fg_base + FG_TAG_LOW] = fg_regs[channel].tag & 0xffff;
      scub_base[OFFS(slot) + fg_base + FG_TAG_HIGH] = fg_regs[channel].tag >> 16;
      scub_base[OFFS(slot) + fg_base + FG_CNTRL] |= FG_ENABLED;

    } else if (slot & DEV_MIL_EXT) {
      short data;
      //if ((status = read_mil(scu_mil_base, &data, FC_CNTRL_RD | dev)) != OKAY)                       dev_failure (status, 0);
      // enable and end block mode
      if ((status = write_mil(scu_mil_base, cntrl_reg_wr | FG_ENABLED, FC_CNTRL_WR | dev)) != OKAY) dev_failure (status, 0);

    } else if (slot & DEV_SIO) {
      short data;
      //if ((status = scub_read_mil(scub_base, slot & 0xf, &data, FC_CNTRL_RD | dev)) != OKAY)                       dev_failure (status, slot & 0xf);
      // enable and end block mode
      if ((status = scub_write_mil(scub_base, slot & 0xf, cntrl_reg_wr | FG_ENABLED, FC_CNTRL_WR | dev)) != OKAY) dev_failure (status, slot & 0xf);
    }

    fg_regs[channel].state = 2; //armed
    SEND_SIG(SIG_ARMED);
  }
  return 0; 
} 

/* scans for fgs on mil extension and scu bus */
void print_fgs() { 
  int i=0;
  for(i=0; i < MAX_FG_MACROS; i++)
    fg_macros[i] = 0;
  scan_scu_bus(scub_base, scu_mil_base, &fg_macros[0]);

  i=0;
  while(i < MAX_FG_MACROS) {
    // hi..lo bytes: slot, device, version, output-bits
    if (fg_macros[i] != 0)
      mprintf("fg-%d-%d ver: %d output-bits: %d\n", fg_macros[i] >> 24,
              (fg_macros[i] >> 16) & 0xff, (fg_macros[i] >> 8) & 0xff,
              fg_macros[i] & 0xff);
    i++;
  } 
}

void print_regs() {
  int i;
  for(i=0; i < MAX_FG_CHANNELS; i++) {
    mprintf("channel[%d].wr_ptr %d\n", i, fg_regs[i].wr_ptr);
    mprintf("channel[%d].rd_ptr %d\n", i, fg_regs[i].rd_ptr);
    mprintf("channel[%d].mbx_slot 0x%x\n", i, fg_regs[i].mbx_slot);
    mprintf("channel[%d].macro_number %d\n", i, fg_regs[i].macro_number);
    mprintf("channel[%d].ramp_count %d\n", i, fg_regs[i].ramp_count);
    mprintf("channel[%d].tag 0x%x\n", i, fg_regs[i].tag);
    mprintf("channel[%d].state %d\n", i, fg_regs[i].state);
    mprintf("\n");
  } 
}

void disable_channel(unsigned int channel) {
  int slot, dev, fg_base, dac_base;
  short data;
  int status;
  if (fg_regs[channel].macro_number == -1) return;
  slot = fg_macros[fg_regs[channel].macro_number] >> 24;         //dereference slot number
  dev = (fg_macros[fg_regs[channel].macro_number] >> 16) & 0xff; //dereference dev number
  //mprintf("disarmed slot %d dev %d in channel[%d] state %d\n", slot, dev, channel, fg_regs[channel].state); //ONLY FOR TESTING
  if ((slot & 0xf0) == 0) {
    /* which macro are we? */
    if (dev == 0) {
      fg_base = FG1_BASE;
      dac_base = DAC1_BASE;
    } else if (dev == 1) {
      fg_base = FG2_BASE;
      dac_base = DAC2_BASE;
    } else
      return;

    // disarm hardware
    scub_base[OFFS(slot) + fg_base + FG_CNTRL] &= ~(0x2);
    scub_base[OFFS(slot) + dac_base + DAC_CNTRL] &= ~(0x10); // unset FG mode

  } else if (slot & DEV_MIL_EXT) {
    // disarm hardware
    if((status = read_mil(scu_mil_base, &data, FC_CNTRL_RD | dev)) != OKAY)          dev_failure(status, 0); 
    if((status = write_mil(scu_mil_base, data & ~(0x2), FC_CNTRL_WR | dev)) != OKAY) dev_failure(status, 0); 
    //write_mil(scu_mil_base, 0x0, 0x60 << 8 | dev);             // unset FG mode

  } else if (slot & DEV_SIO) {
    // disarm hardware
    if((status = scub_read_mil(scub_base, slot & 0xf, &data, FC_CNTRL_RD | dev)) != OKAY)          dev_failure(status, slot & 0xf); 
    if((status = scub_write_mil(scub_base, slot & 0xf, data & ~(0x2), FC_CNTRL_WR | dev)) != OKAY) dev_failure(status, slot & 0xf); 
    //write_mil(scu_mil_base, 0x0, 0x60 << 8 | dev);             // unset FG mode
  }


  if (fg_regs[channel].state == 1) {    // hw is running
    fg_regs[channel].rd_ptr = fg_regs[channel].wr_ptr;
  } else {
    fg_regs[channel].state = 0;
    SEND_SIG(SIG_DISARMED);
  } 
}

void updateTemp() {
  BASE_ONEWIRE = (unsigned char *)wr_1wire_base;
  wrpc_w1_init();
  ReadTempDevices(0, &board_id, &board_temp);
  BASE_ONEWIRE = (unsigned char *)user_1wire_base;
  wrpc_w1_init();
  ReadTempDevices(0, &ext_id, &ext_temp);
  ReadTempDevices(1, &backplane_id, &backplane_temp);
  BASE_ONEWIRE = (unsigned char *)wr_1wire_base; // important for PTP deamon 
  wrpc_w1_init();
}

void tmr_irq_handler() {
  //updateTemp();
}

void init_irq_table() {
  isr_table_clr();
  isr_ptr_table[0] = &irq_handler;
  irq_set_mask(0x01);
  msg_buf[IRQ].ring_head = msg_buf[IRQ].ring_tail; // clear msg buffer
  irq_enable();
  mprintf("IRQ table configured.\n");
}


void init() {
  int i;
  for (i=0; i < MAX_FG_CHANNELS; i++)
    fg_regs[i].macro_number = -1;     //no macros assigned to channels at startup
  updateTemp();                       //update 1Wire ID and temperatures
  print_fgs();                        //scans for slave cards and fgs
} 

void _segfault(int sig)
{
  mprintf("KABOOM!\n");
  //while (1) {}
  return;
}

void sw_irq_handler(unsigned int adr, unsigned int msg) {
  int i;
  unsigned int code, value;
  struct param_set pset;
  
  if (adr != 0x10)
    return;
    
  code = msg >> 16;
  value = msg & 0xffff;

  switch(code) {
    case 0:
      init_buffers(&fg_regs[0], msg, &fg_macros[0], scub_base, scu_mil_base);
      param_sent[value] = 0;
    break;
    case 1:
      //configure_timer(value);
      //enable_scub_msis(value);
      //scub_base[OFFS(0xd) + TMR_BASE + TMR_CNTRL] = 0x2; //multicast tmr enable
    break;
    case 2:
      enable_scub_msis(value);
      configure_fg_macro(value);
      //print_regs();
    break;
    case 3:
      disable_channel(value);
    break;
    case 4:
      for (i = 0; i < MAX_FG_CHANNELS; i++)
        mprintf("fg[%d] buffer: %d param_sent: %d\n", i, cbgetCount(&fg_regs[0], i), param_sent[i]);
    break;
    case 5:
      if (value >= 0 && value < MAX_FG_CHANNELS) {
        if(!cbisEmpty(&fg_regs[0], value)) {
          cbRead(&fg_buffer[0], &fg_regs[0], value, &pset);
          mprintf("read buffer[%d]: a %d, l_a %d, b %d, l_b %d, c %d, n %d\n",
                   value, pset.coeff_a, (pset.control & 0x1f000) >> 12, pset.coeff_b,
                   (pset.control & 0xfc0) >> 6, pset.coeff_c, (pset.control & 0x7));
        } else {
          mprintf("read buffer[%d]: buffer empty!\n", value);
        }
          
      }
    break;
    default:
      mprintf("swi: 0x%x\n", adr);
      mprintf("     0x%x\n", msg);
    break;
  }
}

/* tells if a sio card has enabled dev bus slaves */
/* 1 <= sio_slave_nr <= MAX_SCU_SLAVES            */
int is_active_sio(unsigned int sio_slave_nr) {
  int i, slot;
  for (i = 0; i < MAX_FG_CHANNELS; i++) {
    if (fg_regs[i].state > 0) {
      slot = fg_macros[fg_regs[i].macro_number] >> 24;
      /* is sio and has active fgs */
      if(((slot & 0xf) == sio_slave_nr ) && (slot & DEV_SIO)) {
        return 1;
      }
    }
  }
  return 0;
}

/* declaration for the scheduler */

typedef struct {
  int state;
  int slave_nr;                    /* slave nr of the controlling sio card */
  short irq_data[MAX_FG_CHANNELS];
  int i;
  uint64_t timer;
  uint64_t interval;               /* interval of the task */
  uint64_t lasttick;               /* when was the task ran last */
  void (*func)(int);               /* pointer to the function of the task */
}TaskType;

/* task configuration table */
static TaskType tasks[] = {
  { 0, 0, {0}, 0, 0, ALWAYS         , 0, dev_sio_handler    }, // sio task 1
  { 0, 0, {0}, 0, 0, ALWAYS         , 0, dev_sio_handler    }, // sio task 2
  { 0, 0, {0}, 0, 0, ALWAYS         , 0, dev_sio_handler    }, // sio task 3
  { 0, 0, {0}, 0, 0, ALWAYS         , 0, dev_sio_handler    }, // sio task 4
  { 0, 0, {0}, 0, 0, ALWAYS         , 0, dev_bus_handler    },
  { 0, 0, {0}, 0, 0, ALWAYS         , 0, scu_bus_handler    },
  //{ 0, 0, {0}, 0, 0, INTERVAL_10MS  , 0, cleanup_sio_dev    },
};

TaskType *tsk_getConfig(void) {
  return tasks;
}

int tsk_getNumTasks(void) {
  return sizeof(tasks) / sizeof(*tasks);
}

/* task definition of scu_bus_handler */
void scu_bus_handler(int id) {
  volatile unsigned int slv_int_act_reg;
  unsigned char slave_nr;
  unsigned short slave_acks = 0;
  struct msi m;
  static TaskType *task_ptr;              // task pointer
  task_ptr = tsk_getConfig();             // get a pointer to the task configuration

  if (has_msg(&msg_buf[0], SCUBUS)) {

    m = remove_msg(&msg_buf[0], SCUBUS);
    if (m.adr == 0x0) {
      slave_nr = m.msg + 1;
      if (slave_nr < 0 || slave_nr > MAX_SCU_SLAVES) {
        mprintf("slave nr unknown.\n");
        return;
      }
      slv_int_act_reg = scub_base[OFFS(slave_nr) + SLAVE_INT_ACT];
      if (slv_int_act_reg & 0x1) {// powerup interrupt
        slave_acks |= 0x1;
      }
      if (slv_int_act_reg & FG1_IRQ) { //FG irq?
        handle(slave_nr, FG1_BASE, 0);
        slave_acks |= FG1_IRQ;
      } 
      if (slv_int_act_reg & FG2_IRQ) { //FG irq?
        handle(slave_nr, FG2_BASE, 0);
        slave_acks |= FG2_IRQ;
      } 
      if (slv_int_act_reg & DREQ) { //DRQ irq?
        add_msg(&msg_buf[0], DEVSIO, m);
        slave_acks |= DREQ;
      }
      scub_base[OFFS(slave_nr) + SLAVE_INT_ACT] = slave_acks; // ack all pending irqs 
    }
  } 
  return;
 
}

/* can have multiple instances, one for each active sio card controlling a dev bus       */
/* persistent data, like the state or the sio slave_nr, is stored in a global structure */
void dev_sio_handler(int id) {
  int i;
  int slot, dev;
  int status;
  short dummy_aquisition;
  struct msi m;
  static TaskType *task_ptr;              // task pointer
  task_ptr = tsk_getConfig();             // get a pointer to the task configuration
  
  //if (task_ptr[id].state != 0)
    ////mprintf("sio task id: %d state: %d\n", id, task_ptr[id].state);
  switch(task_ptr[id].state) {
    case 0:
      // we have nothing to do
      if (!has_msg(&msg_buf[0], DEVSIO))
        break;
      else
        m = remove_msg(&msg_buf[0], DEVSIO);
      
      task_ptr[id].slave_nr = m.msg + 1;
      //mprintf("state %d\n", task_ptr[id].state);
      /* poll all pending regs on the dev bus; non blocking read operation */
      for (i = 0; i < MAX_FG_CHANNELS; i++) {
        if (fg_regs[i].state > 0) {
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          /* test only ifas connected to sio */
          if(((slot & 0xf) == task_ptr[id].slave_nr ) && (slot & DEV_SIO)) {
            if ((status = scub_set_task_mil(scub_base, task_ptr[id].slave_nr, i + 1, FC_IRQ_ACT_RD | dev)) != OKAY) dev_failure(status, 20);
          }
        }
      }
      // clear old irq data
      for (i = 0; i < MAX_FG_CHANNELS; i++)
        task_ptr[id].irq_data[i] = 0;
      task_ptr[id].state = 1;
      break;
      
    case 1:
      //mprintf("state %d\n", task_ptr[id].state);
      /* fetch status from dev bus controller; */
      for (i = task_ptr[id].i; i < MAX_FG_CHANNELS; i++) {
        if (fg_regs[i].state > 0) {
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          /* test only ifas connected to sio */
          if(((slot & 0xf) == task_ptr[id].slave_nr ) && (slot & DEV_SIO)) {
            status = scub_get_task_mil(scub_base, task_ptr[id].slave_nr, i + 1, &task_ptr[id].irq_data[i]);
            if (status != OKAY) {
              if (status == RCV_TASK_BSY) {
                break; // break from for loop
              } else if (status == RCV_PARITY) {
                mprintf("parity error when reading task %d\n", task_ptr[id].slave_nr);
              } else if (status == RCV_TIMEOUT) {
                mprintf("timeout error when reading task %d\n", task_ptr[id].slave_nr);
              } else if (status == RCV_ERROR) {
                mprintf("unknown error when reading task %d\n", task_ptr[id].slave_nr);
              }
            }
          }
        }
      }
      if (status == RCV_TASK_BSY) {
        //mprintf("yield\n");
        task_ptr[id].i = i; // start next time from i
        break; //yield
      } else {
        task_ptr[id].i = 0; // start next time from 0
        task_ptr[id].state = 2;
        break;
      }

    case 2:
      //mprintf("state %d\n", task_ptr[id].state);
      /* handle irqs for ifas with active pending regs; non blocking write */
      for (i = 0; i < MAX_FG_CHANNELS; i++) {
        if (task_ptr[id].irq_data[i] & (DEV_STATE_IRQ | DEV_DRQ)) { // any irq pending?
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          handle(slot, dev, task_ptr[id].irq_data[i]);
          //clear irq pending and end block transfer
          if ((status = scub_write_mil(scub_base, task_ptr[id].slave_nr, 0, FC_IRQ_ACT_WR | dev)) != OKAY) dev_failure(status, 22);

        }
      }
      task_ptr[id].state = 3;
      break;

    case 3:
      //mprintf("state %d\n", task_ptr[id].state);
      /* dummy data aquisition */
      for (i = 0; i < MAX_FG_CHANNELS; i++) {
        if (task_ptr[id].irq_data[i] & (DEV_STATE_IRQ | DEV_DRQ)) { // any irq pending?
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          // non blocking read for DAQ
          if ((status = scub_set_task_mil(scub_base, task_ptr[id].slave_nr, i + 1, FC_CNTRL_RD | dev)) != OKAY) dev_failure(status, 23);
        }
      }
      task_ptr[id].state = 4;
      break;
    case 4:
      //mprintf("state %d\n", task_ptr[id].state);
      /* fetch daq data */
      for (i = task_ptr[id].i; i < MAX_FG_CHANNELS; i++) {
        if (task_ptr[id].irq_data[i] & (DEV_STATE_IRQ | DEV_DRQ)) { // any irq pending?
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          // fetch DAQ
          status = scub_get_task_mil(scub_base, task_ptr[id].slave_nr, i + 1, &dummy_aquisition);
          if (status != OKAY) {
            if (status == RCV_TASK_BSY) {
              break; // break from for loop
            } else if (status == RCV_PARITY) {
              mprintf("parity error when reading task %d\n", task_ptr[id].slave_nr);
            } else if (status == RCV_TIMEOUT) {
              mprintf("timeout error when reading task %d\n", task_ptr[id].slave_nr);
            } else if (status == RCV_ERROR) {
              mprintf("unknown error when reading task %d\n", task_ptr[id].slave_nr);
            }
          }
          //mprintf("daq: 0x%x\n", dummy_aquisition);
        }
      }
      if (status == RCV_TASK_BSY) {
        //mprintf("yield\n");
        task_ptr[id].i = i; // start next time from i
        break; //yield
      } else {
        task_ptr[id].i = 0; // start next time from 0
        task_ptr[id].state = 0;
        break;
      }
    default:
      mprintf("unknown state of dev bus handler!\n");
      task_ptr[id].state = 0;
      break;
  }

  return;
    
}

void dev_bus_handler(int id) {
  int i;
  int slot, dev;
  int status;
  short dummy_aquisition;
  struct msi m;
  static TaskType *task_ptr;              // task pointer
  task_ptr = tsk_getConfig();             // get a pointer to the task configuration
  
  switch(task_ptr[id].state) {
    case 0:
      // we have nothing to do
      if (!has_msg(&msg_buf[0], DEVBUS))
        break;
      else
        m = remove_msg(&msg_buf[0], DEVBUS);
      
      //mprintf("state %d\n", task_ptr[id].state);
      /* poll all pending regs on the dev bus; non blocking read operation */
      for (i = 0; i < MAX_FG_CHANNELS; i++) {
        if (fg_regs[i].state > 0) {
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          /* test only ifas connected to mil extension */
          if(slot & DEV_MIL_EXT) {
            if ((status = set_task_mil(scu_mil_base, i + 1, FC_IRQ_ACT_RD | dev)) != OKAY) dev_failure(status, 20);
          }
        }
      }  
      // clear old irq data
      for (i = 0; i < MAX_FG_CHANNELS; i++)
        task_ptr[id].irq_data[i] = 0;
      task_ptr[id].state = 1;
      break;
      
    case 1:
      //mprintf("state %d\n", task_ptr[id].state);
      /* fetch status from dev bus controller; */
      for (i = task_ptr[id].i; i < MAX_FG_CHANNELS; i++) {
        if (fg_regs[i].state > 0) {
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          /* test only ifas connected to mil extension */
          if(slot & DEV_MIL_EXT) {
            status = get_task_mil(scu_mil_base, i + 1, &task_ptr[id].irq_data[i]);
            if (status != OKAY) {
              if (status == RCV_TASK_BSY) {
                break; // break from for loop
              } else if (status == RCV_PARITY) {
                mprintf("parity error when reading task %d\n", task_ptr[id].slave_nr);
              } else if (status == RCV_TIMEOUT) {
                mprintf("timeout error when reading task %d\n", task_ptr[id].slave_nr);
              } else if (status == RCV_ERROR) {
                mprintf("unknown error when reading task %d\n", task_ptr[id].slave_nr);
              }
            }

          }
        }
      }
      if (status == RCV_TASK_BSY) {
        //mprintf("yield\n");
        task_ptr[id].i = i; // start next time from i
        break; //yield
      } else {
        task_ptr[id].i = 0; // start next time from 0
        task_ptr[id].state = 2;
        break;
      }

    case 2:
      //mprintf("state %d\n", task_ptr[id].state);
      /* handle irqs for ifas with active pending regs; non blocking write */
      for (i = 0; i < MAX_FG_CHANNELS; i++) {
        if (task_ptr[id].irq_data[i] & (DEV_STATE_IRQ | DEV_DRQ)) { // any irq pending?
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          handle(slot, dev, task_ptr[id].irq_data[i]);
          //clear irq pending and end block transfer
          if ((status = write_mil(scu_mil_base, 0, FC_IRQ_ACT_WR | dev)) != OKAY) dev_failure(status, 22);

        }
      }
      task_ptr[id].state = 3;
      break;

    case 3:
      //mprintf("state %d\n", task_ptr[id].state);
      /* dummy data aquisition */
      for (i = 0; i < MAX_FG_CHANNELS; i++) {
        if (task_ptr[id].irq_data[i] & (DEV_STATE_IRQ | DEV_DRQ)) { // any irq pending?
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          // non blocking read for DAQ
          if ((status = set_task_mil(scu_mil_base, i + 1, FC_CNTRL_RD | dev)) != OKAY) dev_failure(status, 23); 
        }
      }
      task_ptr[id].state = 4; 
      break;
    case 4:
      //mprintf("state %d\n", task_ptr[id].state);
      /* fetch daq data */
      for (i = task_ptr[id].i; i < MAX_FG_CHANNELS; i++) {
        if (task_ptr[id].irq_data[i] & (DEV_STATE_IRQ | DEV_DRQ)) { // any irq pending?
          slot = fg_macros[fg_regs[i].macro_number] >> 24;
          dev = (fg_macros[fg_regs[i].macro_number] & 0x00ff0000) >> 16;
          // fetch DAQ
          status = get_task_mil(scu_mil_base, i + 1, &dummy_aquisition);
          if (status != OKAY) {
            if (status == RCV_TASK_BSY) {
              break; // break from for loop
            } else if (status == RCV_PARITY) {
              mprintf("parity error when reading task %d\n", task_ptr[id].slave_nr);
            } else if (status == RCV_TIMEOUT) {
              mprintf("timeout error when reading task %d\n", task_ptr[id].slave_nr);
            } else if (status == RCV_ERROR) {
              mprintf("unknown error when reading task %d\n", task_ptr[id].slave_nr);
            }
          }
          //mprintf("daq: 0x%x\n", dummy_aquisition);
        };
      }  
      if (status == RCV_TASK_BSY) {
        //mprintf("yield\n");
        task_ptr[id].i = i; // start next time from i
        break; //yield
      } else {
        task_ptr[id].i = 0; // start next time from 0
        task_ptr[id].state = 0;
        break;
      }
    default:
      mprintf("unknown state of dev bus handler!\n");
      task_ptr[id].state = 0;
      break;
  }

  return;
    
}

void cleanup_sio_dev(int id) {
  unsigned short status;
  static TaskType *task_ptr;              // task pointer
  task_ptr = tsk_getConfig();             // get a pointer to the task configuration
  struct msi m;

  int slave_nr = (task_ptr[id].slave_nr % MAX_SCU_SLAVES);
  if (is_active_sio(slave_nr + 1)) {
    // create swi for dev_sio_handler
    m.msg = slave_nr;
    m.adr = 0;
    add_msg(&msg_buf[0], DEVSIO, m);
  }
  task_ptr[id].slave_nr++;
  return;
}


void addExecutionTime(int id, uint64_t time) {
  //mprintf("Task %d finished in: %d us.\n", id, (int)(time / 1000ULL));
}



int main(void) {
  int i, mb_slot;
  sdb_location found_sdb[20];
  uint32_t lm32_endp_idx = 0;
  uint32_t ow_base_idx = 0;
  uint32_t clu_cb_idx = 0;
  discoverPeriphery();
  uart_init_hw();
  /* additional periphery needed for scu */
  cpu_info_base = (unsigned int*)find_device_adr(GSI, CPU_INFO_ROM);  
  scub_base     = (unsigned short*)find_device_adr(GSI, SCU_BUS_MASTER);
  scub_irq_base = (unsigned int*)find_device_adr(GSI, SCU_IRQ_CTRL);    // irq controller for scu bus
  find_device_multi(&found_sdb[0], &clu_cb_idx, 20, GSI, LM32_CB_CLUSTER); // find location of cluster crossbar
  scu_mil_base  = (unsigned int*)find_device_adr(GSI,SCU_MIL); // mil extension macro
  mil_irq_base  = (unsigned int*)find_device_adr(GSI, MIL_IRQ_CTRL); // irq controller for dev bus extension
  wr_1wire_base = (unsigned int*)find_device_adr(CERN, WR_1Wire); // 1Wire controller in the WRC
  user_1wire_base = (unsigned int*)find_device_adr(GSI, User_1Wire); // 1Wire controller on dev crossbar
  

  mprintf("Found MsgBox at 0x%08x. MSI Path is 0x%08x\n", (uint32_t)pCpuMsiBox, (uint32_t)pMyMsi);
  mb_slot = getMsiBoxSlot(0x10);
  if (mb_slot == -1)
    mprintf("No free slots in MsgBox left!\n");
  else
    mprintf("Configured slot %d in MsgBox\n", mb_slot);
  fg_mb_slot = mb_slot; //tell saftlib the mailbox slot for sw irqs

  init_irq_table();  

  msDelayBig(1500); //wait for wr deamon to read sdbfs

  if ((int)BASE_SYSCON == ERROR_NOT_FOUND)
    mprintf("no SYS_CON found!\n"); 
  else
    mprintf("SYS_CON found on adr: 0x%x\n", BASE_SYSCON);

  timer_init(1); //needed by usleep_init() 
  usleep_init();
  
  if((int)cpu_info_base == ERROR_NOT_FOUND) {
    mprintf("no CPU INFO ROM found!\n");
  } else {
    mprintf("CPU ID: 0x%x\n", cpu_info_base[0]);
    mprintf("number MSI endpoints: %d\n", cpu_info_base[1]);
  }

  mprintf("wr_1wire_base is: 0x%x\n", wr_1wire_base);
  mprintf("user_1wire_base is: 0x%x\n", user_1wire_base);
  mprintf("scub_irq_base is: 0x%x\n", scub_irq_base);
  mprintf("mil_irq_base is: 0x%x\n", mil_irq_base);

  init(); // init and scan for fgs
  


  
  /* definition of task dispatch */
  /* move messages to the correct queue, depending on source */
  void dispatch(int id) {
    struct msi m;
    m = remove_msg(&msg_buf[0], IRQ);
    

    // software message from saftlib
    if ((m.adr & 0xff) == 0x10) {
      sw_irq_handler(m.adr, m.msg);
      return;

    // message from scu bus
    } else if ((m.adr & 0xff) == 0x0) {
      add_msg(&msg_buf[0], SCUBUS, m);
      return;

    // message from dev bus
    } else if ((m.adr & 0xff) == 0x20) {
      add_msg(&msg_buf[0], DEVBUS, m);
      return;
    }

    return;
  }

  static uint64_t tick = 0;               // system tick
  static TaskType *task_ptr;              // task pointer

  static int taskIndex = 0;               // task index
  const int numTasks = tsk_getNumTasks(); // number of tasks

  task_ptr = tsk_getConfig();             // get a pointer to the task configuration
  
  while(1) {
    tick = getSysTime(); /* FIXME get the current system tick */

    // loop through all task. first, run all continuous tasks. then, if the number of ticks
    // since the last time the task was run is greater than or equal to the task interval, execute the task
    for(taskIndex = 0; taskIndex < numTasks; taskIndex++) {

      // call the dispatch task before every other task
      dispatch(numTasks);
      
      if (task_ptr[taskIndex].interval == 0) {
        // run contiuous tasks
        (*task_ptr[taskIndex].func)(taskIndex);

      } else if ((tick - task_ptr[taskIndex].lasttick) >= task_ptr[taskIndex].interval) {
        // run task
        (*task_ptr[taskIndex].func)(taskIndex);
        task_ptr[taskIndex].lasttick = tick; // save last tick the task was ran

      }

    }
  }

  return(0);
}
