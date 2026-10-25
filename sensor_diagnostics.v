// Checks sensor validity and flags readings that appear stuck or implausible.
module sensor_diagnostics #(
    parameter JUMP_LIMIT = 12'd1500,
    parameter BAD_COUNT_LIMIT = 8'd16
) (
    input clk,
    input reset,
    input [11:0] current_in,
    input sensor_valid,
    output reg sensor_fault,
    output reg [7:0] invalid_count
);

    reg [11:0] previous_current;
    reg [7:0] zero_count;
    reg [7:0] max_count;
    reg [12:0] abs_jump;

    // Consecutive-value counters clear as soon as their condition disappears.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            previous_current <= 12'd0;
            zero_count <= 8'd0;
            max_count <= 8'd0;
            invalid_count <= 8'd0;
            sensor_fault <= 1'b0;
        end
        else begin
            previous_current <= current_in;

            if (!sensor_valid) begin
                if (invalid_count < BAD_COUNT_LIMIT)
                    invalid_count <= invalid_count + 1'b1;
            end
            else begin
                invalid_count <= 8'd0;
            end

            if (current_in == 12'd0) begin
                if (zero_count < BAD_COUNT_LIMIT)
                    zero_count <= zero_count + 1'b1;
            end
            else begin
                zero_count <= 8'd0;
            end

            if (current_in == 12'd4095) begin
                if (max_count < BAD_COUNT_LIMIT)
                    max_count <= max_count + 1'b1;
            end
            else begin
                max_count <= 8'd0;
            end

            // Unsigned subtraction in the larger register gives the magnitude
            // of the change regardless of which sample is larger.
            if (current_in >= previous_current)
                abs_jump = current_in - previous_current;
            else
                abs_jump = previous_current - current_in;

            // Invalid validity is an immediate trip; stuck/jump checks are
            // combined into the same diagnostic output.
            if ((!sensor_valid) ||
                (invalid_count >= BAD_COUNT_LIMIT-1) ||
                (zero_count >= BAD_COUNT_LIMIT-1) ||
                (max_count >= BAD_COUNT_LIMIT-1) ||
                (abs_jump > JUMP_LIMIT)) begin
                sensor_fault <= 1'b1;
            end
            else begin
                sensor_fault <= 1'b0;
            end
        end
    end

endmodule
