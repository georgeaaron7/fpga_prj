module pipeline_demo_system (
    input  logic clk,              // Clock input (FPGA oscillator)
    input  logic rst_n,            // Reset button (active low)
    input  logic [3:0] vector_sel, // 4 switches to select test vector (0-9)
    input  logic start_btn,        // Button to start classification
    output logic seizure_led,      // LED for seizure detection result
    output logic non_seizure_led,  // LED for non-seizure indication
    output logic processing_led,   // LED indicating system is processing
    output logic ready_led,        // LED indicating system is ready
    output logic [2:0] vector_leds // LEDs to display selected test vector (binary)
);

    // Internal signals
    logic [15:0] eeg_data [177:0];    // Current test vector
    logic data_valid;                  // Signal to start classification
    logic system_ready;
    logic result_valid;
    logic seizure_detected;
    logic [15:0] confidence;
    logic [1:0] system_status;
    
    // Pipelined button processing
    logic start_btn_ff1, start_btn_ff2, start_btn_ff3;
    logic start_btn_pulse;
    
    // Vector selection with pipeline 
    logic [3:0] vector_index, vector_index_ff1, vector_index_ff2;
    
    // Pipeline registers for outputs
    logic seizure_led_reg, non_seizure_led_reg;
    logic processing_led_reg, ready_led_reg;
    logic [2:0] vector_leds_reg;
    
    // Generate very simple test patterns
    // Instead of using external test_vectors module
    always_comb begin
        // Generate test patterns procedurally
        for (int i = 0; i < 178; i++) begin
            // Even test vectors (0,2,4,6,8) are seizure cases
            // Odd test vectors (1,3,5,7,9) are non-seizure cases
            if (vector_index[0] == 0) 
                eeg_data[i] = 16'h0100 + i + {13'b0, vector_index[3:1]}; // Seizure pattern
            else 
                eeg_data[i] = 16'h0200 + i + {13'b0, vector_index[3:1]}; // Non-seizure pattern
        end
    end
    
    // Multi-stage button debouncing and synchronization
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_btn_ff1 <= 0;
            start_btn_ff2 <= 0;
            start_btn_ff3 <= 0;
            start_btn_pulse <= 0;
        end else begin
            // 3-stage synchronization
            start_btn_ff1 <= start_btn;
            start_btn_ff2 <= start_btn_ff1;
            start_btn_ff3 <= start_btn_ff2;
            
            // Edge detection
            start_btn_pulse <= start_btn_ff2 & ~start_btn_ff3;
        end
    end
    
    // Pipelined vector selection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vector_index <= 0;
            vector_index_ff1 <= 0;
            vector_index_ff2 <= 0;
            data_valid <= 0;
        end else begin
            // Synchronize vector selection
            vector_index_ff1 <= vector_sel;
            vector_index_ff2 <= vector_index_ff1;
            vector_index <= vector_index_ff2;
            
            // Start classification on button press with pipeline delay
            if (start_btn_pulse && system_ready)
                data_valid <= 1;
            else
                data_valid <= 0;
        end
    end
    
    // Pipelined output registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seizure_led_reg <= 0;
            non_seizure_led_reg <= 0;
            processing_led_reg <= 0;
            ready_led_reg <= 0;
            vector_leds_reg <= 0;
        end else begin
            // Register all outputs for better timing
            seizure_led_reg <= result_valid & seizure_detected;
            non_seizure_led_reg <= result_valid & ~seizure_detected;
            processing_led_reg <= (system_status == 2'b01); // PROCESSING state
            ready_led_reg <= system_ready;
            vector_leds_reg <= vector_index[2:0];
        end
    end
    
    // Output assignments
    assign seizure_led = seizure_led_reg;
    assign non_seizure_led = non_seizure_led_reg;
    assign processing_led = processing_led_reg;
    assign ready_led = ready_led_reg;
    assign vector_leds = vector_leds_reg;
    
    // Instantiate seizure detection system
    // Using a simpler version of the classifier with fewer reference points
    seizure_detection_system #(
        .DATA_WIDTH(16),
        .FEATURE_COUNT(178),
        .DETECTION_THRESHOLD(16'h0080)  // 0.5 in Q8.8 format
    ) detector (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(data_valid),
        .eeg_data(eeg_data),
        .system_ready(system_ready),
        .result_valid(result_valid),
        .seizure_detected(seizure_detected),
        .detection_confidence(confidence),
        .system_status(system_status)
    );

endmodule