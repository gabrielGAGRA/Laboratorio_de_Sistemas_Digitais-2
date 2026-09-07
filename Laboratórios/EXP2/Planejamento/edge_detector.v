`default_nettype none

/* ------------------------------------------------------------------------
 *  Arquivo   : edge_detector.v
 * ------------------------------------------------------------------------
 *  Descricao : detector de borda
 *              gera um pulso na saida de 1 periodo de clock
 *              a partir da detecao da borda de subida sa entrada
 * 
 *              sinal de reset ativo em alto
 * 
 *              > codigo adaptado a partir de codigo VHDL disponivel em
 *                https://surf-vhdl.com/how-to-design-a-good-edge-detector/
 * ------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      26/01/2024  1.0     Edson Midorikawa  versao em Verilog
 * ------------------------------------------------------------------------
 */

module edge_detector (
    input  wire clock,
    input  wire reset,
    input  wire sinal,
    output wire pulso
);

    reg sinal_q;
    reg sinal_dly_q;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            sinal_q     <= 1'b0;
            sinal_dly_q <= 1'b0;
        end else begin
            sinal_q     <= sinal;
            sinal_dly_q <= sinal_q;
        end
    end

    assign pulso = ~sinal_dly_q & sinal_q;

endmodule

`default_nettype wire
