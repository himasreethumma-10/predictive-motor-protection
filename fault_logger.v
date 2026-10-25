// Keeps the most recent fault code, peak current, and current fault duration.
module fault_logger (
    input clk,
    input reset,
    input fault,
    input [3:0] fault_code,
    input [11:0] current_in,

    output reg [3:0] last_fault_code,
    output reg [11:0] peak_current,
    output reg [15:0] fault_duration
);
    always @(posedge clk or posedge reset) begin

        if (reset) begin
            last_fault_code <= 4'd0;
            peak_current <= 12'd0;
            fault_duration <= 16'd0;
        end
        else begin
            // Peak current is retained until reset.
            if (current_in > peak_current)
                peak_current <= current_in;

            if (fault) begin
                last_fault_code <= fault_code;

                // Saturate the duration counter rather than allowing wraparound.
                if (fault_duration != 16'hFFFF)
                    fault_duration <= fault_duration + 1'b1;
            end
            else begin
                fault_duration <= 16'd0;
            end
        end
    end

endmodule
