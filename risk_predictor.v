// Projects current forward by a configurable number of sample intervals.
module risk_predictor #(
    parameter PREDICTION_HORIZON = 3
) (
    input clk,
    input reset,
    input [11:0] current_in,
    input signed [12:0] delta_i,
    output reg [11:0] predicted_current
);

    // Extra signed width holds current plus the scaled positive or negative trend.
    reg signed [16:0] prediction_temp;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            predicted_current <= 12'd0;
            prediction_temp <= 17'sd0;
        end
        else begin
            // Clamp the prediction so it remains a valid 12-bit sensor count.
            prediction_temp =
                $signed({1'b0,current_in}) +
                (delta_i * PREDICTION_HORIZON);

            if (prediction_temp < 0)
                predicted_current <= 12'd0;
            else if (prediction_temp > 4095)
                predicted_current <= 12'd4095;
            else
                predicted_current <= prediction_temp[11:0];
        end
    end

endmodule
