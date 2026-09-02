/*---------------Laboratorio Digital-------------------------------------
 * Arquivo   : contador_m.v
 * Projeto   : AEX
 *-----------------------------------------------------------------------
 * Descricao : contador parametrizavel, modulo m, com parametros 
 *             M (modulo do contador) e N (numero de bits),
 *             sinais para clear assincrono (zera_as) e sincrono (zera_s)
 *             e saidas de fim e meio de contagem
 *             
 *-----------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     30/01/2024  1.0     Edson Midorikawa  criacao
 *     16/01/2025  1.1     Edson Midorikawa  revisao
 *     23/03/2026  2.0     Gabriel Agra      modificacao pra uso na AEX
 *-----------------------------------------------------------------------
 */
module contador_m #(
    parameter M=2048, 
    parameter N=11
)
(
    input  wire clock,
    input  wire zera_as,
    input  wire zera_s,
    input  wire conta,
    output reg  [N-1:0] Q,
    output wire fim,
    output wire meio
);

    always @(posedge clock or posedge zera_as) begin
        if (zera_as) begin
            Q <= 0;
        end else if (zera_s) begin
            Q <= 0;
        end else if (conta) begin
            if (Q == M-1) begin
                Q <= 0;
            end else begin
                Q <= Q + 1;
            end
        end
    end

    assign fim = (Q == M-1) ? 1'b1 : 1'b0;
    assign meio = (Q == M/2-1) ? 1'b1 : 1'b0;

endmodule