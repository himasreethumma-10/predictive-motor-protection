// Generates a 1024-count PWM waveform from the requested duty count.
module pwm_generator (
    input clk,
    input reset,
    input [9:0] duty,
    output reg pwm_out
);

    reg [9:0] counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 10'd0;
            pwm_out <= 1'b0;
        end
        else begin
            // The 10-bit counter wraps naturally after 1023.
            counter <= counter + 1'b1;

            if (counter < duty)
                pwm_out <= 1'b1;
            else
                pwm_out <= 1'b0;
        end
    end

endmodule
