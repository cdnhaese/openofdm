`include "common_defs.v"


module ant_switch
#(
    parameter integer IQ_DATA_WIDTH	= 16,
    parameter integer TIMEOUT_WIDTH = 4
)
(   
    input clock,
    input enable,
    input reset,

    // input IQ samples
    input [2*IQ_DATA_WIDTH-1:0] data_ant1_in,
    input [2*IQ_DATA_WIDTH-1:0] data_ant2_in,
    input data_in_strobe,
    
    // RSSI input
    input [10:0] rssi1_half_db_1,
    input [10:0] rssi2_half_db_2,
    
    // power trigger input
    input power_trigger_1,
    input power_trigger_2,
    
    // TODO: ports for sync_short here
    input sync_short_reset,
    input sync_short_enable,
    input [31:0] min_plateau,
    output reg short_preamble_detected,
    output signed [31:0] phase_offset,
    
    // Need to find phase for both antenna
    input [31:0] phase_out_1,
    input phase_out_stb_1,
    input [31:0] phase_out_2,
    input phase_out_stb_2,
    
    output [31:0] phase_in_i_1,
    output [31:0] phase_in_q_1,
    output phase_in_stb_1,
    output [31:0] phase_in_i_2,
    output [31:0] phase_in_q_2,
    output phase_in_stb_2,
    
    output ant_select
);
    `include "common_params.v"

    localparam ANT_WAIT = 0;
    localparam ANT1_PREAMBLE = 1;
    localparam ANT2_PREAMBLE = 2;
    localparam ANT1_FIX = 3;
    localparam ANT2_FIX = 4;
    
    localparam ANT1 = 0;
    localparam ANT2 = 1;
    
    wire [31:0] phase_offset_1;
    wire [31:0] phase_offset_2;
    
    wire short_preamble_detected_1;
    wire short_preamble_detected_2;
    
    wire [10:0] rssi_diff_half_db;
    wire ant_select_internal;
    
    // Take sign of result to find out if RSSI2 > RSSI1
    assign rssi_diff_half_db = rssi2_half_db_2 - rssi1_half_db_1;
    assign ant_select_internal = rssi_diff_half_db[10];
    
    reg [2:0] state;
    reg [TIMEOUT_WIDTH-1:0] timeout_counter;
    
    assign phase_offset = ant_select==ANT1?phase_offset_1:phase_offset_2;
    
    sync_short sync_short_inst1 (
        .clock(clock),
        .reset(reset | sync_short_reset),
        .enable(enable & sync_short_enable),
    
        .min_plateau(min_plateau),
        .sample_in(data_ant1_in),
        .sample_in_strobe(data_in_strobe),
        
        .phase_in_i(phase_in_i_1),
        .phase_in_q(phase_in_q_1),
        .phase_in_stb(phase_in_stb_1),
    
        .phase_out(phase_out_1),
        .phase_out_stb(phase_out_stb_1),
    
        .short_preamble_detected(short_preamble_detected_1),
        .phase_offset(phase_offset_1)
    );
    
    sync_short sync_short_inst2 (
        .clock(clock),
        .reset(reset | sync_short_reset),
        .enable(enable & sync_short_enable),
    
        .min_plateau(min_plateau),
        .sample_in(data_ant2_in),
        .sample_in_strobe(data_in_strobe),
    
        .phase_in_i(phase_in_i_2),
        .phase_in_q(phase_in_q_2),
        .phase_in_stb(phase_in_stb_2),
    
        .phase_out(phase_out_2),
        .phase_out_stb(phase_out_stb_2),
    
        .short_preamble_detected(short_preamble_detected_2),
        .phase_offset(phase_offset_2)
    );
    
    assign ant_select = state==ANT1_FIX?ANT1:ANT2;
    
    always @(posedge clock) begin
        if (reset) begin
            state <= ANT_WAIT;
            short_preamble_detected <= 0;
            timeout_counter <= 0;
        end else begin
            case(state)
                ANT_WAIT: begin
                    short_preamble_detected <= 0;
                    timeout_counter <= 0;
                    if (short_preamble_detected_1) begin
                        state <= ANT1_PREAMBLE;
                    end else if (short_preamble_detected_2) begin
                        state <= ANT2_PREAMBLE;
                    end
                end
                ANT1_PREAMBLE: begin
                    timeout_counter <= timeout_counter + 1;
                    short_preamble_detected <= 0;
                    if (~power_trigger_1) begin
                        state <= ANT_WAIT;
                    end else if (short_preamble_detected_2 && ant_select_internal==ANT2) begin
                        short_preamble_detected <= 1;
                        state <= ANT2_FIX;
                    end else if (timeout_counter == {(TIMEOUT_WIDTH-1){1'b1}}) begin
                        short_preamble_detected <= 1;
                        state <= ANT1_FIX;
                    end
                end
                ANT2_PREAMBLE: begin
                    timeout_counter <= timeout_counter + 1;
                    if (~power_trigger_2) begin
                        state <= ANT_WAIT;
                    end else if (short_preamble_detected_1 && ant_select_internal==ANT1) begin
                        short_preamble_detected <= 1;
                        state <= ANT1_FIX;
                    end else if (timeout_counter == {(TIMEOUT_WIDTH-1){1'b1}}) begin
                        short_preamble_detected <= 1;
                        state <= ANT2_FIX;
                    end
                end
                ANT1_FIX: begin
                    timeout_counter <= 0;
                    if (short_preamble_detected) short_preamble_detected <= 0;
                    if (~power_trigger_1) begin
                        state <= ANT_WAIT;
                    end
                end
                ANT2_FIX: begin
                    timeout_counter <= 0;
                    if (short_preamble_detected) short_preamble_detected <= 0;
                    if (~power_trigger_2) begin
                        state <= ANT_WAIT;
                    end
                end
                default: begin
                    state <= ANT_WAIT;
                    timeout_counter <= 0;
                    short_preamble_detected <= 0;
                end
            endcase
        end
    end
endmodule
