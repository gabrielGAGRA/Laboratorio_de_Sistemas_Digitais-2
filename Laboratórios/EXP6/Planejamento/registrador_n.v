`default_nettype none

module registrador_n #(
    parameter N = 8
) (
    input  wire         clock,
    input  wire         clear,
    input  wire         enable,
    input  wire [N-1:0] D,
    output wire [N-1:0] Q
);

    reg [N-1:0] IQ;

    always @(posedge clock or posedge clear) begin
        if (clear)
            IQ <= {N{1'b0}};
        else if (enable)
            IQ <= D;
    end

    assign Q = IQ;

endmodule

`default_nettype wire
