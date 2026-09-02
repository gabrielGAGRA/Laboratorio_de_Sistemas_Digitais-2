// ---------------------------------------------------------------------------
// Modulo: sync_ram
// Descricao: Memoria RAM sincrona para gravar musica
// ---------------------------------------------------------------------------
module sync_ram #(
    parameter DATA_WIDTH = 7,
    parameter ADDR_WIDTH = 10
)(
    input  wire clock,
    input  wire we,
    input  wire [ADDR_WIDTH-1:0] address,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg  [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];

    always @(posedge clock) begin
        if (we)
            ram[address] <= data_in;
        data_out <= ram[address];
    end
endmodule
