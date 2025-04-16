module fsm_multiplier (
    input wire clk,               // 50 MHz clock
    input wire k0,                // Button input for state transitions (active-low)
    input wire k1,                // Button input for reset (active-low)
    input wire [9:0] switches,    // 10-bit switches for binary input
    output wire [6:0] disp0,      // 7-segment display for digit 0
    output wire [6:0] disp1,      // 7-segment display for digit 1
    output wire [6:0] disp2,      // 7-segment display for digit 2
    output wire [6:0] disp3,      // 7-segment display for digit 3
    output reg [9:0] leds         // 10-bit LED output for state indication
);

    // **State Encoding**
    typedef enum logic [1:0] {
        IDLE,       // Waiting for input
        FIRST_NUM,  // First number captured
        NEXT_NUM,   // Processing and displaying product
        ERROR       // Error state
    } state_t;

    // **State Variables**
    state_t pr_state;  // Represents the current state
    state_t nx_state;  // Represents the next state

    // **Internal Signals**
    logic [15:0] lastn, currentn, cumprod;  // Registers for storing numbers
    wire [15:0] bcd;  // Binary Coded Decimal output from Double Dabble module
    logic k0pressed, k1pressed;  // Debounced key press signals
    logic prev_k0, prev_k1;      // Previous key states for edge detection

    // **Sequential Logic**: State Updates and Registers
    always_ff @(posedge clk) begin
        // Debounce logic for detecting falling edges (active-low keys)
        k0pressed <= prev_k0 && !k0;  // Triggered on a falling edge of k0
        k1pressed <= prev_k1 && !k1;  // Triggered on a falling edge of k1

        // Update previous key states
        prev_k0 <= k0;
        prev_k1 <= k1;

        // State transition logic
        if (k1pressed) begin
            pr_state <= IDLE;  // Reset to IDLE on KEY[1]
        end else begin
            pr_state <= nx_state;  // Update to next state
        end

        // Update internal registers based on state transitions
        if (pr_state == FIRST_NUM && nx_state == NEXT_NUM) begin
            currentn <= switches;           // Capture second number
            cumprod <= lastn * switches;    // Calculate product
        end else if (pr_state == IDLE && nx_state == FIRST_NUM) begin
            lastn <= switches;  // Capture first number
        end
    end

    // **Combinational Logic**: State Transitions and Outputs
    always_comb begin
        nx_state = pr_state;  // Default next state
        leds = 10'b0;         // Default all LEDs off

        case (pr_state)
            IDLE: begin
                leds[0] = 1'b1;  // Indicate IDLE state
                if (k0pressed) nx_state = FIRST_NUM;  // Transition to FIRST_NUM
            end

            FIRST_NUM: begin
                leds[1] = 1'b1;  // Indicate FIRST_NUM state
                if (k0pressed) nx_state = NEXT_NUM;  // Transition to NEXT_NUM
            end

            NEXT_NUM: begin
                leds[2] = 1'b1;  // Indicate NEXT_NUM state
                if (cumprod > 16'd9999) begin
                    nx_state = ERROR;  // Overflow -> ERROR
                end else if (k1pressed) begin
                    nx_state = IDLE;  // Reset to IDLE
                end
            end

            ERROR: begin
                leds = 10'b1111111111;  // Turn on all LEDs to indicate error
            end

            default: nx_state = IDLE;  // Safety fallback
        endcase
    end

    // **Module Instantiations**
    double_dabble dd_inst (
        .bin((pr_state == NEXT_NUM) ? cumprod : switches),  // Use switches in IDLE/FIRST_NUM, cumprod in NEXT_NUM
        .bcd(bcd)                                           // BCD output for display
    );

    // Instantiate Seven Segment Display Drivers
    seven_seg_display_driver hex0_driver (
        .digit((pr_state == ERROR) ? 4'b0000 : bcd[3:0]),   // Error state displays 0000
        .segments(disp0)                                    // Drive HEX0
    );

    seven_seg_display_driver hex1_driver (
        .digit((pr_state == ERROR) ? 4'b0000 : bcd[7:4]),   // Error state displays 0000
        .segments(disp1)                                    // Drive HEX1
    );

    seven_seg_display_driver hex2_driver (
        .digit((pr_state == ERROR) ? 4'b0000 : bcd[11:8]),  // Error state displays 0000
        .segments(disp2)                                    // Drive HEX2
    );

    seven_seg_display_driver hex3_driver (
        .digit((pr_state == ERROR) ? 4'b0000 : bcd[15:12]), // Error state displays 0000
        .segments(disp3)                                    // Drive HEX3
    );

endmodule
