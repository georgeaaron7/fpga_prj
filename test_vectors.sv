// Auto-generated test vectors for k-NN classifier
// Contains 10 test samples with 178 features each
// Using Q8.8 fixed-point format (16-bit)

module test_vectors #(
    parameter DATA_WIDTH = 16,
    parameter FEATURE_COUNT = 178,
    parameter NUM_VECTORS = 10
) (
    input  logic [$clog2(NUM_VECTORS)-1:0] vector_idx,
    output logic [DATA_WIDTH-1:0] test_data [FEATURE_COUNT-1:0],
    output logic expected_label
);

    // Test vectors storage
    logic [DATA_WIDTH-1:0] vectors [NUM_VECTORS-1:0][FEATURE_COUNT-1:0];
    logic vector_labels [NUM_VECTORS-1:0];
    
    // Initialize with test data
    initial begin
        // Test vector 0 (Seizure)
        vector_labels[0] = 1;
        vectors[0][0] = 16'h0026; vectors[0][1] = 16'h004B; vectors[0][2] = 16'h0058;
        vectors[0][3] = 16'h0043; vectors[0][4] = 16'h0034; vectors[0][5] = 16'h0046;
        // ... Simplified for brevity - in a real file, all 178 features would be defined
        // Fill remaining features with pattern
        for (int j = 6; j < FEATURE_COUNT; j++) begin
            vectors[0][j] = 16'h0040 + ((j*7) & 16'h00FF);
        end
        
        // Test vector 1 (Non-Seizure)
        vector_labels[1] = 0;
        vectors[1][0] = 16'hFF9E; vectors[1][1] = 16'hFF92; vectors[1][2] = 16'hFF88;
        vectors[1][3] = 16'hFF7F; vectors[1][4] = 16'hFF75; vectors[1][5] = 16'hFF6D;
        // Fill remaining features with pattern
        for (int j = 6; j < FEATURE_COUNT; j++) begin
            vectors[1][j] = 16'hFF80 + ((j*5) & 16'h00FF);
        end
        
        // Test vector 2 (Seizure)
        vector_labels[2] = 1;
        vectors[2][0] = 16'h00D1; vectors[2][1] = 16'h00D8; vectors[2][2] = 16'h00DF;
        vectors[2][3] = 16'h00E6; vectors[2][4] = 16'h00EC; vectors[2][5] = 16'h00F3;
        // Fill remaining features with pattern
        for (int j = 6; j < FEATURE_COUNT; j++) begin
            vectors[2][j] = 16'h00C0 + ((j*3) & 16'h00FF);
        end
        
        // Test vector 3 (Non-Seizure)
        vector_labels[3] = 0;
        vectors[3][0] = 16'hFFA6; vectors[3][1] = 16'hFFA9; vectors[3][2] = 16'hFFAC;
        vectors[3][3] = 16'hFFAF; vectors[3][4] = 16'hFFB2; vectors[3][5] = 16'hFFB5;
        // Fill remaining features with pattern
        for (int j = 6; j < FEATURE_COUNT; j++) begin
            vectors[3][j] = 16'hFFA0 + ((j*2) & 16'h00FF);
        end
        
        // Test vectors 4-9 with patterns
        for (int i = 4; i < NUM_VECTORS; i++) begin
            // Alternate between seizure and non-seizure
            vector_labels[i] = (i % 2 == 0) ? 1 : 0;
            
            for (int j = 0; j < FEATURE_COUNT; j++) begin
                if (vector_labels[i] == 1) begin
                    // Seizure pattern
                    vectors[i][j] = 16'h0080 + ((i*j) & 16'h007F);
                end else begin
                    // Non-seizure pattern
                    vectors[i][j] = 16'hFF80 + ((i*j) & 16'h007F);
                end
            end
        end
    end
    
    // Output selection logic
    always_comb begin
        for (int j = 0; j < FEATURE_COUNT; j++) begin
            test_data[j] = vectors[vector_idx][j];
        end
        expected_label = vector_labels[vector_idx];
    end
    
endmodule