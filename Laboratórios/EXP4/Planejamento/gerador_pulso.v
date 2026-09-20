/* --------------------------------------------------------------------------
 *  Arquivo   : gerador_pulso.v
 * --------------------------------------------------------------------------
 *  Descricao : componente parametrizado para geracao de pulso de largura
 *              especificada pelo parametro (em periodos do clock)
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */

`default_nettype none

module gerador_pulso #(
    parameter LARGURA = 25
) (
    input  wire clock,
    input  wire reset,
    input  wire gera,
    input  wire para,
    output reg  pulso,
    output reg  pronto
);

    // Tipos e sinais
    reg [1:0]  estado_q, estado_d;
    reg [31:0] cont_q, cont_d;

    // Parâmetros para os estados
    localparam [1:0] STATE_PARADO      = 2'b00;
    localparam [1:0] STATE_CONTAGEM    = 2'b01;
    localparam [1:0] STATE_FINAL_PULSO = 2'b10;

    // Lógica de estado e contagem
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_q <= STATE_PARADO;
            cont_q   <= 32'd0;
        end else begin
            estado_q <= estado_d;
            cont_q   <= cont_d;
        end
    end

    // Lógica de próximo estado e contagem
    always @(*) begin
        pulso    = 1'b0;
        pronto   = 1'b0;
        cont_d   = cont_q;

        case (estado_q)
            STATE_PARADO: begin
                if (gera) begin
                    estado_d = STATE_CONTAGEM;
                end else begin
                    estado_d = STATE_PARADO;
                end
                cont_d = 32'd0;
            end

            STATE_CONTAGEM: begin
                if (para) begin
                    estado_d = STATE_PARADO;
                end else begin
                    if (cont_q == LARGURA - 1) begin
                        estado_d = STATE_FINAL_PULSO;
                    end else begin
                        estado_d = STATE_CONTAGEM;
                        cont_d   = cont_q + 1'b1;
                    end
                end
                pulso = 1'b1;
            end

            STATE_FINAL_PULSO: begin
                estado_d = STATE_PARADO;
                pronto   = 1'b1;
            end

            default: begin
                estado_d = STATE_PARADO;
                pulso    = 1'b0;
                pronto   = 1'b0;
                cont_d   = 32'd0;
            end
        endcase
    end

endmodule

`default_nettype wire