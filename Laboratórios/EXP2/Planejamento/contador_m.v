`default_nettype none

/*---------------Laboratorio Digital-------------------------------------
 * Arquivo   : contador_m.v
 *-----------------------------------------------------------------------
 * Descricao : contador binario, modulo m, com parametros 
 *             M (modulo do contador) e N (numero de bits),
 *             sinais para clear assincrono (zera_as) e sincrono (zera_s)
 *             e saidas de fim e meio de contagem
 *             
 *-----------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     30/01/2024  1.0     Edson Midorikawa  criacao
 *-----------------------------------------------------------------------
 */

module contador_m #(
    parameter M = 100,
    parameter N = 7
) (
    input  wire         clock,
    input  wire         zera_as,
    input  wire         zera_s,
    input  wire         conta,
    output reg  [N-1:0] Q,
    output wire         fim,
    output wire         meio
);

    always @(posedge clock or posedge zera_as) begin
        if (zera_as) begin
            Q <= {N{1'b0}};
        end else begin
            if (zera_s) begin
                Q <= {N{1'b0}};
            end else if (conta) begin
                if (Q == M - 1) begin
                    Q <= {N{1'b0}};
                end else begin
                    Q <= Q + 1'b1;
                end
            end
        end
    end

    // Saidas
    assign fim  = (Q == M - 1) ? 1'b1 : 1'b0;
    assign meio = (Q == (M/2) - 1) ? 1'b1 : 1'b0;

endmodule

`default_nettype wire
