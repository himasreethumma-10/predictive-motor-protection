// Checks voltage bounds and reports the raw-count voltage-current product.
module voltage_power_monitor #(
    parameter VOLTAGE_LOW  = 12'd1000,
    parameter VOLTAGE_HIGH = 12'd4000
) (
    input [11:0] voltage_in,
    input [11:0] current_in,
    output reg voltage_fault,
    output reg [23:0] power_estimate
);

    always @(*) begin
        // This product is an estimate in digital counts, not calibrated watts.
        power_estimate = voltage_in * current_in;
        voltage_fault = (voltage_in < VOLTAGE_LOW) ||
                        (voltage_in > VOLTAGE_HIGH);
    end

endmodule
