// Maintains a simple count-based thermal estimate and threshold flag.
module thermal_estimator #(
    parameter THERMAL_LIMIT = 12'd3000,
    parameter HEAT_STEP = 12'd8,
    parameter COOL_STEP = 12'd2
) (
    input clk,
    input reset,
    input [11:0] current_in,
    input [11:0] temperature_in,
    output reg [11:0] thermal_state,
    output reg thermal_fault
);

    reg [11:0] next_thermal;

    // Calculate the next state combinationally: heat from high current or
    // cool toward zero, then do not let the estimate fall below measurement.
    always @(*) begin
        if (current_in > 12'd1200) begin
            if (thermal_state <= 12'd4087)
                next_thermal = thermal_state + HEAT_STEP;
            else
                next_thermal = 12'd4095;
        end
        else begin
            if (thermal_state >= COOL_STEP)
                next_thermal = thermal_state - COOL_STEP;
            else
                next_thermal = 12'd0;
        end

        if (temperature_in > next_thermal)
            next_thermal = temperature_in;
    end

    // Store the candidate estimate; reset starts the model at zero.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            thermal_state <= 12'd0;
        end
        else begin
            thermal_state <= next_thermal;
        end
    end

    // The raw temperature check trips immediately, without waiting for a clock.
    always @(*) begin
        thermal_fault = (thermal_state >= THERMAL_LIMIT) ||
                        (temperature_in >= THERMAL_LIMIT);
    end

endmodule
