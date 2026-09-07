// ---------------------------------------------------------------------------
// Modulo: gerador_pwm
// Descricao: Gera um sinal PWM com base na configuracao de duty cycle (0 a 15).
// Frequencia do PWM baseada num clock de 50MHz: 50M / 65536 = ~762Hz
// ---------------------------------------------------------------------------
module gerador_pwm (
    input clock,
    input reset,
    input [3:0] duty_cycle,
    output pwm_out
);

    reg [15:0] counter;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            counter <= 16'd0;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    assign pwm_out = (duty_cycle == 4'h0) ? 1'b0 :
                     (duty_cycle == 4'hF) ? 1'b1 :
                     (counter < {duty_cycle, 12'd0});

endmodule
