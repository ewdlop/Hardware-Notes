module icmp_analyzer (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg packet_complete,
    output reg [7:0] type_code,
    output reg [15:0] checksum,
    output reg [31:0] payload_data
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam TYPE = 2'b01;
    localparam CHECKSUM = 2'b10;
    localparam PAYLOAD = 2'b11;

    reg [1:0] current_state, next_state;
    reg [3:0] byte_counter;
    reg [15:0] checksum_calc;

    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            byte_counter <= 0;
            packet_complete <= 0;
            checksum_calc <= 0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (data_valid) begin
                        type_code <= data_in;
                        byte_counter <= 0;
                    end
                end
                
                TYPE: begin
                    if (data_valid) begin
                        checksum[byte_counter ? 7:0 : 15:8] <= data_in;
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                CHECKSUM: begin
                    if (data_valid) begin
                        payload_data <= {payload_data[23:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                PAYLOAD: begin
                    if (byte_counter == 4) begin
                        packet_complete <= 1;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: next_state = data_valid ? TYPE : IDLE;
            TYPE: next_state = (byte_counter == 2) ? CHECKSUM : TYPE;
            CHECKSUM: next_state = (byte_counter == 4) ? PAYLOAD : CHECKSUM;
            PAYLOAD: next_state = packet_complete ? IDLE : PAYLOAD;
            default: next_state = IDLE;
        endcase
    end

endmodule
