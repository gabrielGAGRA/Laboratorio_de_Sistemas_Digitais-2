`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : controle_servo_8.v
 * --------------------------------------------------------------------------
 *  Descricao : Circuito de controle para servomotor com 8 posicoes angulares
 *              (20° a 160° em passos de 20°) via modulacao PWM.
 * --------------------------------------------------------------------------
 */

module controle_servo_8 #(
    parameter CONF_PERIODO = 1000000, // Periodo PWM (20ms a 50MHz)
    parameter LARGURA_000  = 35000,   // 0,700 ms (20°)
    parameter LARGURA_001  = 45700,   // 0,914 ms (40°)
    parameter LARGURA_010  = 56450,   // 1,129 ms (60°)
    parameter LARGURA_011  = 67150,   // 1,343 ms (80°)
    parameter LARGURA_100  = 77850,   // 1,557 ms (100°)
    parameter LARGURA_101  = 88550,   // 1,771 ms (120°)
    parameter LARGURA_110  = 99300,   // 1,986 ms (140°)
    parameter LARGURA_111  = 110000   // 2,200 ms (160°)
) (
    input  wire       clock,
    input  wire       reset,
    input  wire [2:0] posicao,
    output wire       controle,
    output wire       db_reset,
    output wire [2:0] db_posicao,
    output wire       db_controle
);

    reg [31:0] contagem_q = 32'd0;
    reg [31:0] largura_pwm_q;
    reg        s_controle_q;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            largura_pwm_q <= LARGURA_000;
        end else if (contagem_q == CONF_PERIODO - 32'd1) begin
            case (posicao)
                3'b000:  largura_pwm_q <= LARGURA_000;
                3'b001:  largura_pwm_q <= LARGURA_001;
                3'b010:  largura_pwm_q <= LARGURA_010;
                3'b011:  largura_pwm_q <= LARGURA_011;
                3'b100:  largura_pwm_q <= LARGURA_100;
                3'b101:  largura_pwm_q <= LARGURA_101;
                3'b110:  largura_pwm_q <= LARGURA_110;
                3'b111:  largura_pwm_q <= LARGURA_111;
                default: largura_pwm_q <= LARGURA_000;
            endcase
        end
    end

    // Base de tempo periodica continua de 20 ms (50 Hz) para o servomotor
    // Nao silencia os pulsos no reset, prevenindo que o servomotor perca o sinal e dispare
    always @(posedge clock) begin
        if (contagem_q == CONF_PERIODO - 32'd1) begin
            contagem_q <= 32'd0;
        end else begin
            contagem_q <= contagem_q + 32'd1;
        end
        s_controle_q <= (contagem_q < largura_pwm_q);
    end

    assign controle    = s_controle_q;
    assign db_reset    = reset;
    assign db_posicao  = posicao;
    assign db_controle = s_controle_q;

endmodule

`default_nettype wire
