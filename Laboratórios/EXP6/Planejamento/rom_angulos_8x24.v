`default_nettype none

/* 
 *  Descricao : Memoria ROM combinacional mapeando 8 posicoes angulares (0..7)
 *              para os correspondentes caracteres ASCII de angulo ("020" a "160").
 */

module rom_angulos_8x24 (
    input  wire [2:0]  endereco,
    output reg  [23:0] saida
);

    always @* begin
        case (endereco)
            3'd0: saida = 24'h303230; // 0 = "020"
            3'd1: saida = 24'h303430; // 1 = "040"
            3'd2: saida = 24'h303630; // 2 = "060"
            3'd3: saida = 24'h303830; // 3 = "080"
            3'd4: saida = 24'h313030; // 4 = "100"
            3'd5: saida = 24'h313230; // 5 = "120"
            3'd6: saida = 24'h313430; // 6 = "140"
            3'd7: saida = 24'h313630; // 7 = "160"
            default: saida = 24'h303230;
        endcase
    end

endmodule

`default_nettype wire
