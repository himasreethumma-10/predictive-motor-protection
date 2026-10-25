// Registers the already-digitized sensor inputs on each clock edge.
module adc_interface (
    input        clk,
    input        reset,
    input [11:0] current_raw,
    input [11:0] voltage_raw,
    input [11:0] temperature_raw,
    input        sensor_valid_raw,

    output reg [11:0] current_sample,
    output reg [11:0] voltage_sample,
    output reg [11:0] temperature_sample,
    output reg        sensor_valid
);

    // The asynchronous reset gives the rest of the design known startup values.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_sample     <= 12'd0;
            voltage_sample     <= 12'd0;
            temperature_sample <= 12'd0;
            sensor_valid       <= 1'b0;
        end
        else begin
            current_sample     <= current_raw;
            voltage_sample     <= voltage_raw;
            temperature_sample <= temperature_raw;
            sensor_valid       <= sensor_valid_raw;
        end
    end

endmodule
