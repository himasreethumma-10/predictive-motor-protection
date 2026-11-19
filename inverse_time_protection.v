// Digital inverse-time overload accumulator for sustained elevated current.
module inverse_time_protection #(
    parameter [11:0] WARNING_LIMIT       = 12'd1800,
    parameter [15:0] INVERSE_TIME_LIMIT = 16'd2000
) (
    input      clk,
    input      reset,
    input      [11:0] current_in,
    output reg inverse_time_fault
);

    reg [15:0] time_accumulator;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            time_accumulator   <= 16'd0;
            inverse_time_fault <= 1'b0;
        end else begin
            if (current_in >= WARNING_LIMIT) begin
                if (time_accumulator < 16'hFFFF)
                    time_accumulator <= time_accumulator
                                      + {4'd0, current_in[11:4]} + 16'd1;
            end else if (time_accumulator > 16'd2) begin
                time_accumulator <= time_accumulator - 16'd2;
            end else begin
                time_accumulator <= 16'd0;
            end

            inverse_time_fault <= (time_accumulator >= INVERSE_TIME_LIMIT);
        end
    end
endmodule
