// Detects high current with low commanded duty and a non-rising current trend.
module stall_detector #(
    parameter CURRENT_LIMIT = 12'd2400,
    parameter LOW_PWM_LIMIT = 10'd300,
    parameter STALL_COUNT_LIMIT = 8
) (
    input clk,
    input reset,
    input [11:0] current_in,
    input signed [12:0] delta_i,
    input [9:0] pwm_duty,
    output reg stall_fault,
    output reg [7:0] stall_count
);

    wire stall_condition;

    // All three observations must be true in the same cycle.
    assign stall_condition =
        (current_in >= CURRENT_LIMIT) &&
        (pwm_duty <= LOW_PWM_LIMIT) &&
        (delta_i <= 0);

    // Require the condition to persist for STALL_COUNT_LIMIT cycles.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stall_count <= 8'd0;
            stall_fault <= 1'b0;
        end
        else if (stall_condition) begin
            if (stall_count < STALL_COUNT_LIMIT)
                stall_count <= stall_count + 1'b1;

            if (stall_count >= STALL_COUNT_LIMIT-1)
                stall_fault <= 1'b1;
        end
        else begin
            stall_count <= 8'd0;
            stall_fault <= 1'b0;
        end
    end

endmodule
