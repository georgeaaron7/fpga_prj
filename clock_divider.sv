module converter( 
    input  logic bigClk,
    input  logic reset,        // Added reset input
    output logic smallClk 
); 
    logic [15:0] count; 
    
    // SystemVerilog style reset handling
    always_ff @(posedge bigClk or negedge reset) begin 
        if (!reset) begin      // Active low reset
            smallClk <= 1'b0;
            count <= 16'd0;
        end else begin
            if (count < 16'd8000) begin 
                count <= count + 16'd1; 
            end else begin  
                smallClk <= ~smallClk; 
                count <= 16'd0; 
            end
        end
    end 
endmodule