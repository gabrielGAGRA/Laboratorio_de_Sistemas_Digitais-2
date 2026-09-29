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
    input  wire       chave_depuracao,
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
    wire [23:0] s_angulo;
    wire [11:0] s_medida;
    wire [3:0]  s_estado;

    wire s_reset_sinc;
    wire s_ligar_sinc;
    wire s_echo_sinc;

    // Sincronizador modular de reset (ativacao assincrona, desassercao sincrona)
    sincronizador #(
        .WIDTH     (1),
        .INIT_VALUE(1'b1)
    ) u_sync_reset (
        .clock   (clock),
        .reset   (reset),
        .async_in(1'b0),
        .sync_out(s_reset_sinc)
    );

    // Sincronizador modular de 2 estagios para a chave ligar (SW[1])
    sincronizador #(
        .WIDTH     (1),
        .INIT_VALUE(1'b0)
    ) u_sync_ligar (
        .clock   (clock),
        .reset   (s_reset_sinc),
        .async_in(ligar),
        .sync_out(s_ligar_sinc)
    );

    // Sincronizador modular de 2 estagios para o sinal echo do sensor HC-SR04
    sincronizador #(
        .WIDTH     (1),
        .INIT_VALUE(1'b0)
    ) u_sync_echo (
        .clock   (clock),
        .reset   (s_reset_sinc),
        .async_in(echo),
        .sync_out(s_echo_sinc)
    );

    // Instanciacao do nucleo do Sonar
    sonar #(
        .M_INTERVALO(100_000_000), // 2 segundos a 50 MHz
        .N_INTERVALO(27)
    ) u_sonar (
        .clock        (clock),
        .reset        (s_reset_sinc),
        .ligar        (s_ligar_sinc),
        .echo         (s_echo_sinc),
        .trigger      (trigger),
        .pwm          (pwm),
        .saida_serial (saida_serial),
        .fim_posicao  (fim_posicao),
        .db_posicao   (s_posicao),
        .db_angulo    (s_angulo),
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

    // Multiplexacao dos displays HEX3, HEX4, HEX5
    // chave_depuracao = 0: Dados funcionais (HEX5-HEX3: angulo em graus 020 a 160)
    // chave_depuracao = 1: Dados de depuracao (HEX5: estado FSM, HEX4: posicao 0-7, HEX3: apagado)
    wire [4:0] s_hexa3 = (chave_depuracao) ? 5'h1f                   : {1'b0, s_angulo[3:0]};
    wire [4:0] s_hexa4 = (chave_depuracao) ? {2'b00, s_posicao}      : {1'b0, s_angulo[11:8]};
    wire [4:0] s_hexa5 = (chave_depuracao) ? {1'b0, s_estado}        : {1'b0, s_angulo[19:16]};

    hexa7seg u_hex3 (
        .hexa   (s_hexa3),
        .display(hex3)
    );

    hexa7seg u_hex4 (
        .hexa   (s_hexa4),
        .display(hex4)
    );

    hexa7seg u_hex5 (
        .hexa   (s_hexa5),
        .display(hex5)
    );

    // LEDs de depuracao e status
    assign ledr[0]   = fim_posicao;
    assign ledr[1]   = s_ligar_sinc;
    assign ledr[2]   = trigger;
    assign ledr[3]   = s_echo_sinc;
    assign ledr[4]   = saida_serial;
    assign ledr[5]   = pwm;
    assign ledr[6]   = chave_depuracao;
    assign ledr[9:7] = 3'b000;

endmodule

`default_nettype wire
