TARGET      = scu_control
DEVICE      = EP2AGX125
FLASH       = EPCS128
RAM_SIZE    = 98304
SHARED_SIZE = 40K
USRCPUCLK   = 125000
PATHSCU     = ../../../top/gsi_scu
CFLAGS      = -I$(PSCU)/include -I$(PATHSCU) -DHISTORY -fno-toplevel-reorder

include ../../build.mk

CFLAGS        += -O2

$(TARGET).elf: $(PATHSCU)/main.c  $(INCPATH)/display.c  $(PATHSCU)/cb.c \
                $(PATHSCU)/scu_bus.c $(PATHSCU)/scu_mil.c $(PATHSCU)/fg.c  \
		$(PATHSCU)/dow_crc.c $(PATHSCU)/history.c \
                $(W1)/dev/w1.c $(W1)/dev/w1-temp.c $(W1)/dev/w1-hw.c

clean::
	rm -f $(PATHSCU)/main.o $(W1)/dev/*.o

                
