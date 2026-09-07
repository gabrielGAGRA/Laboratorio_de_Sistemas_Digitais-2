// ---------------------------------------------------------------------------
// Modulo: display_sustenido
// Descricao: Implementa a lógica do sustenido para mostrar "H" (representando #)
// ---------------------------------------------------------------------------
module display_sustenido (
    input            sustenido,
    output reg [6:0] display
);

    always @(*) begin
        case (sustenido)
            1'b1: display = 7'b0001001; // H (Tentativa de # em 7-seg)
            default: display = 7'b1111111; // Desligado se nao houver sustenido
        endcase
    end

endmodule
