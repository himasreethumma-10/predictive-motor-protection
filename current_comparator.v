// Produces cumulative threshold flags from the filtered current count.
module current_comparator #(
    parameter WARNING_LIMIT  = 12'd1800,
    parameter DANGER_LIMIT   = 12'd2400,
    parameter CRITICAL_LIMIT = 12'd3000,
    parameter FAULT_LIMIT    = 12'd3600
) (
    input [11:0] current_in,
    output reg warning,
    output reg danger,
    output reg critical,
    output reg emergency_fault
);

    // Higher thresholds also satisfy each lower threshold.
    always @(*) begin
        warning = (current_in >= WARNING_LIMIT);
        danger = (current_in >= DANGER_LIMIT);
        critical = (current_in >= CRITICAL_LIMIT);
        emergency_fault = (current_in >= FAULT_LIMIT);
    end

endmodule
