`default_nettype none

/* 
 *  Descricao : Contador BCD de 3 digitos (000 a 999).
 */

module contador_bcd_3digitos (
    input  wire       clock,
    input  wire       zera,
    input  wire       conta,
    output wire [3:0] digito0,
    output wire [3:0] digito1,
    output wire [3:0] digito2,
    output wire       fim
);

    reg [3:0] s_dig2_q, s_dig1_q, s_dig0_q;

    always @(posedge clock) begin
        if (zera) begin 
            s_dig0_q <= 4'b0000;
            s_dig1_q <= 4'b0000;
            s_dig2_q <= 4'b0000;
        end else if (conta) begin
            if (s_dig0_q == 4'b1001) begin
                s_dig0_q <= 4'b0000;
                if (s_dig1_q == 4'b1001) begin
                    s_dig1_q <= 4'b0000;
                    if (s_dig2_q == 4'b1001) begin
                        s_dig2_q <= 4'b0000;
                    end else begin
                        s_dig2_q <= s_dig2_q + 1'b1; 
                    end
                end else begin
                    s_dig1_q <= s_dig1_q + 1'b1; 
                end
            end else begin
                s_dig0_q <= s_dig0_q + 1'b1; 
            end
        end
    end

    assign fim     = (s_dig2_q == 4'b1001 && s_dig1_q == 4'b1001 && s_dig0_q == 4'b1001);
    assign digito2 = s_dig2_q;
    assign digito1 = s_dig1_q;
    assign digito0 = s_dig0_q;

endmodule

`default_nettype wire
