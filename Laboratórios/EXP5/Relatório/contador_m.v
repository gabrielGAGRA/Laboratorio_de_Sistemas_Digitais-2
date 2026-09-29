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

`default_nettype none

module contador_m #(parameter M=100, N=7)
  (
    input  wire          clock,
    input  wire          zera_as,
    input  wire          zera_s,
    input  wire          conta,
    output reg  [N-1:0]  Q,
    output reg           fim,
    output reg           meio
  );

  localparam [N-1:0] FIM_VAL  = M[N-1:0] - {{(N-1){1'b0}}, 1'b1};
  localparam [N-1:0] MEIO_VAL = (M[N-1:0] >> 1) - {{(N-1){1'b0}}, 1'b1};

  always @(posedge clock or posedge zera_as) begin
    if (zera_as) begin
      Q <= {N{1'b0}};
    end else begin
      if (zera_s) begin
        Q <= {N{1'b0}};
      end else if (conta) begin
        if (Q == FIM_VAL) begin
          Q <= {N{1'b0}};
        end else begin
          Q <= Q + 1'b1;
        end
      end
    end
  end

  // Saidas
  always @* begin
    if (Q == FIM_VAL)
      fim = 1'b1;
    else
      fim = 1'b0;
  end

  always @* begin
    if (Q == MEIO_VAL)
      meio = 1'b1;
    else
      meio = 1'b0;
  end

endmodule

`default_nettype wire
