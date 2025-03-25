module simplified_demo_system (
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
    
    // Test vector selection
    logic [3:0] vector_index;
    logic start_btn_prev;
    logic start_btn_pulse;
    
    // Instantiate test vector ROM (generated from test_vectors.sv)
    test_vectors test_data (
        .vector_idx(vector_index),
        .test_data(eeg_data),
        .expected_label() // Not used in demo
    );
    
    // Instantiate seizure detection system
    seizure_detection_system #(
        .DATA_WIDTH(16),
        .FEATURE_COUNT(178)
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
    
    // Button debouncing and pulse generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_btn_prev <= 0;
            start_btn_pulse <= 0;
        end else begin
            start_btn_prev <= start_btn;
            start_btn_pulse <= start_btn & ~start_btn_prev;
        end
    end
    
    // Test vector selection and start control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vector_index <= 0;
            data_valid <= 0;
        end else begin
            // Select test vector based on switches
            vector_index <= vector_sel;
            
            // Start classification on button press
            if (start_btn_pulse && system_ready)
                data_valid <= 1;
            else
                data_valid <= 0;
        end
    end
    
    // LED outputs
    assign seizure_led = result_valid & seizure_detected;
    assign non_seizure_led = result_valid & ~seizure_detected;
    assign processing_led = (system_status == 2'b01); // PROCESSING state
    assign ready_led = system_ready;
    
    // Display selected test vector number on LEDs (binary)
    assign vector_leds = vector_index[2:0];
    
endmodule