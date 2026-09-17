`default_nettype none

/*
 *  Arquivo   : mux_4x1_n.v
 * ----------------------------------------------------------------
 *  Descricao : multiplexador 4x1  
 *  > parametro BITS: numero de bits das entradas
 * 
 *  > adaptado a partir do codigo my_4t1_mux.vhd 
 *  > do livro "Free Range VHDL" 
 * 
 * ----------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      16/09/2024  3.0     Edson Midorikawa  versao em Verilog
 * ----------------------------------------------------------------
 */

module mux_4x1_n #(
    parameter BITS = 4
) (
    input  wire [BITS-1:0] D3,
    input  wire [BITS-1:0] D2,
    input  wire [BITS-1:0] D1,
    input  wire [BITS-1:0] D0,
    input  wire [1:0]      SEL,
    output wire [BITS-1:0] MUX_OUT
);

    assign MUX_OUT = (SEL == 2'b11) ? D3 :
                     (SEL == 2'b10) ? D2 :
                     (SEL == 2'b01) ? D1 :
                     (SEL == 2'b00) ? D0 :
                     {BITS{1'b1}}; // default 

endmodule

`default_nettype wire
