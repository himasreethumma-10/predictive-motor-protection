// Low-latency overcurrent detector on the unfiltered sampled-current path.
module fast_trip_detector #(
    parameter [11:0] FAST_TRIP_LIMIT = 12'd3500,
    parameter [7:0]  QUALIFY_COUNT   = 8'd2
) (
    input      clk,
    input      reset,
    input      [11:0] current_in,
    output reg fast_trip_fault
);

    reg [7:0] trip_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            trip_count      <= 8'd0;
            fast_trip_fault <= 1'b0;
        end else if (current_in >= FAST_TRIP_LIMIT) begin
            if (trip_count < QUALIFY_COUNT)
                trip_count <= trip_count + 8'd1;
            fast_trip_fault <= (trip_count >= QUALIFY_COUNT - 1'b1);
        end else begin
            trip_count      <= 8'd0;
            fast_trip_fault <= 1'b0;
        end
    end
endmodule
