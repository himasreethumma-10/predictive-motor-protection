// Converts active fault flags into one code using a fixed priority order.
module fault_classifier (
    input emergency_current_fault,
    input thermal_fault,
    input voltage_fault,
    input sensor_fault,
    input stall_fault,
    input persistent_fault,

    output reg fault,
    output reg [3:0] fault_code
);

    // The first active condition wins, so sensor faults have highest priority.
    always @(*) begin
        fault      = 1'b0;
        fault_code = 4'd0;

        if (sensor_fault) begin
            fault      = 1'b1;
            fault_code = 4'd1;
        end
        else if (emergency_current_fault) begin
            fault      = 1'b1;
            fault_code = 4'd2;
        end
        else if (thermal_fault) begin
            fault      = 1'b1;
            fault_code = 4'd3;
        end
        else if (stall_fault) begin
            fault      = 1'b1;
            fault_code = 4'd4;
        end
        else if (voltage_fault) begin
            fault      = 1'b1;
            fault_code = 4'd5;
        end
        else if (persistent_fault) begin
            fault      = 1'b1;
            fault_code = 4'd6;
        end
    end

endmodule
