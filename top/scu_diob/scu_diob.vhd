library ieee;  
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;
use work.scu_bus_slave_pkg.all;
use work.aux_functions_pkg.all;
use work.fg_quad_pkg.all;
use work.diob_sys_clk_local_clk_switch_pkg.all;


------------------------------------------------------------------------------------------------------------------------------------
--  Vers: 0 Revi: 4: erstellt am 12.12.2014, Autor: R.Hartmann                                                                    --
--                                                                                                                                --
--      Base_addr    : DIOB-Config-Register1 (alle Bit können gelesen und geschrieben werden)                                     --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--    15  | Leiterplatten-Test-Mode;  0 = Betrieb   / 1 = Test                                                                    --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--   14-0 |  frei                                                                                                                 --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--                                                                                                                                --
--      Base_addr +1 : DIOB-Config-Register2 (alle Bit können gelesen und geschrieben werden)                                     --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--   15-0 |  frei                                                                                                                 --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--                                                                                                                                --
--                                                                                                                                --
--      Base_addr +2 : DIOB-Status-Register1 (die Status-Bit's werden nach dem Lesen glöscht)                                     --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--      5 |  TAG-ID-Config-Error     | zwei oder mehr Ereigniskanäle mit gleicher Maske und gleichem Ausgangsregister             --
--      4 |  OutReg-Select-Error     | in einem oder mehr Ereigniskanälen ist kein Ausgangsregister ausgewählt                    --
--      3 |  TriggerReg-Select-Error | in einem oder mehr Ereigniskanälen ist kein Eingangsregister für Triggersignal ausgewählt  --
--      2 |  Unknown-OutReg-Select   | in einem oder mehr Ereigniskanälen ist ein nicht unterstütztes Ausgangsregister gewählt    --
--      1 |  Unknown-InReg-Select    | in einem oder mehr Ereigniskanälen ist ein nicht unterstütztes Eingangsregister gewählt    --
--      0 |  Trigger-Time-Out        | zulässige Wartezeit auf externes Triggersignal wurde überschritten (Time-Out)              -- 
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--                                                                                                                                --
--                                                                                                                                --
--      Base_addr +3 : DIOB-Status-Register1 (die Status-Bit's werden nach dem Lesen glöscht)                                     --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--   15-0 |  frei                                                                                                                 --
--   -----+-------------------------------------------------------------------------------------------------------------------    --
--                                                                                                                                --
--                                                                                                                                --
--     Base_addr + 4: Die Bits im Anwender(Piggy)Config-Register1 haben für jedes Piggy eine andere Bedeutung                     --
--                                                                                                                                --
--     ##########################################################################################################                 --
--     ####                                 Anwender-IO: P25IO  -- FG900_710                                  ###                 --
--     ##########################################################################################################                 --
--                                                                                                                                --
--   ----+----------------------------------------------------------------------------------------------------------------------  --
--     1 | Input:  1 = ADC-Daten aus dem Input-Speicher (gespeichert mit EOC)                                                     --
--       |         2 = Daten die am Sub-D Stecker anstehen.                                                                       --
--   ----+----------------------------------------------------------------------------------------------------------------------  --
--     0 | Output: 1 = Output-Daten(DAC-Werte), kommen vom Funktionsgen. und werden mit FG_Strobe uebernommen.                    --
--       |         0 = Output-Daten(DAC-Werte), kommen vom SCU-Bus-Slave.                                                         -- 
--   ----+----------------------------------------------------------------------------------------------------------------------  --
--                                                                                                                                --
--     ##########################################################################################################                 --
--     ####                                 Anwender-IO: P25IO  -- FG900_740                                  ###                 --
--     ##########################################################################################################                 --
--                                                                                                                                --
--   ----+-----------------------------------------------------------------------                                                 --
--     9 | FG_mode;  1 = Funktiongenerator-Mode, DAC-Werte kommen von FG_Data und                                                 --
--       |           0 = Software-Mode, DAC-Werte, kommen vom SCU-Bus-Slave.                                                      --
--   ----+-----------------------------------------------------------------------                                                 --
--     8 | Output-Polarität Lemo,         1 = Negativ,  0 = Positiv(Default)                                                      --
--     7 | Output-Polarität Bit [23..0],  1 = Negativ,  0 = Positiv(Default)                                                      --
--   ----+-----------------------------------------------------------------------                                                 --
--     6 | Enable Output-Lemo,            1 = Enable,   0 = Disable(Default)                                                      --
--     5 | Enable Output-Bit [23..20],    1 = Enable,   0 = Disable(Default)                                                      --
--     4 | Enable Output-Bit [19..16],    1 = Enable,   0 = Disable(Default)                                                      --
--     3 | Enable Output-Bit [15..12],    1 = Enable,   0 = Disable(Default)                                                      --
--     2 | Enable Output-Bit [11..8],     1 = Enable,   0 = Disable(Default)                                                      --
--     1 | Enable Output-Bit [7..4],      1 = Enable,   0 = Disable(Default)                                                      --
--     0 | Enable Output-Bit [3..0],      1 = Enable,   0 = Disable(Default)                                                      --
--   ----+-----------------------------------------------------------------------                                                 --
--                                                                                                                                --
------------------------------------------------------------------------------------------------------------------------------------


entity scu_diob is
generic (
    CLK_sys_in_Hz:      integer := 125000000
    );
port  (
    ------------------------------ Clocks -------------------------------------------------------------------------
    CLK_20MHz_A: in std_logic; -- Clock_A
    CLK_20MHz_B: in std_logic; -- Clock_B
    CLK_20MHz_C: in std_logic; -- Clock_C
    CLK_20MHz_D: in std_logic; -- Clock_D
   
    --------- Parallel SCU-Bus-Signale ----------------------------------------------------------------------------
    A_A: in std_logic_vector(15 downto 0); -- SCU-Adressbus
    A_nADR_EN: out std_logic := '0'; -- '0' => externe Adresstreiber des Slaves aktiv
    A_nADR_FROM_SCUB: out std_logic := '0'; -- '0' => externe Adresstreiber-Richtung: SCU-Bus nach Slave
    A_D: inout std_logic_vector(15 downto 0); -- SCU-Datenbus
    A_nDS: in std_logic; -- Data-Strobe vom Master gertieben
    A_RnW: in std_logic; -- Schreib/Lese-Signal vom Master getrieben, '0' => lesen
    A_nSel_Ext_Data_Drv: out std_logic; -- '0' => externe Datentreiber des Slaves aktiv
    A_Ext_Data_RD: out std_logic; -- '0' => externe Datentreiber-Richtung: SCU-Bus nach
                                                                -- Slave (besser default 0, oder Treiber A/B tauschen)
                                                                -- SCU-Bus nach Slave (besser default 0, oder Treiber A/B tauschen)
    A_nDtack: out std_logic; -- Data-Acknowlege null aktiv, '0' => aktiviert externen
                                                                -- Opendrain-Treiber
    A_nSRQ: out std_logic; -- Service-Request null aktiv, '0' => aktiviert externen
                                                                -- Opendrain-Treiber
    A_nBoardSel: in std_logic; -- '0' => Master aktiviert diesen Slave
    A_nEvent_Str: in std_logic; -- '0' => Master sigalisiert Timing-Zyklus
    A_SysClock: in std_logic; -- Clock vom Master getrieben.
    A_Spare0: in std_logic; -- vom Master getrieben
    A_Spare1: in std_logic; -- vom Master getrieben
    A_nReset: in std_logic; -- Reset (aktiv '0'), vom Master getrieben

    A_nSEL_Ext_Signal_DRV: out std_logic; -- '0' => Treiber fr SCU-Bus-Steuer-Signale aktiv
    A_nExt_Signal_in: out std_logic; -- '0' => Treiber fr SCU-Bus-Steuer-Signale-Richtung: SCU-Bus nach Slave (besser default 0, oder Treiber A/B tauschen)

    ----------------- OneWire ----------------------------------------------------------------------------------------
    A_OneWire: inout std_logic; -- Temp.-OneWire auf dem Slave
    
    ------------ Logic analyser Signals -------------------------------------------------------------------------------
    A_SEL: in std_logic_vector(3 downto 0); -- use to select sources for the logic analyser ports
    A_Tclk: out std_logic; -- Clock  for Logikanalysator Port A
    A_TA:   out std_logic_vector(15 downto 0); -- test port a
--    A_TA: inout std_logic_vector(15 downto 0); -- test port a

    ---------------------------------- Diagnose-LED's -----------------------------------------------------------------
    A_nLED_D2: out std_logic; -- Diagnose-LED_D2 auf dem Basis-Board
    A_nLED_D3: out std_logic; -- Diagnose-LED_D3 auf dem Basis-Board

    ------------ User I/O zur VG-Leiste -------------------------------------------------------------------------------
    A_nUser_EN: out std_logic; -- Enable User-I/O
    UIO: inout std_logic_vector(15 downto 0); -- User I/O VG-Leiste
  
    ---------------- bergabestecker fr Anwender-I/O -----------------------------------------------------------------
    CLK_IO: in std_logic; -- Clock vom Anwender_I/0
    PIO: inout std_logic_vector(150 downto 16)  -- Dig. User I/0 to Piggy
    );
end scu_diob;



architecture scu_diob_arch of scu_diob is



--  +============================================================================================================================+
--  |                                                Anfang: Component                                                           |
--  +============================================================================================================================+


component config_status
  generic ( CS_Base_addr  : integer );
  port (
    Adr_from_SCUB_LA:     in   std_logic_vector(15 downto 0);    -- latched address from SCU_Bus
    Data_from_SCUB_LA:    in   std_logic_vector(15 downto 0);    -- latched data from SCU_Bus 
    Ext_Adr_Val:          in   std_logic;                        -- '1' => "ADR_from_SCUB_LA" is valid
    Ext_Rd_active:        in   std_logic;                        -- '1' => Rd-Cycle is active
    Ext_Rd_fin:           in   std_logic;                        -- marks end of read cycle, active one for one clock period of sys_clk
    Ext_Wr_active:        in   std_logic;                        -- '1' => Wr-Cycle is active
    Ext_Wr_fin:           in   std_logic;                        -- marks end of write cycle, active one for one clock period of sys_clk
    clk:                  in   std_logic;                        -- should be the same clk, used by SCU_Bus_Slave
    nReset:               in   std_logic;

    Diob_Status1:         in   std_logic_vector(15 downto 0);    -- Input-Port 1
    Diob_Status2:         in   std_logic_vector(15 downto 0);    -- Input-Port 2
    AW_Status1:           in   std_logic_vector(15 downto 0);    -- Input-Port 3
    AW_Status2:           in   std_logic_vector(15 downto 0);    -- Input-Port 4
   
    Diob_Config1:         out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut1
    Diob_Config2:         out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut2
    AW_Config1:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut3
    AW_Config2:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut4

    Rd_active:            out  std_logic;                        -- read data available at 'Data_to_SCUB'-AWOut
    Data_to_SCUB:         out  std_logic_vector(15 downto 0);    -- connect read sources to SCUB-Macro
    Dtack_to_SCUB:        out  std_logic;                        -- connect Dtack to SCUB-Macro
    LA:                   out  std_logic_vector(15 downto 0)
      );
end component config_status;


component aw_io_reg
  generic ( AW_Base_addr  : integer );
  port (
        Adr_from_SCUB_LA:     in   std_logic_vector(15 downto 0);    -- latched address from SCU_Bus
        Data_from_SCUB_LA:    in   std_logic_vector(15 downto 0);    -- latched data from SCU_Bus 
        Ext_Adr_Val:          in   std_logic;                        -- '1' => "ADR_from_SCUB_LA" is valid
        Ext_Rd_active:        in   std_logic;                        -- '1' => Rd-Cycle is active
        Ext_Rd_fin:           in   std_logic;                        -- marks end of read cycle, active one for one clock period of sys_clk
        Ext_Wr_active:        in   std_logic;                        -- '1' => Wr-Cycle is active
        Ext_Wr_fin:           in   std_logic;                        -- marks end of write cycle, active one for one clock period of sys_clk
        clk:                  in   std_logic;                        -- should be the same clk, used by SCU_Bus_Slave
        nReset:               in   std_logic;
    
        AWIn1:                in   std_logic_vector(15 downto 0);    -- Input-Port 1
        AWIn2:                in   std_logic_vector(15 downto 0);    -- Input-Port 2
        AWIn3:                in   std_logic_vector(15 downto 0);    -- Input-Port 3
        AWIn4:                in   std_logic_vector(15 downto 0);    -- Input-Port 4
        AWIn5:                in   std_logic_vector(15 downto 0);    -- Input-Port 5
        AWIn6:                in   std_logic_vector(15 downto 0);    -- Input-Port 6
        AWIn7:                in   std_logic_vector(15 downto 0);    -- Input-Port 7
      
        AWOut_Reg1:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut1
        AWOut_Reg2:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut2
        AWOut_Reg3:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut3
        AWOut_Reg4:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut4
        AWOut_Reg5:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut5
        AWOut_Reg6:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut6
        AWOut_Reg7:           out  std_logic_vector(15 downto 0);    -- Daten-Reg. AWOut7

        AWOut_Reg1_wr:        out  std_logic;                      -- Daten-Reg. AWOut1
        AWOut_Reg2_wr:        out  std_logic;                      -- Daten-Reg. AWOut2
        AWOut_Reg3_wr:        out  std_logic;                      -- Daten-Reg. AWOut3
        AWOut_Reg4_wr:        out  std_logic;                      -- Daten-Reg. AWOut4
        AWOut_Reg5_wr:        out  std_logic;                      -- Daten-Reg. AWOut5
        AWOut_Reg6_wr:        out  std_logic;                      -- Daten-Reg. AWOut6
        AWOut_Reg7_wr:        out  std_logic;                      -- Daten-Reg. AWOut7
      
        Rd_active:            out  std_logic;                        -- read data available at 'Data_to_SCUB'-AWOut
        Data_to_SCUB:         out  std_logic_vector(15 downto 0);    -- connect read sources to SCUB-Macro
        Dtack_to_SCUB:        out  std_logic;                        -- connect Dtack to SCUB-Macro
        LA:                   out  std_logic_vector(15 downto 0)
      );
end component aw_io_reg;



component tag_ctrl
  generic ( TAG_Base_addr  : integer );
  port (
    Adr_from_SCUB_LA:     in   std_logic_vector(15 downto 0);    -- latched address from SCU_Bus
    Data_from_SCUB_LA:    in   std_logic_vector(15 downto 0);    -- latched data from SCU_Bus 
    Ext_Adr_Val:          in   std_logic;                        -- '1' => "ADR_from_SCUB_LA" is valid
    Ext_Rd_active:        in   std_logic;                        -- '1' => Rd-Cycle is active
    Ext_Rd_fin:           in   std_logic;                        -- marks end of read cycle, active one for one clock period of sys_clk
    Ext_Wr_active:        in   std_logic;                        -- '1' => Wr-Cycle is active
    Ext_Wr_fin:           in   std_logic;                        -- marks end of write cycle, active one for one clock period of sys_clk
    Timing_Pattern_LA:    in   std_logic_vector(31 downto 0);   -- latched timing pattern from SCU_Bus for external user functions
    Timing_Pattern_RCV:   in   std_logic;                        -- timing pattern received
    Spare0:               in   std_logic;                          -- vom Master getrieben
    Spare1:               in   std_logic;                          -- vom Master getrieben
    clk:                  in   std_logic;                            -- should be the same clk, used by SCU_Bus_Slave
    nReset:               in   std_logic;
    AWIn1:                in   std_logic_vector(15 downto 0);  -- Input-Port 1
    AWIn2:                in   std_logic_vector(15 downto 0);  -- Input-Port 2
    AWIn3:                in   std_logic_vector(15 downto 0);  -- Input-Port 3
    AWIn4:                in   std_logic_vector(15 downto 0);  -- Input-Port 4
    AWIn5:                in   std_logic_vector(15 downto 0);  -- Input-Port 5
    AWIn6:                in   std_logic_vector(15 downto 0);  -- Input-Port 6
    AWIn7:                in   std_logic_vector(15 downto 0);  -- Input-Port 7
    Max_AWOut_Reg_Nr:     in   integer range 0 to 7;           -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr:      in   integer range 0 to 7;           -- Maximale AWIn-Reg-Nummer der Anwendung
    
    Tag_Reg1_Maske:       out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Reg2_Maske:       out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Reg3_Maske:       out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Reg4_Maske:       out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Reg5_Maske:       out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Reg6_Maske:       out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Reg7_Maske:       out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1

    Tag_Outp_Reg1:        out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Outp_Reg2:        out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Outp_Reg3:        out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Outp_Reg4:        out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Outp_Reg5:        out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Outp_Reg6:        out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1
    Tag_Outp_Reg7:        out  std_logic_vector(15 downto 0);  -- Tag-Output-Maske für Register 1

    Tag_FG_Start:         out  std_logic;                      -- Start-Puls für den FG
    Tag_Sts:              out  std_logic_vector(15 downto 0);  -- Tag-Status

    Rd_active:            out  std_logic;                      -- read data available at 'Data_to_SCUB'-AWOut
    Data_to_SCUB:         out  std_logic_vector(15 downto 0);  -- connect read sources to SCUB-Macro
    Dtack_to_SCUB:        out  std_logic;                      -- connect Dtack to SCUB-Macro
    LA_tag_ctrl:          out  std_logic_vector(15 downto 0)
    );  
end component tag_ctrl;



COMPONENT io_reg
  GENERIC ( Base_addr : INTEGER );
  PORT
  (
    Adr_from_SCUB_LA:    IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    Data_from_SCUB_LA:   IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    Ext_Adr_Val:         IN  STD_LOGIC;
    Ext_Rd_active:       IN  STD_LOGIC;
    Ext_Rd_fin:          IN  STD_LOGIC;
    Ext_Wr_active:       IN  STD_LOGIC;
    Ext_Wr_fin:          IN  STD_LOGIC;
    clk:                 IN  STD_LOGIC;
    nReset:              IN  STD_LOGIC;
    Reg_IO1:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_IO2:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_IO3:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_IO4:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_IO5:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_IO6:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_IO7:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_IO8:             OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Reg_rd_active:       OUT STD_LOGIC;
    Data_to_SCUB:        OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    Dtack_to_SCUB:       OUT STD_LOGIC
  );
END COMPONENT io_reg;



component flash_loader_v01
port  (
    noe_in:   in    std_logic
    );
end component;


component pu_reset
generic (
    PU_Reset_in_clks : integer
    );
port  (
    Clk:      in    std_logic;
    PU_Res:   out   std_logic
    );
end component;



component zeitbasis
generic (
    CLK_in_Hz:      integer;
    diag_on:      integer
    );
port  (
    Res:        in  std_logic;
    Clk:        in  std_logic;
    Ena_every_100ns:  out std_logic;
    Ena_every_166ns:  out std_logic;
    Ena_every_250ns:  out std_logic;
    Ena_every_500ns:  out std_logic;
    Ena_every_1us:    out std_logic;
    Ena_Every_20ms:   out std_logic
    );
end component;


--  +============================================================================================================================+
--  |                                                    Ende: Component                                                         |
--  +============================================================================================================================+

  signal clk_sys, clk_cal, locked : std_logic;

  --  signal clk:                       std_logic := '0';

  signal SCUB_SRQ:            std_logic;
  signal SCUB_Dtack:          std_logic;
  signal convst:              std_logic;
  signal rst:                 std_logic;
  
  signal Dtack_to_SCUB:       std_logic;
  
  signal ADR_from_SCUB_LA:    std_logic_vector(15 downto 0);
  signal Data_from_SCUB_LA:   std_logic_vector(15 downto 0);
  signal Ext_Adr_Val:         std_logic;
  signal Ext_Rd_active:       std_logic;
  signal Ext_Wr_active:       std_logic;
  signal Ext_Wr_fin_ovl:      std_logic;
  signal Ext_RD_fin_ovl:      std_logic;
  signal SCU_Ext_Wr_fin:      std_logic;
  signal nPowerup_Res:        std_logic;
  signal Timing_Pattern_LA:   std_logic_vector(31 downto 0);--  latched timing pattern from SCU_Bus for external user functions
  signal Timing_Pattern_RCV:  std_logic;----------------------  timing pattern received
  
  signal extension_cid_system:  integer range 0 to 16#FFFF#;  -- in,  extension card: cid_system
  signal extension_cid_group:   integer range 0 to 16#FFFF#;  --in, extension card: cid_group

  signal Max_AWOut_Reg_Nr:      integer range 0 to 7;           -- Maximale AWOut-Reg-Nummer der Anwendung
  signal Max_AWIn_Reg_Nr:       integer range 0 to 7;           -- Maximale AWIn-Reg-Nummer der Anwendung

 
  signal FG_1_dtack:         std_logic;
  signal FG_1_data_to_SCUB:  std_logic_vector(15 downto 0);
  signal FG_1_rd_active:     std_logic;
  signal FG_1_sw:            std_logic_vector(31 downto 0);
  signal FG_1_strobe:        std_logic;
  signal FG_1_dreq:          std_logic;
  
  signal tmr_rd_active:      std_logic;
  signal tmr_data_to_SCUB:   std_logic_vector(15 downto 0);
  signal tmr_dtack:          std_logic;
  signal tmr_irq:            std_logic;
  
  signal led_ena_cnt:        std_logic;

  signal Data_to_SCUB:       std_logic_vector(15 downto 0);
  
  signal reset_clks :        std_logic_vector(0 downto 0);
  signal reset_rstn :        std_logic_vector(0 downto 0);
  signal clk_sys_rstn :      std_logic;
  
  signal owr_pwren_o:        std_logic_vector(1 downto 0);
  signal owr_en_o:           std_logic_vector(1 downto 0);
  signal owr_i:              std_logic_vector(1 downto 0);
  
  signal wb_scu_rd_active:    std_logic;
  signal wb_scu_dtack:        std_logic;
  signal wb_scu_data_to_SCUB: std_logic_vector(15 downto 0);
   

  signal Powerup_Res:     std_logic; -- only for modelsim!
  signal Powerup_Done:    std_logic;     -- this memory is set to one if an Powerup is done. Only the SCUB-Master can clear this bit.
  signal WRnRD:           std_logic; -- only for modelsim!

  signal Deb_SCUB_Reset_out:  std_logic;
  signal Standard_Reg_Acc:    std_logic;
  signal Ext_Rd_fin:          std_logic;
--  signal Ext_Wr_fin:          std_logic;

  
  signal Ena_Every_100ns: std_logic;
  signal Ena_Every_166ns: std_logic;
  signal Ena_Every_20ms:  std_logic;
  signal Ena_Every_1us:   std_logic;
  signal Ena_Every_250ms: std_logic;
  signal Ena_Every_500ms: std_logic;
 
  signal F_12p5_MHz:      std_logic;
   
  signal test_port_in_0:  std_logic_vector(15 downto 0);
  signal test_clocks:     std_logic_vector(15 downto 0);
  
  signal s_nLED_Sel:      std_logic;   -- LED = Sel
  signal s_nLED_Dtack:    std_logic;   -- LED = Dtack
  signal s_nLED_inR:      std_logic;   -- LED = interrupt
   
  signal s_nLED:          std_logic_vector(7 downto 0); -- LED's
  signal s_nLED_Out:      std_logic_vector(7 downto 0); -- LED's
  signal s_AW_ID:         std_logic_vector(7 downto 0); -- Anwender_ID
   
  signal AWin1:           std_logic_vector(15 downto 0);
  signal AWin2:           std_logic_vector(15 downto 0);
  signal AWin3:           std_logic_vector(15 downto 0);
  signal AWin4:           std_logic_vector(15 downto 0);
  signal AWin5:           std_logic_vector(15 downto 0);
  signal AWin6:           std_logic_vector(15 downto 0);
  signal AWin7:           std_logic_vector(15 downto 0);

  
--------------------------- Conf_Sts1 ----------------------------------------------------------------------
    
  signal DIOB_Config1:    std_logic_vector(15 downto 0);
  signal DIOB_Config2:    std_logic_vector(15 downto 0);
  signal DIOB_Status1:    std_logic_vector(15 downto 0);
  signal DIOB_Status2:    std_logic_vector(15 downto 0);
  signal AW_Config1:      std_logic_vector(15 downto 0);
  signal AW_Config2:      std_logic_vector(15 downto 0);
  signal AW_Status1:      std_logic_vector(15 downto 0);
  signal AW_Status2:      std_logic_vector(15 downto 0);

  signal Conf_Sts1_rd_active:    std_logic;
  signal Conf_Sts1_Dtack:        std_logic;
  signal Conf_Sts1_data_to_SCUB: std_logic_vector(15 downto 0);
  signal LA_Conf_Sts1:           std_logic_vector(15 downto 0);

  
--------------------------- AWOut ----------------------------------------------------------------------
    
  signal AWOut_Reg1_int:      std_logic_vector(15 downto 0);
  signal AWOut_Reg2_int:      std_logic_vector(15 downto 0);
  signal AWOut_Reg3_int:      std_logic_vector(15 downto 0);
  signal AWOut_Reg4_int:      std_logic_vector(15 downto 0);
  signal AWOut_Reg5_int:      std_logic_vector(15 downto 0);
  signal AWOut_Reg6_int:      std_logic_vector(15 downto 0);
  signal AWOut_Reg7_int:      std_logic_vector(15 downto 0);

  signal AWOut_Reg1_Wr:   std_logic;
  signal AWOut_Reg2_Wr:   std_logic;
  signal AWOut_Reg3_Wr:   std_logic;
  signal AWOut_Reg4_Wr:   std_logic;
  signal AWOut_Reg5_Wr:   std_logic;
  signal AWOut_Reg6_Wr:   std_logic;
  signal AWOut_Reg7_Wr:   std_logic;
  
  signal AW_Port1_rd_active:    std_logic;
  signal AW_Port1_Dtack:        std_logic;
  signal AW_Port1_data_to_SCUB: std_logic_vector(15 downto 0);
  signal Tag_Reg_Conf_Err:      std_logic;
  signal LA_AW_Port1:           std_logic_vector(15 downto 0);

--------------------------- Ctrl1 ----------------------------------------------------------------------
  
  signal Tag_Reg1_Maske:     std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Reg2_Maske:     std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Reg3_Maske:     std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Reg4_Maske:     std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Reg5_Maske:     std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Reg6_Maske:     std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Reg7_Maske:     std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Outp_Reg1:      std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Outp_Reg2:      std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Outp_Reg3:      std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Outp_Reg4:      std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Outp_Reg5:      std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Outp_Reg6:      std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1
  signal Tag_Outp_Reg7:      std_logic_vector(15 downto 0);       -- Tag-Output-Maske für Register 1


  signal Tag_FG_Start:           std_logic;                       -- Start-Puls für den FG
  signal Tag_Sts:                std_logic_vector(15 downto 0);   -- Tag-Status

  signal Tag_Ctrl1_rd_active:    std_logic;                       -- read data available at 'Data_to_SCUB'-Tag_Ctrl1
  signal Tag_Ctrl1_Dtack:        std_logic;                       -- connect read sources to SCUB-Macro         
  signal Tag_Ctrl1_data_to_SCUB: std_logic_vector(15 downto 0);   -- connect Dtack to SCUB-Macro                
  signal LA_Tag_Ctrl1:           std_logic_vector(15 downto 0);  
  

--------------------------- Ouput-Register ----------------------------------------------------------------------
    
  signal AWOut_Reg1:      std_logic_vector(15 downto 0);
  signal AWOut_Reg2:      std_logic_vector(15 downto 0);
  signal AWOut_Reg3:      std_logic_vector(15 downto 0);
  signal AWOut_Reg4:      std_logic_vector(15 downto 0);
  signal AWOut_Reg5:      std_logic_vector(15 downto 0);
  signal AWOut_Reg6:      std_logic_vector(15 downto 0);
  signal AWOut_Reg7:      std_logic_vector(15 downto 0);
  
--------------------------- INL_msk ----------------------------------------------------------------------
  
  signal INL_msk_IO1:           std_logic_vector(15 downto 0);         
  signal INL_msk_IO2:           std_logic_vector(15 downto 0);         
  signal INL_msk_IO3:           std_logic_vector(15 downto 0);       
  signal INL_msk_IO4:           std_logic_vector(15 downto 0);         
  signal INL_msk_IO5:           std_logic_vector(15 downto 0);         
  signal INL_msk_IO6:           std_logic_vector(15 downto 0);         
  signal INL_msk_IO7:           std_logic_vector(15 downto 0);         
  signal INL_msk1_rd_active:    std_logic;   
  signal INL_msk1_Dtack:        std_logic;      
  signal INL_msk1_data_to_SCUB: std_logic_vector(15 downto 0);


  --------------------------- INL_xor ----------------------------------------------------------------------
  
  signal INL_xor_IO1:           std_logic_vector(15 downto 0);        
  signal INL_xor_IO2:           std_logic_vector(15 downto 0);        
  signal INL_xor_IO3:           std_logic_vector(15 downto 0);        
  signal INL_xor_IO4:           std_logic_vector(15 downto 0);        
  signal INL_xor_IO5:           std_logic_vector(15 downto 0);        
  signal INL_xor_IO6:           std_logic_vector(15 downto 0);        
  signal INL_xor_IO7:           std_logic_vector(15 downto 0);        
  signal INL_xor1_rd_active:    std_logic;   
  signal INL_xor1_Dtack:        std_logic;      
  signal INL_xor1_data_to_SCUB: std_logic_vector(15 downto 0);
       

       
       
       
  signal INL_IO1:   std_logic_vector(15 downto 0);        
  signal INL_IO2:   std_logic_vector(15 downto 0);        
  signal INL_IO3:   std_logic_vector(15 downto 0);        
  signal INL_IO4:   std_logic_vector(15 downto 0);        
  signal INL_IO5:   std_logic_vector(15 downto 0);        
  signal INL_IO6:   std_logic_vector(15 downto 0);        
  signal INL_IO7:   std_logic_vector(15 downto 0);        
  signal Interlock: std_logic;        

  signal hp_la_o:      std_logic_vector(15 downto 0); -- Output für HP-Logicanalysator
   
  signal s_nLED_User1_i: std_logic;  -- LED3 = User 1 
  signal s_nLED_User2_i: std_logic;  -- LED2 = User 2 
  signal s_nLED_User3_i: std_logic;  -- LED1 = User 3 
  signal s_nLED_User1_o: std_logic;  -- LED3 = User 1 
  signal s_nLED_User2_o: std_logic;  -- LED2 = User 2 
  signal s_nLED_User3_o: std_logic;  -- LED1 = User 3 

  signal uart_txd_out:  std_logic;


  
--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: P37IO  -- FG900_700                                    |
--  +============================================================================================================================+

  signal P37IO_Start_i:        std_logic;    -- input "Start" L-Aktiv
  signal P37IO_Start_deb_o:    std_logic;    -- input "Start" entprellt
  signal P37IO_nLED_Start_o:   std_logic;    --  Output "nLED_Start"
  signal P37IO_Stop_i:         std_logic;    -- input "Stop" L-Aktiv
  signal P37IO_Stop_deb_o:     std_logic;    -- input "Stop" entprellt
  signal P37IO_nLED_Stop_o:    std_logic;    --  Output "nLED_Stop"
  signal P37IO_Reset_i:        std_logic;    -- input "Reset" L-Aktiv
  signal P37IO_Reset_deb_o:    std_logic;    -- input "Rest" entprellt
  signal P37IO_BNC_o:          std_logic;    -- Output "BNC"
  signal P37IO_nELD_BNC_o:     std_logic;    -- Output "nLED_BNC"

  signal P37IO_in_Data_Deb_i: std_logic_vector(15 downto 0); -- Data_Input über Optokoppler
  signal P37IO_in_Data_Deb_o: std_logic_vector(15 downto 0); -- entprellter Data_Input

  
--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: P25IO  -- FG900_710                                    |
--  +============================================================================================================================+

  signal P25IO_Start_i:        std_logic;        -- input "Start" L-Aktiv
  signal P25IO_Start_deb_o:    std_logic;        -- input "Start" entprellt
  signal P25IO_nLED_Start_o:   std_logic;        --  Output "nLED_Start"
  signal P25IO_Stop_i:         std_logic;        -- input "Stop" L-Aktiv
  signal P25IO_Stop_deb_o:     std_logic;        -- input "Stop" entprellt
  signal P25IO_nLED_Stop_o:    std_logic;        --  Output "nLED_Stop"
  signal P25IO_Reset_i:        std_logic;        -- input "Reset" L-Aktiv
  signal P25IO_Reset_deb_o:    std_logic;        -- input "Rest" entprellt
  signal P25IO_BNC_o:          std_logic;        -- Output "BNC"
  signal P25IO_nELD_BNC_o:     std_logic;        -- Output "nLED_BNC"

  signal P25IO_DAC_Out:             std_logic_vector(15 downto 0); -- Zwischenspeicher
  signal P25IO_DAC_Strobe_Start_i:  std_logic;        -- input  "Start-Signal für den Stobe vom DAC"
  signal P25IO_DAC_Strobe_Start_o:  std_logic;        -- Output "Start-Puls für den Stobe vom DAC (1 CLK breit)"
  signal P25IO_DAC_Strobe_i:        std_logic;        -- input  "Start-Puls für den DAC-Strobe"
  signal P25IO_nDAC_Strobe_o:       std_logic;        -- Output "DAC-Stobe"
  signal P25IO_DAC_shift:           std_logic_vector(2  downto 0); -- Shift-Reg.
 
  signal P25IO_ADC_ECC_Start_i:  std_logic;          -- input  "Start-Signal für das Enable vom ADC"
  signal P25IO_ADC_ECC_Start_o:  std_logic;          -- Output "Start-Puls für das Enable vom ADC (1 CLK breit)"
  signal P25IO_ADC_ECC_i:        std_logic;          -- input  "Start-Puls für das Enable vom ADC"
  signal P25IO_nADC_ECC_o:       std_logic;          -- Output "ADC-Enable"
  signal P25IO_ADC_shift:        std_logic_vector(2  downto 0); -- Shift-Reg.
 
  signal P25IO_Ext_Tim_i:        std_logic;          -- input "Start" L-Aktiv
  signal P25IO_Ext_Tim_deb_o:    std_logic;          -- input "Start" entprellt
  signal P25IO_nLED_Ext_Tim_o:   std_logic;          --  Output "nLED_Start"


  signal P25IO_Ext_Tim_Strobe_Start_o:  std_logic;                      -- Output "Start-Puls für den ext. Trigger"
  signal P25IO_Ext_Tim_shift:           std_logic_vector(2  downto 0);  -- Shift-Reg.

  
  signal P25IO_EOC_i:          std_logic;                      --  input "nEOC"
  signal P25IO_EOC_deb_o:      std_logic;                      -- input "EOC" entprellt
  signal P25IO_ADC_Data_FF_i:  std_logic_vector(15  downto 0); -- input  "Daten ADC-Register"
  signal P25IO_ADC_Data_FF_o:  std_logic_vector(15  downto 0); -- Output "Daten ADC-Register"
 
 
 
  signal s_str_shift_EE_20ms:   std_logic_vector(2  downto 0);  -- Shift-Reg.
  signal s_str_EE_20ms:         std_logic;                      -- Puls-Output


  signal P25IO_in_Data_Deb_i: std_logic_vector(15 downto 0); -- Data_Input über Optokoppler
  signal P25IO_in_Data_Deb_o: std_logic_vector(15 downto 0); -- entprellter Data_Input

  
--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: OCIN   -- FG900_720                                    |
--  +============================================================================================================================+


  signal OCIN_in_Data_Deb1_i: std_logic_vector(15 downto 0); -- Data_Input über Optokoppler
  signal OCIN_in_Data_Deb1_o: std_logic_vector(15 downto 0); -- entprellter Data_Input
  signal OCIN_in_Data_Deb2_i: std_logic_vector(15 downto 0); -- Data_Input über Optokoppler
  signal OCIN_in_Data_Deb2_o: std_logic_vector(15 downto 0); -- entprellter Data_Input


--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: OCIO   -- FG900_730                                    |
--  +============================================================================================================================+


  signal OCIO_in_Data_Deb1_i: std_logic_vector(15 downto 0); -- Data_Input über Optokoppler
  signal OCIO_in_Data_Deb1_o: std_logic_vector(15 downto 0); -- entprellter Data_Input
  signal OCIO_in_Data_Deb2_i: std_logic_vector(7  downto 0); -- Data_Input über Optokoppler
  signal OCIO_in_Data_Deb2_o: std_logic_vector(7  downto 0); -- entprellter Data_Input

  
--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: OCIO   -- FG900_740                                    |
--  +============================================================================================================================+

  signal UIO_Out:         std_logic_vector(23 downto 0); -- Data_Output
  signal UIO_Data_FG_Out: std_logic_vector(23 downto 0); -- Data/FG-Output
  signal UIO_HS_In:       std_logic_vector(23 downto 0); -- Input auf GND 
  signal UIO_LS_In:       std_logic_vector(23 downto 0); -- Input Uext

  signal UIO_LED_Lemo_In_i:     std_logic;  --  Input  "nLED_Lemo_In"
  signal UIO_nLED_Lemo_In_o:    std_logic;  --  Output "nLED_Lemo_In"
  signal UIO_LED_Lemo_Out_i:    std_logic;  --  Input  "nLED_Lemo_Out"
  signal UIO_nLED_Lemo_Out_o:   std_logic;  --  Output "nLED_Lemo_Out"

  signal UIO_Lemo_deb_i:        std_logic;  --  Input "Lemo" 
  signal UIO_Lemo_deb_o:        std_logic;  --  Input "Lemo" entprellt
  
  signal UIO_in_Lo_Data_Deb1_i: std_logic_vector(23 downto 0); -- Data_Input über Optokoppler
  signal UIO_in_Lo_Data_Deb1_o: std_logic_vector(23 downto 0); -- entprellter Data_Input
 
  signal UIO_in_Hi_Data_Deb1_i: std_logic_vector(23 downto 0); -- Data_Input über Optokoppler
  signal UIO_in_Hi_Data_Deb1_o: std_logic_vector(23 downto 0); -- entprellter Data_Input


--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: DA    -- FG900_750                                     |
--  +============================================================================================================================+


  signal DA_DAC1_Out:             std_logic_vector(15 downto 0); -- Zwischenspeicher
  signal DA_DAC1_Strobe:          std_logic;                     -- Output Strobe

  signal DA_DAC2_Out:             std_logic_vector(15 downto 0); -- Zwischenspeicher
  signal DA_DAC2_Strobe:          std_logic;                     -- Output Strobe
  
  signal DAC_Test_Out:            std_logic_vector(15 downto 0); -- Test-Bitmuster
  signal DAC_Test_Strobe:         std_logic;                     -- Output Test-Strobe

  signal DAC_Wait_cnt:            integer range 0 to 65535;      -- 0-FFFF -- Wait-Counter
  

  type dac_state_t is   (dac_idle, dac_data1, dac_str1h, dac_str1l, dac_loop1, dac_wait1, dac_wait2, dac_data2, dac_str2h, dac_str2l, dac_loop2, dac_end);
  signal dac_state:      dac_state_t := dac_idle;



--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: SPSIO  -- FG900.770                                    |
--  +============================================================================================================================+

  signal SPSIO_in_Data_Deb_i: std_logic_vector(23 downto 0); -- Data_Input über Optokoppler
  signal SPSIO_in_Data_Deb_o: std_logic_vector(23 downto 0); -- entprellter Data_Input


--  +============================================================================================================================+
--  |                                   Übergabe-Signale für Anwender-IO: HFIO  -- FG900.780                                     |
--  +============================================================================================================================+

  signal HFIO_Tastpuls_i:                 std_logic;  --  Input  "nLED_Tastpuls"
  signal HFIO_nLED_Tastpuls_o:            std_logic;  --  Output "nLED_Tastpuls"
  signal HFIO_Sample_Puls_inv_i:          std_logic;  --  Input  "nLED_Sample_Puls_inv"
  signal HFIO_nLED_Sample_Puls_inv_o:     std_logic;  --  Output "nLED_Sample_Puls_inv"
  signal HFIO_Aux_i:                      std_logic;  --  Input  "nLED_Aux"
  signal HFIO_nLED_Aux_o:                 std_logic;  --  Output "nLED_Aux"
  signal HFIO_Sample_Puls_Display_i:      std_logic;  --  Input  "nLED_Sample_Puls_Display"
  signal HFIO_nLED_Sample_Puls_Display_o: std_logic;  --  Output "nLED_Sample_Puls_Display"

  signal HFIO_in_AMP_FEHLER_Deb_i:        std_logic;  -- Input  "AMP_FEHLER"
  signal HFIO_in_AMP_FEHLER_Deb_o:        std_logic;  -- Output "AMP_FEHLER"
  signal HFIO_in_PHASE_FEHLER_Deb_i:      std_logic;  -- Input  "PHASE_FEHLER"
  signal HFIO_in_PHASE_FEHLER_Deb_o:      std_logic;  -- Output  PHASE_FEHLER"
  
  

--  +============================================================================================================================+

--  signal Deb_in:      std_logic_vector(15 downto 0);
--  signal Deb_out:    std_logic_vector(15 downto 0);

--  +============================================================================================================================+


  signal clk_blink: std_logic;
  
  signal sys_clk_is_bad:          std_logic;
  signal sys_clk_is_bad_led_n:    std_logic;
  signal sys_clk_is_bad_la:       std_logic;
  signal local_clk_is_bad:        std_logic;
  signal local_clk_is_running:    std_logic;
  signal local_clk_runs_led_n:    std_logic;
  signal sys_clk_failed:          std_logic;
  signal sys_clk_deviation:       std_logic;
  signal sys_clk_deviation_la:    std_logic;
  signal sys_clk_deviation_led_n: std_logic;
  signal clk_switch_rd_data:      std_logic_vector(15 downto 0);
  signal clk_switch_rd_active:    std_logic;
  signal clk_switch_dtack:        std_logic;
  signal pll_locked:              std_logic;
  signal clk_switch_intr:         std_logic;
  
  signal signal_tap_clk_250mhz: std_logic;
  
  
--  constant  C_Debounce_input_in_ns: integer := 5000;

  constant  C_P37IO_Start_Debounce_input_in_ns:   integer := 5000;    -- Debounce, Start-Input von FG900_700
  constant  C_P37IO_Stop_Debounce_input_in_ns:    integer := 5000;    -- Debounce, Stop-Input  von FG900_700
  constant  C_P37IO_Reset_Debounce_input_in_ns:   integer := 5000;    -- Debounce, Reset-Input von FG900_700
  constant  C_P37IO_Data_Debounce_input_in_ns:    integer := 5000;    -- Debounce, Data-Input  von FG900_700
                                                                     
  constant  C_P25IO_Start_Debounce_input_in_ns:   integer := 5000;    -- Debounce, Data-Input von FG900_710
  constant  C_P25IO_Stop_Debounce_input_in_ns:    integer := 5000;    -- Debounce, Data-Input von FG900_710
  constant  C_P25IO_Reset_Debounce_input_in_ns:   integer := 5000;    -- Debounce, Data-Input von FG900_710
  constant  C_P25IO_Ext_Tim_Debounce_input_in_ns: integer := 5000;    -- Debounce, Data-Input von FG900_710
  constant  C_P25IO_EOC_Debounce_input_in_ns:     integer := 500;     -- Debounce, Data-Input von FG900_710
  constant  C_P25IO_Data_Debounce_input_in_ns:    integer := 5000;    -- Debounce, Data-Input von FG900_710
                                                                     
  constant  C_OCIN_Data_Debounce_input_in_ns:     integer := 5000;    -- Debounce, Data-Input  von FG900_720
  constant  C_OCIO_Data_Debounce_input_in_ns:     integer := 5000;    -- Debounce, Data-Input  von FG900_730
  constant  C_UIO_Lo_Data_Debounce_input_in_ns:   integer := 5000;    -- Debounce, Data-Input  von FG900_740
  constant  C_UIO_Hi_Data_Debounce_input_in_ns:   integer := 5000;    -- Debounce, Data-Input  von FG900_740
  constant  C_UIO_Lemo_Debounce_input_in_ns:      integer := 5000;    -- Debounce, Lemo-Input  von FG900_740


  
  constant  C_SPSIO_Data_Debounce_input_in_ns:        integer := 5000;      -- Debounce, Data-Input von FG900_770

  constant  C_HFIO_AMP_FEHLER_Debounce_input_in_ns:   integer := 5000;  -- Debounce, Data-Input von FG900_780
  constant  C_HFIO_PHASE_FEHLER_Debounce_input_in_ns: integer := 5000;  -- Debounce, Data-Input von FG900_780
 
  
  
  constant  Clk_in_ns: integer:= 1000000000/clk_sys_in_Hz;
  constant  stretch_cnt: integer := 5;
  

  CONSTANT c_AW_P37IO:   std_logic_vector(7 downto 0):= B"00000001"; -- FG900_700
  CONSTANT c_AW_P25IO:   std_logic_vector(7 downto 0):= B"00000010"; -- FG900_710
  CONSTANT c_AW_OCin:    std_logic_vector(7 downto 0):= B"00000011"; -- FG900_720
  CONSTANT c_AW_OCIO:    std_logic_vector(7 downto 0):= B"00000100"; -- FG900_730
  CONSTANT c_AW_UIO:     std_logic_vector(7 downto 0):= B"00000101"; -- FG900_740
  CONSTANT c_AW_DA:      std_logic_vector(7 downto 0):= B"00000110"; -- FG900_750
  CONSTANT c_AW_Frei:    std_logic_vector(7 downto 0):= B"00000111"; -- FG900_760
  CONSTANT c_AW_SPSIO:   std_logic_vector(7 downto 0):= B"00001000"; -- FG900_770
  CONSTANT c_AW_HFIO:    std_logic_vector(7 downto 0):= B"00001001"; -- FG900_780

  
--  +============================================================================================================================+
--  |                                                        Begin                                                               |
--  +============================================================================================================================+


  begin


  A_nADR_EN             <= '0';
  A_nADR_FROM_SCUB      <= '0';
  A_nExt_Signal_in      <= '0';
  A_nSEL_Ext_Signal_DRV <= '0';
  A_nUser_EN            <= '0';
  

--  Deb16:  for I in 0 to 15 generate
--    DB_I:  debounce generic map(DB_Cnt => C_Debounce_input_in_ns / clk_in_ns)
--              port map(DB_in => Deb_in(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => Deb_out(I));
--    end generate Deb16;
  
  
  Powerup_Res <= not nPowerup_Res;  -- only for modelsim!
  WRnRD       <= not A_RnW;         -- only for modelsim!

  diob_clk_switch: diob_sys_clk_local_clk_switch
    port map(
      local_clk_i           => CLK_20MHz_D,
      sys_clk_i             => A_SysClock,
      nReset                => nPowerup_Res,
      master_clk_o          => clk_sys,               -- core clocking
      pll_locked            => pll_locked,
      sys_clk_is_bad        => sys_clk_is_bad,
      sys_clk_is_bad_la     => sys_clk_is_bad_la,
      local_clk_is_bad      => local_clk_is_bad,
      local_clk_is_running  => local_clk_is_running,
      sys_clk_deviation     => sys_clk_deviation,
      sys_clk_deviation_la  => sys_clk_deviation_la,
      Adr_from_SCUB_LA      => ADR_from_SCUB_LA,      -- in, latched address from SCU_Bus
      Data_from_SCUB_LA     => Data_from_SCUB_LA,     -- in, latched data from SCU_Bus
      Ext_Adr_Val           => Ext_Adr_Val,           -- in, '1' => "ADR_from_SCUB_LA" is valid
      Ext_Rd_active         => Ext_Rd_active,         -- in, '1' => Rd-Cycle is active
      Ext_Wr_active         => Ext_Wr_active,         -- in, '1' => Wr-Cycle is active
      Rd_Port               => clk_switch_rd_data,    -- output for all read sources of this macro
      Rd_Activ              => clk_switch_rd_active,  -- this acro has read data available at the Rd_Port.
      Dtack                 => clk_switch_dtack,
      signal_tap_clk_250mhz => signal_tap_clk_250mhz
      );
    
    
      
Conf_Sts1: config_status     
generic map(
      CS_Base_addr =>   16#500#
           )
port map  (     

      Adr_from_SCUB_LA    =>  ADR_from_SCUB_LA,          -- latched address from SCU_Bus
      Data_from_SCUB_LA   =>  Data_from_SCUB_LA,         -- latched data from SCU_Bus 
      Ext_Adr_Val         =>  Ext_Adr_Val,               -- '1' => "ADR_from_SCUB_LA" is valid
      Ext_Rd_active       =>  Ext_Rd_active,             -- '1' => Rd-Cycle is active
      Ext_Rd_fin          =>  Ext_Rd_fin,                -- marks end of read cycle, active one for one clock period of sys_clk
      Ext_Wr_active       =>  Ext_Wr_active,             -- '1' => Wr-Cycle is active
      Ext_Wr_fin          =>  SCU_Ext_Wr_fin,            -- marks end of write cycle, active one for one clock period of sys_clk
      clk                 =>  clk_sys,                   -- should be the same clk, used by SCU_Bus_Slave
      nReset              =>  nPowerup_Res,              
      
      Diob_Status1        =>  Diob_Status1,              -- Input-Diob_Status1 
      Diob_Status2        =>  Diob_Status2,              -- Input-Diob_Status2 
      AW_Status1          =>  AW_Status1,                -- Input-AW_Status1   
      AW_Status2          =>  AW_Status2,                -- Input-AW_Status2   
                                        
      Diob_Config1        =>  Diob_Config1,              -- Daten-Reg_Diob_Config1
      Diob_Config2        =>  Diob_Config2,              -- Daten-Reg_Diob_Config2
      AW_Config1          =>  AW_Config1,                -- Daten-Reg_AW_Config1  
      AW_Config2          =>  AW_Config2,                -- Daten-Reg_AW_Config2  
     
      Rd_active           =>  Conf_Sts1_rd_active,       -- read data available at 'Data_to_SCUB'-AWOut
      Dtack_to_SCUB       =>  Conf_Sts1_Dtack,           -- connect read sources to SCUB-Macro
      Data_to_SCUB        =>  Conf_Sts1_data_to_SCUB,    -- connect Dtack to SCUB-Macro
      LA                  =>  LA_Conf_Sts1            
      );
  
      
AW_Port1: aw_io_reg     
generic map(
      AW_Base_addr =>   16#510#
           )
port map  (     

      Adr_from_SCUB_LA    =>  ADR_from_SCUB_LA,  -- latched address from SCU_Bus
      Data_from_SCUB_LA   =>  Data_from_SCUB_LA, -- latched data from SCU_Bus 
      Ext_Adr_Val         =>  Ext_Adr_Val,       -- '1' => "ADR_from_SCUB_LA" is valid
      Ext_Rd_active       =>  Ext_Rd_active,     -- '1' => Rd-Cycle is active
      Ext_Rd_fin          =>  Ext_Rd_fin,        -- marks end of read cycle, active one for one clock period of sys_clk
      Ext_Wr_active       =>  Ext_Wr_active,     -- '1' => Wr-Cycle is active
      Ext_Wr_fin          =>  SCU_Ext_Wr_fin,    -- marks end of write cycle, active one for one clock period of sys_clk
      clk                 =>  clk_sys,           -- should be the same clk, used by SCU_Bus_Slave
      nReset              =>  nPowerup_Res,      

      AWin1               =>  AWin1,             -- Input-Port 1
      AWin2               =>  AWin2,             -- Input-Port 2
      AWin3               =>  AWin3,             -- Input-Port 3
      AWin4               =>  AWin4,             -- Input-Port 4
      AWin5               =>  AWin5,             -- Input-Port 5
      AWin6               =>  AWin6,             -- Input-Port 6
      AWin7               =>  AWin7,             -- Input-Port 7
      
      AWOut_Reg1          =>  AWOut_Reg1_int,    -- Daten-Reg. AWOut1 -+--> zu Output-Multiplexer 
      AWOut_Reg2          =>  AWOut_Reg2_int,    -- Daten-Reg. AWOut2  |
      AWOut_Reg3          =>  AWOut_Reg3_int,    -- Daten-Reg. AWOut3  |
      AWOut_Reg4          =>  AWOut_Reg4_int,    -- Daten-Reg. AWOut4  |
      AWOut_Reg5          =>  AWOut_Reg5_int,    -- Daten-Reg. AWOut5  |
      AWOut_Reg6          =>  AWOut_Reg6_int,    -- Daten-Reg. AWOut6  |
      AWOut_Reg7          =>  AWOut_Reg7_int,    -- Daten-Reg. AWOut7 -+

      AWOut_Reg1_wr       =>  AWOut_Reg1_wr,     -- Daten-Reg. AWOut1
      AWOut_Reg2_wr       =>  AWOut_Reg2_wr,     -- Daten-Reg. AWOut2
      AWOut_Reg3_wr       =>  AWOut_Reg3_wr,     -- Daten-Reg. AWOut3
      AWOut_Reg4_wr       =>  AWOut_Reg4_wr,     -- Daten-Reg. AWOut4
      AWOut_Reg5_wr       =>  AWOut_Reg5_wr,     -- Daten-Reg. AWOut5
      AWOut_Reg6_wr       =>  AWOut_Reg6_wr,     -- Daten-Reg. AWOut6
      AWOut_Reg7_wr       =>  AWOut_Reg7_wr,     -- Daten-Reg. AWOut7
      
      Rd_active           =>  AW_Port1_rd_active,       -- read data available at 'Data_to_SCUB'-AWOut
      Dtack_to_SCUB       =>  AW_Port1_Dtack,           -- connect read sources to SCUB-Macro
      Data_to_SCUB        =>  AW_Port1_data_to_SCUB,    -- connect Dtack to SCUB-Macro
      LA                  =>  LA_AW_Port1            
      );

      
      


Tag_Ctrl1: tag_ctrl     
generic map(
      TAG_Base_addr =>   16#580#
           )
port map  (     

      Adr_from_SCUB_LA    =>  ADR_from_SCUB_LA,          -- latched address from SCU_Bus
      Data_from_SCUB_LA   =>  Data_from_SCUB_LA,         -- latched data from SCU_Bus 
      Ext_Adr_Val         =>  Ext_Adr_Val,               -- '1' => "ADR_from_SCUB_LA" is valid
      Ext_Rd_active       =>  Ext_Rd_active,             -- '1' => Rd-Cycle is active
      Ext_Rd_fin          =>  Ext_Rd_fin,                -- marks end of read cycle, active one for one clock period of sys_clk
      Ext_Wr_active       =>  Ext_Wr_active,             -- '1' => Wr-Cycle is active
      Ext_Wr_fin          =>  SCU_Ext_Wr_fin,            -- marks end of write cycle, active one for one clock period of sys_clk
      
      Timing_Pattern_LA   =>  Timing_Pattern_LA,         -- latched timing pattern from SCU_Bus for external user functions
      Timing_Pattern_RCV  =>  Timing_Pattern_RCV,        -- timing pattern received
      Spare0              =>  A_Spare0,                  -- vom Master getrieben
      Spare1              =>  A_Spare1,                  -- vom Master getrieben
      clk                 =>  clk_sys,                   -- should be the same clk, used by SCU_Bus_Slave
      nReset              =>  nPowerup_Res,              
      AWin1               =>  AWin1,                     -- Input-Port 1
      AWin2               =>  AWin2,                     -- Input-Port 2
      AWin3               =>  AWin3,                     -- Input-Port 3
      AWin4               =>  AWin4,                     -- Input-Port 4
      AWin5               =>  AWin5,                     -- Input-Port 5      
      AWin6               =>  AWin6,                     -- Input-Port 6      
      AWin7               =>  AWin7,                     -- Input-Port 7      
      
      Max_AWOut_Reg_Nr    =>  Max_AWOut_Reg_Nr,          -- Maximale AWOut-Reg-Nummer der Anwendung
      Max_AWIn_Reg_Nr     =>  Max_AWIn_Reg_Nr,           -- Maximale AWIn-Reg-Nummer der Anwendung
    
      Tag_Reg1_Maske      =>  Tag_Reg1_Maske,            -- Tag-Output-Maske für Register 1
      Tag_Reg2_Maske      =>  Tag_Reg2_Maske,            -- Tag-Output-Maske für Register 1
      Tag_Reg3_Maske      =>  Tag_Reg3_Maske,            -- Tag-Output-Maske für Register 1
      Tag_Reg4_Maske      =>  Tag_Reg4_Maske,            -- Tag-Output-Maske für Register 1
      Tag_Reg5_Maske      =>  Tag_Reg5_Maske,            -- Tag-Output-Maske für Register 1
      Tag_Reg6_Maske      =>  Tag_Reg6_Maske,            -- Tag-Output-Maske für Register 1
      Tag_Reg7_Maske      =>  Tag_Reg7_Maske,            -- Tag-Output-Maske für Register 1
      Tag_Outp_Reg1       =>  Tag_Outp_Reg1,             -- Tag-Output-Maske für Register 1
      Tag_Outp_Reg2       =>  Tag_Outp_Reg2,             -- Tag-Output-Maske für Register 1
      Tag_Outp_Reg3       =>  Tag_Outp_Reg3,             -- Tag-Output-Maske für Register 1
      Tag_Outp_Reg4       =>  Tag_Outp_Reg4,             -- Tag-Output-Maske für Register 1
      Tag_Outp_Reg5       =>  Tag_Outp_Reg5,             -- Tag-Output-Maske für Register 1
      Tag_Outp_Reg6       =>  Tag_Outp_Reg6,             -- Tag-Output-Maske für Register 1
      Tag_Outp_Reg7       =>  Tag_Outp_Reg7,             -- Tag-Output-Maske für Register 1

      Tag_FG_Start        =>  Tag_FG_Start,              -- Start-Puls für den FG
      Tag_Sts             =>  Tag_Sts,                   -- Tag-Status

      Rd_active           =>  Tag_Ctrl1_rd_active,       -- read data available at 'Data_to_SCUB'-AWOut
      Data_to_SCUB        =>  Tag_Ctrl1_Data_to_SCUB,    -- connect read sources to SCUB-Macro
      Dtack_to_SCUB       =>  Tag_Ctrl1_Dtack,           -- connect Dtack to SCUB-Macro
      LA_Tag_Ctrl         =>  LA_Tag_Ctrl1
      );  
      



--------- AW-Output Mux --------------------

p_AW_Out_Mux:  PROCESS (Tag_Reg1_Maske, Tag_Reg2_Maske, Tag_Reg3_Maske, Tag_Reg4_Maske, Tag_Reg5_Maske, Tag_Reg6_Maske, Tag_Reg7_Maske,
                        Tag_Outp_Reg1,  Tag_Outp_Reg2,  Tag_Outp_Reg3,  Tag_Outp_Reg4,  Tag_Outp_Reg5,  Tag_Outp_Reg6,  Tag_Outp_Reg7,
                        AWOut_Reg1_int, AWOut_Reg2_int, AWOut_Reg3_int, AWOut_Reg4_int, AWOut_Reg5_int, AWOut_Reg6_int, AWOut_Reg7_int) 
    BEGin
    for i in 0 to 15 loop
      IF Tag_Reg1_Maske(i)  = '0' then AWOut_Reg1(i)  <= AWOut_Reg1_int(i);  else  AWOut_Reg1(i)  <= Tag_Outp_Reg1(i);  end if;    -- Daten-Reg. AWOut1
      IF Tag_Reg2_Maske(i)  = '0' then AWOut_Reg2(i)  <= AWOut_Reg2_int(i);  else  AWOut_Reg2(i)  <= Tag_Outp_Reg2(i);  end if;    -- Daten-Reg. AWOut2
      IF Tag_Reg3_Maske(i)  = '0' then AWOut_Reg3(i)  <= AWOut_Reg3_int(i);  else  AWOut_Reg3(i)  <= Tag_Outp_Reg3(i);  end if;    -- Daten-Reg. AWOut3
      IF Tag_Reg4_Maske(i)  = '0' then AWOut_Reg4(i)  <= AWOut_Reg4_int(i);  else  AWOut_Reg4(i)  <= Tag_Outp_Reg4(i);  end if;    -- Daten-Reg. AWOut4
      IF Tag_Reg5_Maske(i)  = '0' then AWOut_Reg5(i)  <= AWOut_Reg5_int(i);  else  AWOut_Reg5(i)  <= Tag_Outp_Reg5(i);  end if;    -- Daten-Reg. AWOut5
      IF Tag_Reg6_Maske(i)  = '0' then AWOut_Reg6(i)  <= AWOut_Reg6_int(i);  else  AWOut_Reg6(i)  <= Tag_Outp_Reg6(i);  end if;    -- Daten-Reg. AWOut6
      IF Tag_Reg7_Maske(i)  = '0' then AWOut_Reg7(i)  <= AWOut_Reg7_int(i);  else  AWOut_Reg7(i)  <= Tag_Outp_Reg7(i);  end if;    -- Daten-Reg. AWOut7
    end loop;  
  END PROCESS p_AW_Out_Mux;



  
INL_xor1: io_reg     
generic map(
      Base_addr =>  16#530#
      )
port map  (     
      Adr_from_SCUB_LA   =>  ADR_from_SCUB_LA,
      Data_from_SCUB_LA  =>  Data_from_SCUB_LA,
      Ext_Adr_Val        =>  Ext_Adr_Val,
      Ext_Rd_active      =>  Ext_Rd_active,
      Ext_Rd_fin         =>  Ext_Rd_fin,
      Ext_Wr_active      =>  Ext_Wr_active,
      Ext_Wr_fin         =>  SCU_Ext_Wr_fin,
      clk                =>  clk_sys,
      nReset             =>  nPowerup_Res,
--
      Reg_IO1             =>  INL_xor_IO1,
      Reg_IO2             =>  INL_xor_IO2,    
      Reg_IO3             =>  INL_xor_IO3,    
      Reg_IO4             =>  INL_xor_IO4,    
      Reg_IO5             =>  INL_xor_IO5,    
      Reg_IO6             =>  INL_xor_IO6,  
      Reg_IO7             =>  INL_xor_IO7,    
      Reg_IO8             =>  open,    
--                     
      Reg_rd_active       =>  INL_xor1_rd_active,
      Dtack_to_SCUB       =>  INL_xor1_Dtack,
      Data_to_SCUB        =>  INL_xor1_data_to_SCUB
    );
    
    
INL_msk1: io_reg     
generic map(
      Base_addr =>  16#540#
      )
port map  (     
      Adr_from_SCUB_LA   =>  ADR_from_SCUB_LA,
      Data_from_SCUB_LA  =>  Data_from_SCUB_LA,
      Ext_Adr_Val        =>  Ext_Adr_Val,
      Ext_Rd_active      =>  Ext_Rd_active,
      Ext_Rd_fin         =>  Ext_Rd_fin,
      Ext_Wr_active      =>  Ext_Wr_active,
      Ext_Wr_fin         =>  SCU_Ext_Wr_fin,
      clk                =>  clk_sys,
      nReset             =>  nPowerup_Res,
--
      Reg_IO1            =>  INL_msk_IO1,
      Reg_IO2            =>  INL_msk_IO2,   
      Reg_IO3            =>  INL_msk_IO3,  
      Reg_IO4            =>  INL_msk_IO4,  
      Reg_IO5            =>  INL_msk_IO5,  
      Reg_IO6            =>  INL_msk_IO6,
      Reg_IO7            =>  INL_msk_IO7,
      Reg_IO8            =>  open,    
--
      Reg_rd_active      =>  INL_msk1_rd_active,
      Dtack_to_SCUB      =>  INL_msk1_Dtack,
      Data_to_SCUB       =>  INL_msk1_data_to_SCUB
    );

 
    
testport_mux: process (A_SEL, AW_Config1, AWin1, AWOut_Reg1, LA_AW_Port1, LA_Conf_Sts1, Timing_Pattern_RCV,
                       Timing_Pattern_LA, test_port_in_0, test_clocks, uart_txd_out,
                       Ext_Rd_active, Ext_Rd_fin, Ext_Rd_Fin_ovl, Ext_Wr_active, SCU_Ext_Wr_fin, Ext_Wr_fin_ovl
                       )
variable test_out: std_logic_vector(15 downto 0);
begin
  case (not A_SEL) is
    when X"0" => test_out := AW_Config1;
    when X"1" => test_out := AWOut_Reg1;
    when X"2" => test_out := AWin1;
    when X"3" => test_out := X"0000";
--
    when X"4" => test_out := X"0000";
    when X"5" => test_out := X"0000";
    when X"6" => test_out := X"0000";
    when X"7" => test_out := X"0000";
--                                                 +--- '1' drives the external max level shifter
    when X"8" => test_out := X"000" & '0' & '0' & '1' & uart_txd_out;
    when X"9" => test_out := LA_Conf_Sts1;
    when X"A" => test_out := LA_AW_Port1;
--

    when X"B" => test_out := X"00"&
                              '0' &
                              '0' &
                              Ext_Rd_active  &  -- out, '1' => Rd-Cycle to external user register is active
                              Ext_Rd_fin     &  -- out, marks end of read cycle, active one for one clock period of clk past cycle end (no overlap)
                              Ext_Rd_Fin_ovl &  -- out, marks end of read cycle, active one for one clock period of clk during cycle end (overlap)
                              Ext_Wr_active  &  -- out, '1' => Wr-Cycle to external user register is active
                              SCU_Ext_Wr_fin &  -- out, marks end of write cycle, active high for one clock period of clk past cycle end (no overlap)
                              Ext_Wr_fin_ovl;   -- out, marks end of write cycle, active high for one clock period of clk before write cycle finished (with overlap)
--
    when X"C" => test_out := Timing_Pattern_RCV & Timing_Pattern_LA(14 downto 0);-- Timing
   --
    when X"D" => test_out := X"0000";
    when X"E" => test_out := test_clocks;
    when X"F" => test_out := test_port_in_0;
    when others =>  test_out := (others => '0');
  end case;
    hp_la_o <= test_out(15 downto 0);
end process testport_mux;




test_port_in_0 <= nPowerup_Res          & clk_sys         & Ena_Every_100ns & Ena_Every_166ns & -- bit15..12
                  Ext_Wr_active         & SCU_Ext_Wr_fin  & '0'             & FG_1_strobe     & -- bit11..8
                  signal_tap_clk_250mhz & pll_locked      & A_RnW & A_nDS   &                   -- bit7..4
                  A_nBoardSel           & FG_1_strobe     & '0'             & SCUB_Dtack      ; -- bit3..0

            
test_clocks <=  X"0"                                                                              -- bit15..12
              & '0' & signal_tap_clk_250mhz & A_SysClock & CLK_20MHz_D                            -- bit11..8
              & '0' & pll_locked & sys_clk_deviation & sys_clk_deviation_la                       -- bit7..4
              & local_clk_is_running & local_clk_is_bad & sys_clk_is_bad & sys_clk_is_bad_la;     -- bit3..0



fl : flash_loader_v01
port map  (
      noe_in  =>  '0'
      );
  
    
  -- open drain buffer for one wire
        owr_i(0) <= A_OneWire;
        A_OneWire <= owr_pwren_o(0) when (owr_pwren_o(0) = '1' or owr_en_o(0) = '1') else 'Z';
  
zeit1 : zeitbasis
generic map (
      CLK_in_Hz =>  clk_sys_in_Hz,
      diag_on   =>  1
      )
port map  (
      Res               =>  Powerup_Res,
      Clk               =>  clk_sys,
      Ena_every_100ns   =>  Ena_Every_100ns,
      Ena_every_166ns   =>  Ena_Every_166ns,
      Ena_every_250ns   =>  open,
      Ena_every_500ns   =>  open,
      Ena_every_1us     =>  Ena_every_1us,
      Ena_Every_20ms    =>  Ena_Every_20ms
      );

    
p_led_sel: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys, Sig_in => not A_nBoardSel, nLED => s_nLED_Sel);-- LED: sel Board
  
p_led_dtack: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys, Sig_in => SCUB_Dtack, nLED => s_nLED_Dtack);-- LED: Dtack to SCU-Bus

p_led_inr: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys, Sig_in => SCUB_SRQ, nLED => s_nLED_inR);-- LED: interrupt

--p_led_pu: led_n
--  generic map (stretch_cnt => stretch_cnt)
--  port map      (ena => Ena_Every_20ms, CLK => clk_sys, Sig_in => not (nPowerup_Res), nLED => s_nLED_PU);-- LED: nPowerup_Reset
  
p_led_user1: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys, Sig_in => s_nLED_User1_i, nLED => s_nLED_User1_o);-- LED3 = User 1

p_led_user2: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys, Sig_in => s_nLED_User2_i, nLED => s_nLED_User2_o);-- LED3 = User 1

p_led_user3: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys, Sig_in => s_nLED_User3_i, nLED => s_nLED_User3_o);-- LED3 = User 1
  
  
  
A_nLED_D2 <=   s_nLED_Sel;    -- Diagnose-LED_D2 = BoardSelekt  
A_nLED_D3 <=   s_nLED_Dtack;  -- Diagnose-LED_D3 = Dtack




sel_every_250ms: div_n
  generic map (n => 12, diag_on => 0)  -- ena nur alle 20ms fr einen Takt aktiv, deshalb 13x20ms = 260ms
    port map  ( res => Powerup_Res,
                clk => clk_sys,
                ena => Ena_Every_20ms,
                div_o => ENA_every_250ms
              );
              
sel_every_500ms: div_n
  generic map (n => 25, diag_on => 0)  -- ena nur alle 20ms fr einen Takt aktiv, deshalb 25x20ms = 500ms
    port map  ( res => Powerup_Res,
                clk => clk_sys,
                ena => Ena_Every_20ms,
                div_o => ENA_every_500ms
              );
          
              
p_clk_blink:  
process (clk_sys, Powerup_Res, ENA_every_250ms)
begin
  if  ( Powerup_Res    = '1') then
      clk_blink   <= '0';
  elsif (rising_edge(clk_sys)) then
    if (ENA_every_500ms = '1') then
      clk_blink <= not clk_blink;
    end if;
  end if;
end process;
  
            
 

clk_switch_intr <= local_clk_is_running or sys_clk_deviation_la;

SCU_Slave: SCU_Bus_Slave
generic map (
    CLK_in_Hz => clk_sys_in_Hz,
    Firmware_Release        => 3,
    Firmware_Version        => 0,
    CID_System => 55, -- important: 55 => CSCOHW
    CID_Group => 26, --- important: 26 => "FG900500_SCU_Diob1"
    intr_Enable          => b"0000_0000_0000_0001")
port map (
    SCUB_Addr => A_A, -- in,        SCU_Bus: address bus
    nSCUB_Timing_Cyc         => A_nEvent_Str, -- in,        SCU_Bus signal: low active SCU_Bus runs timing cycle
    SCUB_Data => A_D, -- inout,        SCU_Bus: data bus (FPGA tri state buffer)
    nSCUB_Slave_Sel => A_nBoardSel, -- in, SCU_Bus: '0' => SCU master select slave
    nSCUB_DS => A_nDS, -- in,        SCU_Bus: '0' => SCU master activate data strobe
    SCUB_RDnWR => A_RnW, -- in, SCU_Bus: '1' => SCU master read slave
    clk => clk_sys,
    nSCUB_Reset_in => A_nReset, -- in,        SCU_Bus-Signal: '0' => 'nSCUB_Reset_in' is active
    Data_to_SCUB => Data_to_SCUB, -- in,        connect read sources from external user functions
    Dtack_to_SCUB => Dtack_to_SCUB, -- in,        connect Dtack from from external user functions
    intr_in => FG_1_dreq & '0' & tmr_irq & '0'  -- bit 15..12
            & x"0"                              -- bit 11..8
            & x"0"                              -- bit 7..4
            & '0' & '0' & clk_switch_intr,      -- bit 3..1
    User_Ready => '1',
    extension_cid_system => extension_cid_system, -- in,  extension card: cid_system
    extension_cid_group => extension_cid_group, --in,     extension card: cid_group
    Data_from_SCUB_LA => Data_from_SCUB_LA, -- out,        latched data from SCU_Bus for external user functions
    ADR_from_SCUB_LA => ADR_from_SCUB_LA, -- out,        latched address from SCU_Bus for external user functions
    Timing_Pattern_LA => Timing_Pattern_LA, -- out,        latched timing pattern from SCU_Bus for external user functions
    Timing_Pattern_RCV => Timing_Pattern_RCV, -- out,        timing pattern received
    nSCUB_Dtack_Opdrn => open, -- out,        for direct connect to SCU_Bus opendrain signal
                                                    -- '0' => slave give dtack to SCU master
    SCUB_Dtack => SCUB_Dtack, -- out,        for connect via ext. open collector driver
                                                    -- '1' => slave give dtack to SCU master
    nSCUB_SRQ_Opdrn => open, -- out,        for direct connect to SCU_Bus opendrain signal
                                                    -- '0' => slave service request to SCU ma
    SCUB_SRQ => SCUB_SRQ, -- out,        for connect via ext. open collector driver
                                                    -- '1' => slave service request to SCU master
    nSel_Ext_Data_Drv => A_nSel_Ext_Data_Drv, -- out,        '0' => select the external data driver on the SCU_Bus slave
    Ext_Data_Drv_Rd         => A_Ext_Data_RD, -- out,        '1' => direction of the external data driver on the
                                                    -- SCU_Bus slave is to the SCU_Bus
    Standard_Reg_Acc => Standard_Reg_Acc, -- out,        '1' => mark the access to register of this macro
    Ext_Adr_Val => Ext_Adr_Val, -- out,        for external user functions: '1' => "ADR_from_SCUB_LA" is valid
    Ext_Rd_active => Ext_Rd_active, -- out,        '1' => Rd-Cycle to external user register is active
    Ext_Rd_fin => Ext_Rd_fin, -- out,        marks end of read cycle, active one for one clock period
                                                    -- of clk past cycle end (no overlap)
    Ext_Rd_Fin_ovl => Ext_Rd_Fin_ovl, -- out,        marks end of read cycle, active one for one clock period
                                                    -- of clk during cycle end (overlap)
    Ext_Wr_active => Ext_Wr_active, -- out,        '1' => Wr-Cycle to external user register is active
    Ext_Wr_fin => SCU_Ext_Wr_fin, -- out,        marks end of write cycle, active high for one clock period
                                                    -- of clk past cycle end (no overlap)
    Ext_Wr_fin_ovl => Ext_Wr_fin_ovl, -- out, marks end of write cycle, active high for one clock period
                                                    -- of clk before write cycle finished (with overlap)
    Deb_SCUB_Reset_out => Deb_SCUB_Reset_out, -- out,        the debounced 'nSCUB_Reset_in'-signal, is active high,
                                                    -- can be used to reset
                                                    -- external macros, when 'nSCUB_Reset_in' is '0'
    nPowerup_Res => nPowerup_Res, -- out,        this macro generated a power up reset
    Powerup_Done => Powerup_Done          -- out  this memory is set to one if an Powerup is done. Only the SCUB-Master can clear this bit.
    );


lm32_ow: housekeeping
  generic map (
    Base_Addr => x"0040" )
  port map (
    clk_sys => clk_sys,
    n_rst => nPowerup_Res,

    ADR_from_SCUB_LA  => ADR_from_SCUB_LA,
    Data_from_SCUB_LA => Data_from_SCUB_LA,
    Ext_Adr_Val       => Ext_Adr_Val,
    Ext_Rd_active     => Ext_Rd_active,
    Ext_Wr_active     => Ext_Wr_active,
    user_rd_active    => wb_scu_rd_active,
    Data_to_SCUB      => wb_scu_data_to_SCUB,
    Dtack_to_SCUB     => wb_scu_dtack,

    owr_pwren_o       => owr_pwren_o,
    owr_en_o          => owr_en_o,
    owr_i             => owr_i,

    debug_serial_o    => uart_txd_out,
    debug_serial_i    => '0');

    
fg_1: fg_quad_scu_bus
  generic map (
    Base_addr => x"0300",
    clk_in_hz => clk_sys_in_Hz,
    diag_on_is_1 => 0 -- if 1 then diagnosic information is generated during compilation
    )
  port map (

    -- SCUB interface
    Adr_from_SCUB_LA  => ADR_from_SCUB_LA,      -- in, latched address from SCU_Bus
    Data_from_SCUB_LA => Data_from_SCUB_LA,     -- in, latched data from SCU_Bus
    Ext_Adr_Val       => Ext_Adr_Val,           -- in, '1' => "ADR_from_SCUB_LA" is valid
    Ext_Rd_active     => Ext_Rd_active,         -- in, '1' => Rd-Cycle is active
    Ext_Wr_active     => Ext_Wr_active,         -- in, '1' => Wr-Cycle is active
    clk               => clk_sys,               -- in, should be the same clk, used by SCU_Bus_Slave
    nReset            => nPowerup_Res,          -- in, '0' => resets the fg_1
    Rd_Port           => FG_1_data_to_SCUB,     -- out, connect read sources (over multiplexer) to SCUB-Macro
    user_rd_active    => FG_1_rd_active,        -- '1' = read data available at 'Rd_Port'-output
    Dtack             => FG_1_dtack,            -- connect Dtack to SCUB-Macro
    dreq              => FG_1_dreq,             -- request of new parameter set
    brdcst_i          => '0',
    brdcst_o          => open,          

    -- fg output
    sw_out            => FG_1_sw,               -- 24bit output from fg
    sw_strobe         => FG_1_strobe            -- signals new output data
  );

  tmr: tmr_scu_bus
  generic map (
    Base_addr     => x"0330",
    diag_on_is_1  => 1)
  port map (
    clk           => clk_sys,
    nrst          => nPowerup_Res,
    tmr_irq       => tmr_irq,
    
    Adr_from_SCUB_LA  => ADR_from_SCUB_LA,
    Data_from_SCUB_LA => Data_from_SCUB_LA,
    Ext_Adr_Val       => Ext_Adr_Val,
    Ext_Rd_active     => Ext_Rd_active,
    Ext_Wr_active     => Ext_Wr_active,
    user_rd_active    => tmr_rd_active,
    Data_to_SCUB      => tmr_data_to_SCUB,
    Dtack_to_SCUB     => tmr_dtack);

rd_port_mux:  process ( clk_switch_rd_active, clk_switch_rd_data,
                        wb_scu_rd_active,     wb_scu_data_to_SCUB,
                        FG_1_rd_active,       FG_1_data_to_SCUB,
                        AW_Port1_rd_active,   AW_Port1_data_to_SCUB,
                        Tag_Ctrl1_rd_active,  Tag_Ctrl1_data_to_SCUB,
                        Conf_Sts1_rd_active,  Conf_Sts1_data_to_SCUB,
                        INL_msk1_rd_active,   INL_msk1_data_to_SCUB,
                        INL_xor1_rd_active,   INL_xor1_data_to_SCUB,
                        tmr_rd_active,        tmr_data_to_SCUB )

  variable sel: unsigned(8 downto 0);
  begin
    sel :=  tmr_rd_active     & INL_xor1_rd_active    & INL_msk1_rd_active   &  AW_Port1_rd_active   &  FG_1_rd_active &
            wb_scu_rd_active  & clk_switch_rd_active  & Conf_Sts1_rd_active  &  Tag_Ctrl1_rd_active ;
    
  case sel IS
      when "100000000" => Data_to_SCUB <= tmr_data_to_SCUB;
      when "010000000" => Data_to_SCUB <= INL_xor1_data_to_SCUB;
      when "001000000" => Data_to_SCUB <= INL_msk1_data_to_SCUB;
      when "000100000" => Data_to_SCUB <= AW_Port1_data_to_SCUB;
      when "000010000" => Data_to_SCUB <= FG_1_data_to_SCUB;
      when "000001000" => Data_to_SCUB <= wb_scu_data_to_SCUB;
      when "000000100" => Data_to_SCUB <= clk_switch_rd_data;
      when "000000010" => Data_to_SCUB <= Conf_Sts1_data_to_SCUB;
      when "000000001" => Data_to_SCUB <= Tag_Ctrl1_data_to_SCUB;
      when others      => Data_to_SCUB <= (others => '0');
    end case;
  end process rd_port_mux;

    
-------------- Dtack_to_SCUB -----------------------------   

    Dtack_to_SCUB <= ( tmr_dtack    or INL_xor1_Dtack   or INL_msk1_Dtack  or AW_Port1_Dtack  or FG_1_dtack  or 
                       wb_scu_dtack or clk_switch_dtack or Conf_Sts1_Dtack or Tag_Ctrl1_Dtack );
                     

    A_nDtack <= NOT(SCUB_Dtack);
    A_nSRQ   <= NOT(SCUB_SRQ);


p_interlock:  
process (AWin1, AWin2, AWin3, AWin4, AWin5, AWin6, AWin7, Max_AWIn_Reg_Nr,                        -- Input-Register
      INL_xor_IO1, INL_xor_IO2, INL_xor_IO3, INL_xor_IO4, INL_xor_IO5, INL_xor_IO6, INL_xor_IO7,  -- Pegel(xor)-Register (default = 0)
      INL_msk_IO1, INL_msk_IO2, INL_msk_IO3, INL_msk_IO4, INL_msk_IO5, INL_msk_IO6, INL_msk_IO7,  -- Maskenregister      (default = 0)
      INL_IO1,    INL_IO2,    INL_IO3,    INL_IO4,     INL_IO5,    INL_IO6,     INL_IO7)          -- Zwischenergebnis: Interlock-Bits xor, Maske
begin
--
  INL_IO1  <=  ((AWin1 xor INL_xor_IO1) and not INL_msk_IO1);
  INL_IO2  <=  ((AWin2 xor INL_xor_IO2) and not INL_msk_IO2);
  INL_IO3  <=  ((AWin3 xor INL_xor_IO3) and not INL_msk_IO3);
  INL_IO4  <=  ((AWin4 xor INL_xor_IO4) and not INL_msk_IO4);
  INL_IO5  <=  ((AWin5 xor INL_xor_IO5) and not INL_msk_IO5);
  INL_IO6  <=  ((AWin6 xor INL_xor_IO6) and not INL_msk_IO6);
  INL_IO7  <=  ((AWin7 xor INL_xor_IO7) and not INL_msk_IO7);

-- "Oder-Veknüpfung aller Statusbits (nach Aktiv-Pegel-Selekt und Maske) ---  

case Max_AWIn_Reg_Nr is
  when 1 =>
        if   (INL_IO1 = x"0000")  then
          interlock <= '0'; -- alle Bits = 0 ==> kein Interloc
        else
          interlock <= '1'; -- Interlock aktiv
        end if;
  when 2 =>
        if  ((INL_IO1 = x"0000") and (INL_IO2 = x"0000")) then
          interlock <= '0'; -- alle Bits = 0 ==> kein Interloc
        else
          interlock <= '1'; -- Interlock aktiv
        end if;
  when others =>
        if  ((INL_IO1 = x"0000") and (INL_IO2 = x"0000") and (INL_IO3 = x"0000") and 
             (INL_IO4 = x"0000") and (INL_IO5 = x"0000") and (INL_IO6 = x"0000") and (INL_IO7 = x"0000")) then
        
          interlock <= '0'; -- alle Bits = 0 ==> kein Interloc
        else
          interlock <= '1'; -- Interlock aktiv
        end if;
end case;
  
end process;
  
  
--  +============================================================================================================================+
--  |                                          Anwender-IO: P37IO  -- FG900_700                                                 |
--  +============================================================================================================================+


P37IO_in_Start_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P37IO_Start_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => P37IO_Start_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P37IO_Start_deb_o);
      
P37IO_Out_Led_Start: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => P37IO_Start_deb_o,    nLED => P37IO_nLED_Start_o);
  

P37IO_in_Stop_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P37IO_Stop_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => P37IO_Stop_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P37IO_Stop_deb_o);
 
P37IO_Out_Led_Stop: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => P37IO_Stop_deb_o,    nLED => P37IO_nLED_Stop_o);
 

P37IO_in_Reset_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P37IO_Reset_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => P37IO_Reset_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P37IO_Reset_deb_o);


  
p_P37IO_dff: 
process (clk_sys, P37IO_Start_deb_o, P37IO_Stop_deb_o, P37IO_Reset_deb_o, Powerup_Res)
begin
  -- Reset whenever the reset signal goes low, regardless of the clock
  -- or the clock enable
  if  ( Powerup_Res    = '1') then
      P37IO_BNC_o  <= '0';
  elsif ( (P37IO_Stop_deb_o or P37IO_Reset_deb_o)  = '1') then
      P37IO_BNC_o  <= '0';

      -- If not resetting, and the clock signal is enabled on this register, 
  -- update the register output on the clock's rising edge
  elsif (rising_edge(clk_sys)) then
    if (P37IO_Start_deb_o = '1') then
      P37IO_BNC_o <= '1';
    end if;
  end if;
end process;


P37IO_Out_Led_BNC: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => P37IO_BNC_o,    nLED => P37IO_nELD_BNC_o);


P37IO_in_Data_Deb:  for I in 0 to 15 generate
              DB_I:  debounce generic map(DB_Cnt => C_P37IO_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => P37IO_in_Data_Deb_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => P37IO_in_Data_Deb_o(I));
              end generate P37IO_in_Data_Deb;
              
  

--  +============================================================================================================================+
--  |                                          Anwender-IO: P25IO  -- FG900_710                                                  |
--  +============================================================================================================================+
  


P25IO_in_Start_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P25IO_Start_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => P25IO_Start_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P25IO_Start_deb_o);
      
P25IO_Out_Led_Start: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => P25IO_Start_deb_o,    nLED => P25IO_nLED_Start_o);
  

P25IO_in_Stop_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P25IO_Stop_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => P25IO_Stop_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P25IO_Stop_deb_o);
 
P25IO_Out_Led_Stop: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => P25IO_Stop_deb_o,    nLED => P25IO_nLED_Stop_o);
 

P25IO_in_Reset_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P25IO_Reset_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => P25IO_Reset_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P25IO_Reset_deb_o);


  
p_P25IO_dff: 
process (clk_sys, P25IO_Start_deb_o, P25IO_Stop_deb_o, P25IO_Reset_deb_o, Powerup_Res)
begin
  -- Reset whenever the reset signal goes low, regardless of the clock
  -- or the clock enable
  if  ( Powerup_Res    = '1') then
      P25IO_BNC_o  <= '0';
  elsif ( (P25IO_Stop_deb_o or P25IO_Reset_deb_o)  = '1') then
      P25IO_BNC_o  <= '0';

      -- If not resetting, and the clock signal is enabled on this register, 
  -- update the register output on the clock's rising edge
  elsif (rising_edge(clk_sys)) then
    if (P25IO_Start_deb_o = '1') then
      P25IO_BNC_o <= '1';
    end if;
  end if;
end process;


P25IO_Out_Led_BNC: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => P25IO_BNC_o,    nLED => P25IO_nELD_BNC_o);


 
 
--------- Puls als Signal (1 Clock breit) --------------------

p_P25IO_DAC_Strobe_Start:  PROCESS (clk_sys, Powerup_Res, P25IO_DAC_Strobe_Start_i)
  BEGin
    IF Powerup_Res  = '1' THEN
      P25IO_DAC_shift  <= (OTHERS => '0');
      P25IO_DAC_Strobe_Start_o    <= '0';

    ELSIF rising_edge(clk_sys) THEN
      P25IO_DAC_shift <= (P25IO_DAC_shift(P25IO_DAC_shift'high-1 downto 0) & (P25IO_DAC_Strobe_Start_i));

      IF P25IO_DAC_shift(P25IO_DAC_shift'high) = '0' AND P25IO_DAC_shift(P25IO_DAC_shift'high-1) = '1' THEN
        P25IO_DAC_Strobe_Start_o <= '1';
      ELSE
        P25IO_DAC_Strobe_Start_o <= '0';
      END IF;
    END IF;
  END PROCESS p_P25IO_DAC_Strobe_Start;
  
  
  --------- DAC_Out-Strobe --------------------
P25IO_DAC_Strobe: led_n
  generic map (stretch_cnt => 125) -- 125 x 8ns(1/125 MHz) = 1us
  port map      (ena => '1', CLK => clk_sys,   Sig_in => P25IO_DAC_Strobe_Start_o,    nLED => P25IO_nDAC_Strobe_o);-- 


   

--------- Puls als Signal (1 Clock breit) --------------------

p_P25IO_ADC_Strobe_Start:  PROCESS (clk_sys, Powerup_Res, P25IO_ADC_ECC_Start_i)
  BEGin
    IF Powerup_Res  = '1' THEN
      P25IO_ADC_shift  <= (OTHERS => '0');
      P25IO_ADC_ECC_Start_o    <= '0';

    ELSIF rising_edge(clk_sys) THEN
      P25IO_ADC_shift <= (P25IO_ADC_shift(P25IO_ADC_shift'high-1 downto 0) & (P25IO_ADC_ECC_Start_i));

      IF P25IO_ADC_shift(P25IO_ADC_shift'high) = '0' AND P25IO_ADC_shift(P25IO_ADC_shift'high-1) = '1' THEN
        P25IO_ADC_ECC_Start_o <= '1';
      ELSE
        P25IO_ADC_ECC_Start_o <= '0';
      END IF;
    END IF;
  END PROCESS p_P25IO_ADC_Strobe_Start;


--------- ADC_Out-ECC --------------------

P25IO_in_Ext_Tim_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P25IO_Ext_Tim_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => P25IO_Ext_Tim_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P25IO_Ext_Tim_deb_o);
      
P25IO_Out_Led_Ext_Tim: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => P25IO_Ext_Tim_deb_o, nLED => P25IO_nLED_Ext_Tim_o);

  
--------- Puls als Signal (1 Clock breit) --------------------

p_P25IO_Ext_Tim_Strobe_Start:  PROCESS (clk_sys, Powerup_Res, P25IO_Ext_Tim_deb_o)
  BEGin
    IF Powerup_Res  = '1' THEN
      P25IO_Ext_Tim_shift  <= (OTHERS => '0');
      P25IO_Ext_Tim_Strobe_Start_o    <= '0';

    ELSIF rising_edge(clk_sys) THEN
      P25IO_Ext_Tim_shift <= (P25IO_Ext_Tim_shift(P25IO_Ext_Tim_shift'high-1 downto 0) & (P25IO_Ext_Tim_deb_o));

      IF P25IO_Ext_Tim_shift(P25IO_Ext_Tim_shift'high) = '0' AND P25IO_Ext_Tim_shift(P25IO_Ext_Tim_shift'high-1) = '1' THEN
        P25IO_Ext_Tim_Strobe_Start_o <= '1';
      ELSE
        P25IO_Ext_Tim_Strobe_Start_o <= '0';
      END IF;
    END IF;
  END PROCESS p_P25IO_Ext_Tim_Strobe_Start;

  
P25IO_ADC_ECC: led_n
  generic map (stretch_cnt => 250) -- 250 x 8ns(1/125 MHz) = 2us
  port map      (ena => '1', CLK => clk_sys,   Sig_in => (P25IO_ADC_ECC_i), nLED => P25IO_nADC_ECC_o);-- 
  

P25IO_in_EOC_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_P25IO_EOC_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => not P25IO_EOC_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => P25IO_EOC_deb_o);


  
p_P25IO_ADC_FF: 
process (clk_sys, P25IO_EOC_deb_o, P25IO_ADC_Data_FF_i, Powerup_Res)
begin
  if  ( Powerup_Res      = '1') then   P25IO_ADC_Data_FF_o  <= (OTHERS => '0');
  elsif (rising_edge(clk_sys)) then
    if (P25IO_EOC_deb_o = '1') then  P25IO_ADC_Data_FF_o  <= P25IO_ADC_Data_FF_i;
    end if;
  end if;
end process;


P25IO_in_Data_Deb:  for I in 0 to 15 generate
              DB_I:  debounce generic map(DB_Cnt => C_OCIO_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => P25IO_in_Data_Deb_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => P25IO_in_Data_Deb_o(I));
              end generate P25IO_in_Data_Deb;
              
  

--  +============================================================================================================================+
--  |                                          Anwender-IO: OCIN  -- FG900_720                                                  |
--  +============================================================================================================================+

OCIN_in_Data_Deb1:  for I in 0 to 15 generate
              DB_I:  debounce generic map(DB_Cnt => C_OCIN_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => OCIN_in_Data_Deb1_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => OCIN_in_Data_Deb1_o(I));
              end generate OCIN_in_Data_Deb1;
              
OCIN_in_Data_Deb2:  for I in 0 to 15 generate
              DB_I:  debounce generic map(DB_Cnt => C_OCIN_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => OCIN_in_Data_Deb2_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => OCIN_in_Data_Deb2_o(I));
              end generate OCIN_in_Data_Deb2;
              
  

--  +============================================================================================================================+
--  |                                          Anwender-IO: OCIO  -- FG900_730                                                  |
--  +============================================================================================================================+

OCIO_in_Data_Deb1:  for I in 0 to 15 generate
              DB_I:  debounce generic map(DB_Cnt => C_OCIO_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => OCIO_in_Data_Deb1_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => OCIO_in_Data_Deb1_o(I));
              end generate OCIO_in_Data_Deb1;

OCIO_in_Data_Deb2:  for I in 0 to 7 generate
              DB_I:  debounce generic map(DB_Cnt => C_OCIO_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => OCIO_in_Data_Deb2_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => OCIO_in_Data_Deb2_o(I));
              end generate OCIO_in_Data_Deb2;
              

--  +============================================================================================================================+
--  |                                          Anwender-IO: UIO  -- FG900_740                                                  |
--  +============================================================================================================================+

UIO_Out_Led_Lemo_In: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => UIO_LED_Lemo_In_i,    nLED => UIO_nLED_Lemo_In_o);

UIO_Out_Led_Lemo_Out: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => UIO_LED_Lemo_Out_i,    nLED => UIO_nLED_Lemo_Out_o);

UIO_in_Start_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_UIO_Lemo_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => UIO_Lemo_deb_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => UIO_Lemo_deb_o);

UIO_in_Lo_Data_Deb1:  for I in 0 to 23 generate
              DB_I:  debounce generic map(DB_Cnt => C_UIO_Lo_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => UIO_in_Lo_Data_Deb1_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => UIO_in_Lo_Data_Deb1_o(I));
              end generate UIO_in_Lo_Data_Deb1;
              
UIO_in_Hi_Data_Deb1:  for I in 0 to 23 generate
              DB_I:  debounce generic map(DB_Cnt => C_UIO_Hi_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => UIO_in_Hi_Data_Deb1_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => UIO_in_Hi_Data_Deb1_o(I));
              end generate UIO_in_Hi_Data_Deb1;
 

 

--  +============================================================================================================================+
--  |                                          Anwender-IO: DA  -- FG900_750                                                     |
--  +============================================================================================================================+

-------- DAC_Test_Loop:  AWOut_Reg3 = 1. DAC-Wert, AWOut_Reg4 = 2. DAC-Wert, AWOut_Reg5 = Verzögerungszeit in Taktperioden (8ns)                                                                       

  
P_Dac_Test_Loop:  process (clk_sys, Powerup_Res, dac_state, AWOut_Reg3, AWOut_Reg4, AWOut_Reg5)

    begin
      if (Powerup_Res = '1') then
        dac_state         <= dac_idle;
        DAC_Test_Out      <= (others => '0');    -- Test-Bitmuster
        DAC_Test_Strobe   <=  '0';               -- Output Test-Strobe
        DAC_Wait_cnt      <= 0;                  -- Wait-Counter

        
    ELSIF rising_edge(clk_sys) then
      case dac_state is
        when dac_idle   =>     if  (AW_Config1(15) = '1')  THEN
                                   dac_state          <= dac_data1;
                               else
                                   dac_state          <= dac_idle;
                               end if;
                               
--------------------------------- DAC-Daten und Strobe für Datenwert 1 ------------------------------------------

        when dac_data1    =>    DAC_Test_Out       <= AWOut_Reg3;         -- 1. Dac-Sollwert
                                 dac_state          <= dac_str1h;     
          
        when dac_str1h    =>    DAC_Test_Strobe    <=  '1';               -- Output Test-Strobe
                                dac_state          <= dac_str1l;      
          
        when dac_str1l    =>    DAC_Test_Strobe    <=  '0';               -- Output Test-Strobe
                                DAC_Wait_cnt       <=  to_integer(unsigned(AWOut_Reg5));   -- Wait-Counter 
                                dac_state          <= dac_loop1;
    
        when dac_loop1    =>   if (DAC_Wait_cnt  > 0) then 
                                   DAC_Wait_cnt <= DAC_Wait_cnt-1;    
                                   dac_state    <= dac_loop1;
                               elsE
                                   dac_state    <= dac_wait1;
                               end if;

------------------------------ DAC-Daten und Strobe für Datenwert 2 ------------------------------------------
 
        when dac_wait1    =>    dac_state          <= dac_wait2;          --+--> Laufzeitausgleich    
        when dac_wait2    =>    dac_state          <= dac_data2;          --+


 
        when dac_data2    =>    DAC_Test_Out       <= AWOut_Reg4;         -- 2. Dac-Sollwert
                                dac_state          <= dac_str2h;     
              
        when dac_str2h    =>    DAC_Test_Strobe    <=  '1';               -- Output Test-Strobe
                                dac_state          <= dac_str2l;      
          
        when dac_str2l    =>    DAC_Test_Strobe    <=  '0';               -- Output Test-Strobe
                                DAC_Wait_cnt       <=  to_integer(unsigned(AWOut_Reg5));   -- Wait-Counter 
                                dac_state          <= dac_loop2;
    
        when dac_loop2    =>   if (DAC_Wait_cnt  > 0) then 
                                      DAC_Wait_cnt <= DAC_Wait_cnt-1;    
                                      dac_state    <= dac_loop2;
                                  elsE
                                      dac_state    <= dac_end;
                                  end if;

                                  
         when dac_end     =>   dac_state          <= dac_idle;


      end case;
    end if;
  end process P_Dac_Test_Loop;
  
  
 
 
 
 
 
 
 
 
 
 
--  +===========================================================================================================================+
--  |                                          Anwender-IO:  SPSIO  --  FG900.770 ---                                           |
--  +===========================================================================================================================+

SPSIO_in_Data_Deb:  for I in 0 to 23 generate
              DB_I:  debounce generic map(DB_Cnt => C_SPSIO_Data_Debounce_input_in_ns / clk_in_ns)
              port map(DB_in => SPSIO_in_Data_Deb_i(I),  Reset => Powerup_Res, clk => clk_sys, DB_Out => SPSIO_in_Data_Deb_o(I));
              end generate SPSIO_in_Data_Deb;

--  +==========================================================================================================================+
--  |                                          Anwender-IO:  HFIO  --  FG900.780 ---                                           |
--  +==========================================================================================================================+


HFIO_nLED_Tastpuls: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => HFIO_Tastpuls_i,    nLED => HFIO_nLED_Tastpuls_o);

HFIO_nLED_Sample_Puls_inv: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => HFIO_Sample_Puls_inv_i,    nLED => HFIO_nLED_Sample_Puls_inv_o);

HFIO_nLED_Aux: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => HFIO_Aux_i,    nLED => HFIO_nLED_Aux_o);

HFIO_nLED_Sample_Puls_Display: led_n
  generic map (stretch_cnt => stretch_cnt)
  port map      (ena => Ena_Every_20ms, CLK => clk_sys,   Sig_in => HFIO_Sample_Puls_Display_i,    nLED => HFIO_nLED_Sample_Puls_Display_o);



HFIO_in_AMP_FEHLER_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_HFIO_AMP_FEHLER_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => HFIO_in_AMP_FEHLER_Deb_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => HFIO_in_AMP_FEHLER_Deb_o);
 
HFIO_in_PHASE_FEHLER_Deb:  Debounce
  GENERIC MAP (DB_Cnt => C_HFIO_PHASE_FEHLER_Debounce_input_in_ns / clk_in_ns)    -- Entprellung (C_Debounce_input_in_ns / clk_in_ns)
  PORT MAP  (DB_in => HFIO_in_PHASE_FEHLER_Deb_i,  Reset => Powerup_Res, clk => clk_sys, DB_Out => HFIO_in_PHASE_FEHLER_Deb_o);
 
 
  
  

--  +============================================================================================================================+
--  +============================================================================================================================+
  
  

p_AW_MUX: PROCESS (clk_sys, Powerup_Res, Powerup_Done, s_AW_ID, s_nLED_Out, PIO, A_SEL, signal_tap_clk_250mhz,
             FG_1_sw, FG_1_strobe, P25IO_DAC_Out,
             AW_Config1, CLK_IO, AWin1, AWin2, AWin3, AWin4, AWin5, AWin6, AWin7, 
             AWOut_Reg1, AWOut_Reg1_wr, AWOut_Reg2, AWOut_Reg2_wr, AWOut_Reg3, AWOut_Reg4, AWOut_Reg5, AWOut_Reg6, AWOut_Reg7, 
             Interlock, UIO, hp_la_o, local_clk_is_running, clk_blink,
             s_nLED_Sel, s_nLED_Dtack, s_nLED_inR, s_nLED_User1_o, s_nLED_User2_o, s_nLED_User3_o, 
             P37IO_nLED_Start_o, P37IO_nLED_Stop_o, P37IO_BNC_o, P37IO_nELD_BNC_o, P37IO_in_Data_Deb_o,
             P25IO_EOC_deb_o, P25IO_nLED_Start_o, P25IO_nLED_Stop_o, P25IO_BNC_o, P25IO_nELD_BNC_o,
             P25IO_nDAC_Strobe_o, P25IO_nLED_Ext_Tim_o, P25IO_nADC_ECC_o, P25IO_in_Data_Deb_o, P25IO_ADC_Data_FF_o,
             P25IO_ADC_Data_FF_i, P25IO_ADC_ECC_Start_o, P25IO_Ext_Tim_Strobe_Start_o,
             OCIN_in_Data_Deb1_o, OCIN_in_Data_Deb2_o,
             OCIO_in_Data_Deb1_o, OCIO_in_Data_Deb2_o,
             SPSIO_in_Data_Deb_o,
             HFIO_nLED_Aux_o, HFIO_nLED_Tastpuls_o, HFIO_nLED_Sample_Puls_Display_o,
             HFIO_in_AMP_FEHLER_Deb_o, HFIO_in_PHASE_FEHLER_Deb_o, HFIO_nLED_Sample_Puls_inv_o,
             UIO_HS_IN, UIO_LS_IN,
             UIO_Out, UIO_Data_FG_Out, UIO_nLED_Lemo_In_o, UIO_nLED_Lemo_Out_o,   
             UIO_Lemo_deb_o, UIO_in_Lo_Data_Deb1_o, UIO_in_Hi_Data_Deb1_o,
             DIOB_Config1, DA_DAC1_Out, DA_DAC1_Strobe, DA_DAC2_Out, DA_DAC2_Strobe,
             Tag_Sts, DAC_Test_Out, DAC_Test_Strobe
             )
  
BEGIN

  --############################# Set Defaults ######################################

    PIO(150 downto 16)  <= (OTHERS => 'Z');   -- setze alle IO-Pins auf input;
    UIO(15 downto 0)    <= (OTHERS => 'Z');   -- UIO = Input;

    AWin1(15 downto 0)  <=  x"0000";  -- AW-in-Register 1
    AWin2(15 downto 0)  <=  x"0000";  -- AW-in-Register 2
    AWin3(15 downto 0)  <=  x"0000";  -- AW-in-Register 3
    AWin4(15 downto 0)  <=  x"0000";  -- AW-in-Register 4
    AWin5(15 downto 0)  <=  x"0000";  -- AW-in-Register 5
    AWin6(15 downto 0)  <=  x"0000";  -- AW-in-Register 6
    AWin7(15 downto 0)  <=  x"0000";  -- AW-in-Register 7
    s_AW_ID(7 downto 0) <=  x"FF";    -- Anwender-Karten ID
    
    extension_cid_system <= 0;   -- extension card: cid_system
    extension_cid_group  <= 0;   -- extension card: cid_group
    
    Max_AWOut_Reg_Nr     <= 0;    -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <= 0;    -- Maximale AWIn-Reg-Nummer der Anwendung
 


    Diob_Status1(15 downto 6) <= (OTHERS => '0');       -- Reserve
    Diob_Status1(5 downto 0)  <= Tag_Sts(5 downto 0);   -- Tag-Ctrl Status

    Diob_Status2    <= x"123B";  -- Input-Port-Diob_Status2
    AW_Status1      <= x"123C";  -- "Dummy" Input-Port-AW_Sts    
    AW_Status2      <= x"123D";  -- "Dummy" Input-Port-AW_Sts2
     
    A_Tclk               <= '0';  -- Clock  für HP-Logic-Analysator

    
    s_nLED_User1_i <= '0';        -- LED3 = User 1, -- frei -- 
    s_nLED_User2_i <= '0';        -- LED3 = User 2, -- frei -- 
    s_nLED_User3_i <= '0';        -- LED3 = User 3, -- frei -- 
   
    P37IO_Start_i         <= '0';
    P37IO_Stop_i          <= '0';
    P37IO_Reset_i         <= '0';
    P37IO_in_Data_Deb_i   <= (OTHERS => '0');
    
    P25IO_Start_i            <= '0';
    P25IO_Stop_i             <= '0';
    P25IO_Reset_i            <= '0';
    P25IO_DAC_Strobe_Start_i <= '0';
    P25IO_DAC_Out            <=  (OTHERS => '0');
    P25IO_ADC_ECC_i          <= '0';
    P25IO_ADC_ECC_Start_i    <= '0';
    P25IO_Ext_Tim_i          <= '0';
    P25IO_in_Data_Deb_i      <=  (OTHERS => '0');
    P25IO_ADC_Data_FF_i      <=  (OTHERS => '0');
    P25IO_EOC_i              <= '0';
    
    OCIN_in_Data_Deb1_i      <=  (OTHERS => '0');
    OCIN_in_Data_Deb2_i      <=  (OTHERS => '0');
    OCIO_in_Data_Deb1_i      <=  (OTHERS => '0');
    OCIO_in_Data_Deb2_i      <=  (OTHERS => '0');
                        
    SPSIO_in_Data_Deb_i      <=  (OTHERS => '0');
    
    HFIO_Aux_i                  <= '0';
    HFIO_Tastpuls_i             <= '0';
    HFIO_Sample_Puls_Display_i  <= '0';
    HFIO_Sample_Puls_inv_i      <= '0';
    HFIO_in_AMP_FEHLER_Deb_i    <= '0';       
    HFIO_in_PHASE_FEHLER_Deb_i  <= '0';

    UIO_Data_FG_Out             <= (OTHERS => '0'); -- Data/FG-Output
    UIO_Out                     <= (OTHERS => '0'); -- Data_Output
    UIO_HS_In                   <= (OTHERS => '0'); -- Input auf GND 
    UIO_LS_In                   <= (OTHERS => '0'); -- Input Uext
    UIO_in_Lo_Data_Deb1_i       <= (OTHERS => '0'); -- Data_Input über Optokoppler
    UIO_in_Hi_Data_Deb1_i       <= (OTHERS => '0'); -- Data_Input über Optokoppler
    UIO_LED_Lemo_In_i           <=  '0';            -- Input  "nLED_Lemo_In"
    UIO_LED_Lemo_Out_i          <=  '0';            -- Input  "nLED_Lemo_Out"
    UIO_Lemo_deb_i              <=  '0';            -- Input "Lemo" 

    DA_DAC1_Strobe              <=  '0';                -- Output Strobe
    DA_DAC1_Out                 <=   (OTHERS => '0');   -- Output Bit-15
    DA_DAC2_Strobe              <=  '0';                -- Output Strobe
    DA_DAC2_Out                 <=   (OTHERS => '0');   -- Output Bit-15


  
  
    --#################################################################################
    --###                                                                           ###
    --###                    IO-Stecker-Test mit "BrückenStecker                    ###
    --###                                                                           ###
    --#################################################################################
    
    
    IF  DIOB_Config1(15) = '1'  THEN   -- Config-Reg Bit15 = 1  --> Testmode 


    --- Test der PIO-Pins ---

      AWin1(15 downto 0)  <=  ( CLK_IO,   PIO(16),  PIO(17),  PIO(18),  PIO(19),  PIO(20),  PIO(21),  PIO(22),
                                PIO(23),  PIO(24),  PIO(25),  PIO(26),  PIO(27),  PIO(28),  PIO(29),  PIO(30)   );

          ( PIO(61),  PIO(62),  PIO(59),  PIO(60),  PIO(57),  PIO(58),  PIO(55),  PIO(56),                      
            PIO(53),  PIO(54),  PIO(51),  PIO(52),  PIO(49),  PIO(50),  PIO(47),  PIO(48)   )   <=  AWOut_Reg1(15 downto 0) ;         
  

      AWin2(15 downto 0)  <=  ( PIO(31),  PIO(32),  PIO(33),  PIO(34),  PIO(35),  PIO(36),  PIO(37),  PIO(38),
                                PIO(39),  PIO(40),  PIO(41),  PIO(42),  PIO(43),  PIO(44),  PIO(45),  PIO(46)   );

          ( PIO(77),  PIO(78),  PIO(75),  PIO(76),  PIO(73),  PIO(74),  PIO(71),  PIO(72),
            PIO(69),  PIO(70),  PIO(67),  PIO(68),  PIO(65),  PIO(66),  PIO(63),  PIO(64)   )   <=  AWOut_Reg2(15 downto 0) ;


      AWin3(15 downto 0)  <=  ( PIO(79),  PIO(80),  PIO(81),  PIO(82),  PIO(83),  PIO(84),  PIO(85),  PIO(86),
                                PIO(87),  PIO(88),  PIO(89),  PIO(90),  PIO(91),  PIO(92),  PIO(93),  PIO(94)   );
              
          ( PIO(125), PIO(126), PIO(123), PIO(124), PIO(121), PIO(122), PIO(119), PIO(120),
            PIO(117), PIO(118), PIO(115), PIO(116), PIO(113), PIO(114), PIO(111), PIO(112)  )   <=  AWOut_Reg3(15 downto 0) ;

            
      AWin4(15 downto 0)  <=  ( PIO(95),  PIO(96),  PIO(97),  PIO(98),  PIO(99),  PIO(100), PIO(101), PIO(102),
                                PIO(103), PIO(104), PIO(105), PIO(106), PIO(107), PIO(108), PIO(109), PIO(110)  );
                          
          ( PIO(141), PIO(142), PIO(139), PIO(140), PIO(137), PIO(138), PIO(135), PIO(136),               
            PIO(133), PIO(134), PIO(131), PIO(132), PIO(129), PIO(130), PIO(127), PIO(128)  )   <=  AWOut_Reg4(15 downto 0) ;



    AWin5(15 downto 4)  <=   AWOut_Reg5(15 downto 4); --+   Input [15..4] = Copy der Output-Bits, da Testprog. nur 16 Bit Vergleich.
     AWin5(3  downto 0)  <=  (PIO(143), PIO(144), PIO(149), PIO(150));
 
                    (PIO(147), PIO(148), PIO(145), PIO(146))    <=  AWOut_Reg5(3 downto 0) ;


    --- Test der User-Pins zur VG-Leiste und HPLA1 (HP-Logicanalysator) ---

    UIO(15 downto 0)    <= (OTHERS => 'Z');         -- UIO = Input;
    AWin6(15 downto 0)  <=  UIO(15 downto 0);       -- User-Pins zur VG-Leiste als Input
    A_TA(15 downto 0)    <= AWOut_Reg6(15 downto 0);  -- HPLA1 (HP-Logicanalysator) als Output


    --- Test Codierschalter ---

    AWin7(15 downto 4)  <=  (OTHERS => '0');       -- setze alle unbenutzten Bit's = 0
    AWin7(3 downto 0)    <=  not A_SEL(3 downto 0);   -- Lese Codierschalter (neg. Logic)


 

  else
  
    --#################################################################################
    --#################################################################################
    --###                                                                           ###
    --###                         Stecker Anwender I/O                              ###
    --###                                                                           ###
    --#################################################################################
    --#################################################################################
  
  

    --input: Anwender_ID ---      
      s_AW_ID(7 downto 0)   <=  PIO(150 downto 143);
      AWin5(15 downto 0)    <=  x"00" & s_AW_ID(7 downto 0);-- Anwender_ID
    

  
    --  --- Output: Anwender-LED's ---

    PIO(17) <= s_nLED_Sel;                    -- LED7 = sel Board 
    PIO(19) <= s_nLED_Dtack;                  -- LED6 = Dtack 
    PIO(21) <= s_nLED_inR;                    -- LED5 = interrupt
    PIO(23) <= not Powerup_Done or clk_blink;  -- LED4 = Powerup 
    PIO(25) <= s_nLED_User1_o;                -- LED3 = User 1
    PIO(27) <= s_nLED_User2_o;                -- LED2 = User 2  
    PIO(29) <= s_nLED_User3_o;                -- LED1 = User 3 
    PIO(31) <= local_clk_is_running and clk_blink;  -- LED0 (User-4) = int. Clock 
    

    A_TA     <= hp_la_o; ----------------- Output für HP-Logic-Analysator
    A_Tclk   <= signal_tap_clk_250mhz;  -- Clock  für HP-Logic-Analysator


    UIO(0)  <= not Interlock; -- Ist kein Interlock-Bit gesetzt ==> UIO(0) = 1 (low-aktiv)
    
  CASE s_AW_ID(7 downto 0) IS
  

  WHEN  c_AW_P37IO =>

    --#################################################################################
    --####                  Anwender-IO: P37IO  -- FG900_700                        ###
    --#################################################################################

      extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
      extension_cid_group  <= 27; -- extension card: cid_group, "FG900700_P37IO1" = 27

      Max_AWOut_Reg_Nr     <= 2;  -- Maximale AWOut-Reg-Nummer der Anwendung
      Max_AWIn_Reg_Nr      <= 1;  -- Maximale AWIn-Reg-Nummer der Anwendung

    s_nLED_User1_i <= '0';        -- LED3 = User 1, -- frei -- 
    s_nLED_User2_i <= '0';        -- LED3 = User 2, -- frei -- 
    s_nLED_User3_i <= '0';        -- LED3 = User 3, -- frei -- 

    
    --############################# Start/Stop FF ######################################

    P37IO_Start_i    <=  not PIO(139);           -- input "LemoBuchse-Start" H-Aktiv, nach dem Optokoppler aber L-Aktiv
      PIO(33)         <= P37IO_nLED_Start_o;   --  Output "nLED_Start"
      P37IO_Stop_i    <=  not PIO(141);           -- input "LemoBuchse-Stop" L-Aktiv, nach dem Optokoppler aber L-Aktiv
      PIO(35)         <= P37IO_nLED_Stop_o;    --  Output "nLED_Stop"
      P37IO_Reset_i    <=  not PIO(133);           -- input "Rest-Taster" L-Aktiv

      PIO(51)           <=  P37IO_BNC_o;          -- Output "BNC"
      PIO(37)           <=  P37IO_nELD_BNC_o;    -- Output "nLED_BNC"

      PIO(51)           <=  P37IO_BNC_o;          -- Output "BNC"
      PIO(37)           <=  P37IO_nELD_BNC_o;    -- Output "nLED_BNC"

      PIO(39) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
      PIO(41) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
      PIO(43) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)

      PIO(65) <=  not AWOut_Reg1(7);  --  Output "CO_D7"
      PIO(69) <=  not AWOut_Reg1(6);  --  Output "CO_D6"
      PIO(61) <=  not AWOut_Reg1(5);  --  Output "CO_D5"
      PIO(67) <=  not AWOut_Reg1(4);  --  Output "CO_D4"
      PIO(63) <=  not AWOut_Reg1(3);  --  Output "CO_D3"
      PIO(71) <=  not AWOut_Reg1(2);  --  Output "CO_D2"
      PIO(55) <=  not AWOut_Reg1(1);  --  Output "CO_D1"
      PIO(53) <=  not AWOut_Reg1(0);  --  Output "CO_D0"
      PIO(57) <=  not AWOut_Reg2(1);  --  Output "CO_FAULT"
      PIO(59) <=  not AWOut_Reg2(0);  --  Output "CO_STAT"
                

          

    --############################# Debounce Input ######################################
      
      P37IO_in_Data_Deb_i(15) <=  PIO(131); --  input "HI7"
      P37IO_in_Data_Deb_i(14) <=  PIO(129); --  input "HI6"
      P37IO_in_Data_Deb_i(13) <=  PIO(127); --  input "HI5"
      P37IO_in_Data_Deb_i(12) <=  PIO(125); --  input "HI4"
      P37IO_in_Data_Deb_i(11) <=  PIO(123); --  input "HI3"
      P37IO_in_Data_Deb_i(10) <=  PIO(121); --  input "HI2"
      P37IO_in_Data_Deb_i(9)  <=  PIO(119); --  input "HI1"
      P37IO_in_Data_Deb_i(8)  <=  PIO(117); --  input "HI0"
    
      P37IO_in_Data_Deb_i(7)  <=  PIO(115); --  input "LO7"
      P37IO_in_Data_Deb_i(6)  <=  PIO(113); --  input "LO6"
      P37IO_in_Data_Deb_i(5)  <=  PIO(111); --  input "LO5"
      P37IO_in_Data_Deb_i(4)  <=  PIO(109); --  input "LO4"
      P37IO_in_Data_Deb_i(3)  <=  PIO(107); --  input "LO3"
      P37IO_in_Data_Deb_i(2)  <=  PIO(105); --  input "LO2"
      P37IO_in_Data_Deb_i(1)  <=  PIO(103); --  input "LO1"
      P37IO_in_Data_Deb_i(0)  <=  PIO(101); --  input "LO0"
    
    AWin1  <=  P37IO_in_Data_Deb_o;



  WHEN   c_AW_P25IO =>
  
    --#################################################################################
    --####                    Anwender-IO: P25IO  -- FG900_710                      ###
    --#################################################################################

--    ------+-----------------------------------------------------------------------    --
--     1    | ADC_mode;  1 = ADC-Daten aus dem Speicher, gespeichert mit EOC            --
--          |            0 = ADC-Daten die am Sub-D Stecker anstehen.                   --
--    ------+-----------------------------------------------------------------------    --
--     0    | FG_mode;  1 = Funktiongenerator-Mode, DAC-Werte kommen von FG_Data und    --
--          |               werden mit FG_Strobe uebernommen. Kein externer Trigger!    --
--          |           0 = Software-Mode, DAC-Werte, kommen vom SCU-Bus-Slave.         --
--    ------+-----------------------------------------------------------------------    --
    
    extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
    extension_cid_group  <= 28; -- extension card: cid_group, "FG900710_P25IO1" = 28

    Max_AWOut_Reg_Nr     <= 1;  -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <= 1;  -- Maximale AWIn-Reg-Nummer der Anwendung

    
      s_nLED_User1_i <= AW_Config1(0);          -- LED3 = User 1, DAC-Data vom FG
      s_nLED_User2_i <= not P25IO_nADC_ECC_o;  -- LED2 = User 2, ECC zum ADC (Enable)  
      s_nLED_User3_i <= P25IO_EOC_deb_o;       -- LED1 = User 3, EOC vom ADC 
    
    
 
    --############################# Start/Stop FF ######################################

    P25IO_Start_i    <=  not PIO(71);           -- input "LemoBuchse-Start" H-Aktiv, nach dem Optokoppler aber L-Aktiv
      PIO(87)         <= P25IO_nLED_Start_o;     --  Output "nLED_Start"
      P25IO_Stop_i    <=  not PIO(75);           -- input "LemoBuchse-Stop" L-Aktiv, nach dem Optokoppler aber L-Aktiv
      PIO(89)         <= P25IO_nLED_Stop_o;    --  Output "nLED_Stop"
      P25IO_Reset_i    <=  not PIO(67);           -- input "Rest-Taster" L-Aktiv

      PIO(103)          <=  P25IO_BNC_o;          -- Output "BNC"
      PIO(91)           <=  P25IO_nELD_BNC_o;      -- Output "nLED_BNC"
 

    --############################# DAC out ######################################

    IF  (AW_Config1(0) = '1')  THEN
  
--           FG_mode; DAC-Werte kommen von FG_Data und werden mit FG_Strobe uebernommen. Kein externer Trigger! 

        P25IO_DAC_Strobe_Start_i  <=  FG_1_strobe;          -- FG_1_strobe (vom Funktionsgen)
        PIO(105)              <=  P25IO_nDAC_Strobe_o;    --  Der Strobe-Output ist "LO"-Aktiv
            P25IO_DAC_Out(15 downto 0) <= FG_1_sw(31 downto 16);  
        Else
--           Software-Mode, DAC-Werte, kommen vom SCU-Bus-Slave. Externe Triggerung mit pos. oder neg. Flanke, kann eingeschaltet werden. 

        P25IO_DAC_Strobe_Start_i  <=  AWOut_Reg1_wr;        -- AWOut_Reg1_wr (vom SCU-Bus-Slave)
        PIO(105)                  <=  P25IO_nDAC_Strobe_o;    --  Der Strobe-Output ist "LO"-Aktiv  
            P25IO_DAC_Out(15 downto 0) <= AWOut_Reg1(15 downto 0);
      END IF; 


    --    Output DAC-Daten

      PIO(77) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
      PIO(79) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
      PIO(81) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
      PIO(83) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
      PIO(95) <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)


      PIO(107)  <=  not P25IO_DAC_Out(15);  -- Output Bit-15
      PIO(109)  <=  not P25IO_DAC_Out(14);  -- Output Bit-14
      PIO(111)  <=  not P25IO_DAC_Out(13);  -- Output Bit-13
      PIO(113)  <=  not P25IO_DAC_Out(12);  -- Output Bit-12
      PIO(115)  <=  not P25IO_DAC_Out(11);  -- Output Bit-11
      PIO(117)  <=  not P25IO_DAC_Out(10);  -- Output Bit-10
      PIO(119)  <=  not P25IO_DAC_Out(9);   -- Output Bit-9
      PIO(121)  <=  not P25IO_DAC_Out(8);   -- Output Bit-8
      PIO(123)  <=  not P25IO_DAC_Out(7);   -- Output Bit-7
      PIO(125)  <=  not P25IO_DAC_Out(6);   -- Output Bit-6
      PIO(127)  <=  not P25IO_DAC_Out(5);   -- Output Bit-5
      PIO(129)  <=  not P25IO_DAC_Out(4);   -- Output Bit-4
      PIO(131)  <=  not P25IO_DAC_Out(3);   -- Output Bit-3
      PIO(133)  <=  not P25IO_DAC_Out(2);   -- Output Bit-2
      PIO(135)  <=  not P25IO_DAC_Out(1);   -- Output Bit-1
      PIO(137)  <=  not P25IO_DAC_Out(0);   -- Output Bit-0
    


    --############################# ADC in ######################################


--    Start ADC-Conversion    
    P25IO_ADC_ECC_Start_i  <=  AWOut_Reg2_wr;                          -- pos. Flanke vom AWOut_Reg2_wr (vom SCU-Bus-Slave) ==> Puls von 1 Clock-Breite.
    P25IO_ADC_ECC_i      <=  ((P25IO_ADC_ECC_Start_o and AWOut_Reg2(0)) or     -- wenn AWOut_Reg2(0)=1 ist oder  
                        P25IO_Ext_Tim_Strobe_Start_o);              -- ein ext. Trigger ==> Puls = 2us 

    P25IO_Ext_Tim_i      <=  not PIO(85);           -- input "LemoBuchse-ExtTiming" H-Aktiv, nach dem Optokoppler aber L-Aktiv
      PIO(93)             <= P25IO_nLED_Ext_Tim_o;   --  Output "nLED_Extern-Timing"

    PIO(101)            <=  not P25IO_nADC_ECC_o;  --  Der Strobe-Output für ECC "Hi"-Aktiv
    

--    input ADC-Daten
    P25IO_in_Data_Deb_i(15)  <=   PIO(41);  --------------  input "HI7"      
    P25IO_in_Data_Deb_i(14)  <=   PIO(43);  --------------  input "HI6"     
    P25IO_in_Data_Deb_i(13)  <=   PIO(37);  --------------  input "HI5"     
    P25IO_in_Data_Deb_i(12)  <=   PIO(39);  --------------  input "HI4"     
    P25IO_in_Data_Deb_i(11)  <=   PIO(33);  --------------  input "HI3"     
    P25IO_in_Data_Deb_i(10)  <=   PIO(35);  --------------  input "HI2"     
    P25IO_in_Data_Deb_i(9)  <=   PIO(49);  --------------  input "HI1"    
    P25IO_in_Data_Deb_i(8)  <=   PIO(51);  --------------  input "HI0"    
    P25IO_in_Data_Deb_i(7)  <=   PIO(53);  --  input "Lo7"    
    P25IO_in_Data_Deb_i(6)  <=   PIO(55);  --  input "LO6"    
    P25IO_in_Data_Deb_i(5)  <=   PIO(45);  --  input "LO5"    
    P25IO_in_Data_Deb_i(4)  <=   PIO(47);  --  input "LO4"    
    P25IO_in_Data_Deb_i(3)  <=   PIO(57);  --  input "LO3"    
    P25IO_in_Data_Deb_i(2)  <=   PIO(59);  --  input "LO2"    
    P25IO_in_Data_Deb_i(1)  <=   PIO(61);  --  input "LO1"    
    P25IO_in_Data_Deb_i(0)  <=   PIO(63);  --  input "LO0"    
      
    P25IO_ADC_Data_FF_i    <=  P25IO_in_Data_Deb_o;

    
--    ADC-EOC
    P25IO_EOC_i    <=    PIO(65); -- input Strobe für ADC-Daten

  
    
    IF  (AW_Config1(1) = '1')  THEN
  
--          ADC-Daten aus dem Speicher (gespeichert mit EOC) 
        AWin1    <=    P25IO_ADC_Data_FF_o;     -- Output "Daten ADC-Register"
       Else
--           ADC-Daten die am Sub-D Stecker anstehen. 
        AWin1    <=    P25IO_ADC_Data_FF_i;     -- Output "Daten ADC-Register"
      END IF; 


 
  
  WHEN   c_AW_OCin =>

    --#################################################################################
    --####                    Anwender-IO: OCin -- FG900_720                        ###
    --#################################################################################

      extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
      extension_cid_group  <= 29; -- extension card: cid_group, "FG900720_OCin1" = 29

     Max_AWOut_Reg_Nr     <= 1;  -- Maximale AWOut-Reg-Nummer der Anwendung
     Max_AWIn_Reg_Nr      <= 2;  -- Maximale AWIn-Reg-Nummer der Anwendung


    s_nLED_User1_i <= '0';        -- LED3 = User 1, -- frei -- 
    s_nLED_User2_i <= '0';        -- LED3 = User 2, -- frei -- 
    s_nLED_User3_i <= '0';        -- LED3 = User 3, -- frei -- 
    
    
    

      OCIN_in_Data_Deb1_i(15) <=  '0';      --------------  Frei
      OCIN_in_Data_Deb1_i(14) <=  '0';      --------------  Frei
      OCIN_in_Data_Deb1_i(13) <=  PIO(73);  --------------  input "B5"
      OCIN_in_Data_Deb1_i(12) <=  PIO(75);  --------------  input "B4"
      OCIN_in_Data_Deb1_i(11) <=  PIO(93);  --------------  input "B3"
      OCIN_in_Data_Deb1_i(10) <=  PIO(95);  --------------  input "B2"
      OCIN_in_Data_Deb1_i(9)  <=  PIO(97);  --------------  input "B1"
      OCIN_in_Data_Deb1_i(8)  <=  PIO(99);  --------------  input "B0"
      OCIN_in_Data_Deb1_i(7)  <=  PIO(117); --  input "A7"
      OCIN_in_Data_Deb1_i(6)  <=  PIO(119); --  input "A6"
      OCIN_in_Data_Deb1_i(5)  <=  PIO(121); --  input "A5"
      OCIN_in_Data_Deb1_i(4)  <=  PIO(123); --  input "A4"
      OCIN_in_Data_Deb1_i(3)  <=  PIO(133); --  input "A3"
      OCIN_in_Data_Deb1_i(2)  <=  PIO(135); --  input "A2"
      OCIN_in_Data_Deb1_i(1)  <=  PIO(137); --  input "A1"
      OCIN_in_Data_Deb1_i(0)  <=  PIO(139); --  input "A0"
    
    AWin1    <=    OCIN_in_Data_Deb1_o;
    
  
      OCIN_in_Data_Deb2_i(15) <=  PIO(81);  --------------  input "D7"
      OCIN_in_Data_Deb2_i(14) <=  PIO(79);  --------------  input "D6"
      OCIN_in_Data_Deb2_i(13) <=  PIO(77);  --------------  input "D5"
      OCIN_in_Data_Deb2_i(12) <=  PIO(83);  --------------  input "D4"
      OCIN_in_Data_Deb2_i(11) <=  PIO(85);  --------------  input "D3"
      OCIN_in_Data_Deb2_i(10) <=  PIO(87);  --------------  input "D2"
      OCIN_in_Data_Deb2_i(9)  <=  PIO(89);  --------------  input "D1"
      OCIN_in_Data_Deb2_i(8)  <=  PIO(91);  --------------  input "D0"
      OCIN_in_Data_Deb2_i(7)  <=  PIO(109); --  input "C7"
      OCIN_in_Data_Deb2_i(6)  <=  PIO(111); --  input "C6"
      OCIN_in_Data_Deb2_i(5)  <=  PIO(113); --  input "C5"
      OCIN_in_Data_Deb2_i(4)  <=  PIO(115); --  input "C4"
      OCIN_in_Data_Deb2_i(3)  <=  PIO(125); --  input "C3"
      OCIN_in_Data_Deb2_i(2)  <=  PIO(127); --  input "C2"
      OCIN_in_Data_Deb2_i(1)  <=  PIO(129); --  input "C1"
      OCIN_in_Data_Deb2_i(0)  <=  PIO(131); --  input "C0"

    AWin2    <=    OCIN_in_Data_Deb2_o;
   
    
      PIO(39)   <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)

      PIO(49) <=  not AWOut_Reg1(3);  --  Output "2CB2"
      PIO(47) <=  not AWOut_Reg1(2);  --  Output "2CA2"
      PIO(45) <=  not AWOut_Reg1(1);  --  Output "1CB2"
      PIO(43) <=  not AWOut_Reg1(0);  --  Output "1CA2"


    
  WHEN   c_AW_OCIO =>
  
    --#################################################################################
    --####                      Anwender-IO: OCIO -- FG900_730                      ###
    --#################################################################################

      extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
      extension_cid_group  <= 30; -- extension card: cid_group, "FG900730_OCIO1" = 30

      Max_AWOut_Reg_Nr     <= 1;  -- Maximale AWOut-Reg-Nummer der Anwendung
      Max_AWIn_Reg_Nr      <= 2;  -- Maximale AWIn-Reg-Nummer der Anwendung

    
    s_nLED_User1_i <= '0';        -- LED3 = User 1, -- frei -- 
    s_nLED_User2_i <= '0';        -- LED3 = User 2, -- frei -- 
    s_nLED_User3_i <= '0';        -- LED3 = User 3, -- frei -- 
    

      OCIO_in_Data_Deb1_i(15) <=  PIO(45);  --------------  input "C7"
      OCIO_in_Data_Deb1_i(14) <=  PIO(47);  --------------  input "C6"
      OCIO_in_Data_Deb1_i(13) <=  PIO(51);  --------------  input "C5"
      OCIO_in_Data_Deb1_i(12) <=  PIO(53);  --------------  input "C4"
      OCIO_in_Data_Deb1_i(11) <=  PIO(37);  --------------  input "C3"
      OCIO_in_Data_Deb1_i(10) <=  PIO(39);  --------------  input "C2"
      OCIO_in_Data_Deb1_i(9)  <=  PIO(41);  --------------  input "C1"
      OCIO_in_Data_Deb1_i(8)  <=  PIO(43);  --------------  input "C0"
      OCIO_in_Data_Deb1_i(7)  <=  PIO(127); --  input "A7"
      OCIO_in_Data_Deb1_i(6)  <=  PIO(125); --  input "A6"
      OCIO_in_Data_Deb1_i(5)  <=  PIO(123); --  input "A5"
      OCIO_in_Data_Deb1_i(4)  <=  PIO(121); --  input "A4"
      OCIO_in_Data_Deb1_i(3)  <=  PIO(99);  --  input "A3"
      OCIO_in_Data_Deb1_i(2)  <=  PIO(97);  --  input "A2"
      OCIO_in_Data_Deb1_i(1)  <=  PIO(95);  --  input "A1"
      OCIO_in_Data_Deb1_i(0)  <=  PIO(93);  --  input "A0"

    AWin1    <=    OCIO_in_Data_Deb1_o;
    
    
      OCIO_in_Data_Deb2_i(7)  <=  PIO(89);  --  input "D7"    
      OCIO_in_Data_Deb2_i(6)  <=  PIO(91);  --  input "D6"
      OCIO_in_Data_Deb2_i(5)  <=  PIO(119); --  input "D5"
      OCIO_in_Data_Deb2_i(4)  <=  PIO(117); --  input "D4"
      OCIO_in_Data_Deb2_i(3)  <=  PIO(87);  --  input "D3"
      OCIO_in_Data_Deb2_i(2)  <=  PIO(85);  --  input "D2"
      OCIO_in_Data_Deb2_i(1)  <=  PIO(83);  --  input "D1"
      OCIO_in_Data_Deb2_i(0)  <=  PIO(81);  --  input "D0"

      AWin2(15 downto 8)  <=  (OTHERS => '0');  -- inPUT = 0; 
      AWin2(15 downto 8)  <=  OCIO_in_Data_Deb2_o;  
  

      PIO(77)   <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
      
      PIO(105)  <=  not AWOut_Reg1(11); ----------------  Output "CD2"
      PIO(61)   <=  not AWOut_Reg1(10); ----------------  Output "CC2"
      PIO(107)  <=  not AWOut_Reg1(9);  ----------------  Output "CB2"
      PIO(115)  <=  not AWOut_Reg1(8);  ----------------  Output "CA2"
      PIO(109)  <=  not AWOut_Reg1(7);  --  Output "B7"
      PIO(111)  <=  not AWOut_Reg1(6);  --  Output "B6"
      PIO(113)  <=  not AWOut_Reg1(5);  --  Output "B5"
      PIO(101)  <=  not AWOut_Reg1(4);  --  Output "B4"
      PIO(103)  <=  not AWOut_Reg1(3);  --  Output "B3"
      PIO(59)   <=  not AWOut_Reg1(2);  --  Output "B2"
      PIO(57)   <=  not AWOut_Reg1(1);  --  Output "B1"
      PIO(55)   <=  not AWOut_Reg1(0);  --  Output "B0"


      
  WHEN   c_AW_UIO =>
  
    --#####################################################################################
    --####                       Anwender-IO: UIO  -- FG900_740                         ###
    --#####################################################################################

--    ------+-----------------------------------------------------------------------    --
--      9   | FG_mode;  1 = Funktiongenerator-Mode, DAC-Werte kommen von FG_Data und    --
--          |           0 = Software-Mode, DAC-Werte, kommen vom SCU-Bus-Slave.         --
--    ------+-----------------------------------------------------------------------    --
--      8   | Output-Polarität Lemo,         1 = Negativ,  0 = Positiv(Default)         --
--      7   | Output-Polarität Bit [23..0],  1 = Negativ,  0 = Positiv(Default)         --
--    ------+-----------------------------------------------------------------------    --
--      6   | Enable Output-Lemo,            1 = Enable,   0 = Disable(Default)         --
--      5   | Enable Output-Bit [23..20],    1 = Enable,   0 = Disable(Default)         --
--      4   | Enable Output-Bit [19..16],    1 = Enable,   0 = Disable(Default)         --
--      3   | Enable Output-Bit [15..12],    1 = Enable,   0 = Disable(Default)         --
--      2   | Enable Output-Bit [11..8],     1 = Enable,   0 = Disable(Default)         --
--      1   | Enable Output-Bit [7..4],      1 = Enable,   0 = Disable(Default)         --
--      0   | Enable Output-Bit [3..0],      1 = Enable,   0 = Disable(Default)         --
--    ------+-----------------------------------------------------------------------    --

    extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
    extension_cid_group  <= 31; -- extension card: cid_group, "FG900740_UIO1" = 31

    Max_AWOut_Reg_Nr     <= 2;  -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <= 2;  -- Maximale AWIn-Reg-Nummer der Anwendung
      
    --################### Output-Daten von den AWOut_Registern oder dem FG ##################

    IF  (AW_Config1(9) = '1')  THEN
            UIO_Data_FG_Out(23 downto 0) <= FG_1_sw(31 downto 8);       -- Daten vom FG 
        Else
            UIO_Data_FG_Out(23 DOWNTO 20) <=  AWOut_Reg2( 7 DOWNTO  4); -- IO(23..20) = AWOut_Reg2( 7 ...4)
            UIO_Data_FG_Out(19 DOWNTO 16) <=  AWOut_Reg2( 3 DOWNTO  0); -- IO(19..16) = AWOut_Reg2( 3 ...0)
            UIO_Data_FG_Out(15 DOWNTO 12) <=  AWOut_Reg1(15 DOWNTO 12); -- IO(15..12) = AWOut_Reg1(15 ..12)
            UIO_Data_FG_Out(11 DOWNTO  8) <=  AWOut_Reg1(11 DOWNTO  8); -- IO(11...8) = AWOut_Reg1(11 ...8)
            UIO_Data_FG_Out( 7 DOWNTO  4) <=  AWOut_Reg1( 7 DOWNTO  4); -- IO( 7...4) = AWOut_Reg1( 7....4)
            UIO_Data_FG_Out( 3 DOWNTO  0) <=  AWOut_Reg1( 3 DOWNTO  0); -- IO( 3...0) = AWOut_Reg1( 3....0)
    END IF; 
              
    --######################## Einstellen der Output-Polarität ##############################

    IF  (AW_Config1(7) = '1')  THEN
            UIO_Out(23 DOWNTO 0) <=  Not UIO_Data_FG_Out(23 downto 0); -- Output negativ 
        Else
            UIO_Out(23 DOWNTO 0) <=      UIO_Data_FG_Out(23 downto 0); -- Output positiv 
    END IF; 

    --################################### Output-Enable ##################################

    PIO(132) <=  not AW_Config1(6);  ---- Output_Enable (Lemo)
    PIO(24)  <=  not AW_Config1(5);  ---- Output_Enable (IO_20-23)
    PIO(26)  <=  not AW_Config1(4);  ---- Output_Enable (IO_16-19)
    PIO(28)  <=  not AW_Config1(3);  ---- Output_Enable (IO_12-15)
    PIO(30)  <=  not AW_Config1(2);  ---- Output_Enable (IO_8-11)
    PIO(22)  <=  not AW_Config1(1);  ---- Output_Enable (IO_4-7)
    PIO(20)  <=  not AW_Config1(0);  ---- Output_Enable (IO_3-0)
      
      
    --########################## Daten zum Piggy-Stecker JPIO1 ###########################

    PIO(69) <=  UIO_Out(23);  PIO(71) <=  UIO_Out(22);  PIO(73) <=  UIO_Out(21);  PIO(75) <=  UIO_Out(20); --- Output-Pins zum Piggy [23..20]
    PIO(61) <=  UIO_Out(19);  PIO(63) <=  UIO_Out(18);  PIO(65) <=  UIO_Out(17);  PIO(67) <=  UIO_Out(16); --- Output-Pins zum Piggy [19..16]
    PIO(62) <=  UIO_Out(15);  PIO(66) <=  UIO_Out(14);  PIO(70) <=  UIO_Out(13);  PIO(74) <=  UIO_Out(12); --- Output-Pins zum Piggy [15..12]
    PIO(78) <=  UIO_Out(11);  PIO(82) <=  UIO_Out(10);  PIO(86) <=  UIO_Out(9);   PIO(90) <=  UIO_Out(8);  --- Output-Pins zum Piggy [11.. 8]
    PIO(77) <=  UIO_Out(7);   PIO(79) <=  UIO_Out(6);   PIO(81) <=  UIO_Out(5);   PIO(83) <=  UIO_Out(4);  --- Output-Pins zum Piggy [ 7.. 4]
    PIO(85) <=  UIO_Out(3);   PIO(87) <=  UIO_Out(2);   PIO(89) <=  UIO_Out(1);   PIO(91) <=  UIO_Out(0);  --- Output-Pins zum Piggy [ 3.. 0]

    
    --####################### Lemo: Output, Polarität und LED ############################

    IF  (AW_Config1(8) = '1')  THEN
            PIO(133)    <=  Not AWOut_Reg2(15);   -- Lemo-Output negativ 
        Else
            PIO(133)    <=      AWOut_Reg2(15);   -- Lemo-Output positiv 
    END IF; 

    UIO_LED_Lemo_Out_i  <=  AWOut_Reg2(15);        --  Input  "nLED_Lemo_Out"
    PIO(141)            <=  UIO_nLED_Lemo_Out_o;  --  Output "nLED_Lemo_Out"


    --######################## Lemo: Input, Debounce und LED ############################

    UIO_Lemo_deb_i      <=  NOT PIO(127);        --  Input "Lemo-Buchse" 
--  AWin2(15)           <=  UIO_Lemo_deb_o;      --  Input "Lemo-Buchse" entprellt
    AWin2(15)           <=  PIO(127);            --  Input "Lemo-Buchse" ===== nicht entprellt =====
    
    UIO_LED_Lemo_In_i   <=  UIO_Lemo_deb_o;      --  Input  "nLED_Lemo_IN"
    PIO(139)            <=  UIO_nLED_Lemo_In_o;  --  Output "nLED_Lemo_IN"

    
    --############################# High-Signal-Input-Daten vom Piggy-Stecker JPIO1 #####################################

    UIO_HS_IN(23)  <=  PIO(103);  UIO_HS_IN(22)  <=  PIO(99);   UIO_HS_IN(21)  <=  PIO(95);   UIO_HS_IN(20)  <=  PIO(57);    
    UIO_HS_IN(19)  <=  PIO(53);   UIO_HS_IN(18)  <=  PIO(49);   UIO_HS_IN(17)  <=  PIO(45);   UIO_HS_IN(16)  <=  PIO(41);    
    UIO_HS_IN(15)  <=  PIO(37);   UIO_HS_IN(14)  <=  PIO(115);  UIO_HS_IN(13)  <=  PIO(111);  UIO_HS_IN(12)  <=  PIO(107);    
    UIO_HS_IN(11)  <=  PIO(114);  UIO_HS_IN(10)  <=  PIO(110);  UIO_HS_IN(9)   <=  PIO(106);  UIO_HS_IN(8)   <=  PIO(102);    
    UIO_HS_IN(7)   <=  PIO(98);   UIO_HS_IN(6)   <=  PIO(94);   UIO_HS_IN(5)   <=  PIO(56);   UIO_HS_IN(4)   <=  PIO(52);    
    UIO_HS_IN(3)   <=  PIO(48);   UIO_HS_IN(2)   <=  PIO(44);   UIO_HS_IN(1)   <=  PIO(40);   UIO_HS_IN(0)   <=  PIO(36);    

    UIO_in_Hi_Data_Deb1_i(23 DOWNTO 0)  <=  NOT UIO_HS_IN(23 DOWNTO 0);   -- Input-Daten an Debounce-Input

    AWin2( 7 DOWNTO 0)  <=  UIO_in_Hi_Data_Deb1_o(23 DOWNTO 16);          -- Debounce-Output zum AWin2-Register
    AWin1(15 DOWNTO 0)  <=  UIO_in_Hi_Data_Deb1_o(15 DOWNTO  0);          -- Debounce-Output zum AWin1-Register
    
    --############################# Low-Signal-Input-Daten vom Piggy-Stecker JPIO1 #####################################
    
    UIO_LS_IN(23)  <=  PIO(101);  UIO_LS_IN(22)  <=  PIO(97);   UIO_LS_IN(21)  <=  PIO(93);   UIO_LS_IN(20)  <=  PIO(55);    
    UIO_LS_IN(19)  <=  PIO(51);   UIO_LS_IN(18)  <=  PIO(47);   UIO_LS_IN(17)  <=  PIO(43);   UIO_LS_IN(16)  <=  PIO(39);    
    UIO_LS_IN(15)  <=  PIO(35);   UIO_LS_IN(14)  <=  PIO(113);  UIO_LS_IN(13)  <=  PIO(109);  UIO_LS_IN(12)  <=  PIO(105);    
    UIO_LS_IN(11)  <=  PIO(116);  UIO_LS_IN(10)  <=  PIO(112);  UIO_LS_IN(9)   <=  PIO(108);  UIO_LS_IN(8)   <=  PIO(104);    
    UIO_LS_IN(7)   <=  PIO(100);  UIO_LS_IN(6)   <=  PIO(96);   UIO_LS_IN(5)   <=  PIO(58);   UIO_LS_IN(4)   <=  PIO(54);    
    UIO_LS_IN(3)   <=  PIO(50);   UIO_LS_IN(2)   <=  PIO(46);   UIO_LS_IN(1)   <=  PIO(42);   UIO_LS_IN(0)   <=  PIO(38);    

    UIO_in_Lo_Data_Deb1_i(23 DOWNTO 0)  <=  NOT UIO_LS_IN(23 DOWNTO 0);   --  Input-Daten an Debounce-Input

    AWin4( 7 DOWNTO 0)  <=  UIO_in_Lo_Data_Deb1_o(23 DOWNTO 16);          -- Debounce-Output zum AWin2-Register
    AWin3(15 DOWNTO 0)  <=  UIO_in_Lo_Data_Deb1_o(15 DOWNTO  0);          -- Debounce-Output zum AWin1-Register
  
    

  WHEN   c_AW_DA =>
      
    --###################################################################################
    --####                  Anwender-IO: DA(DAC/ADC)  -- FG900_750                    ###
    --###################################################################################
--
--                                                                                
--   ----+------------------------------------------------------------------------------------- 
--    15 | Test_Mode;  0 = Normalbetrieb      
--       |             1 = Testbetrieb :  AWOut_Reg3 = 1. DAC-Wert
--       |                                AWOut_Reg4 = 2. DAC-Wert
--       |                                AWOut_Reg5 = Verzögerungszeit in Taktperioden (8ns)                                                                       
--   ----+------------------------------------------------------------------------------------- 
--     8 | frei     
--     | | frei 
--     1 | frei     
--   ----+------------------------------------------------------------------------------------ 
--     0 | FG_mode;  1 = Funktiongenerator-Mode, DAC-Werte kommen von FG_Data und 
--       |               werden mit FG_Strobe uebernommen. Kein externer Trigger! 
--       |           0 = Software-Mode, DAC-Werte, kommen vom SCU-Bus-Slave.      
--    ---+------------------------------------------------------------------------------------ 

    extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
    extension_cid_group  <= 32; -- extension card: cid_group, "FG900740_UIO1" = 31

    Max_AWOut_Reg_Nr     <= 2;  -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <= 2;  -- Maximale AWIn-Reg-Nummer der Anwendung
    

    Max_AWOut_Reg_Nr     <= 3;  -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <= 1;  -- Maximale AWIn-Reg-Nummer der Anwendung

    
      s_nLED_User1_i <= AW_Config1(0);        -- LED3 = User 1, DAC-Data vom FG
      s_nLED_User2_i <= '0';                  -- LED3 = User 2, -- frei -- 
      s_nLED_User3_i <= '0';                  -- LED3 = User 3, -- frei -- 
    
    
    IF  (AW_Config1(15) = '1')  THEN
    
      DA_DAC1_Strobe   <=  DAC_Test_Strobe;        -- Output Strobe
      DA_DAC1_Out      <=  DAC_Test_Out;           -- Test-Bitmuster
      DA_DAC2_Strobe   <=  '0';                    -- Output Strobe
      DA_DAC2_Out      <=  (others => '0');        -- Test-Bitmuster
    
      Else

      DA_DAC1_Strobe <=  (AWOut_Reg1_wr or (Powerup_Res));  -- Output Strobe
      DA_DAC1_Out    <=   AWOut_Reg1;  -- Output Bit-15
    

      DA_DAC2_Strobe <=  (AWOut_Reg2_wr or (Powerup_Res));  -- Output Strobe
      DA_DAC2_Out    <=   AWOut_Reg2;  -- Output Bit-15

    
    END IF; 

 --############################# DAC out ######################################

      PIO(99)   <=  not DA_DAC1_Strobe;  -- Output Strobe
      PIO(133)  <=  not DA_DAC2_Strobe;  -- Output Strobe
    
      PIO(97)  <=  not  DA_DAC1_Out(15);  -- Output Bit-15
      PIO(95)  <=       DA_DAC1_Out(14);  -- Output Bit-14
      PIO(93)  <=       DA_DAC1_Out(13);  -- Output Bit-13
      PIO(91)  <=       DA_DAC1_Out(12);  -- Output Bit-12
      PIO(89)  <=       DA_DAC1_Out(11);  -- Output Bit-11
      PIO(87)  <=       DA_DAC1_Out(10);  -- Output Bit-10
      PIO(85)  <=       DA_DAC1_Out(9);   -- Output Bit-9
      PIO(83)  <=       DA_DAC1_Out(8);   -- Output Bit-8
      PIO(81)  <=       DA_DAC1_Out(7);   -- Output Bit-7
      PIO(79)  <=       DA_DAC1_Out(6);   -- Output Bit-6
      PIO(77)  <=       DA_DAC1_Out(5);   -- Output Bit-5
      PIO(75)  <=       DA_DAC1_Out(4);   -- Output Bit-4
      PIO(73)  <=       DA_DAC1_Out(3);   -- Output Bit-3
      PIO(71)  <=       DA_DAC1_Out(2);   -- Output Bit-2
      PIO(69)  <=       DA_DAC1_Out(1);   -- Output Bit-1
      PIO(67)  <=       DA_DAC1_Out(0);   -- Output Bit-0
 
    
      PIO(131)  <=  not DA_DAC2_Out(15);  -- Output Bit-15
      PIO(129)  <=      DA_DAC2_Out(14);  -- Output Bit-14
      PIO(127)  <=      DA_DAC2_Out(13);  -- Output Bit-13
      PIO(125)  <=      DA_DAC2_Out(12);  -- Output Bit-12
      PIO(123)  <=      DA_DAC2_Out(11);  -- Output Bit-11
      PIO(121)  <=      DA_DAC2_Out(10);  -- Output Bit-10
      PIO(119)  <=      DA_DAC2_Out(9);   -- Output Bit-9
      PIO(117)  <=      DA_DAC2_Out(8);   -- Output Bit-8
      PIO(115)  <=      DA_DAC2_Out(7);   -- Output Bit-7
      PIO(113)  <=      DA_DAC2_Out(6);   -- Output Bit-6
      PIO(111)  <=      DA_DAC2_Out(5);   -- Output Bit-5
      PIO(109)  <=      DA_DAC2_Out(4);   -- Output Bit-4
      PIO(107)  <=      DA_DAC2_Out(3);   -- Output Bit-3
      PIO(105)  <=      DA_DAC2_Out(2);   -- Output Bit-2
      PIO(103)  <=      DA_DAC2_Out(1);   -- Output Bit-1
      PIO(101)  <=      DA_DAC2_Out(0);   -- Output Bit-0
    


  WHEN   c_AW_Frei =>
      
    --###################################################################################
    --####                  Anwender-IO: DA(DAC/ADC)  -- FG900_760                    ###
    --###################################################################################



  WHEN   c_AW_SPSIO =>
      
    --###################################################################################
    --####                  Anwender-IO: DA(DAC/ADC)  -- FG900_770                    ###
    --###################################################################################

    extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
    extension_cid_group  <= 35; -- extension card: cid_group, "FG900770_SPSIO1" = 34

    Max_AWOut_Reg_Nr     <= 1;  -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <= 2;  -- Maximale AWIn-Reg-Nummer der Anwendung

    
    s_nLED_User1_i <= '0';        -- LED3 = User 1, -- frei -- 
    s_nLED_User2_i <= '0';        -- LED3 = User 2, -- frei -- 
    s_nLED_User3_i <= '0';        -- LED3 = User 3, -- frei -- 



  --========================== Input Register 1+2 ======================================

    SPSIO_in_Data_Deb_i(23) <=  PIO(35); --  input "23"
    SPSIO_in_Data_Deb_i(22) <=  PIO(37); --  input "22"
    SPSIO_in_Data_Deb_i(21) <=  PIO(39); --  input "21"
    SPSIO_in_Data_Deb_i(20) <=  PIO(41); --  input "20"
    SPSIO_in_Data_Deb_i(19) <=  PIO(43); --  input "19"
    SPSIO_in_Data_Deb_i(18) <=  PIO(45); --  input "18"
    SPSIO_in_Data_Deb_i(17) <=  PIO(47); --  input "17"
    SPSIO_in_Data_Deb_i(16) <=  PIO(49); --  input "16"
    SPSIO_in_Data_Deb_i(15) <=  PIO(51); --  input "15"
    SPSIO_in_Data_Deb_i(14) <=  PIO(53); --  input "14"
    SPSIO_in_Data_Deb_i(13) <=  PIO(55); --  input "13"
    SPSIO_in_Data_Deb_i(12) <=  PIO(57); --  input "12"
    SPSIO_in_Data_Deb_i(11) <=  PIO(59); --  input "11"
    SPSIO_in_Data_Deb_i(10) <=  PIO(61); --  input "10"
    SPSIO_in_Data_Deb_i(9)  <=  PIO(63); --  input "9"
    SPSIO_in_Data_Deb_i(8)  <=  PIO(65); --  input "8"
    SPSIO_in_Data_Deb_i(7)  <=  PIO(67); --  input "7"
    SPSIO_in_Data_Deb_i(6)  <=  PIO(69); --  input "6"
    SPSIO_in_Data_Deb_i(5)  <=  PIO(71); --  input "5"
    SPSIO_in_Data_Deb_i(4)  <=  PIO(73); --  input "4"
    SPSIO_in_Data_Deb_i(3)  <=  PIO(75); --  input "3"
    SPSIO_in_Data_Deb_i(2)  <=  PIO(77); --  input "2"
    SPSIO_in_Data_Deb_i(1)  <=  PIO(79); --  input "1"
    SPSIO_in_Data_Deb_i(0)  <=  PIO(81); --  input "0"
   
    
    AWin1(15 downto 0)    <=    SPSIO_in_Data_Deb_o(15 downto 0);
    AWin2(15 downto 8)    <=    (OTHERS => '0');  -- InPUT = 0; 
    AWin2(7  downto 0)    <=    SPSIO_in_Data_Deb_o(23 downto 16);
    


  --========================== Output Register 1 ======================================
    
    PIO(101)   <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
    PIO(119)   <=  '0';  ------------------------------- Output_Enable (nach init vom ALTERA)
    
    PIO(111)  <=  AWOut_Reg1(7);  --  Output "7"
    PIO(113)  <=  AWOut_Reg1(6);  --  Output "6"
    PIO(115)  <=  AWOut_Reg1(5);  --  Output "5"
    PIO(117)  <=  AWOut_Reg1(4);  --  Output "4"
    PIO(103)  <=  AWOut_Reg1(3);  --  Output "3"
    PIO(105)  <=  AWOut_Reg1(2);  --  Output "2"
    PIO(107)  <=  AWOut_Reg1(1);  --  Output "1"
    PIO(109)  <=  AWOut_Reg1(0);  --  Output "0"
    
      

  WHEN   c_AW_HFIO =>
      
    --###################################################################################
    --####                  Anwender-IO: DA(DAC/ADC)  -- FG900_780                    ###
    --###################################################################################
  
    extension_cid_system <= 55; -- extension card: cid_system, CSCOHW=55
    extension_cid_group  <= 34; -- extension card: cid_group, "FG900780_HFIO1" = 34

    Max_AWOut_Reg_Nr     <= 3;  -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <= 1;  -- Maximale AWIn-Reg-Nummer der Anwendung

    s_nLED_User1_i <= '0';        -- LED3 = User 1, -- frei -- 
    s_nLED_User2_i <= '0';        -- LED3 = User 2, -- frei -- 
    s_nLED_User3_i <= '0';        -- LED3 = User 3, -- frei -- 

    

   --========================== Output Register 1 ======================================

                           --   +-- Pin-Nr. D-Sub37-F(J5)
                           --   |
    PIO(83)   <=  not AWOut_Reg1(12); --  14, OE12, "Strobe Amplitude"
    PIO(85)   <=  not AWOut_Reg1(11); --  13, OE11, "Amplitude-Bit11"
    PIO(87)   <=  not AWOut_Reg1(10); --  12, OE10, "Amplitude-Bit10"
    PIO(89)   <=  not AWOut_Reg1(9);  --  11, OE9,  "Amplitude-Bit9"
    PIO(91)   <=  not AWOut_Reg1(8);  --  10, OE8,  "Amplitude-Bit8"
    PIO(93)   <=  not AWOut_Reg1(7);  --  9,  OE7,  "Amplitude-Bit7"
    PIO(95)   <=  not AWOut_Reg1(6);  --  8,  OE6,  "Amplitude-Bit6"
    PIO(97)   <=  not AWOut_Reg1(5);  --  7,  OE5,  "Amplitude-Bit5"
    PIO(99)   <=  not AWOut_Reg1(4);  --  6,  OE4,  "Amplitude-Bit4"
    PIO(101)  <=  not AWOut_Reg1(3);  --  5,  OE3,  "Amplitude-Bit3"
    PIO(103)  <=  not AWOut_Reg1(2);  --  4,  OE2,  "Amplitude-Bit2"
    PIO(105)  <=  not AWOut_Reg1(1);  --  3,  OE1,  "Amplitude-Bit1"
    PIO(107)  <=  not AWOut_Reg1(0);  --  2,  OE0,  "Amplitude-Bit0"
                                                
                                                
    --========================== Output Register 2 ======================================
    
                           --   +-- Pin-Nr. D-Sub37-F(J5)
                           --   |
    PIO(61)   <=  not AWOut_Reg2(10); --  31, OC10, "Strobe Phase"
    PIO(63)   <=  not AWOut_Reg2(9);  --  30, OC9,  "Phase-Bit9"
    PIO(65)   <=  not AWOut_Reg2(8);  --  29, OC8,  "Phase-Bit8"
    PIO(67)   <=  not AWOut_Reg2(7);  --  28, OC7,  "Phase-Bit7"
    PIO(69)   <=  not AWOut_Reg2(6);  --  27, OC6,  "Phase-Bit6"
    PIO(71)   <=  not AWOut_Reg2(5);  --  26, OC5,  "Phase-Bit5"
    PIO(73)   <=  not AWOut_Reg2(4);  --  25, OC4,  "Phase-Bit4"
    PIO(75)   <=  not AWOut_Reg2(3);  --  24, OC3,  "Phase-Bit3"
    PIO(77)   <=  not AWOut_Reg2(2);  --  23, OC2,  "Phase-Bit2"
    PIO(79)   <=  not AWOut_Reg2(1);  --  22, OC1,  "Phase-Bit1"
    PIO(81)   <=  not AWOut_Reg2(0);  --  21, OC0,  "Phase-Bit0"



    --========================== Output Register 3 ======================================
    
    PIO(133)   <=  '0';  ---------------- Output_Enable (nach init vom ALTERA) für Tastpuls,Sample_Puls_Display und Reserve
    
    
    PIO(113)                    <= AWOut_Reg3(7);                   --  --- LEMO2 ---  (Frei, J7),  "Aux "
    HFIO_Aux_i                  <= AWOut_Reg3(7);                    --  Input  "nLED_Aux"
    PIO(35)                     <= HFIO_nLED_Aux_o;                 --  Output "nLED_Aux"
                                                            
    PIO(59)                     <= not AWOut_Reg3(6);               --  D-Sub37-F(J5)_Pin-Nr. 32, OC11, "Flattop-Puls"
                                                            
    PIO(111)                    <= not AWOut_Reg3(5);               --  --- Lemo4 ---  (Tastpuls),          OE15, "Tastpuls(Gating) "
    HFIO_Tastpuls_i              <=     AWOut_Reg3(5);                --  Input  "nLED_Tastpuls"
    PIO(39)                     <= HFIO_nLED_Tastpuls_o;            --  Output "nLED_Tastpuls"
                                                            
    PIO(57)                     <= not AWOut_Reg3(4);                --  D-Sub37-F(J5)_Pin-Nr. 33, OC12, "Tast-Puls inv."
    PIO(55)                     <= not AWOut_Reg3(3);                --  D-Sub37-F(J5)_Pin-Nr. 34, OC13, "Tast-Puls"
                                                            
    PIO(115)                    <= AWOut_Reg3(2);                   --  --- LEMO1 ---  (Sample_Puls_Display, J8),       "Sample_Puls_Display"
    HFIO_Sample_Puls_Display_i  <= AWOut_Reg3(2);                    --  Input  "nLED_Sample-Puls-Display"
    PIO(33)                     <= HFIO_nLED_Sample_Puls_Display_o;  --  Output "nLED_Sample_Puls_Display"

    PIO(51)                     <= AWOut_Reg3(1);                   --  --- LEMO3 ---  (Sample_Puls_inv, J6),     OC15, "Sample_Puls_inv. "
    HFIO_Sample_Puls_inv_i      <= AWOut_Reg3(1);                    --  Input  "nLED_Sample_Puls_inv"
    PIO(37)                     <= HFIO_nLED_Sample_Puls_inv_o;      --  Output "nLED_Sample_Puls_inv"
                                                               
    PIO(53)                     <=  not AWOut_Reg3(0);              --  D-Sub37-F(J5)_Pin-Nr. 35,       OC14, "Sample-Puls"

    

    --========================== Input Register 1 ======================================

    HFIO_in_AMP_FEHLER_Deb_i    <=  PIO(43);                    --  input "AMP_FEHLER"
    AWin1(1)                    <=  HFIO_in_AMP_FEHLER_Deb_o;
    HFIO_in_PHASE_FEHLER_Deb_i  <=  PIO(41);                    --  input "PHASE_FEHLER"
    AWin1(0)                    <=  HFIO_in_PHASE_FEHLER_Deb_o;

  
      
  WHEN OTHERS =>

    extension_cid_system <=  0;  -- extension card: cid_system
    extension_cid_group  <=  0;  -- extension card: cid_group

    Max_AWOut_Reg_Nr     <=  0;  -- Maximale AWOut-Reg-Nummer der Anwendung
    Max_AWIn_Reg_Nr      <=  0;  -- Maximale AWIn-Reg-Nummer der Anwendung

    s_nLED_User1_i       <= '0';        -- LED3 = User 1, -- frei -- 
    s_nLED_User2_i       <= '0';        -- LED3 = User 2, -- frei -- 
    s_nLED_User3_i       <= '0';        -- LED3 = User 3, -- frei -- 


  -- Output: Anwender-LED's ---

    PIO(17)   <=    clk_blink; -- LED7
    PIO(19)   <=    clk_blink; -- LED6   
    PIO(21)   <=    clk_blink; -- LED5     
    PIO(23)   <=    clk_blink; -- LED4   
    PIO(25)   <=    clk_blink; -- LED3   
    PIO(27)   <=    clk_blink; -- LED2      
    PIO(29)   <=    clk_blink; -- LED1      
    PIO(31)   <=    clk_blink; -- LED0   
           
  END CASE;


  END IF;
--
--  
END PROCESS p_AW_MUX;


end architecture;
