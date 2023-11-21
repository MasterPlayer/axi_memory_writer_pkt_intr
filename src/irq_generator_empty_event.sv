`timescale 1ns / 1ps



module irq_generator_empty_event (
    input  logic        CLK              ,
    input  logic        RESET            ,
    input  logic [31:0] DURATION         ,
    input  logic        CMD_EMPTY        ,
    input  logic        CMD_RDEN         ,
    output logic        CMD_EMPTY_IMPULSE
);

    typedef enum {
        IDLE_ST         ,
        EVENT_GEN_ST 
    } fsm;

    fsm current_state = IDLE_ST;

    logic d_cmd_empty;
    logic cmd_empty_event;
    logic d_cmd_rden;

    logic [31:0] duration_reg = '{default:0};

    always_ff @(posedge CLK) begin : d_cmd_empty_processing 
        d_cmd_empty <= CMD_EMPTY;
    end 

    always_ff @(posedge CLK) begin : cmd_empty_event_processing 
        if (!CMD_EMPTY & d_cmd_empty) begin 
            cmd_empty_event <= 1'b1;
        end else begin 
            if (!CMD_EMPTY & d_cmd_rden) begin 
                cmd_empty_event <= 1'b1;
            end else begin 
                cmd_empty_event <= 1'b0;
            end 
        end 
    end 


    always_ff @(posedge CLK) begin : d_cmd_rden_processing 
        d_cmd_rden <= CMD_RDEN;
    end 

    always_ff @(posedge CLK) begin : duration_reg_processing 
        case (current_state) 
            IDLE_ST : 
                duration_reg <= '{default:0};

            EVENT_GEN_ST : 
                if (duration_reg < DURATION) begin 
                    duration_reg <= duration_reg + 1;
                end else begin 
                    duration_reg <= duration_reg;
                end 

        endcase
    end 


    always_ff @(posedge CLK) begin : current_state_processing 
        if (RESET) begin 
            current_state <= IDLE_ST;
        end else begin
            case (current_state)  
                IDLE_ST : 
                    if (cmd_empty_event) begin 
                        current_state <= EVENT_GEN_ST;
                    end else begin 
                        current_state <= current_state;
                    end  

                EVENT_GEN_ST :
                    if (CMD_RDEN) begin 
                        current_state <= IDLE_ST;
                    end else begin 
                        if (duration_reg == (DURATION-1)) begin 
                            current_state <= IDLE_ST;
                        end else begin 
                            current_state <= current_state;
                        end 
                    end 

                default : 
                    current_state <= current_state;

            endcase
        end 
    end 


    always_ff @(posedge CLK) begin : CMD_EMPTY_IMPULSE_processing 
        case (current_state)
            EVENT_GEN_ST : 
                if (CMD_RDEN) begin 
                    CMD_EMPTY_IMPULSE <= 1'b0;
                end else begin 
                    CMD_EMPTY_IMPULSE <= 1'b1;
                end 

            default :   
                CMD_EMPTY_IMPULSE <= 1'b0;

        endcase // current_state
    end 





endmodule
