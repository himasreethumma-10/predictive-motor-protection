// Current-sample deglitcher for the normal protection path.
// The fast-trip detector remains connected directly to the raw sampled path.
module current_deglitcher #(
    parameter [11:0] JUMP_LIMIT = 12'd1000,
    parameter [7:0]  GLITCH_SAMPLES = 8'd2
) (
    input             clk,
    input             reset,
    input      [11:0] current_in,
    output reg [11:0] deglitched_current,
    output reg        deglitch_fault
);

    reg  [11:0] previous_current;
    reg  [7:0]  spike_count;
    wire [12:0] abs_jump;

    assign abs_jump = (current_in >= previous_current)
                    ? (current_in - previous_current)
                    : (previous_current - current_in);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            previous_current   <= 12'd0;
            deglitched_current <= 12'd0;
            deglitch_fault     <= 1'b0;
            spike_count        <= 8'd0;
        end else begin
            if (abs_jump > JUMP_LIMIT) begin
                if (spike_count < GLITCH_SAMPLES)
                    spike_count <= spike_count + 8'd1;

                deglitch_fault     <= (spike_count >= GLITCH_SAMPLES - 1'b1);
                deglitched_current <= previous_current;
            end else begin
                spike_count        <= 8'd0;
                deglitch_fault     <= 1'b0;
                deglitched_current <= current_in;
            end

            previous_current <= current_in;
        end
    end
endmodule
