`timescale 1ns / 1ps


module pcie_wrapper #(
    parameter integer WRITE_CHANNEL_COUNT       = 2      , // Number of memory writer for writing data from user logic to DDR memory
    parameter integer READER_CHANNEL_COUNT      = 2      , // Number of memory readers for reading data from DDR memory and transmit to user logic (buffered reading)
    parameter integer AXI_TO_AXIS_CHANNEL_COUNT = 2      , // Number of channels for reading data from PCIe (PC) and transmit to user logic (unbuffered reading)
    parameter integer FLASH_COUNT               = 2      , // Number of FLASH components
    parameter integer        WR_FREQ_HZ                     [WRITE_CHANNEL_COUNT]   = {250000000, 250000000}         ,
    parameter integer WR_N_BYTES                = 32     ,
    parameter integer WR_ADDR_WIDTH             = 32     ,
    parameter integer        WR_BURST_LIMIT                 [WRITE_CHANNEL_COUNT]   = {256, 256}                     ,
    parameter         [31:0] WR_DEFAULT_MEM_BASEADDR       [WRITE_CHANNEL_COUNT]   = {32'h00000000, 32'h10000000}   ,
    parameter         [31:0] WR_DEFAULT_MEM_HIGHADDR        [WRITE_CHANNEL_COUNT]   = {32'h10000000, 32'h20000000}   ,
    parameter integer        WR_DEFAULT_USER_EVENT_DURATION [WRITE_CHANNEL_COUNT]   = {100, 100}                     ,
    parameter integer        WR_DEFAULT_PORTION_SIZE        [WRITE_CHANNEL_COUNT]   = {1048576, 1048576}             ,
    parameter integer        WR_CMD_FIFO_DEPTH              [WRITE_CHANNEL_COUNT]   = {64, 64}                       ,
    parameter string         WR_CMD_FIFO_MEMTYPE            [WRITE_CHANNEL_COUNT]   = '{"block", "block"}            ,
    parameter integer        WR_SUSPENDABLE                 [WRITE_CHANNEL_COUNT]   = {1, 1}                         ,
    // reader default parameters
    parameter integer        RD_FREQ_HZ                     [READER_CHANNEL_COUNT]  = {250000000, 250000000}         ,
    parameter integer RD_N_BYTES                = 32     ,
    parameter integer RD_ADDR_WIDTH             = 32     ,
    parameter integer        RD_BURST_LIMIT                 [READER_CHANNEL_COUNT]  = {256, 256}                     ,
    parameter         [31:0] RD_DEFAULT_MEM_BASEADDR        [READER_CHANNEL_COUNT]  = {32'h20000000, 32'h30000000}   ,
    parameter integer        RD_DEFAULT_SEGMENT_COUNT       [READER_CHANNEL_COUNT]  = {32, 32}                       ,
    parameter integer        RD_DEFAULT_USER_EVENT_DURATION [READER_CHANNEL_COUNT]  = {100, 100}                     ,
    parameter integer        RD_DEFAULT_SEGMENT_SIZE        [READER_CHANNEL_COUNT]  = {1048576, 1048576}             ,
    parameter integer        RD_CMD_FIFO_DEPTH              [READER_CHANNEL_COUNT]  = {64, 64}                       ,
    parameter string         RD_CMD_FIFO_MEMTYPE            [READER_CHANNEL_COUNT]  = '{"block", "block"}            ,
    // axi_full_to_axi-stream parameters
    parameter integer F_TO_S_ID_WIDTH           = 1      ,
    parameter integer F_TO_S_DATA_WIDTH         = 256    ,
    parameter integer F_TO_S_ADDR_WIDTH         = 64     ,
    parameter string  F_TO_S_AXI_ACCESS         = "RW"   ,
    parameter string  F_TO_S_FIFO_MEMTYPE       = "block",
    parameter integer F_TO_S_FIFO_DEPTH         = 256    ,
    parameter integer F_TO_S_ASYNC              = 0      , 
    
    parameter integer        FLASH_CTRL_FREQ_HZ                  = 250000000   ,
    parameter integer        FLASH_CTRL_BYTE_WIDTH               = 8           ,
    parameter integer        FLASH_CTRL_ADDR_WIDTH               = 32          ,
    parameter         [31:0] FLASH_CTRL_DEFAULT_STARTADDR_MEMORY = 32'h80000000,
    parameter         [31:0] FLASH_CTRL_DEFAULT_STARTADDR_FLASH  = 32'h00000000,
    parameter         [31:0] FLASH_CTRL_DEFAULT_SIZE             = 32'h00001000

    
) (
    // PCIe signal group
    input                                                                     PCIE_PERST          ,
    input                                                                     PCIE_CLK_QO_N       ,
    input                                                                     PCIE_CLK_QO_P       ,
    input        [                            7:0]                            PCIE_RX_N           ,
    input        [                            7:0]                            PCIE_RX_P           ,
    output       [                            7:0]                            PCIE_TX_N           ,
    output       [                            7:0]                            PCIE_TX_P           ,
    // DDR4 signal group
    input                                                                     DDR4_A_SYS_CLK_P    ,
    input                                                                     DDR4_A_SYS_CLK_N    ,
    output                                                                    DDR4_A_ACT_B        ,
    output       [                           16:0]                            DDR4_A_A            ,
    output       [                            1:0]                            DDR4_A_BA           ,
    output       [                            0:0]                            DDR4_A_BG           ,
    output                                                                    DDR4_A_CKE          ,
    output                                                                    DDR4_A_ODT          ,
    output                                                                    DDR4_A_CS_B         ,
    output                                                                    DDR4_A_CK_C         ,
    output                                                                    DDR4_A_CK_T         ,
    output                                                                    DDR4_A_RESET_B      ,
    inout        [                            7:0]                            DDR4_A_DM           ,
    inout        [                           63:0]                            DDR4_A_DQ           ,
    inout        [                            7:0]                            DDR4_A_DQS_C        ,
    inout        [                            7:0]                            DDR4_A_DQS_T        ,
    input                                                                     DDR4_A_ALERT_B      ,
    output                                                                    DDR4_A_PAR          ,
    output                                                                    DDR4_A_TEN          ,
    // input clk signal for CDC from external source
    input  logic                                                              CLK_350             ,
    input  logic                                                              RESET_350           ,
    // output clk signal with reset formed from PCIe core
    output logic                                                              CLK_250             ,
    output logic                                                              RESET_250           ,
    // Memory writer signal group (CLK_250 clock domain)
    input  logic [      (WRITE_CHANNEL_COUNT-1):0][       (WR_N_BYTES*8)-1:0] MEMWR_S_AXIS_TDATA  ,
    input  logic [      (WRITE_CHANNEL_COUNT-1):0]                            MEMWR_S_AXIS_TVALID ,
    output logic [      (WRITE_CHANNEL_COUNT-1):0]                            MEMWR_S_AXIS_TREADY ,
    input  logic [      (WRITE_CHANNEL_COUNT-1):0]                            MEMWR_S_AXIS_TLAST  ,
    // Memory reader signal group (CLK_250 clock domain)
    output logic [     (READER_CHANNEL_COUNT-1):0][       (RD_N_BYTES*8)-1:0] MEMRD_M_AXIS_TDATA  ,
    output logic [     (READER_CHANNEL_COUNT-1):0]                            MEMRD_M_AXIS_TVALID ,
    output logic [     (READER_CHANNEL_COUNT-1):0]                            MEMRD_M_AXIS_TLAST  ,
    input  logic [     (READER_CHANNEL_COUNT-1):0]                            MEMRD_M_AXIS_TREADY ,
    // FULL TO STREAM signal group (CLK_250 clock domain)
    output logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][    F_TO_S_DATA_WIDTH-1:0] F_TO_S_M_AXIS_TDATA ,
    output logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][(F_TO_S_DATA_WIDTH/8)-1:0] F_TO_S_M_AXIS_TKEEP ,
    output logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]                            F_TO_S_M_AXIS_TVALID,
    input  logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]                            F_TO_S_M_AXIS_TREADY,
    output logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]                            F_TO_S_M_AXIS_TLAST ,
    input  logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][    F_TO_S_DATA_WIDTH-1:0] F_TO_S_S_AXIS_TDATA ,
    input  logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]                            F_TO_S_S_AXIS_TVALID,
    output logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]                            F_TO_S_S_AXIS_TREADY,
    
    output logic [(FLASH_COUNT-1):0][                 7:0]                    M_AXIS_FLASH_CMD       ,
    output logic [(FLASH_COUNT-1):0][                31:0]                    M_AXIS_FLASH_CMD_TSIZE ,
    output logic [(FLASH_COUNT-1):0][                31:0]                    M_AXIS_FLASH_CMD_TADDR ,
    output logic [(FLASH_COUNT-1):0]                                          M_AXIS_FLASH_CMD_TVALID,
    input  logic [(FLASH_COUNT-1):0]                                          M_AXIS_FLASH_CMD_TREADY,

    output logic [(FLASH_COUNT-1):0][((FLASH_CTRL_BYTE_WIDTH*8)-1):0]         MEM_TO_FLASH_M_AXIS_TDATA           ,
    output logic [(FLASH_COUNT-1):0][    (FLASH_CTRL_BYTE_WIDTH-1):0]         MEM_TO_FLASH_M_AXIS_TKEEP           ,
    output logic [(FLASH_COUNT-1):0]                                          MEM_TO_FLASH_M_AXIS_TVALID          ,
    input  logic [(FLASH_COUNT-1):0]                                          MEM_TO_FLASH_M_AXIS_TREADY          ,
    output logic [(FLASH_COUNT-1):0]                                          MEM_TO_FLASH_M_AXIS_TLAST           ,
    
    input  logic [(FLASH_COUNT-1):0]                                          FLASH_BUSY,                          
    
    input  logic [3 : 0]                                                      DCD_STATUS_DVI,        
    input  logic [3 : 0][31 : 0]                                              DCD_STATUS_DI,
    input  logic [3 : 0]                                                      DCD_IRQ, 
    
    output logic                                                              DCD_IRQ_CONFIG_DVO,   
    output logic [31 : 0]                                                     DCD_IRQ_CONFIG_DO
   
    
);

    logic clk_250  ;
    logic reset_250;
    logic clk_300  ;
    logic reset_300;

    /*===================================== MEMORY WRITER SIGNAL GROUP ===================================== */

    logic [(WRITE_CHANNEL_COUNT-1):0][31:0] m_axi_lite_memwr_araddr ;
    logic [(WRITE_CHANNEL_COUNT-1):0][ 2:0] m_axi_lite_memwr_arprot ;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_arready;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_arvalid;
    logic [(WRITE_CHANNEL_COUNT-1):0][31:0] m_axi_lite_memwr_awaddr ;
    logic [(WRITE_CHANNEL_COUNT-1):0][ 2:0] m_axi_lite_memwr_awprot ;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_awready;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_awvalid;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_bready ;
    logic [(WRITE_CHANNEL_COUNT-1):0][ 1:0] m_axi_lite_memwr_bresp  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_bvalid ;
    logic [(WRITE_CHANNEL_COUNT-1):0][31:0] m_axi_lite_memwr_rdata  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_rready ;
    logic [(WRITE_CHANNEL_COUNT-1):0][ 1:0] m_axi_lite_memwr_rresp  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_rvalid ;
    logic [(WRITE_CHANNEL_COUNT-1):0][31:0] m_axi_lite_memwr_wdata  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_wready ;
    logic [(WRITE_CHANNEL_COUNT-1):0][ 3:0] m_axi_lite_memwr_wstrb  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]       m_axi_lite_memwr_wvalid ;

    logic [(WRITE_CHANNEL_COUNT-1):0][ 31:0] s_axi_memwr_awaddr ;
    logic [(WRITE_CHANNEL_COUNT-1):0][  1:0] s_axi_memwr_awburst;
    logic [(WRITE_CHANNEL_COUNT-1):0][  3:0] s_axi_memwr_awcache;
    logic [(WRITE_CHANNEL_COUNT-1):0][  7:0] s_axi_memwr_awlen  ;
    logic [(WRITE_CHANNEL_COUNT-1):0][  0:0] s_axi_memwr_awlock ;
    logic [(WRITE_CHANNEL_COUNT-1):0][  2:0] s_axi_memwr_awprot ;
    logic [(WRITE_CHANNEL_COUNT-1):0][  3:0] s_axi_memwr_awqos  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]        s_axi_memwr_awready;
    logic [(WRITE_CHANNEL_COUNT-1):0][  2:0] s_axi_memwr_awsize ;
    logic [(WRITE_CHANNEL_COUNT-1):0]        s_axi_memwr_awvalid;
    logic [(WRITE_CHANNEL_COUNT-1):0]        s_axi_memwr_bready ;
    logic [(WRITE_CHANNEL_COUNT-1):0][  1:0] s_axi_memwr_bresp  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]        s_axi_memwr_bvalid ;
    logic [(WRITE_CHANNEL_COUNT-1):0][255:0] s_axi_memwr_wdata  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]        s_axi_memwr_wlast  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]        s_axi_memwr_wready ;
    logic [(WRITE_CHANNEL_COUNT-1):0][ 31:0] s_axi_memwr_wstrb  ;
    logic [(WRITE_CHANNEL_COUNT-1):0]        s_axi_memwr_wvalid ;

    logic [(WRITE_CHANNEL_COUNT-1):0] wr_user_event    ;
    logic [(WRITE_CHANNEL_COUNT-1):0] wr_user_event_ack;

    logic [(WRITE_CHANNEL_COUNT-1):0][31:0] wr_current_address  ;
    logic [(WRITE_CHANNEL_COUNT-1):0][31:0] wr_transmitted_bytes;


    /* ===================================== MEMORY READER SIGNAL GROUP ===================================== */

    logic [(READER_CHANNEL_COUNT-1):0][ 31:0] m_axi_lite_memrd_araddr ;
    logic [(READER_CHANNEL_COUNT-1):0][  2:0] m_axi_lite_memrd_arprot ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_arready;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_arvalid;
    logic [(READER_CHANNEL_COUNT-1):0][ 31:0] m_axi_lite_memrd_awaddr ;
    logic [(READER_CHANNEL_COUNT-1):0][  2:0] m_axi_lite_memrd_awprot ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_awready;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_awvalid;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_bready ;
    logic [(READER_CHANNEL_COUNT-1):0][  1:0] m_axi_lite_memrd_bresp  ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_bvalid ;
    logic [(READER_CHANNEL_COUNT-1):0][ 31:0] m_axi_lite_memrd_rdata  ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_rready ;
    logic [(READER_CHANNEL_COUNT-1):0][  1:0] m_axi_lite_memrd_rresp  ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_rvalid ;
    logic [(READER_CHANNEL_COUNT-1):0][ 31:0] m_axi_lite_memrd_wdata  ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_wready ;
    logic [(READER_CHANNEL_COUNT-1):0][  3:0] m_axi_lite_memrd_wstrb  ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] m_axi_lite_memrd_wvalid ;

    logic [(READER_CHANNEL_COUNT-1):0][ 31:0] s_axi_memrd_araddr ;
    logic [(READER_CHANNEL_COUNT-1):0][  1:0] s_axi_memrd_arburst;
    logic [(READER_CHANNEL_COUNT-1):0][  3:0] s_axi_memrd_arcache;
    logic [(READER_CHANNEL_COUNT-1):0][  7:0] s_axi_memrd_arlen  ;
    logic [(READER_CHANNEL_COUNT-1):0][  0:0] s_axi_memrd_arlock ;
    logic [(READER_CHANNEL_COUNT-1):0][  2:0] s_axi_memrd_arprot ;
    logic [(READER_CHANNEL_COUNT-1):0][  3:0] s_axi_memrd_arqos  ;
    logic [(READER_CHANNEL_COUNT-1):0]        s_axi_memrd_arready;
    logic [(READER_CHANNEL_COUNT-1):0][  2:0] s_axi_memrd_arsize ;
    logic [(READER_CHANNEL_COUNT-1):0]        s_axi_memrd_arvalid;
    logic [(READER_CHANNEL_COUNT-1):0][255:0] s_axi_memrd_rdata  ;
    logic [(READER_CHANNEL_COUNT-1):0]        s_axi_memrd_rlast  ;
    logic [(READER_CHANNEL_COUNT-1):0]        s_axi_memrd_rready ;
    logic [(READER_CHANNEL_COUNT-1):0][  1:0] s_axi_memrd_rresp  ;
    logic [(READER_CHANNEL_COUNT-1):0]        s_axi_memrd_rvalid ;

    logic [(READER_CHANNEL_COUNT-1):0] rd_user_event    ;
    logic [(READER_CHANNEL_COUNT-1):0] rd_user_event_ack;

    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][ 63:0] axi_to_axis_araddr      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  1:0] axi_to_axis_arburst     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  3:0] axi_to_axis_arcache     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  7:0] axi_to_axis_arlen       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  0:0] axi_to_axis_arlock      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  2:0] axi_to_axis_arprot      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  3:0] axi_to_axis_arqos       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_arready     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  2:0] axi_to_axis_arsize      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_arvalid     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][ 63:0] axi_to_axis_awaddr      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  1:0] axi_to_axis_awburst     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  3:0] axi_to_axis_awcache     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  7:0] axi_to_axis_awlen       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  0:0] axi_to_axis_awlock      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  2:0] axi_to_axis_awprot      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  3:0] axi_to_axis_awqos       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_awready     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  2:0] axi_to_axis_awsize      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_awvalid     ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_bready      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  1:0] axi_to_axis_bresp       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_bvalid      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][255:0] axi_to_axis_rdata       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_rlast       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_rready      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][  1:0] axi_to_axis_rresp       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_rvalid      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][255:0] axi_to_axis_wdata       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_wlast       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_wready      ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0][ 31:0] axi_to_axis_wstrb       ;
    logic [(AXI_TO_AXIS_CHANNEL_COUNT-1):0]        axi_to_axis_wvalid      ;

    logic [3:0] usr_irq_ack;
    logic [3:0] usr_irq_req;

    
    logic [FLASH_COUNT-1:0][31:0]m_axi_lite_flash_ctrl_araddr;
    logic [FLASH_COUNT-1:0][ 2:0]m_axi_lite_flash_ctrl_arprot;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_arready;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_arvalid;
    logic [FLASH_COUNT-1:0][31:0]m_axi_lite_flash_ctrl_awaddr;
    logic [FLASH_COUNT-1:0][ 2:0]m_axi_lite_flash_ctrl_awprot;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_awready;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_awvalid;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_bready;
    logic [FLASH_COUNT-1:0][ 1:0]m_axi_lite_flash_ctrl_bresp;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_bvalid;
    logic [FLASH_COUNT-1:0][31:0]m_axi_lite_flash_ctrl_rdata;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_rready;
    logic [FLASH_COUNT-1:0][ 1:0]m_axi_lite_flash_ctrl_rresp;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_rvalid;
    logic [FLASH_COUNT-1:0][31:0]m_axi_lite_flash_ctrl_wdata;
    logic [FLASH_COUNT-1:0]      m_axi_lite_flash_ctrl_wready;
    logic [FLASH_COUNT-1:0][ 3:0]m_axi_lite_flash_ctrl_wstrb;
    logic [FLASH_COUNT-1:0][ 0:0]m_axi_lite_flash_ctrl_wvalid;

    
    logic [FLASH_COUNT-1:0][33:0]s_axi_flash_ctrl_araddr;
    logic [FLASH_COUNT-1:0][ 1:0]s_axi_flash_ctrl_arburst;
    logic [FLASH_COUNT-1:0][ 3:0]s_axi_flash_ctrl_arcache;
    logic [FLASH_COUNT-1:0][ 7:0]s_axi_flash_ctrl_arlen;
    logic [FLASH_COUNT-1:0][ 0:0]s_axi_flash_ctrl_arlock;
    logic [FLASH_COUNT-1:0][ 2:0]s_axi_flash_ctrl_arprot;
    logic [FLASH_COUNT-1:0][ 3:0]s_axi_flash_ctrl_arqos;
    logic [FLASH_COUNT-1:0]      s_axi_flash_ctrl_arready;
    logic [FLASH_COUNT-1:0][ 2:0]s_axi_flash_ctrl_arsize;
    logic [FLASH_COUNT-1:0]      s_axi_flash_ctrl_arvalid;
    logic [FLASH_COUNT-1:0][63:0]s_axi_flash_ctrl_rdata;
    logic [FLASH_COUNT-1:0]      s_axi_flash_ctrl_rlast;
    logic [FLASH_COUNT-1:0]      s_axi_flash_ctrl_rready;
    logic [FLASH_COUNT-1:0][ 1:0]s_axi_flash_ctrl_rresp;
    logic [FLASH_COUNT-1:0]      s_axi_flash_ctrl_rvalid;
    
    // Decoder status
    logic   [3 : 0][31 : 0]             dcd_status_awaddr;
    logic   [3 : 0]                     dcd_status_awvalid;
    logic   [3 : 0]                     dcd_status_awready;

    logic   [3 : 0][31 : 0]             dcd_status_wdata;
    logic   [3 : 0][3 : 0]              dcd_status_wstrb;
    logic   [3 : 0]                     dcd_status_wvalid;
    logic   [3 : 0]                     dcd_status_wready;

    logic   [3 : 0][1 : 0]              dcd_status_bresp;
    logic   [3 : 0]                     dcd_status_bvalid;
    logic   [3 : 0]                     dcd_status_bready;

    logic   [3 : 0][31 : 0]             dcd_status_araddr;
    logic   [3 : 0]                     dcd_status_arvalid;
    logic   [3 : 0]                     dcd_status_arready;

    logic   [3 : 0][31 : 0]             dcd_status_rdata;
    logic   [3 : 0]                     dcd_status_rresp;
    logic   [3 : 0]                     dcd_status_rvalid;
    logic   [3 : 0]                     dcd_status_rready;
    
    // Decoder interrupt configuration
    logic   [31 : 0]                    dcd_irq_config_awaddr;
    logic                               dcd_irq_config_awvalid;
    logic                               dcd_irq_config_awready;

    logic   [31 : 0]                    dcd_irq_config_wdata;
    logic   [3 : 0]                     dcd_irq_config_wstrb;
    logic                               dcd_irq_config_wvalid;
    logic                               dcd_irq_config_wready;

    logic   [1 : 0]                     dcd_irq_config_bresp;
    logic                               dcd_irq_config_bvalid;
    logic                               dcd_irq_config_bready;

    logic   [31 : 0]                    dcd_irq_config_araddr;
    logic                               dcd_irq_config_arvalid;
    logic                               dcd_irq_config_arready;

    logic   [31 : 0]                    dcd_irq_config_rdata;
    logic                               dcd_irq_config_rresp;
    logic                               dcd_irq_config_rvalid;
    logic                               dcd_irq_config_rready;



    always_comb begin 
        CLK_250 = clk_250;
        RESET_250 = reset_250;
    end 


    quantum_pcie_bd_wrapper quantum_pcie_bd_wrapper_inst (
        .CLK_250                   (clk_250                    ),
        .RESET_250                 (reset_250                  ),
        .CLK_300                   (clk_300                    ),
        .RESET_300                 (reset_300                  ),
        .DDR4_SYS_CLK_clk_n        (DDR4_A_SYS_CLK_N           ),
        .DDR4_SYS_CLK_clk_p        (DDR4_A_SYS_CLK_P           ),
        .DDR4_act_n                (DDR4_A_ACT_B               ),
        .DDR4_adr                  (DDR4_A_A                   ),
        .DDR4_ba                   (DDR4_A_BA                  ),
        .DDR4_bg                   (DDR4_A_BG                  ),
        .DDR4_ck_c                 (DDR4_A_CK_C                ),
        .DDR4_ck_t                 (DDR4_A_CK_T                ),
        .DDR4_cke                  (DDR4_A_CKE                 ),
        .DDR4_cs_n                 (DDR4_A_CS_B                ),
        .DDR4_dm_n                 (DDR4_A_DM                  ),
        .DDR4_dq                   (DDR4_A_DQ                  ),
        .DDR4_dqs_c                (DDR4_A_DQS_C               ),
        .DDR4_dqs_t                (DDR4_A_DQS_T               ),
        .DDR4_odt                  (DDR4_A_ODT                 ),
        .DDR4_reset_n              (DDR4_A_RESET_B             ),
        
        .PCIE_MGT_rxn              (PCIE_RX_N                  ),
        .PCIE_MGT_rxp              (PCIE_RX_P                  ),
        .PCIE_MGT_txn              (PCIE_TX_N                  ),
        .PCIE_MGT_txp              (PCIE_TX_P                  ),
        .PCIE_PERSTN               (PCIE_PERST                 ),
        .PCIE_clk_n                (PCIE_CLK_QO_N              ),
        .PCIE_clk_p                (PCIE_CLK_QO_P              ),
        .USR_IRQ_ACK               (usr_irq_ack                ),
        .USR_IRQ_REQ               (usr_irq_req                ),
        
        .AXI_TO_AXIS_0_araddr      (axi_to_axis_araddr[0]      ),
        .AXI_TO_AXIS_0_arburst     (axi_to_axis_arburst[0]     ),
        .AXI_TO_AXIS_0_arcache     (axi_to_axis_arcache[0]     ),
        .AXI_TO_AXIS_0_arlen       (axi_to_axis_arlen[0]       ),
        .AXI_TO_AXIS_0_arlock      (axi_to_axis_arlock[0]      ),
        .AXI_TO_AXIS_0_arprot      (axi_to_axis_arprot[0]      ),
        .AXI_TO_AXIS_0_arqos       (axi_to_axis_arqos[0]       ),
        .AXI_TO_AXIS_0_arready     (axi_to_axis_arready[0]     ),
        .AXI_TO_AXIS_0_arsize      (axi_to_axis_arsize[0]      ),
        .AXI_TO_AXIS_0_arvalid     (axi_to_axis_arvalid[0]     ),
        .AXI_TO_AXIS_0_awaddr      (axi_to_axis_awaddr[0]      ),
        .AXI_TO_AXIS_0_awburst     (axi_to_axis_awburst[0]     ),
        .AXI_TO_AXIS_0_awcache     (axi_to_axis_awcache[0]     ),
        .AXI_TO_AXIS_0_awlen       (axi_to_axis_awlen[0]       ),
        .AXI_TO_AXIS_0_awlock      (axi_to_axis_awlock[0]      ),
        .AXI_TO_AXIS_0_awprot      (axi_to_axis_awprot[0]      ),
        .AXI_TO_AXIS_0_awqos       (axi_to_axis_awqos[0]       ),
        .AXI_TO_AXIS_0_awready     (axi_to_axis_awready[0]     ),
        .AXI_TO_AXIS_0_awsize      (axi_to_axis_awsize[0]      ),
        .AXI_TO_AXIS_0_awvalid     (axi_to_axis_awvalid[0]     ),
        .AXI_TO_AXIS_0_bready      (axi_to_axis_bready[0]      ),
        .AXI_TO_AXIS_0_bresp       (axi_to_axis_bresp[0]       ),
        .AXI_TO_AXIS_0_bvalid      (axi_to_axis_bvalid[0]      ),
        .AXI_TO_AXIS_0_rdata       (axi_to_axis_rdata[0]       ),
        .AXI_TO_AXIS_0_rlast       (axi_to_axis_rlast[0]       ),
        .AXI_TO_AXIS_0_rready      (axi_to_axis_rready[0]      ),
        .AXI_TO_AXIS_0_rresp       (axi_to_axis_rresp[0]       ),
        .AXI_TO_AXIS_0_rvalid      (axi_to_axis_rvalid[0]      ),
        .AXI_TO_AXIS_0_wdata       (axi_to_axis_wdata[0]       ),
        .AXI_TO_AXIS_0_wlast       (axi_to_axis_wlast[0]       ),
        .AXI_TO_AXIS_0_wready      (axi_to_axis_wready[0]      ),
        .AXI_TO_AXIS_0_wstrb       (axi_to_axis_wstrb[0]       ),
        .AXI_TO_AXIS_0_wvalid      (axi_to_axis_wvalid[0]      ),
        .AXI_TO_AXIS_1_araddr      (axi_to_axis_araddr[1]      ),
        .AXI_TO_AXIS_1_arburst     (axi_to_axis_arburst[1]     ),
        .AXI_TO_AXIS_1_arcache     (axi_to_axis_arcache[1]     ),
        .AXI_TO_AXIS_1_arlen       (axi_to_axis_arlen[1]       ),
        .AXI_TO_AXIS_1_arlock      (axi_to_axis_arlock[1]      ),
        .AXI_TO_AXIS_1_arprot      (axi_to_axis_arprot[1]      ),
        .AXI_TO_AXIS_1_arqos       (axi_to_axis_arqos[1]       ),
        .AXI_TO_AXIS_1_arready     (axi_to_axis_arready[1]     ),
        .AXI_TO_AXIS_1_arsize      (axi_to_axis_arsize[1]      ),
        .AXI_TO_AXIS_1_arvalid     (axi_to_axis_arvalid[1]     ),
        .AXI_TO_AXIS_1_awaddr      (axi_to_axis_awaddr[1]      ),
        .AXI_TO_AXIS_1_awburst     (axi_to_axis_awburst[1]     ),
        .AXI_TO_AXIS_1_awcache     (axi_to_axis_awcache[1]     ),
        .AXI_TO_AXIS_1_awlen       (axi_to_axis_awlen[1]       ),
        .AXI_TO_AXIS_1_awlock      (axi_to_axis_awlock[1]      ),
        .AXI_TO_AXIS_1_awprot      (axi_to_axis_awprot[1]      ),
        .AXI_TO_AXIS_1_awqos       (axi_to_axis_awqos[1]       ),
        .AXI_TO_AXIS_1_awready     (axi_to_axis_awready[1]     ),
        .AXI_TO_AXIS_1_awsize      (axi_to_axis_awsize[1]      ),
        .AXI_TO_AXIS_1_awvalid     (axi_to_axis_awvalid[1]     ),
        .AXI_TO_AXIS_1_bready      (axi_to_axis_bready[1]      ),
        .AXI_TO_AXIS_1_bresp       (axi_to_axis_bresp[1]       ),
        .AXI_TO_AXIS_1_bvalid      (axi_to_axis_bvalid[1]      ),
        .AXI_TO_AXIS_1_rdata       (axi_to_axis_rdata[1]       ),
        .AXI_TO_AXIS_1_rlast       (axi_to_axis_rlast[1]       ),
        .AXI_TO_AXIS_1_rready      (axi_to_axis_rready[1]      ),
        .AXI_TO_AXIS_1_rresp       (axi_to_axis_rresp[1]       ),
        .AXI_TO_AXIS_1_rvalid      (axi_to_axis_rvalid[1]      ),
        .AXI_TO_AXIS_1_wdata       (axi_to_axis_wdata[1]       ),
        .AXI_TO_AXIS_1_wlast       (axi_to_axis_wlast[1]       ),
        .AXI_TO_AXIS_1_wready      (axi_to_axis_wready[1]      ),
        .AXI_TO_AXIS_1_wstrb       (axi_to_axis_wstrb[1]       ),
        .AXI_TO_AXIS_1_wvalid      (axi_to_axis_wvalid[1]      ),
        
        .M_AXI_LITE_MEMRD_0_araddr (m_axi_lite_memrd_araddr[0] ),
        .M_AXI_LITE_MEMRD_0_arprot (m_axi_lite_memrd_arprot[0] ),
        .M_AXI_LITE_MEMRD_0_arready(m_axi_lite_memrd_arready[0]),
        .M_AXI_LITE_MEMRD_0_arvalid(m_axi_lite_memrd_arvalid[0]),
        .M_AXI_LITE_MEMRD_0_awaddr (m_axi_lite_memrd_awaddr[0] ),
        .M_AXI_LITE_MEMRD_0_awprot (m_axi_lite_memrd_awprot[0] ),
        .M_AXI_LITE_MEMRD_0_awready(m_axi_lite_memrd_awready[0]),
        .M_AXI_LITE_MEMRD_0_awvalid(m_axi_lite_memrd_awvalid[0]),
        .M_AXI_LITE_MEMRD_0_bready (m_axi_lite_memrd_bready[0] ),
        .M_AXI_LITE_MEMRD_0_bresp  (m_axi_lite_memrd_bresp[0]  ),
        .M_AXI_LITE_MEMRD_0_bvalid (m_axi_lite_memrd_bvalid[0] ),
        .M_AXI_LITE_MEMRD_0_rdata  (m_axi_lite_memrd_rdata[0]  ),
        .M_AXI_LITE_MEMRD_0_rready (m_axi_lite_memrd_rready[0] ),
        .M_AXI_LITE_MEMRD_0_rresp  (m_axi_lite_memrd_rresp[0]  ),
        .M_AXI_LITE_MEMRD_0_rvalid (m_axi_lite_memrd_rvalid[0] ),
        .M_AXI_LITE_MEMRD_0_wdata  (m_axi_lite_memrd_wdata[0]  ),
        .M_AXI_LITE_MEMRD_0_wready (m_axi_lite_memrd_wready[0] ),
        .M_AXI_LITE_MEMRD_0_wstrb  (m_axi_lite_memrd_wstrb[0]  ),
        .M_AXI_LITE_MEMRD_0_wvalid (m_axi_lite_memrd_wvalid[0] ),
        
        .M_AXI_LITE_MEMRD_1_araddr (m_axi_lite_memrd_araddr[1] ),
        .M_AXI_LITE_MEMRD_1_arprot (m_axi_lite_memrd_arprot[1] ),
        .M_AXI_LITE_MEMRD_1_arready(m_axi_lite_memrd_arready[1]),
        .M_AXI_LITE_MEMRD_1_arvalid(m_axi_lite_memrd_arvalid[1]),
        .M_AXI_LITE_MEMRD_1_awaddr (m_axi_lite_memrd_awaddr[1] ),
        .M_AXI_LITE_MEMRD_1_awprot (m_axi_lite_memrd_awprot[1] ),
        .M_AXI_LITE_MEMRD_1_awready(m_axi_lite_memrd_awready[1]),
        .M_AXI_LITE_MEMRD_1_awvalid(m_axi_lite_memrd_awvalid[1]),
        .M_AXI_LITE_MEMRD_1_bready (m_axi_lite_memrd_bready[1] ),
        .M_AXI_LITE_MEMRD_1_bresp  (m_axi_lite_memrd_bresp[1]  ),
        .M_AXI_LITE_MEMRD_1_bvalid (m_axi_lite_memrd_bvalid[1] ),
        .M_AXI_LITE_MEMRD_1_rdata  (m_axi_lite_memrd_rdata[1]  ),
        .M_AXI_LITE_MEMRD_1_rready (m_axi_lite_memrd_rready[1] ),
        .M_AXI_LITE_MEMRD_1_rresp  (m_axi_lite_memrd_rresp[1]  ),
        .M_AXI_LITE_MEMRD_1_rvalid (m_axi_lite_memrd_rvalid[1] ),
        .M_AXI_LITE_MEMRD_1_wdata  (m_axi_lite_memrd_wdata[1]  ),
        .M_AXI_LITE_MEMRD_1_wready (m_axi_lite_memrd_wready[1] ),
        .M_AXI_LITE_MEMRD_1_wstrb  (m_axi_lite_memrd_wstrb[1]  ),
        .M_AXI_LITE_MEMRD_1_wvalid (m_axi_lite_memrd_wvalid[1] ),
        
        
        .M_AXI_LITE_MEMWR_0_araddr ({2'b11, m_axi_lite_memwr_araddr[0]}),
        .M_AXI_LITE_MEMWR_0_arprot (m_axi_lite_memwr_arprot[0] ),
        .M_AXI_LITE_MEMWR_0_arready(m_axi_lite_memwr_arready[0]),
        .M_AXI_LITE_MEMWR_0_arvalid(m_axi_lite_memwr_arvalid[0]),
        .M_AXI_LITE_MEMWR_0_awaddr ({2'b11, m_axi_lite_memwr_awaddr[0]} ),
        .M_AXI_LITE_MEMWR_0_awprot (m_axi_lite_memwr_awprot[0] ),
        .M_AXI_LITE_MEMWR_0_awready(m_axi_lite_memwr_awready[0]),
        .M_AXI_LITE_MEMWR_0_awvalid(m_axi_lite_memwr_awvalid[0]),
        .M_AXI_LITE_MEMWR_0_bready (m_axi_lite_memwr_bready[0] ),
        .M_AXI_LITE_MEMWR_0_bresp  (m_axi_lite_memwr_bresp[0]  ),
        .M_AXI_LITE_MEMWR_0_bvalid (m_axi_lite_memwr_bvalid[0] ),
        .M_AXI_LITE_MEMWR_0_rdata  (m_axi_lite_memwr_rdata[0]),
        .M_AXI_LITE_MEMWR_0_rready (m_axi_lite_memwr_rready[0] ),
        .M_AXI_LITE_MEMWR_0_rresp  (m_axi_lite_memwr_rresp[0]  ),
        .M_AXI_LITE_MEMWR_0_rvalid (m_axi_lite_memwr_rvalid[0] ),
        .M_AXI_LITE_MEMWR_0_wdata  (m_axi_lite_memwr_wdata[0]  ),
        .M_AXI_LITE_MEMWR_0_wready (m_axi_lite_memwr_wready[0] ),
        .M_AXI_LITE_MEMWR_0_wstrb  (m_axi_lite_memwr_wstrb[0]  ),
        .M_AXI_LITE_MEMWR_0_wvalid (m_axi_lite_memwr_wvalid[0] ),
        
        .M_AXI_LITE_MEMWR_1_araddr (m_axi_lite_memwr_araddr[1] ),
        .M_AXI_LITE_MEMWR_1_arprot (m_axi_lite_memwr_arprot[1] ),
        .M_AXI_LITE_MEMWR_1_arready(m_axi_lite_memwr_arready[1]),
        .M_AXI_LITE_MEMWR_1_arvalid(m_axi_lite_memwr_arvalid[1]),
        .M_AXI_LITE_MEMWR_1_awaddr (m_axi_lite_memwr_awaddr[1] ),
        .M_AXI_LITE_MEMWR_1_awprot (m_axi_lite_memwr_awprot[1] ),
        .M_AXI_LITE_MEMWR_1_awready(m_axi_lite_memwr_awready[1]),
        .M_AXI_LITE_MEMWR_1_awvalid(m_axi_lite_memwr_awvalid[1]),
        .M_AXI_LITE_MEMWR_1_bready (m_axi_lite_memwr_bready[1] ),
        .M_AXI_LITE_MEMWR_1_bresp  (m_axi_lite_memwr_bresp[1]  ),
        .M_AXI_LITE_MEMWR_1_bvalid (m_axi_lite_memwr_bvalid[1] ),
        .M_AXI_LITE_MEMWR_1_rdata  (m_axi_lite_memwr_rdata[1]  ),
        .M_AXI_LITE_MEMWR_1_rready (m_axi_lite_memwr_rready[1] ),
        .M_AXI_LITE_MEMWR_1_rresp  (m_axi_lite_memwr_rresp[1]  ),
        .M_AXI_LITE_MEMWR_1_rvalid (m_axi_lite_memwr_rvalid[1] ),
        .M_AXI_LITE_MEMWR_1_wdata  (m_axi_lite_memwr_wdata[1]  ),
        .M_AXI_LITE_MEMWR_1_wready (m_axi_lite_memwr_wready[1] ),
        .M_AXI_LITE_MEMWR_1_wstrb  (m_axi_lite_memwr_wstrb[1]  ),
        .M_AXI_LITE_MEMWR_1_wvalid (m_axi_lite_memwr_wvalid[1] ),
        
        
        .M_AXI_LITE_FLASH_CTRL_0_araddr     (m_axi_lite_flash_ctrl_araddr[0]),
        .M_AXI_LITE_FLASH_CTRL_0_arprot     (m_axi_lite_flash_ctrl_arprot[0]),
        .M_AXI_LITE_FLASH_CTRL_0_arready    (m_axi_lite_flash_ctrl_arready[0]),
        .M_AXI_LITE_FLASH_CTRL_0_arvalid    (m_axi_lite_flash_ctrl_arvalid[0]),
        .M_AXI_LITE_FLASH_CTRL_0_awaddr     (m_axi_lite_flash_ctrl_awaddr[0]),
        .M_AXI_LITE_FLASH_CTRL_0_awprot     (m_axi_lite_flash_ctrl_awprot[0]),
        .M_AXI_LITE_FLASH_CTRL_0_awready    (m_axi_lite_flash_ctrl_awready[0]),
        .M_AXI_LITE_FLASH_CTRL_0_awvalid    (m_axi_lite_flash_ctrl_awvalid[0]),
        .M_AXI_LITE_FLASH_CTRL_0_bready     (m_axi_lite_flash_ctrl_bready[0]),
        .M_AXI_LITE_FLASH_CTRL_0_bresp      (m_axi_lite_flash_ctrl_bresp[0]),
        .M_AXI_LITE_FLASH_CTRL_0_bvalid     (m_axi_lite_flash_ctrl_bvalid[0]),
        .M_AXI_LITE_FLASH_CTRL_0_rdata      (m_axi_lite_flash_ctrl_rdata[0]),
        .M_AXI_LITE_FLASH_CTRL_0_rready     (m_axi_lite_flash_ctrl_rready[0]),
        .M_AXI_LITE_FLASH_CTRL_0_rresp      (m_axi_lite_flash_ctrl_rresp[0]),
        .M_AXI_LITE_FLASH_CTRL_0_rvalid     (m_axi_lite_flash_ctrl_rvalid[0]),
        .M_AXI_LITE_FLASH_CTRL_0_wdata      (m_axi_lite_flash_ctrl_wdata[0]),
        .M_AXI_LITE_FLASH_CTRL_0_wready     (m_axi_lite_flash_ctrl_wready[0]),
        .M_AXI_LITE_FLASH_CTRL_0_wstrb      (m_axi_lite_flash_ctrl_wstrb[0]),
        .M_AXI_LITE_FLASH_CTRL_0_wvalid     (m_axi_lite_flash_ctrl_wvalid[0]),
 
        .M_AXI_LITE_FLASH_CTRL_1_araddr     (m_axi_lite_flash_ctrl_araddr[1]),
        .M_AXI_LITE_FLASH_CTRL_1_arprot     (m_axi_lite_flash_ctrl_arprot[1]),
        .M_AXI_LITE_FLASH_CTRL_1_arready    (m_axi_lite_flash_ctrl_arready[1]),
        .M_AXI_LITE_FLASH_CTRL_1_arvalid    (m_axi_lite_flash_ctrl_arvalid[1]),
        .M_AXI_LITE_FLASH_CTRL_1_awaddr     (m_axi_lite_flash_ctrl_awaddr[1]),
        .M_AXI_LITE_FLASH_CTRL_1_awprot     (m_axi_lite_flash_ctrl_awprot[1]),
        .M_AXI_LITE_FLASH_CTRL_1_awready    (m_axi_lite_flash_ctrl_awready[1]),
        .M_AXI_LITE_FLASH_CTRL_1_awvalid    (m_axi_lite_flash_ctrl_awvalid[1]),
        .M_AXI_LITE_FLASH_CTRL_1_bready     (m_axi_lite_flash_ctrl_bready[1]),
        .M_AXI_LITE_FLASH_CTRL_1_bresp      (m_axi_lite_flash_ctrl_bresp[1]),
        .M_AXI_LITE_FLASH_CTRL_1_bvalid     (m_axi_lite_flash_ctrl_bvalid[1]),
        .M_AXI_LITE_FLASH_CTRL_1_rdata      (m_axi_lite_flash_ctrl_rdata[1]),
        .M_AXI_LITE_FLASH_CTRL_1_rready     (m_axi_lite_flash_ctrl_rready[1]),
        .M_AXI_LITE_FLASH_CTRL_1_rresp      (m_axi_lite_flash_ctrl_rresp[1]),
        .M_AXI_LITE_FLASH_CTRL_1_rvalid     (m_axi_lite_flash_ctrl_rvalid[1]),
        .M_AXI_LITE_FLASH_CTRL_1_wdata      (m_axi_lite_flash_ctrl_wdata[1]),
        .M_AXI_LITE_FLASH_CTRL_1_wready     (m_axi_lite_flash_ctrl_wready[1]),
        .M_AXI_LITE_FLASH_CTRL_1_wstrb      (m_axi_lite_flash_ctrl_wstrb[1]),
        .M_AXI_LITE_FLASH_CTRL_1_wvalid     (m_axi_lite_flash_ctrl_wvalid[1]),
 
        
        .S_AXI_MEMWR0_awaddr       (s_axi_memwr_awaddr[0]      ),
        .S_AXI_MEMWR0_awburst      (s_axi_memwr_awburst[0]     ),
        .S_AXI_MEMWR0_awcache      (s_axi_memwr_awcache[0]     ),
        .S_AXI_MEMWR0_awlen        (s_axi_memwr_awlen[0]       ),
        .S_AXI_MEMWR0_awlock       (s_axi_memwr_awlock[0]      ),
        .S_AXI_MEMWR0_awprot       (s_axi_memwr_awprot[0]      ),
        .S_AXI_MEMWR0_awqos        (s_axi_memwr_awqos[0]       ),
        .S_AXI_MEMWR0_awready      (s_axi_memwr_awready[0]     ),
        .S_AXI_MEMWR0_awsize       (s_axi_memwr_awsize[0]      ),
        .S_AXI_MEMWR0_awvalid      (s_axi_memwr_awvalid[0]     ),
        .S_AXI_MEMWR0_bready       (s_axi_memwr_bready[0]      ),
        .S_AXI_MEMWR0_bresp        (s_axi_memwr_bresp[0]       ),
        .S_AXI_MEMWR0_bvalid       (s_axi_memwr_bvalid[0]      ),
        .S_AXI_MEMWR0_wdata        (s_axi_memwr_wdata[0]       ),
        .S_AXI_MEMWR0_wlast        (s_axi_memwr_wlast[0]       ),
        .S_AXI_MEMWR0_wready       (s_axi_memwr_wready[0]      ),
        .S_AXI_MEMWR0_wstrb        (s_axi_memwr_wstrb[0]       ),
        .S_AXI_MEMWR0_wvalid       (s_axi_memwr_wvalid[0]      ),
        
        .S_AXI_MEMWR1_awaddr       (s_axi_memwr_awaddr[1]      ),
        .S_AXI_MEMWR1_awburst      (s_axi_memwr_awburst[1]     ),
        .S_AXI_MEMWR1_awcache      (s_axi_memwr_awcache[1]     ),
        .S_AXI_MEMWR1_awlen        (s_axi_memwr_awlen[1]       ),
        .S_AXI_MEMWR1_awlock       (s_axi_memwr_awlock[1]      ),
        .S_AXI_MEMWR1_awprot       (s_axi_memwr_awprot[1]      ),
        .S_AXI_MEMWR1_awqos        (s_axi_memwr_awqos[1]       ),
        .S_AXI_MEMWR1_awready      (s_axi_memwr_awready[1]     ),
        .S_AXI_MEMWR1_awsize       (s_axi_memwr_awsize[1]      ),
        .S_AXI_MEMWR1_awvalid      (s_axi_memwr_awvalid[1]     ),
        .S_AXI_MEMWR1_bready       (s_axi_memwr_bready[1]      ),
        .S_AXI_MEMWR1_bresp        (s_axi_memwr_bresp[1]       ),
        .S_AXI_MEMWR1_bvalid       (s_axi_memwr_bvalid[1]      ),
        .S_AXI_MEMWR1_wdata        (s_axi_memwr_wdata[1]       ),
        .S_AXI_MEMWR1_wlast        (s_axi_memwr_wlast[1]       ),
        .S_AXI_MEMWR1_wready       (s_axi_memwr_wready[1]      ),
        .S_AXI_MEMWR1_wstrb        (s_axi_memwr_wstrb[1]       ),
        .S_AXI_MEMWR1_wvalid       (s_axi_memwr_wvalid[1]      ),
        
        .S_AXI_MEMRD0_araddr       (s_axi_memrd_araddr[0]      ),
        .S_AXI_MEMRD0_arburst      (s_axi_memrd_arburst[0]     ),
        .S_AXI_MEMRD0_arcache      (s_axi_memrd_arcache[0]     ),
        .S_AXI_MEMRD0_arlen        (s_axi_memrd_arlen[0]       ),
        .S_AXI_MEMRD0_arlock       (s_axi_memrd_arlock[0]      ),
        .S_AXI_MEMRD0_arprot       (s_axi_memrd_arprot[0]      ),
        .S_AXI_MEMRD0_arqos        (s_axi_memrd_arqos[0]       ),
        .S_AXI_MEMRD0_arready      (s_axi_memrd_arready[0]     ),
        .S_AXI_MEMRD0_arsize       (s_axi_memrd_arsize[0]      ),
        .S_AXI_MEMRD0_arvalid      (s_axi_memrd_arvalid[0]     ),
        .S_AXI_MEMRD0_rdata        (s_axi_memrd_rdata[0]       ),
        .S_AXI_MEMRD0_rlast        (s_axi_memrd_rlast[0]       ),
        .S_AXI_MEMRD0_rready       (s_axi_memrd_rready[0]      ),
        .S_AXI_MEMRD0_rresp        (s_axi_memrd_rresp[0]       ),
        .S_AXI_MEMRD0_rvalid       (s_axi_memrd_rvalid[0]      ),
        
        .S_AXI_MEMRD1_araddr       (s_axi_memrd_araddr[1]      ),
        .S_AXI_MEMRD1_arburst      (s_axi_memrd_arburst[1]     ),
        .S_AXI_MEMRD1_arcache      (s_axi_memrd_arcache[1]     ),
        .S_AXI_MEMRD1_arlen        (s_axi_memrd_arlen[1]       ),
        .S_AXI_MEMRD1_arlock       (s_axi_memrd_arlock[1]      ),
        .S_AXI_MEMRD1_arprot       (s_axi_memrd_arprot[1]      ),
        .S_AXI_MEMRD1_arqos        (s_axi_memrd_arqos[1]       ),
        .S_AXI_MEMRD1_arready      (s_axi_memrd_arready[1]     ),
        .S_AXI_MEMRD1_arsize       (s_axi_memrd_arsize[1]      ),
        .S_AXI_MEMRD1_arvalid      (s_axi_memrd_arvalid[1]     ),
        .S_AXI_MEMRD1_rdata        (s_axi_memrd_rdata[1]       ),
        .S_AXI_MEMRD1_rlast        (s_axi_memrd_rlast[1]       ),
        .S_AXI_MEMRD1_rready       (s_axi_memrd_rready[1]      ),
        .S_AXI_MEMRD1_rresp        (s_axi_memrd_rresp[1]       ),
        .S_AXI_MEMRD1_rvalid       (s_axi_memrd_rvalid[1]      ),
 
        .S_AXI_FLASH_CTRL_0_araddr      (s_axi_flash_ctrl_araddr[0] ),
        .S_AXI_FLASH_CTRL_0_arburst     (s_axi_flash_ctrl_arburst[0]),
        .S_AXI_FLASH_CTRL_0_arcache     (s_axi_flash_ctrl_arcache[0]),
        .S_AXI_FLASH_CTRL_0_arlen       (s_axi_flash_ctrl_arlen[0]  ),
        .S_AXI_FLASH_CTRL_0_arlock      (s_axi_flash_ctrl_arlock[0] ),
        .S_AXI_FLASH_CTRL_0_arprot      (s_axi_flash_ctrl_arprot[0] ),
        .S_AXI_FLASH_CTRL_0_arqos       (s_axi_flash_ctrl_arqos[0]  ),
        .S_AXI_FLASH_CTRL_0_arready     (s_axi_flash_ctrl_arready[0]),
        .S_AXI_FLASH_CTRL_0_arsize      (s_axi_flash_ctrl_arsize[0] ),
        .S_AXI_FLASH_CTRL_0_arvalid     (s_axi_flash_ctrl_arvalid[0]),
        .S_AXI_FLASH_CTRL_0_rdata       (s_axi_flash_ctrl_rdata[0]  ),
        .S_AXI_FLASH_CTRL_0_rlast       (s_axi_flash_ctrl_rlast[0]  ),
        .S_AXI_FLASH_CTRL_0_rready      (s_axi_flash_ctrl_rready[0] ),
        .S_AXI_FLASH_CTRL_0_rresp       (s_axi_flash_ctrl_rresp[0]  ),
        .S_AXI_FLASH_CTRL_0_rvalid      (s_axi_flash_ctrl_rvalid[0] ),

        .S_AXI_FLASH_CTRL_1_araddr      (s_axi_flash_ctrl_araddr[1] ),
        .S_AXI_FLASH_CTRL_1_arburst     (s_axi_flash_ctrl_arburst[1]),
        .S_AXI_FLASH_CTRL_1_arcache     (s_axi_flash_ctrl_arcache[1]),
        .S_AXI_FLASH_CTRL_1_arlen       (s_axi_flash_ctrl_arlen[1]  ),
        .S_AXI_FLASH_CTRL_1_arlock      (s_axi_flash_ctrl_arlock[1] ),
        .S_AXI_FLASH_CTRL_1_arprot      (s_axi_flash_ctrl_arprot[1] ),
        .S_AXI_FLASH_CTRL_1_arqos       (s_axi_flash_ctrl_arqos[1]  ),
        .S_AXI_FLASH_CTRL_1_arready     (s_axi_flash_ctrl_arready[1]),
        .S_AXI_FLASH_CTRL_1_arsize      (s_axi_flash_ctrl_arsize[1] ),
        .S_AXI_FLASH_CTRL_1_arvalid     (s_axi_flash_ctrl_arvalid[1]),
        .S_AXI_FLASH_CTRL_1_rdata       (s_axi_flash_ctrl_rdata[1]  ),
        .S_AXI_FLASH_CTRL_1_rlast       (s_axi_flash_ctrl_rlast[1]  ),
        .S_AXI_FLASH_CTRL_1_rready      (s_axi_flash_ctrl_rready[1] ),
        .S_AXI_FLASH_CTRL_1_rresp       (s_axi_flash_ctrl_rresp[1]  ),
        .S_AXI_FLASH_CTRL_1_rvalid      (s_axi_flash_ctrl_rvalid[1] ),

        .DCD_STATUS_0_araddr              (dcd_status_araddr[0]), 
        .DCD_STATUS_0_arprot              (),
        .DCD_STATUS_0_arready             (dcd_status_arready[0]),
        .DCD_STATUS_0_arvalid             (dcd_status_arvalid[0]),
        .DCD_STATUS_0_awaddr              (dcd_status_awaddr[0]),
        .DCD_STATUS_0_awprot              (),
        .DCD_STATUS_0_awready             (dcd_status_awready[0]),
        .DCD_STATUS_0_awvalid             (dcd_status_awvalid[0]),
        .DCD_STATUS_0_bready              (dcd_status_bready[0]),
        .DCD_STATUS_0_bresp               (dcd_status_bresp[0]),
        .DCD_STATUS_0_bvalid              (dcd_status_bvalid[0]),
        .DCD_STATUS_0_rdata               (dcd_status_rdata[0]),
        .DCD_STATUS_0_rready              (dcd_status_rready[0]),
        .DCD_STATUS_0_rresp               (dcd_status_rresp[0]),
        .DCD_STATUS_0_rvalid              (dcd_status_rvalid[0]),
        .DCD_STATUS_0_wdata               (dcd_status_wdata[0]),
        .DCD_STATUS_0_wready              (dcd_status_wready[0]),
        .DCD_STATUS_0_wstrb               (dcd_status_wstrb[0]),
        .DCD_STATUS_0_wvalid              (dcd_status_wvalid[0]),
        
        .DCD_STATUS_1_araddr              (dcd_status_araddr[1]), 
        .DCD_STATUS_1_arprot              (),
        .DCD_STATUS_1_arready             (dcd_status_arready[1]),
        .DCD_STATUS_1_arvalid             (dcd_status_arvalid[1]),
        .DCD_STATUS_1_awaddr              (dcd_status_awaddr[1]),
        .DCD_STATUS_1_awprot              (),
        .DCD_STATUS_1_awready             (dcd_status_awready[1]),
        .DCD_STATUS_1_awvalid             (dcd_status_awvalid[1]),
        .DCD_STATUS_1_bready              (dcd_status_bready[1]),
        .DCD_STATUS_1_bresp               (dcd_status_bresp[1]),
        .DCD_STATUS_1_bvalid              (dcd_status_bvalid[1]),
        .DCD_STATUS_1_rdata               (dcd_status_rdata[1]),
        .DCD_STATUS_1_rready              (dcd_status_rready[1]),
        .DCD_STATUS_1_rresp               (dcd_status_rresp[1]),
        .DCD_STATUS_1_rvalid              (dcd_status_rvalid[1]),
        .DCD_STATUS_1_wdata               (dcd_status_wdata[1]),
        .DCD_STATUS_1_wready              (dcd_status_wready[1]),
        .DCD_STATUS_1_wstrb               (dcd_status_wstrb[1]),
        .DCD_STATUS_1_wvalid              (dcd_status_wvalid[1]),
        
        .DCD_STATUS_2_araddr              (dcd_status_araddr[2]), 
        .DCD_STATUS_2_arprot              (),
        .DCD_STATUS_2_arready             (dcd_status_arready[2]),
        .DCD_STATUS_2_arvalid             (dcd_status_arvalid[2]),
        .DCD_STATUS_2_awaddr              (dcd_status_awaddr[2]),
        .DCD_STATUS_2_awprot              (),
        .DCD_STATUS_2_awready             (dcd_status_awready[2]),
        .DCD_STATUS_2_awvalid             (dcd_status_awvalid[2]),
        .DCD_STATUS_2_bready              (dcd_status_bready[2]),
        .DCD_STATUS_2_bresp               (dcd_status_bresp[2]),
        .DCD_STATUS_2_bvalid              (dcd_status_bvalid[2]),
        .DCD_STATUS_2_rdata               (dcd_status_rdata[2]),
        .DCD_STATUS_2_rready              (dcd_status_rready[2]),
        .DCD_STATUS_2_rresp               (dcd_status_rresp[2]),
        .DCD_STATUS_2_rvalid              (dcd_status_rvalid[2]),
        .DCD_STATUS_2_wdata               (dcd_status_wdata[2]),
        .DCD_STATUS_2_wready              (dcd_status_wready[2]),
        .DCD_STATUS_2_wstrb               (dcd_status_wstrb[2]),
        .DCD_STATUS_2_wvalid              (dcd_status_wvalid[2]),
        
        .DCD_STATUS_3_araddr              (dcd_status_araddr[3]), 
        .DCD_STATUS_3_arprot              (),
        .DCD_STATUS_3_arready             (dcd_status_arready[3]),
        .DCD_STATUS_3_arvalid             (dcd_status_arvalid[3]),
        .DCD_STATUS_3_awaddr              (dcd_status_awaddr[3]),
        .DCD_STATUS_3_awprot              (),
        .DCD_STATUS_3_awready             (dcd_status_awready[3]),
        .DCD_STATUS_3_awvalid             (dcd_status_awvalid[3]),
        .DCD_STATUS_3_bready              (dcd_status_bready[3]),
        .DCD_STATUS_3_bresp               (dcd_status_bresp[3]),
        .DCD_STATUS_3_bvalid              (dcd_status_bvalid[3]),
        .DCD_STATUS_3_rdata               (dcd_status_rdata[3]),
        .DCD_STATUS_3_rready              (dcd_status_rready[3]),
        .DCD_STATUS_3_rresp               (dcd_status_rresp[3]),
        .DCD_STATUS_3_rvalid              (dcd_status_rvalid[3]),
        .DCD_STATUS_3_wdata               (dcd_status_wdata[3]),
        .DCD_STATUS_3_wready              (dcd_status_wready[3]),
        .DCD_STATUS_3_wstrb               (dcd_status_wstrb[3]),
        .DCD_STATUS_3_wvalid              (dcd_status_wvalid[3]),
        
        .DCD_IRQ_CONFIG_araddr            (dcd_irq_config_araddr), 
        .DCD_IRQ_CONFIG_arprot            (),
        .DCD_IRQ_CONFIG_arready           (dcd_irq_config_arready),
        .DCD_IRQ_CONFIG_arvalid           (dcd_irq_config_arvalid),
        .DCD_IRQ_CONFIG_awaddr            (dcd_irq_config_awaddr),
        .DCD_IRQ_CONFIG_awprot            (),
        .DCD_IRQ_CONFIG_awready           (dcd_irq_config_awready),
        .DCD_IRQ_CONFIG_awvalid           (dcd_irq_config_awvalid),
        .DCD_IRQ_CONFIG_bready            (dcd_irq_config_bready),
        .DCD_IRQ_CONFIG_bresp             (dcd_irq_config_bresp),
        .DCD_IRQ_CONFIG_bvalid            (dcd_irq_config_bvalid),
        .DCD_IRQ_CONFIG_rdata             (dcd_irq_config_rdata),
        .DCD_IRQ_CONFIG_rready            (dcd_irq_config_rready),
        .DCD_IRQ_CONFIG_rresp             (dcd_irq_config_rresp),
        .DCD_IRQ_CONFIG_rvalid            (dcd_irq_config_rvalid),
        .DCD_IRQ_CONFIG_wdata             (dcd_irq_config_wdata),
        .DCD_IRQ_CONFIG_wready            (dcd_irq_config_wready),
        .DCD_IRQ_CONFIG_wstrb             (dcd_irq_config_wstrb),
        .DCD_IRQ_CONFIG_wvalid            (dcd_irq_config_wvalid)
        
    );
    
    // 
//    always_comb begin 
//        usr_irq_req[0] = wr_user_event[0];
//        wr_user_event_ack[0] = usr_irq_ack[0];

//        usr_irq_req[1] = DCD_IRQ[0] || DCD_IRQ[1] || DCD_IRQ[2];
//        wr_user_event_ack[1] = 1'b0;

//        usr_irq_req[2] = 1'b0;
//        rd_user_event_ack[0] = 1'b0;

//        usr_irq_req[3] = 1'b0;
//        rd_user_event_ack[1] = 1'b0;
//    end 
    
    always_comb begin 
        usr_irq_req[0] = wr_user_event[0];
        wr_user_event_ack[0] = usr_irq_ack[0];

        usr_irq_req[1] = DCD_IRQ[0];
        wr_user_event_ack[1] = 1'b0;

        usr_irq_req[2] = DCD_IRQ[1];
        rd_user_event_ack[0] = 1'b0;

        usr_irq_req[3] = DCD_IRQ[2];
        rd_user_event_ack[1] = 1'b0;
    end 


    generate
        
        for (genvar write_ch_index = 0; write_ch_index < WRITE_CHANNEL_COUNT; write_ch_index++) begin : GEN_MEM_WR

            axi_memory_writer_pkt #(
                .FREQ_HZ                    (WR_FREQ_HZ[write_ch_index]                    ),
                .N_BYTES                    (WR_N_BYTES                                    ),
                .ADDR_WIDTH                 (WR_ADDR_WIDTH                                 ),
                .BURST_LIMIT                (WR_BURST_LIMIT[write_ch_index]                ),
                .DEFAULT_MEM_BASEADDR       (WR_DEFAULT_MEM_BASEADDR[write_ch_index]       ),
                .DEFAULT_MEM_HIGHADDR       (WR_DEFAULT_MEM_HIGHADDR[write_ch_index]       ),
                .DEFAULT_USER_EVENT_DURATION(WR_DEFAULT_USER_EVENT_DURATION[write_ch_index]),
                .CMD_FIFO_DEPTH             (WR_CMD_FIFO_DEPTH[write_ch_index]             ),
                .CMD_FIFO_MEMTYPE           (WR_CMD_FIFO_MEMTYPE[write_ch_index]           ),
                .SUSPENDABLE                (WR_SUSPENDABLE[write_ch_index]                ),
                .RETRY_COUNTER_LIMIT        (100000000                                     )
            ) axi_memory_writer_pkt_inst (
                .aclk             (clk_250                                 ),
                .aresetn          (~reset_250                              ),
                // CONFIGURATION BUS
                .S_AXI_AWADDR     (m_axi_lite_memwr_awaddr[write_ch_index] ),
                .S_AXI_AWPROT     (m_axi_lite_memwr_awprot[write_ch_index] ),
                .S_AXI_AWVALID    (m_axi_lite_memwr_awvalid[write_ch_index]),
                .S_AXI_AWREADY    (m_axi_lite_memwr_awready[write_ch_index]),
                .S_AXI_WDATA      (m_axi_lite_memwr_wdata[write_ch_index]  ),
                .S_AXI_WSTRB      (m_axi_lite_memwr_wstrb[write_ch_index]  ),
                .S_AXI_WVALID     (m_axi_lite_memwr_wvalid[write_ch_index] ),
                .S_AXI_WREADY     (m_axi_lite_memwr_wready[write_ch_index] ),
                .S_AXI_BRESP      (m_axi_lite_memwr_bresp[write_ch_index]  ),
                .S_AXI_BVALID     (m_axi_lite_memwr_bvalid[write_ch_index] ),
                .S_AXI_BREADY     (m_axi_lite_memwr_bready[write_ch_index] ),
                .S_AXI_ARADDR     (m_axi_lite_memwr_araddr[write_ch_index] ),
                .S_AXI_ARPROT     (m_axi_lite_memwr_arprot[write_ch_index] ),
                .S_AXI_ARVALID    (m_axi_lite_memwr_arvalid[write_ch_index]),
                .S_AXI_ARREADY    (m_axi_lite_memwr_arready[write_ch_index]),
                .S_AXI_RDATA      (m_axi_lite_memwr_rdata[write_ch_index]  ),
                .S_AXI_RRESP      (m_axi_lite_memwr_rresp[write_ch_index]  ),
                .S_AXI_RVALID     (m_axi_lite_memwr_rvalid[write_ch_index] ),
                .S_AXI_RREADY     (m_axi_lite_memwr_rready[write_ch_index] ),
                // USER EVENT INTERRUPTS
                .CURRENT_ADDR     (wr_current_address[write_ch_index]      ),
                .TRANSMITTED_BYTES(wr_transmitted_bytes[write_ch_index]    ),
                .USER_EVENT       (wr_user_event[write_ch_index]           ),
                // S_AXIS BUS
                .S_AXIS_TDATA     (MEMWR_S_AXIS_TDATA[write_ch_index]      ),
                .S_AXIS_TVALID    (MEMWR_S_AXIS_TVALID[write_ch_index]     ),
                .S_AXIS_TREADY    (MEMWR_S_AXIS_TREADY[write_ch_index]     ),
                .S_AXIS_TLAST     (MEMWR_S_AXIS_TLAST[write_ch_index]      ),
                // M_AXI FULL BUS ONLY WRITE MODE
                .M_AXI_AWADDR     (s_axi_memwr_awaddr[write_ch_index]      ),
                .M_AXI_AWLEN      (s_axi_memwr_awlen[write_ch_index]       ),
                .M_AXI_AWSIZE     (s_axi_memwr_awsize[write_ch_index]      ),
                .M_AXI_AWBURST    (s_axi_memwr_awburst[write_ch_index]     ),
                .M_AXI_AWLOCK     (s_axi_memwr_awlock[write_ch_index]      ),
                .M_AXI_AWCACHE    (s_axi_memwr_awcache[write_ch_index]     ),
                .M_AXI_AWPROT     (s_axi_memwr_awprot[write_ch_index]      ),
                .M_AXI_AWVALID    (s_axi_memwr_awvalid[write_ch_index]     ),
                .M_AXI_AWREADY    (s_axi_memwr_awready[write_ch_index]     ),
                .M_AXI_WDATA      (s_axi_memwr_wdata[write_ch_index]       ),
                .M_AXI_WSTRB      (s_axi_memwr_wstrb[write_ch_index]       ),
                .M_AXI_WLAST      (s_axi_memwr_wlast[write_ch_index]       ),
                .M_AXI_WVALID     (s_axi_memwr_wvalid[write_ch_index]      ),
                .M_AXI_WREADY     (s_axi_memwr_wready[write_ch_index]      ),
                .M_AXI_BRESP      (s_axi_memwr_bresp[write_ch_index]       ),
                .M_AXI_BVALID     (s_axi_memwr_bvalid[write_ch_index]      ),
                .M_AXI_BREADY     (s_axi_memwr_bready[write_ch_index]      )
            );

        end 



        for (genvar read_ch_index = 0; read_ch_index < READER_CHANNEL_COUNT; read_ch_index++) begin : GEN_MEM_RD 

            axi_memory_reader_intr #(
                .FREQ_HZ                    (RD_FREQ_HZ[read_ch_index]                    ),
                .N_BYTES                    (RD_N_BYTES                                   ),
                .ADDR_WIDTH                 (RD_ADDR_WIDTH                                ),
                .BURST_LIMIT                (RD_BURST_LIMIT[read_ch_index]                ),
                .DEFAULT_MEM_BASEADDR       (RD_DEFAULT_MEM_BASEADDR[read_ch_index]       ),
                .DEFAULT_SEGMENT_COUNT      (RD_DEFAULT_SEGMENT_COUNT[read_ch_index]      ),
                .DEFAULT_USER_EVENT_DURATION(RD_DEFAULT_USER_EVENT_DURATION[read_ch_index]),
                .DEFAULT_SEGMENT_SIZE       (RD_DEFAULT_SEGMENT_SIZE[read_ch_index]       ),
                .CMD_FIFO_DEPTH             (RD_CMD_FIFO_DEPTH[read_ch_index]             ),
                .CMD_FIFO_MEMTYPE           (RD_CMD_FIFO_MEMTYPE[read_ch_index]           )
            ) axi_memory_reader_intr_inst (
                .aclk            (clk_250                                ),
                .aresetn         (~reset_250                             ),
                // CONFIGURATION BUS
                .S_AXI_AWADDR    (m_axi_lite_memrd_awaddr[read_ch_index] ),
                .S_AXI_AWPROT    (m_axi_lite_memrd_awprot[read_ch_index] ),
                .S_AXI_AWVALID   (m_axi_lite_memrd_awvalid[read_ch_index]),
                .S_AXI_AWREADY   (m_axi_lite_memrd_awready[read_ch_index]),
                .S_AXI_WDATA     (m_axi_lite_memrd_wdata[read_ch_index]  ),
                .S_AXI_WSTRB     (m_axi_lite_memrd_wstrb[read_ch_index]  ),
                .S_AXI_WVALID    (m_axi_lite_memrd_wvalid[read_ch_index] ),
                .S_AXI_WREADY    (m_axi_lite_memrd_wready[read_ch_index] ),
                .S_AXI_BRESP     (m_axi_lite_memrd_bresp[read_ch_index]  ),
                .S_AXI_BVALID    (m_axi_lite_memrd_bvalid[read_ch_index] ),
                .S_AXI_BREADY    (m_axi_lite_memrd_bready[read_ch_index] ),
                .S_AXI_ARADDR    (m_axi_lite_memrd_araddr[read_ch_index] ),
                .S_AXI_ARPROT    (m_axi_lite_memrd_arprot[read_ch_index] ),
                .S_AXI_ARVALID   (m_axi_lite_memrd_arvalid[read_ch_index]),
                .S_AXI_ARREADY   (m_axi_lite_memrd_arready[read_ch_index]),
                .S_AXI_RDATA     (m_axi_lite_memrd_rdata[read_ch_index]  ),
                .S_AXI_RRESP     (m_axi_lite_memrd_rresp[read_ch_index]  ),
                .S_AXI_RVALID    (m_axi_lite_memrd_rvalid[read_ch_index] ),
                .S_AXI_RREADY    (m_axi_lite_memrd_rready[read_ch_index] ),
                // USER EVENT INTERRUPTS
                .CURRENT_ADDR    (                                       ),
                .TRANSFERRED_SIZE(                                       ),
                .USER_EVENT      (rd_user_event[read_ch_index]           ),
                .USER_EVENT_ACK  (rd_user_event_ack[read_ch_index]       ),
                
                .M_AXIS_TDATA    (MEMRD_M_AXIS_TDATA[read_ch_index]      ),
                .M_AXIS_TVALID   (MEMRD_M_AXIS_TVALID[read_ch_index]     ),
                .M_AXIS_TLAST    (MEMRD_M_AXIS_TLAST[read_ch_index]      ),
                .M_AXIS_TREADY   (MEMRD_M_AXIS_TREADY[read_ch_index]     ),
                
                .M_AXI_ARADDR    (s_axi_memrd_araddr[read_ch_index]      ),
                .M_AXI_ARLEN     (s_axi_memrd_arlen[read_ch_index]       ),
                .M_AXI_ARSIZE    (s_axi_memrd_arsize[read_ch_index]      ),
                .M_AXI_ARBURST   (s_axi_memrd_arburst[read_ch_index]     ),
                .M_AXI_ARVALID   (s_axi_memrd_arvalid[read_ch_index]     ),
                .M_AXI_ARREADY   (s_axi_memrd_arready[read_ch_index]     ),
                .M_AXI_RDATA     (s_axi_memrd_rdata[read_ch_index]       ),
                .M_AXI_RRESP     (s_axi_memrd_rresp[read_ch_index]       ),
                .M_AXI_RLAST     (s_axi_memrd_rlast[read_ch_index]       ),
                .M_AXI_RVALID    (s_axi_memrd_rvalid[read_ch_index]      ),
                .M_AXI_RREADY    (s_axi_memrd_rready[read_ch_index]      )
            );

        end 


        for (genvar fs_index = 0; fs_index < AXI_TO_AXIS_CHANNEL_COUNT; fs_index++) begin : GEN_FULL_TO_STREAM_LOGIC  

            axi_full_data_register_addr_ranged #(
                .ID_WIDTH    (F_TO_S_ID_WIDTH    ),
                .DATA_WIDTH  (F_TO_S_DATA_WIDTH  ),
                .ADDR_WIDTH  (F_TO_S_ADDR_WIDTH  ),
                .AXI_ACCESS  (F_TO_S_AXI_ACCESS  ),
                .FIFO_MEMTYPE(F_TO_S_FIFO_MEMTYPE),
                .FIFO_DEPTH  (F_TO_S_FIFO_DEPTH  ),
                .ASYNC       (F_TO_S_ASYNC       )
            ) axi_full_data_register_addr_ranged_inst (
                .CLK          (clk_250                       ),
                .RESET        (reset_250                     ),
                .AWID         ('b0                           ),
                .AWADDR       (axi_to_axis_awaddr[fs_index]  ),
                .AWLEN        (axi_to_axis_awlen[fs_index]   ),
                .AWSIZE       (axi_to_axis_awsize[fs_index]  ),
                .AWBURST      (axi_to_axis_awburst[fs_index] ),
                .AWCACHE      (axi_to_axis_awcache[fs_index] ),
                .AWPROT       (axi_to_axis_awprot[fs_index]  ),
                .AWVALID      (axi_to_axis_awvalid[fs_index] ),
                .AWREADY      (axi_to_axis_awready[fs_index] ),
                .WDATA        (axi_to_axis_wdata[fs_index]   ),
                .WSTRB        (axi_to_axis_wstrb[fs_index]   ),
                .WLAST        (axi_to_axis_wlast[fs_index]   ),
                .WVALID       (axi_to_axis_wvalid[fs_index]  ),
                .WREADY       (axi_to_axis_wready[fs_index]  ),
                .BID          (                              ),
                .BRESP        (axi_to_axis_bresp[fs_index]   ),
                .BVALID       (axi_to_axis_bvalid[fs_index]  ),
                .BREADY       (axi_to_axis_bready[fs_index]  ),
                .ARID         ('b0                           ),
                .ARADDR       (axi_to_axis_araddr[fs_index]  ),
                .ARLEN        (axi_to_axis_arlen[fs_index]   ),
                .ARSIZE       (axi_to_axis_arsize[fs_index]  ),
                .ARBURST      (axi_to_axis_arburst[fs_index] ),
                .ARCACHE      (axi_to_axis_arcache[fs_index] ),
                .ARPROT       (axi_to_axis_arprot[fs_index]  ),
                .ARVALID      (axi_to_axis_arvalid[fs_index] ),
                .ARREADY      (axi_to_axis_arready[fs_index] ),
                .RID          (                              ),
                .RDATA        (axi_to_axis_rdata[fs_index]   ),
                .RRESP        (axi_to_axis_rresp[fs_index]   ),
                .RLAST        (axi_to_axis_rlast[fs_index]   ),
                .RVALID       (axi_to_axis_rvalid[fs_index]  ),
                .RREADY       (axi_to_axis_rready[fs_index]  ),
                
                .M_AXIS_CLK   (CLK_350                       ),
                .M_AXIS_TDATA (F_TO_S_M_AXIS_TDATA[fs_index] ),
                .M_AXIS_TKEEP (F_TO_S_M_AXIS_TKEEP[fs_index] ),
                .M_AXIS_TVALID(F_TO_S_M_AXIS_TVALID[fs_index]),
                .M_AXIS_TREADY(F_TO_S_M_AXIS_TREADY[fs_index]),
                .M_AXIS_TLAST (F_TO_S_M_AXIS_TLAST[fs_index] ),
                
                .S_AXIS_CLK   (CLK_350                       ),
                .S_AXIS_TDATA (F_TO_S_S_AXIS_TDATA[fs_index] ),
                .S_AXIS_TVALID(F_TO_S_S_AXIS_TVALID[fs_index]),
                .S_AXIS_TREADY(F_TO_S_S_AXIS_TREADY[fs_index])
            );

        end
        
                
        for (genvar flash_index = 0; flash_index < FLASH_COUNT; flash_index++) begin : GEN_FLASH_CONTROL_MGR  
        
            axi_flash_control_mgr #(
                .FREQ_HZ                  (FLASH_CTRL_FREQ_HZ                   ),
                .BYTE_WIDTH               (FLASH_CTRL_BYTE_WIDTH                ),
                .ADDR_WIDTH               (FLASH_CTRL_ADDR_WIDTH                ),
                .DEFAULT_STARTADDR_MEMORY (FLASH_CTRL_DEFAULT_STARTADDR_MEMORY  ),
                .DEFAULT_STARTADDR_FLASH  (FLASH_CTRL_DEFAULT_STARTADDR_FLASH   ),
                .DEFAULT_SIZE             (FLASH_CTRL_DEFAULT_SIZE              )
            ) axi_flash_control_mgr_inst (
                .aclk                  (clk_250),
                .aresetn               (~reset_250),
                // CONFIGURATION BUS
                .S_AXI_AWADDR           (m_axi_lite_flash_ctrl_awaddr[flash_index]),
                .S_AXI_AWPROT           (m_axi_lite_flash_ctrl_awprot[flash_index]),
                .S_AXI_AWVALID          (m_axi_lite_flash_ctrl_awvalid[flash_index]),
                .S_AXI_AWREADY          (m_axi_lite_flash_ctrl_awready[flash_index]),
                .S_AXI_WDATA            (m_axi_lite_flash_ctrl_wdata[flash_index]),
                .S_AXI_WSTRB            (m_axi_lite_flash_ctrl_wstrb[flash_index]),
                .S_AXI_WVALID           (m_axi_lite_flash_ctrl_wvalid[flash_index]),
                .S_AXI_WREADY           (m_axi_lite_flash_ctrl_wready[flash_index]),
                .S_AXI_BRESP            (m_axi_lite_flash_ctrl_bresp[flash_index]),
                .S_AXI_BVALID           (m_axi_lite_flash_ctrl_bvalid[flash_index]),
                .S_AXI_BREADY           (m_axi_lite_flash_ctrl_bready[flash_index]),
                .S_AXI_ARADDR           (m_axi_lite_flash_ctrl_araddr[flash_index]),
                .S_AXI_ARPROT           (m_axi_lite_flash_ctrl_arprot[flash_index]),
                .S_AXI_ARVALID          (m_axi_lite_flash_ctrl_arvalid[flash_index]),
                .S_AXI_ARREADY          (m_axi_lite_flash_ctrl_arready[flash_index]),
                .S_AXI_RDATA            (m_axi_lite_flash_ctrl_rdata[flash_index]),
                .S_AXI_RRESP            (m_axi_lite_flash_ctrl_rresp[flash_index]),
                .S_AXI_RVALID           (m_axi_lite_flash_ctrl_rvalid[flash_index]),
                .S_AXI_RREADY           (m_axi_lite_flash_ctrl_rready[flash_index]),
                // USER EVENT INTERRUPTS
                .M_AXIS_FLASH_CMD       (M_AXIS_FLASH_CMD[flash_index]),
                .M_AXIS_FLASH_CMD_TSIZE (M_AXIS_FLASH_CMD_TSIZE[flash_index]),
                .M_AXIS_FLASH_CMD_TADDR (M_AXIS_FLASH_CMD_TADDR[flash_index]),
                .M_AXIS_FLASH_CMD_TVALID(M_AXIS_FLASH_CMD_TVALID[flash_index]),
                .M_AXIS_FLASH_CMD_TREADY(M_AXIS_FLASH_CMD_TREADY[flash_index]),
                // interface to memory
                .M_AXI_ARADDR           (s_axi_flash_ctrl_araddr[flash_index]),
                .M_AXI_ARLEN            (s_axi_flash_ctrl_arlen[flash_index]),
                .M_AXI_ARSIZE           (s_axi_flash_ctrl_arsize[flash_index]),
                .M_AXI_ARBURST          (s_axi_flash_ctrl_arburst[flash_index]),
                .M_AXI_ARVALID          (s_axi_flash_ctrl_arvalid[flash_index]),
                .M_AXI_ARREADY          (s_axi_flash_ctrl_arready[flash_index]),
                .M_AXI_RDATA            (s_axi_flash_ctrl_rdata[flash_index]),
                .M_AXI_RRESP            (s_axi_flash_ctrl_rresp[flash_index]),
                .M_AXI_RLAST            (s_axi_flash_ctrl_rlast[flash_index]),
                .M_AXI_RVALID           (s_axi_flash_ctrl_rvalid[flash_index]),
                .M_AXI_RREADY           (s_axi_flash_ctrl_rready[flash_index]),
                // interface to flash
                .M_AXIS_TDATA           (MEM_TO_FLASH_M_AXIS_TDATA[flash_index]),
                .M_AXIS_TKEEP           (MEM_TO_FLASH_M_AXIS_TKEEP[flash_index]),
                .M_AXIS_TVALID          (MEM_TO_FLASH_M_AXIS_TVALID[flash_index]),
                .M_AXIS_TREADY          (MEM_TO_FLASH_M_AXIS_TREADY[flash_index]),
                .M_AXIS_TLAST           (MEM_TO_FLASH_M_AXIS_TLAST[flash_index]),
            
                .FLASH_BUSY            (FLASH_BUSY[flash_index])
            );
            
        end 
        
    endgenerate

//    for (genvar i = 0; i < 3; i++) begin : dcd_status_reg_gen  

//        axi_full_ctrl_register #(
//            .ID_WIDTH               (8),
//            .DATA_WIDTH             (32),
//            .ADDR_WIDTH             (32),
//            .ADDRESS                ({12'h001, 4'(unsigned'(i)), 16'h0000}),
//            .AXI_ACCESS             ("RW"),
//            .DEFAULT_VALUE          (32'd0)
//        ) axi_full_ctrl_register_inst (
//            .ACLK                   (clk_250),            //    input  logic                      ACLK         ,
//            .ARESETN                (~reset_250),         //    input  logic                      ARESETN      ,
//            .AWID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] AWID         ,
//            .AWADDR                 (dcd_status_awaddr[i]),  //    input  logic [    ADDR_WIDTH-1:0] AWADDR       ,
//            .AWVALID                (dcd_status_awvalid[i]), //    input  logic                      AWVALID      ,
//            .AWREADY                (dcd_status_awready[i]), //    output logic                      AWREADY      ,
//            .WID                    (9'd0),               //    input  logic [      ID_WIDTH-1:0] WID          ,
//            .WDATA                  (dcd_status_wdata[i]),   //    input  logic [    DATA_WIDTH-1:0] WDATA        ,
//            .WSTRB                  (dcd_status_wstrb[i]),   //    input  logic [(DATA_WIDTH/8)-1:0] WSTRB        ,
//            .WVALID                 (dcd_status_wvalid[i]),  //    input  logic                      WVALID       ,
//            .WREADY                 (dcd_status_wready[i]),  //    output logic                      WREADY       ,
//            .BID                    (),                   //    output logic [      ID_WIDTH-1:0] BID          ,
//            .BRESP                  (dcd_status_bresp[i]),   //    output logic [               1:0] BRESP        ,
//            .BVALID                 (dcd_status_bvalid[i]),  //    output logic                      BVALID       ,
//            .BREADY                 (dcd_status_bready[i]),  //    input  logic                      BREADY       ,
//            .ARID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] ARID         ,
//            .ARADDR                 (dcd_status_araddr[i]),  //    input  logic [    ADDR_WIDTH-1:0] ARADDR       ,
//            .ARVALID                (dcd_status_arvalid[i]), //    input  logic                      ARVALID      ,
//            .ARREADY                (dcd_status_arready[i]), //    output logic                      ARREADY      ,
//            .RID                    (),                   //    output logic [      ID_WIDTH-1:0] RID          ,
//            .RDATA                  (dcd_status_rdata[i]),   //    output logic [    DATA_WIDTH-1:0] RDATA        ,
//            .RRESP                  (dcd_status_rresp[i]),   //    output logic [               1:0] RRESP        ,
//            .RVALID                 (dcd_status_rvalid[i]),  //    output logic                      RVALID       ,
//            .RREADY                 (dcd_status_rready[i]),  //    input  logic                      RREADY       ,
//            //
//            .REG_IN                 (DCD_STATUS_DI[i]),
//            .REG_IN_VALID           (DCD_STATUS_DVI[i]),
//            //
//            .REG_OUT      (),
//            .REG_OUT_VALID()
//        );

//    end

    axi_full_ctrl_register #(
        .ID_WIDTH               (8),
        .DATA_WIDTH             (32),
        .ADDR_WIDTH             (32),
        .ADDRESS                ({32'h0010_0000}),
        .AXI_ACCESS             ("RW"),
        .DEFAULT_VALUE          (32'd0)
    ) axi_full_ctrl_register_inst0 (
        .ACLK                   (clk_250),            //    input  logic                      ACLK         ,
        .ARESETN                (~reset_250),         //    input  logic                      ARESETN      ,
        .AWID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] AWID         ,
        .AWADDR                 (dcd_status_awaddr[0]),  //    input  logic [    ADDR_WIDTH-1:0] AWADDR       ,
        .AWVALID                (dcd_status_awvalid[0]), //    input  logic                      AWVALID      ,
        .AWREADY                (dcd_status_awready[0]), //    output logic                      AWREADY      ,
        .WID                    (9'd0),               //    input  logic [      ID_WIDTH-1:0] WID          ,
        .WDATA                  (dcd_status_wdata[0]),   //    input  logic [    DATA_WIDTH-1:0] WDATA        ,
        .WSTRB                  (dcd_status_wstrb[0]),   //    input  logic [(DATA_WIDTH/8)-1:0] WSTRB        ,
        .WVALID                 (dcd_status_wvalid[0]),  //    input  logic                      WVALID       ,
        .WREADY                 (dcd_status_wready[0]),  //    output logic                      WREADY       ,
        .BID                    (),                   //    output logic [      ID_WIDTH-1:0] BID          ,
        .BRESP                  (dcd_status_bresp[0]),   //    output logic [               1:0] BRESP        ,
        .BVALID                 (dcd_status_bvalid[0]),  //    output logic                      BVALID       ,
        .BREADY                 (dcd_status_bready[0]),  //    input  logic                      BREADY       ,
        .ARID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] ARID         ,
        .ARADDR                 (dcd_status_araddr[0]),  //    input  logic [    ADDR_WIDTH-1:0] ARADDR       ,
        .ARVALID                (dcd_status_arvalid[0]), //    input  logic                      ARVALID      ,
        .ARREADY                (dcd_status_arready[0]), //    output logic                      ARREADY      ,
        .RID                    (),                   //    output logic [      ID_WIDTH-1:0] RID          ,
        .RDATA                  (dcd_status_rdata[0]),   //    output logic [    DATA_WIDTH-1:0] RDATA        ,
        .RRESP                  (dcd_status_rresp[0]),   //    output logic [               1:0] RRESP        ,
        .RVALID                 (dcd_status_rvalid[0]),  //    output logic                      RVALID       ,
        .RREADY                 (dcd_status_rready[0]),  //    input  logic                      RREADY       ,
        //
        .REG_IN                 (DCD_STATUS_DI[0]),
        .REG_IN_VALID           (DCD_STATUS_DVI[0]),
        //
        .REG_OUT      (),
        .REG_OUT_VALID()
    );

    axi_full_ctrl_register #(
        .ID_WIDTH               (8),
        .DATA_WIDTH             (32),
        .ADDR_WIDTH             (32),
        .ADDRESS                ({32'h0011_0000}),
        .AXI_ACCESS             ("RW"),
        .DEFAULT_VALUE          (32'd0)
    ) axi_full_ctrl_register_inst1 (
        .ACLK                   (clk_250),            //    input  logic                      ACLK         ,
        .ARESETN                (~reset_250),         //    input  logic                      ARESETN      ,
        .AWID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] AWID         ,
        .AWADDR                 (dcd_status_awaddr[1]),  //    input  logic [    ADDR_WIDTH-1:0] AWADDR       ,
        .AWVALID                (dcd_status_awvalid[1]), //    input  logic                      AWVALID      ,
        .AWREADY                (dcd_status_awready[1]), //    output logic                      AWREADY      ,
        .WID                    (9'd0),               //    input  logic [      ID_WIDTH-1:0] WID          ,
        .WDATA                  (dcd_status_wdata[1]),   //    input  logic [    DATA_WIDTH-1:0] WDATA        ,
        .WSTRB                  (dcd_status_wstrb[1]),   //    input  logic [(DATA_WIDTH/8)-1:0] WSTRB        ,
        .WVALID                 (dcd_status_wvalid[1]),  //    input  logic                      WVALID       ,
        .WREADY                 (dcd_status_wready[1]),  //    output logic                      WREADY       ,
        .BID                    (),                   //    output logic [      ID_WIDTH-1:0] BID          ,
        .BRESP                  (dcd_status_bresp[1]),   //    output logic [               1:0] BRESP        ,
        .BVALID                 (dcd_status_bvalid[1]),  //    output logic                      BVALID       ,
        .BREADY                 (dcd_status_bready[1]),  //    input  logic                      BREADY       ,
        .ARID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] ARID         ,
        .ARADDR                 (dcd_status_araddr[1]),  //    input  logic [    ADDR_WIDTH-1:0] ARADDR       ,
        .ARVALID                (dcd_status_arvalid[1]), //    input  logic                      ARVALID      ,
        .ARREADY                (dcd_status_arready[1]), //    output logic                      ARREADY      ,
        .RID                    (),                   //    output logic [      ID_WIDTH-1:0] RID          ,
        .RDATA                  (dcd_status_rdata[1]),   //    output logic [    DATA_WIDTH-1:0] RDATA        ,
        .RRESP                  (dcd_status_rresp[1]),   //    output logic [               1:0] RRESP        ,
        .RVALID                 (dcd_status_rvalid[1]),  //    output logic                      RVALID       ,
        .RREADY                 (dcd_status_rready[1]),  //    input  logic                      RREADY       ,
        //
        .REG_IN                 (DCD_STATUS_DI[1]),
        .REG_IN_VALID           (DCD_STATUS_DVI[1]),
        //
        .REG_OUT      (),
        .REG_OUT_VALID()
    );

    axi_full_ctrl_register #(
        .ID_WIDTH               (8),
        .DATA_WIDTH             (32),
        .ADDR_WIDTH             (32),
        .ADDRESS                ({32'h0012_0000}),
        .AXI_ACCESS             ("RW"),
        .DEFAULT_VALUE          (32'd0)
    ) axi_full_ctrl_register_inst2 (
        .ACLK                   (clk_250),            //    input  logic                      ACLK         ,
        .ARESETN                (~reset_250),         //    input  logic                      ARESETN      ,
        .AWID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] AWID         ,
        .AWADDR                 (dcd_status_awaddr[2]),  //    input  logic [    ADDR_WIDTH-1:0] AWADDR       ,
        .AWVALID                (dcd_status_awvalid[2]), //    input  logic                      AWVALID      ,
        .AWREADY                (dcd_status_awready[2]), //    output logic                      AWREADY      ,
        .WID                    (9'd0),               //    input  logic [      ID_WIDTH-1:0] WID          ,
        .WDATA                  (dcd_status_wdata[2]),   //    input  logic [    DATA_WIDTH-1:0] WDATA        ,
        .WSTRB                  (dcd_status_wstrb[2]),   //    input  logic [(DATA_WIDTH/8)-1:0] WSTRB        ,
        .WVALID                 (dcd_status_wvalid[2]),  //    input  logic                      WVALID       ,
        .WREADY                 (dcd_status_wready[2]),  //    output logic                      WREADY       ,
        .BID                    (),                   //    output logic [      ID_WIDTH-1:0] BID          ,
        .BRESP                  (dcd_status_bresp[2]),   //    output logic [               1:0] BRESP        ,
        .BVALID                 (dcd_status_bvalid[2]),  //    output logic                      BVALID       ,
        .BREADY                 (dcd_status_bready[2]),  //    input  logic                      BREADY       ,
        .ARID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] ARID         ,
        .ARADDR                 (dcd_status_araddr[2]),  //    input  logic [    ADDR_WIDTH-1:0] ARADDR       ,
        .ARVALID                (dcd_status_arvalid[2]), //    input  logic                      ARVALID      ,
        .ARREADY                (dcd_status_arready[2]), //    output logic                      ARREADY      ,
        .RID                    (),                   //    output logic [      ID_WIDTH-1:0] RID          ,
        .RDATA                  (dcd_status_rdata[2]),   //    output logic [    DATA_WIDTH-1:0] RDATA        ,
        .RRESP                  (dcd_status_rresp[2]),   //    output logic [               1:0] RRESP        ,
        .RVALID                 (dcd_status_rvalid[2]),  //    output logic                      RVALID       ,
        .RREADY                 (dcd_status_rready[2]),  //    input  logic                      RREADY       ,
        //
        .REG_IN                 (DCD_STATUS_DI[2]),
        .REG_IN_VALID           (DCD_STATUS_DVI[2]),
        //
        .REG_OUT      (),
        .REG_OUT_VALID()
    );

    axi_full_ctrl_register #(
        .ID_WIDTH               (8),
        .DATA_WIDTH             (32),
        .ADDR_WIDTH             (32),
        .ADDRESS                ({32'h0013_0000}),
        .AXI_ACCESS             ("RW"),
        .DEFAULT_VALUE          (32'd0)
    ) axi_full_ctrl_register_inst3 (
        .ACLK                   (clk_250),            //    input  logic                      ACLK         ,
        .ARESETN                (~reset_250),         //    input  logic                      ARESETN      ,
        .AWID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] AWID         ,
        .AWADDR                 (dcd_status_awaddr[3]),  //    input  logic [    ADDR_WIDTH-1:0] AWADDR       ,
        .AWVALID                (dcd_status_awvalid[3]), //    input  logic                      AWVALID      ,
        .AWREADY                (dcd_status_awready[3]), //    output logic                      AWREADY      ,
        .WID                    (9'd0),               //    input  logic [      ID_WIDTH-1:0] WID          ,
        .WDATA                  (dcd_status_wdata[3]),   //    input  logic [    DATA_WIDTH-1:0] WDATA        ,
        .WSTRB                  (dcd_status_wstrb[3]),   //    input  logic [(DATA_WIDTH/8)-1:0] WSTRB        ,
        .WVALID                 (dcd_status_wvalid[3]),  //    input  logic                      WVALID       ,
        .WREADY                 (dcd_status_wready[3]),  //    output logic                      WREADY       ,
        .BID                    (),                   //    output logic [      ID_WIDTH-1:0] BID          ,
        .BRESP                  (dcd_status_bresp[3]),   //    output logic [               1:0] BRESP        ,
        .BVALID                 (dcd_status_bvalid[3]),  //    output logic                      BVALID       ,
        .BREADY                 (dcd_status_bready[3]),  //    input  logic                      BREADY       ,
        .ARID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] ARID         ,
        .ARADDR                 (dcd_status_araddr[3]),  //    input  logic [    ADDR_WIDTH-1:0] ARADDR       ,
        .ARVALID                (dcd_status_arvalid[3]), //    input  logic                      ARVALID      ,
        .ARREADY                (dcd_status_arready[3]), //    output logic                      ARREADY      ,
        .RID                    (),                   //    output logic [      ID_WIDTH-1:0] RID          ,
        .RDATA                  (dcd_status_rdata[3]),   //    output logic [    DATA_WIDTH-1:0] RDATA        ,
        .RRESP                  (dcd_status_rresp[3]),   //    output logic [               1:0] RRESP        ,
        .RVALID                 (dcd_status_rvalid[3]),  //    output logic                      RVALID       ,
        .RREADY                 (dcd_status_rready[3]),  //    input  logic                      RREADY       ,
        //
        .REG_IN                 (DCD_STATUS_DI[3]),
        .REG_IN_VALID           (DCD_STATUS_DVI[3]),
        //
        .REG_OUT      (),
        .REG_OUT_VALID()
    );

    axi_full_ctrl_register #(
        .ID_WIDTH               (8),
        .DATA_WIDTH             (32),
        .ADDR_WIDTH             (32),
        .ADDRESS                ({32'h0014_0000}),
        .AXI_ACCESS             ("RW"),
        .DEFAULT_VALUE          (32'd0)
    ) axi_full_ctrl_register_inst4 (
        .ACLK                   (clk_250),            //    input  logic                      ACLK         ,
        .ARESETN                (~reset_250),         //    input  logic                      ARESETN      ,
        .AWID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] AWID         ,
        .AWADDR                 (dcd_irq_config_awaddr),  //    input  logic [    ADDR_WIDTH-1:0] AWADDR       ,
        .AWVALID                (dcd_irq_config_awvalid), //    input  logic                      AWVALID      ,
        .AWREADY                (dcd_irq_config_awready), //    output logic                      AWREADY      ,
        .WID                    (9'd0),               //    input  logic [      ID_WIDTH-1:0] WID          ,
        .WDATA                  (dcd_irq_config_wdata),   //    input  logic [    DATA_WIDTH-1:0] WDATA        ,
        .WSTRB                  (dcd_irq_config_wstrb),   //    input  logic [(DATA_WIDTH/8)-1:0] WSTRB        ,
        .WVALID                 (dcd_irq_config_wvalid),  //    input  logic                      WVALID       ,
        .WREADY                 (dcd_irq_config_wready),  //    output logic                      WREADY       ,
        .BID                    (),                   //    output logic [      ID_WIDTH-1:0] BID          ,
        .BRESP                  (dcd_irq_config_bresp),   //    output logic [               1:0] BRESP        ,
        .BVALID                 (dcd_irq_config_bvalid),  //    output logic                      BVALID       ,
        .BREADY                 (dcd_irq_config_bready),  //    input  logic                      BREADY       ,
        .ARID                   (8'd0),               //    input  logic [      ID_WIDTH-1:0] ARID         ,
        .ARADDR                 (dcd_irq_config_araddr),  //    input  logic [    ADDR_WIDTH-1:0] ARADDR       ,
        .ARVALID                (dcd_irq_config_arvalid), //    input  logic                      ARVALID      ,
        .ARREADY                (dcd_irq_config_arready), //    output logic                      ARREADY      ,
        .RID                    (),                   //    output logic [      ID_WIDTH-1:0] RID          ,
        .RDATA                  (dcd_irq_config_rdata),   //    output logic [    DATA_WIDTH-1:0] RDATA        ,
        .RRESP                  (dcd_irq_config_rresp),   //    output logic [               1:0] RRESP        ,
        .RVALID                 (dcd_irq_config_rvalid),  //    output logic                      RVALID       ,
        .RREADY                 (dcd_irq_config_rready),  //    input  logic                      RREADY       ,
        //
        .REG_IN                 (32'b0),
        .REG_IN_VALID           (1'd0),
        //
        .REG_OUT                (DCD_IRQ_CONFIG_DO),
        .REG_OUT_VALID          (DCD_IRQ_CONFIG_DVO)
    );

endmodule
