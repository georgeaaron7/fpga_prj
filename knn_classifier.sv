//----------------------------------------------------------------------
// knn_classifier.sv
// k-Nearest Neighbors classifier for epileptic seizure detection
//----------------------------------------------------------------------

module knn_classifier #(
    parameter DATA_WIDTH = 16,         // Q8.8 fixed-point format
    parameter FEATURE_COUNT = 178,     // Number of EEG data points
    parameter K_VALUE = 5,             // Number of neighbors to consider
    parameter REF_POINT_COUNT = 100,   // Number of reference points stored
    parameter DISTANCE_WIDTH = 32      // Width for distance calculation
) (
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            start,
    input  logic [DATA_WIDTH-1:0]           eeg_data [FEATURE_COUNT-1:0],
    output logic                            valid_out,
    output logic                            seizure_detected,
    output logic [DATA_WIDTH-1:0]           confidence
);

    // Fixed point arithmetic parameters
    localparam INT_BITS = 8;
    localparam FRAC_BITS = 8;
    
    // State definition
    typedef enum logic [3:0] {
        IDLE,
        LOAD_DATA,
        CALC_DIST_START,
        CALC_DIST_ACCUM,
        CALC_DIST_FINALIZE,
        SORT_INIT,
        SORT_COMPARE,
        SORT_SWAP,
        SORT_CHECK,
        FIND_K_NEAREST,
        MAJORITY_VOTE,
        OUTPUT_RESULT
    } state_t;
    
    state_t current_state, next_state;

    // Internal signals
    logic [DATA_WIDTH-1:0] ref_points [REF_POINT_COUNT-1:0][FEATURE_COUNT-1:0];
    logic ref_labels [REF_POINT_COUNT-1:0]; // Binary labels (0=non-seizure, 1=seizure)
    logic [DISTANCE_WIDTH-1:0] distances [REF_POINT_COUNT-1:0];
    logic [$clog2(REF_POINT_COUNT)-1:0] sorted_indices [REF_POINT_COUNT-1:0];
    logic ref_sorted_labels [K_VALUE-1:0];
    
    // Counters and control signals
    logic [$clog2(REF_POINT_COUNT)-1:0] point_idx;
    logic [$clog2(FEATURE_COUNT)-1:0] feature_idx;
    logic [$clog2(REF_POINT_COUNT)-1:0] sort_idx;
    logic [$clog2(REF_POINT_COUNT)-1:0] compare_idx;
    logic sort_done;
    
    // Temporary variables for calculation
    logic [DATA_WIDTH-1:0] abs_diff;
    logic [DISTANCE_WIDTH-1:0] current_dist;
    
    // Class counters for majority voting
    logic [7:0] seizure_count;
    logic [7:0] non_seizure_count;
    
    // Initialize reference data
    // In a real implementation, this would be loaded from memory
    initial begin
        // Initialize with test data - typically this would be loaded from memory
        for (int i = 0; i < REF_POINT_COUNT; i++) begin
            // Set half the reference points as seizure, half as non-seizure
            ref_labels[i] = (i < REF_POINT_COUNT/2) ? 1'b1 : 1'b0;
            
            for (int j = 0; j < FEATURE_COUNT; j++) begin
                // Initialize with different patterns for seizure and non-seizure
                if (ref_labels[i])
                    ref_points[i][j] = 16'h0100 + ((i * j) & 16'h00FF); // Seizure pattern
                else 
                    ref_points[i][j] = 16'h0200 + ((i * j) & 16'h00FF); // Non-seizure pattern
            end
        end
    end

    // State machine
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
                if (start)
                    next_state = LOAD_DATA;
                    
            LOAD_DATA:
                next_state = CALC_DIST_START;
                
            CALC_DIST_START:
                next_state = CALC_DIST_ACCUM;
                
            CALC_DIST_ACCUM:
                if (feature_idx == FEATURE_COUNT-1)
                    next_state = CALC_DIST_FINALIZE;
                    
            CALC_DIST_FINALIZE:
                if (point_idx == REF_POINT_COUNT-1)
                    next_state = SORT_INIT;
                else
                    next_state = CALC_DIST_START;
                    
            SORT_INIT:
                next_state = SORT_COMPARE;
                
            SORT_COMPARE:
                next_state = SORT_SWAP;
                
            SORT_SWAP:
                if (compare_idx == REF_POINT_COUNT-sort_idx-2)
                    next_state = SORT_CHECK;
                else
                    next_state = SORT_COMPARE;
                    
            SORT_CHECK:
                if (sort_idx == REF_POINT_COUNT-2)
                    next_state = FIND_K_NEAREST;
                else
                    next_state = SORT_COMPARE;
                    
            FIND_K_NEAREST:
                next_state = MAJORITY_VOTE;
                
            MAJORITY_VOTE:
                next_state = OUTPUT_RESULT;
                
            OUTPUT_RESULT:
                next_state = IDLE;
                
            default:
                next_state = IDLE;
        endcase
    end
    
    // Main processing logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            seizure_detected <= 0;
            confidence <= 0;
            point_idx <= 0;
            feature_idx <= 0;
            sort_idx <= 0;
            compare_idx <= 0;
            sort_done <= 0;
            current_dist <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    valid_out <= 0;
                    point_idx <= 0;
                    feature_idx <= 0;
                    sort_idx <= 0;
                    compare_idx <= 0;
                    sort_done <= 0;
                end
                
                LOAD_DATA: begin
                    // Initialize counters and structures for a new calculation
                    for (int i = 0; i < REF_POINT_COUNT; i++) begin
                        distances[i] <= 0;
                        sorted_indices[i] <= i;
                    end
                end
                
                CALC_DIST_START: begin
                    // Start new distance calculation
                    feature_idx <= 0;
                    current_dist <= 0;
                end
                
                CALC_DIST_ACCUM: begin
                    // Calculate Manhattan distance component for one feature
                    if (eeg_data[feature_idx] >= ref_points[point_idx][feature_idx])
                        abs_diff = eeg_data[feature_idx] - ref_points[point_idx][feature_idx];
                    else
                        abs_diff = ref_points[point_idx][feature_idx] - eeg_data[feature_idx];
                    
                    // Accumulate distance
                    current_dist <= current_dist + abs_diff;
                    feature_idx <= feature_idx + 1;
                end
                
                CALC_DIST_FINALIZE: begin
                    // Store the final distance for this reference point
                    distances[point_idx] <= current_dist;
                    point_idx <= point_idx + 1;
                end
                
                SORT_INIT: begin
                    // Initialize bubble sort
                    sort_idx <= 0;
                    compare_idx <= 0;
                end
                
                SORT_COMPARE: begin
                    // Compare distances for bubble sort
                    compare_idx <= compare_idx + 1;
                end
                
                SORT_SWAP: begin
                    // Swap if needed
                    if (distances[sorted_indices[compare_idx]] > distances[sorted_indices[compare_idx+1]]) begin
                        logic [$clog2(REF_POINT_COUNT)-1:0] temp;
                        temp = sorted_indices[compare_idx];
                        sorted_indices[compare_idx] = sorted_indices[compare_idx+1];
                        sorted_indices[compare_idx+1] = temp;
                    end
                    
                    if (compare_idx < REF_POINT_COUNT-sort_idx-2)
                        compare_idx <= compare_idx + 1;
                end
                
                SORT_CHECK: begin
                    if (sort_idx < REF_POINT_COUNT-2) begin
                        sort_idx <= sort_idx + 1;
                        compare_idx <= 0;
                    end else begin
                        sort_done <= 1;
                    end
                end
                
                FIND_K_NEAREST: begin
                    // Extract labels of K nearest neighbors
                    for (int i = 0; i < K_VALUE; i++) begin
                        ref_sorted_labels[i] <= ref_labels[sorted_indices[i]];
                    end
                end
                
                MAJORITY_VOTE: begin
                    // Count votes for seizure vs non-seizure
                    seizure_count <= 0;
                    non_seizure_count <= 0;
                    
                    for (int i = 0; i < K_VALUE; i++) begin
                        if (ref_sorted_labels[i])
                            seizure_count <= seizure_count + 1;
                        else
                            non_seizure_count <= non_seizure_count + 1;
                    end
                end
                
                OUTPUT_RESULT: begin
                    // Set output based on majority vote
                    valid_out <= 1;
                    seizure_detected <= (seizure_count > non_seizure_count);
                    
                    // Calculate confidence as proportion of winning votes
                    // scaled to Q8.8 format where 256 (0x0100) represents 1.0
                    if (seizure_count > non_seizure_count)
                        confidence <= (seizure_count * 16'h0100) / K_VALUE;
                    else
                        confidence <= (non_seizure_count * 16'h0100) / K_VALUE;
                end
            endcase
        end
    end

endmodule