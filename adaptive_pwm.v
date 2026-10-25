// Selects a risk-based duty and ramps up gradually during recovery.
module adaptive_pwm #(
    parameter SAFE_DUTY     = 10'd800,
    parameter WARNING_DUTY  = 10'd650,
    parameter DANGER_DUTY   = 10'd450,
    parameter CRITICAL_DUTY = 10'd200
) (
    input clk,
    input reset,
    input [2:0] risk_level,
    input motor_enable,
    input recovery_active,

    output reg [9:0] pwm_duty,
    output recovery_complete
);

    localparam SAFE     = 3'd0;
    localparam WARNING  = 3'd1;
    localparam DANGER   = 3'd2;
    localparam CRITICAL = 3'd3;
    localparam FAULT    = 3'd4;

    reg [9:0] target_duty;

    // A default value is assigned before the case so every path is defined.
    always @(*) begin
        target_duty = 10'd0;

        case (risk_level)
            SAFE:     target_duty = SAFE_DUTY;
            WARNING:  target_duty = WARNING_DUTY;
            DANGER:   target_duty = DANGER_DUTY;
            CRITICAL: target_duty = CRITICAL_DUTY;
            default:  target_duty = 10'd0;
        endcase

        if (!motor_enable)
            target_duty = 10'd0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pwm_duty <= 10'd0;
        end
        else if (!motor_enable) begin
            pwm_duty <= 10'd0;
        end
        else if (recovery_active) begin
            // Step toward the target without overshooting it.
            if (pwm_duty < target_duty)
                pwm_duty <= pwm_duty + 10'd10;
            else
                pwm_duty <= target_duty;
        end
        else begin
            pwm_duty <= target_duty;
        end
    end

    // The FSM can leave recovery only after the selected target is reached.
    assign recovery_complete = (pwm_duty >= target_duty);

endmodule
