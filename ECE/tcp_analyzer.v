// TCP Protocol Analyzer
module tcp_analyzer (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg packet_complete,
    output reg [15:0] source_port,
    output reg [15:0] dest_port,
    output reg [31:0] sequence_num,
    output reg [31:0] ack_num,
    output reg [15:0] window_size,
    output reg [15:0] checksum
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam PORTS = 3'b001;
    localparam SEQ_NUM = 3'b010;
    localparam ACK_NUM = 3'b011;
    localparam HEADER_LEN = 3'b100;
    localparam WINDOW = 3'b101;
    localparam CHECK = 3'b110;

    reg [2:0] current_state, next_state;
    reg [3:0] byte_counter;

    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            byte_counter <= 0;
            packet_complete <= 0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (data_valid) begin
                        source_port[15:8] <= data_in;
                        byte_counter <= 0;
                    end
                end
                
                PORTS: begin
                    if (data_valid) begin
                        case (byte_counter)
                            0: source_port[7:0] <= data_in;
                            1: dest_port[15:8] <= data_in;
                            2: dest_port[7:0] <= data_in;
                        endcase
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                SEQ_NUM: begin
                    if (data_valid) begin
                        sequence_num <= {sequence_num[23:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                ACK_NUM: begin
                    if (data_valid) begin
                        ack_num <= {ack_num[23:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                WINDOW: begin
                    if (data_valid) begin
                        window_size <= {window_size[7:0], data_in};
                        byte_counter <= byte_counter + 1;
                    end
                end
                
                CHECK: begin
                    if (data_valid) begin
                        checksum <= {checksum[7:0], data_in};
                        if (byte_counter == 1) packet_complete <= 1;
                        byte_counter <= byte_counter + 1;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: next_state = data_valid ? PORTS : IDLE;
            PORTS: next_state = (byte_counter == 3) ? SEQ_NUM : PORTS;
            SEQ_NUM: next_state = (byte_counter == 4) ? ACK_NUM : SEQ_NUM;
            ACK_NUM: next_state = (byte_counter == 4) ? WINDOW : ACK_NUM;
            WINDOW: next_state = (byte_counter == 2) ? CHECK : WINDOW;
            CHECK: next_state = packet_complete ? IDLE : CHECK;
            default: next_state = IDLE;
        endcase
    end

endmodule
