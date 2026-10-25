// Tracks the previous filtered-current sample and its signed change.
module trend_detector (
    input clk,
    input reset,
    input [11:0] current_in,
    output reg signed [12:0] delta_i,
    output reg [11:0] previous_current
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            previous_current <= 12'd0;
            delta_i <= 13'sd0;
        end
        else begin
            // Extend both unsigned counts before subtraction to keep the
            // signed difference range from -4095 through +4095.
            delta_i <= $signed({1'b0,current_in}) -
                       $signed({1'b0,previous_current});
            previous_current <= current_in;
        end
    end

endmodule
