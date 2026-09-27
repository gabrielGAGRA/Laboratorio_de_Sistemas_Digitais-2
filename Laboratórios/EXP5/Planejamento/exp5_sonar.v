`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : exp5_sonar.v
 * --------------------------------------------------------------------------
 *  Descricao : Top-level para a placa FPGA Cyclone V DE0-CV.
 *              Instancia o nucleo do Sistema de Sonar (sonar.v) e mapeia os
 *              sinais aos pinos da placa (chaves SW, displays HEX0-HEX5,
 *              LEDs LEDR e conectores GPIO para HC-SR04, servo e USB-serial).
 * --------------------------------------------------------------------------
 */

module exp5_sonar (
    input  wire       clock,
    input  wire       reset,
    input  wire       ligar,
    input  wire       echo,
    output wire       trigger,
    output wire       pwm,
    output wire       saida_serial,
    output wire       fim_posicao,
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire [6:0] hex3,
    output wire [6:0] hex4,
    output wire [6:0] hex5,
    output wire [9:0] ledr
);

    wire [2:0]  s_posicao;
    wire [11:0] s_medida;
    wire [3:0]  s_estado;

    // Sincronizador de reset de 2 estagios para prevencao de metaestabilidade
    // e cumprimento dos tempos de recovery/removal no clock de 50 MHz
    reg reset_sync_1_q;
    reg reset_sync_2_q;
    wire s_reset_sinc;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            reset_sync_1_q <= 1'b1;
            reset_sync_2_q <= 1'b1;
        end else begin
            reset_sync_1_q <= 1'b0;
            reset_sync_2_q <= reset_sync_1_q;
        end
    end

    assign s_reset_sinc = reset_sync_2_q;

    // Instanciacao do nucleo do Sonar
    sonar #(
        .M_INTERVALO(100_000_000), // 2 segundos a 50 MHz
        .N_INTERVALO(27)
    ) u_sonar (
        .clock        (clock),
        .reset        (s_reset_sinc),
        .ligar        (ligar),
        .echo         (echo),
        .trigger      (trigger),
        .pwm          (pwm),
        .saida_serial (saida_serial),
        .fim_posicao  (fim_posicao),
        .db_posicao   (s_posicao),
        .db_medida    (s_medida),
        .db_estado    (s_estado)
    );

    // Decodificadores de 7 segmentos para a distancia medida (HEX0, HEX1, HEX2)
    hexa7seg u_hex0 (
        .hexa   ({1'b0, s_medida[3:0]}),
        .display(hex0)
    );

    hexa7seg u_hex1 (
        .hexa   ({1'b0, s_medida[7:4]}),
        .display(hex1)
    );

    hexa7seg u_hex2 (
        .hexa   ({1'b0, s_medida[11:8]}),
        .display(hex2)
    );

    // Display HEX3 apagado
    assign hex3 = 7'b1111111;

    // Display HEX4: Posicao angular atual do servomotor (0 a 7)
    hexa7seg u_hex4 (
        .hexa   ({2'b00, s_posicao}),
        .display(hex4)
    );

    // Display HEX5: Estado atual da FSM de controle (0 a 7)
    hexa7seg u_hex5 (
        .hexa   ({1'b0, s_estado}),
        .display(hex5)
    );

    // LEDs de depuracao e status
    assign ledr[0]   = fim_posicao;
    assign ledr[1]   = ligar;
    assign ledr[2]   = trigger;
    assign ledr[3]   = echo;
    assign ledr[4]   = saida_serial;
    assign ledr[5]   = pwm;
    assign ledr[9:6] = 4'b0000;

endmodule

`default_nettype wire
