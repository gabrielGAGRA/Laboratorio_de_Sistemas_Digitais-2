`default_nettype none

/* ------------------------------------------------------------------
 * Arquivo   : deslocador_n.vhd
 * ------------------------------------------------------------------
 * Descricao : deslocador de n bits para transmissao serial
 *             > parametro N: numero de bits
 *
 * ------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     09/09/2021  1.0     Edson Midorikawa  versao inicial em VHDL
 *     27/08/2024  3.0     Edson Midorikawa  conversão para Verilog
 * ------------------------------------------------------------------
 */

module deslocador_n #(
    parameter N = 4
) (
    input  wire         clock,
    input  wire         reset,
    input  wire         carrega,
    input  wire         desloca,
    input  wire         entrada_serial,
    input  wire [N-1:0] dados,
    output wire [N-1:0] saida
);

    reg [N-1:0] dados_q;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            dados_q <= {N{1'b1}}; // Inicializa com todos os bits em '1' (repouso)
        end else begin
            if (carrega) begin
                dados_q <= dados;
            end else if (desloca) begin
                dados_q <= {entrada_serial, dados_q[N-1:1]}; // Deslocamento a direita
            end
        end
    end

    assign saida = dados_q;

endmodule

`default_nettype wire