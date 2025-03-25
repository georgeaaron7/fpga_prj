//----------------------------------------------------------------------
// seizure_detection_system.sv
// Top-level module for epileptic seizure detection system
//----------------------------------------------------------------------

module seizure_detection_system #(
    parameter DATA_WIDTH = 16,          // Q8.8 fixed-point format
    parameter FEATURE_COUNT = 178,      // Number of EEG data points
    parameter DETECTION_THRESHOLD = 16'h0080  // 0.5 in Q8.8 format
) (
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            data_valid,
    input  logic [DATA_WIDTH-1:0]           eeg_data [FEATURE_COUNT-1:0],
    output logic                            system_ready,
    output logic                            result_valid,
    output logic                            seizure_detected,
    output logic [DATA_WIDTH-1:0]           detection_confidence,
    output logic [1:0]                      system_status
);

    // System status codes
    localparam STATUS_IDLE = 2'b00;
    localparam STATUS_PROCESSING = 2'b01;
    localparam STATUS_RESULT_READY = 2'b10;
    localparam STATUS_ERROR = 2'b11;
    
    // Internal signals
    logic classifier_start;
    logic classifier_valid;
    logic classifier_result;
    logic [DATA_WIDTH-1:0] classifier_confidence;
    
    // State machine definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        RESULT,
        ERROR
    } state_t;
    
    state_t current_state, next_state;
    
    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end
    
    // Next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: 
                if (data_valid)
                    next_state = PROCESSING;
            
            PROCESSING:
                if (classifier_valid)
                    next_state = RESULT;
            
            RESULT:
                next_state = IDLE;
            
            ERROR:
                if (rst_n)
                    next_state = IDLE;
            
            default:
                next_state = IDLE;
        endcase
    end
    
    // Control signals
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            classifier_start <= 0;
            system_ready <= 1;
            result_valid <= 0;
            system_status <= STATUS_IDLE;
            seizure_detected <= 0;
            detection_confidence <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    system_ready <= 1;
                    result_valid <= 0;
                    system_status <= STATUS_IDLE;
                    
                    if (data_valid)
                        classifier_start <= 1;
                    else
                        classifier_start <= 0;
                end
                
                PROCESSING: begin
                    classifier_start <= 0;
                    system_ready <= 0;
                    result_valid <= 0;
                    system_status <= STATUS_PROCESSING;
                end
                
                RESULT: begin
                    system_ready <= 1;
                    result_valid <= 1;
                    seizure_detected <= classifier_result;
                    detection_confidence <= classifier_confidence;
                    system_status <= STATUS_RESULT_READY;
                end
                
                ERROR: begin
                    system_ready <= 0;
                    result_valid <= 0;
                    system_status <= STATUS_ERROR;
                end
            endcase
        end
    end
    
    // Instantiate the k-NN classifier
    knn_classifier #(
        .DATA_WIDTH(DATA_WIDTH),
        .FEATURE_COUNT(FEATURE_COUNT),
        .K_VALUE(5),              // Using 5 nearest neighbors
        .REF_POINT_COUNT(100)     // Using 100 reference points
    ) classifier_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(classifier_start),
        .eeg_data(eeg_data),
        .valid_out(classifier_valid),
        .seizure_detected(classifier_result),
        .confidence(classifier_confidence)
    );

endmodule