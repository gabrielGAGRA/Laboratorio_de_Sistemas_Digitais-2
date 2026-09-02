// ---------------------------------------------------------------------------
// Modulo: led_oitava
// Descricao: Indica se a oitava deve ser alterada (para cima ou para baixo).
// ---------------------------------------------------------------------------
module led_oitava (
    input      [2:0] oitava_certa,
    input      [2:0] oitava_atual,
    output reg       led_up,
    output reg       led_down
);

    always @(*) begin
        led_up = 1'b0;
        led_down = 1'b0;
        
        if (oitava_certa > oitava_atual) begin
            led_up = 1'b1;
        end
        else if (oitava_certa < oitava_atual) begin
            led_down = 1'b1;
        end
    end

endmodule
