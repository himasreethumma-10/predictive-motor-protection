// Verilog-2001 compatible classifier for SAFE through FAULT risk levels.
module risk_classifier #(
    parameter WARNING_LIMIT  = 12'd1800,
    parameter DANGER_LIMIT   = 12'd2400,
    parameter CRITICAL_LIMIT = 12'd3000,
    parameter FAULT_LIMIT    = 12'd3600
) (
    input [11:0] current_in,
    input [11:0] predicted_current,
    // Kept in the interface for integration; prediction already uses this trend.
    input signed [12:0] delta_i,
    output reg [2:0] risk_level
);

    localparam SAFE     = 3'd0;
    localparam WARNING  = 3'd1;
    localparam DANGER   = 3'd2;
    localparam CRITICAL = 3'd3;
    localparam FAULT    = 3'd4;

    reg [11:0] effective_current;

    always @(*) begin
        // Compare present and projected counts; use the highest matching band.
        if (predicted_current > current_in)
            effective_current = predicted_current;
        else
            effective_current = current_in;

        // Check the most severe band first, then work down to SAFE.
        if (current_in >= FAULT_LIMIT || predicted_current >= FAULT_LIMIT)
            risk_level = FAULT;
        else if (current_in >= CRITICAL_LIMIT || predicted_current >= CRITICAL_LIMIT)
            risk_level = CRITICAL;
        else if (current_in >= DANGER_LIMIT || predicted_current >= DANGER_LIMIT)
            risk_level = DANGER;
        else if (effective_current >= WARNING_LIMIT)
            risk_level = WARNING;
        else
            risk_level = SAFE;
    end

endmodule
