module debouncer (
    input wire clk,         // 50 MHz clock
    input wire btn,         // Noisy button input (active low)
    output reg btn_out      // Clean debounced output
);

    // Parameters for debouncing
    parameter DEBOUNCE_TIME = 500000; // 10 ms debounce period for 50 MHz clock

    // Internal registers
    reg [19:0] counter = 0; // Counter for debounce timing
    reg btn_sync_0 = 1'b1;  // First stage of synchronization
    reg btn_sync_1 = 1'b1;  // Second stage of synchronization

    always_ff @(posedge clk) begin
        // Synchronize the button input to avoid metastability
        btn_sync_0 <= btn;
        btn_sync_1 <= btn_sync_0;

        // If the current button state is different from the previous stable state
        if (btn_sync_1 != btn_out) begin
            counter <= counter + 1;
            if (counter >= DEBOUNCE_TIME) begin
                btn_out <= btn_sync_1; // Update the debounced output
                counter <= 0;          // Reset the counter
            end
        end else begin
            counter <= 0; // Reset counter if no change in button state
        end
    end

endmodule
