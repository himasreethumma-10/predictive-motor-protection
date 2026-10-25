// Controls startup, normal operation, shutdown, qualified recovery, and lockout.
module protection_fsm #(
    parameter COOLDOWN_CYCLES = 16,
    parameter CLEAR_QUALIFY_CYCLES = 8,
    parameter MAX_RECOVERY_ATTEMPTS = 3
) (
    input clk,
    input reset,

    input [2:0] risk_level,
    input fault,
    input bist_done,
    input bist_fail,
    input recovery_complete,

    output reg [3:0] state,
    output reg motor_enable,
    output reg recovery_active,
    output reg lockout
);

    localparam ST_STARTUP      = 4'd0;
    localparam ST_BIST         = 4'd1;
    localparam ST_NORMAL       = 4'd2;
    localparam ST_WARNING      = 4'd3;
    localparam ST_PWM_REDUCE   = 4'd4;
    localparam ST_MONITOR      = 4'd5;
    localparam ST_CRITICAL     = 4'd6;
    localparam ST_FAULT_OFF    = 4'd7;
    localparam ST_COOLDOWN     = 4'd8;
    localparam ST_SELF_CHECK   = 4'd9;
    localparam ST_RECOVERY     = 4'd10;
    localparam ST_LOCKOUT      = 4'd11;

    localparam SAFE     = 3'd0;
    localparam WARNING  = 3'd1;
    localparam DANGER   = 3'd2;
    localparam CRITICAL = 3'd3;
    localparam FAULT    = 3'd4;

    reg [3:0] next_state;
    reg [7:0] cooldown_count;
    reg [7:0] clear_qualify_count;
    reg [7:0] recovery_attempt_count;
    reg cooldown_done;

    // State and timing counters are updated together on the rising clock edge.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state                  <= ST_STARTUP;
            cooldown_count         <= 8'd0;
            clear_qualify_count    <= 8'd0;
            recovery_attempt_count <= 8'd0;
            cooldown_done          <= 1'b0;
        end
        else begin
            state <= next_state;

            // Count cooldown clocks while the FSM is entering or in cooldown.
            if (next_state == ST_COOLDOWN) begin
                if (cooldown_count < COOLDOWN_CYCLES - 1) begin
                    cooldown_count <= cooldown_count + 1'b1;
                    cooldown_done  <= 1'b0;
                end else begin
                    cooldown_done  <= 1'b1;
                end
            end
            else begin
                cooldown_count <= 8'd0;
                cooldown_done  <= 1'b0;
            end

            // Any interruption restarts the consecutive-clear qualification.
            if ((state == ST_SELF_CHECK) && !fault && !bist_fail &&
                (risk_level <= WARNING)) begin
                if (clear_qualify_count < CLEAR_QUALIFY_CYCLES)
                    clear_qualify_count <= clear_qualify_count + 1'b1;
            end
            else begin
                clear_qualify_count <= 8'd0;
            end

            // Count attempts when recovery is entered, not on every recovery clock.
            if ((state == ST_SELF_CHECK) && (next_state == ST_RECOVERY))
                recovery_attempt_count <= recovery_attempt_count + 1'b1;
        end
    end

    // Combinational next-state logic describes every allowed transition.
    always @(*) begin
        next_state = state;

        case (state)
            ST_STARTUP: begin
                next_state = ST_BIST;
            end

            ST_BIST: begin
                if (bist_fail)
                    next_state = ST_LOCKOUT;
                else if (bist_done)
                    next_state = ST_NORMAL;
            end

            ST_NORMAL: begin
                if (fault)
                    next_state = ST_FAULT_OFF;
                else if (risk_level == WARNING)
                    next_state = ST_WARNING;
                else if (risk_level == DANGER)
                    next_state = ST_PWM_REDUCE;
                else if (risk_level == CRITICAL)
                    next_state = ST_CRITICAL;
                else if (risk_level == FAULT)
                    next_state = ST_FAULT_OFF;
            end

            ST_WARNING: begin
                if (fault)
                    next_state = ST_FAULT_OFF;
                else if (risk_level == SAFE)
                    next_state = ST_NORMAL;
                else if (risk_level == DANGER)
                    next_state = ST_PWM_REDUCE;
                else if ((risk_level == CRITICAL) || (risk_level == FAULT))
                    next_state = ST_CRITICAL;
            end

            ST_PWM_REDUCE: begin
                if (fault)
                    next_state = ST_FAULT_OFF;
                else if (risk_level == SAFE)
                    next_state = ST_MONITOR;
                else if (risk_level == WARNING)
                    next_state = ST_WARNING;
                else if (risk_level == CRITICAL || risk_level == FAULT)
                    next_state = ST_CRITICAL;
            end

            ST_MONITOR: begin
                if (fault)
                    next_state = ST_FAULT_OFF;
                else if (risk_level == SAFE)
                    next_state = ST_RECOVERY;
                else if (risk_level >= CRITICAL)
                    next_state = ST_CRITICAL;
            end

            ST_CRITICAL: begin
                next_state = ST_FAULT_OFF;
            end

            ST_FAULT_OFF: begin
                next_state = ST_COOLDOWN;
            end

            ST_COOLDOWN: begin
                if (bist_fail)
                    next_state = ST_LOCKOUT;
                else if (cooldown_done)
                    next_state = ST_SELF_CHECK;
            end

            ST_SELF_CHECK: begin
                // Unsafe or unstable conditions lock out; eligible clears recover.
                if (fault || bist_fail || (risk_level > WARNING))
                    next_state = ST_LOCKOUT;
                else if (clear_qualify_count >= CLEAR_QUALIFY_CYCLES - 1) begin
                    if (recovery_attempt_count < MAX_RECOVERY_ATTEMPTS)
                        next_state = ST_RECOVERY;
                    else
                        next_state = ST_LOCKOUT;
                end
            end

            ST_RECOVERY: begin
                if (fault || risk_level >= CRITICAL)
                    next_state = ST_FAULT_OFF;
                else if ((risk_level <= WARNING) && recovery_complete)
                    next_state = ST_NORMAL;
            end

            ST_LOCKOUT: begin
                next_state = ST_LOCKOUT;
            end

            default: begin
                next_state = ST_LOCKOUT;
            end
        endcase
    end

    // Decode state into motor-enable, recovery, and lockout control outputs.
    always @(*) begin
        motor_enable    = 1'b0;
        recovery_active = 1'b0;
        lockout         = 1'b0;

        case (state)
            ST_NORMAL,
            ST_WARNING,
            ST_PWM_REDUCE,
            ST_MONITOR: motor_enable = 1'b1;

            ST_RECOVERY: begin
                motor_enable    = 1'b1;
                recovery_active = 1'b1;
            end

            ST_LOCKOUT: lockout = 1'b1;

            default: begin
                motor_enable = 1'b0;
            end
        endcase
    end

endmodule
