/* --------------------------------------------------------------------------
 *  Arquivo   : contador_bcd_3digitos.v
 * --------------------------------------------------------------------------
 *  Descricao : componente Verilog de um contador BCD de 3 digitos (contagem
 *              de 000 a 999) com descricao comportamental
 *
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */

`default_nettype none

module contador_bcd_3digitos (
    input  wire       clock,
    input  wire       zera,
    input  wire       conta,
    output wire [3:0] digito0,
    output wire [3:0] digito1,
    output wire [3:0] digito2,
    output wire       fim
);

    reg [3:0] s_dig2, s_dig1, s_dig0;

    always @(posedge clock) begin
        if (zera) begin 
            s_dig0 <= 4'b0000;
            s_dig1 <= 4'b0000;
            s_dig2 <= 4'b0000;
        end else if (conta) begin
            if (s_dig0 == 4'b1001) begin
                s_dig0 <= 4'b0000;
                if (s_dig1 == 4'b1001) begin
                    s_dig1 <= 4'b0000;
                    if (s_dig2 == 4'b1001) begin
                        s_dig2 <= 4'b0000;
                    end else begin
                        s_dig2 <= s_dig2 + 1'b1; 
                    end
                end else begin
                    s_dig1 <= s_dig1 + 1'b1; 
                end
            end else begin
                s_dig0 <= s_dig0 + 1'b1; 
            end
        end
    end

    // fim de contagem
    assign fim = (s_dig2 == 4'b1001 && s_dig1 == 4'b1001 && s_dig0 == 4'b1001) ? 1'b1 : 1'b0; 

    // saídas
    assign digito2 = s_dig2;
    assign digito1 = s_dig1;
    assign digito0 = s_dig0;

endmodule

`default_nettype wire
