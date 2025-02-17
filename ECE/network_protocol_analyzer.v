module network_protocol_analyzer (
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire data_valid,
    input wire [1:0] protocol_select, // 00: IP, 01: TCP, 10: ICMP
    output wire ip_complete,
    output wire tcp_complete,
    output wire icmp_complete
);

    // Instantiate all protocol analyzers
    ip_analyzer ip_anal (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_valid(data_valid && protocol_select == 2'b00),
        .packet_complete(ip_complete)
        // ... other ports connected as needed
    );

    tcp_analyzer tcp_anal (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_valid(data_valid && protocol_select == 2'b01),
        .packet_complete(tcp_complete)
        // ... other ports connected as needed
    );

    icmp_analyzer icmp_anal (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_valid(data_valid && protocol_select == 2'b10),
        .packet_complete(icmp_complete)
        // ... other ports connected as needed
    );

endmodule
