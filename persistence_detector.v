// Flags a high-risk condition that remains active for COUNT_LIMIT clocks.
module persistence_detector #(
    parameter COUNT_LIMIT = 8
) (
    input clk,
    input reset,
    input high_risk,
    output reg persistent_fault,
    output reg [7:0] count
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 8'd0;
            persistent_fault <= 1'b0;
        end
        else if (high_risk) begin
            // Saturate the count and keep the fault asserted while risk persists.
            if (count < COUNT_LIMIT)
                count <= count + 1'b1;

            if (count >= COUNT_LIMIT-1)
                persistent_fault <= 1'b1;
        end
        else begin
            count <= 8'd0;
            persistent_fault <= 1'b0;
        end
    end

endmodule
