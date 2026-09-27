`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : sonar.v
 * --------------------------------------------------------------------------
 *  Descricao : Top-level do Sistema de Sonar (conforme Figura 1 da apostila).
 *              Interface estrutural que integra UC e FD, com sinais de
 *              depuracao para a placa FPGA DE0-CV e simulacao.
 * --------------------------------------------------------------------------
 */

module sonar #(
    parameter M_INTERVALO = 100_000_000, // 2s a 50MHz (ajustavel em TB)
    parameter N_INTERVALO = 27
) (
    input  wire        clock,
    input  wire        reset,
    input  wire        ligar,
    input  wire        echo,
    output wire        trigger,
    output wire        pwm,
    output wire        saida_serial,
    output wire        fim_posicao,
    // Sinais de depuracao
    output wire [2:0]  db_posicao,
    output wire [11:0] db_medida,
    output wire [3:0]  db_estado
);

    // Sinais de controle e condicao entre UC e FD
    wire s_zera_posicao;
    wire s_conta_posicao;
    wire s_zera_timer;
    wire s_conta_timer;
    wire s_medir;
    wire s_transmitir;
    wire s_fim_timer;
    wire s_fim_medida;
    wire s_fim_transmissao;
    wire [3:0] s_estado;

    // Unidade de Controle
    sonar_uc u_uc (
        .clock           (clock),
        .reset           (reset),
        .ligar           (ligar),
        .fim_timer       (s_fim_timer),
        .fim_medida      (s_fim_medida),
        .fim_transmissao (s_fim_transmissao),
        .zera_posicao    (s_zera_posicao),
        .conta_posicao   (s_conta_posicao),
        .zera_timer      (s_zera_timer),
        .conta_timer     (s_conta_timer),
        .medir           (s_medir),
        .transmitir      (s_transmitir),
        .fim_posicao     (fim_posicao),
        .db_estado       (s_estado)
    );

    // Fluxo de Dados
    sonar_fd #(
        .M_INTERVALO(M_INTERVALO),
        .N_INTERVALO(N_INTERVALO)
    ) u_fd (
        .clock           (clock),
        .reset           (reset),
        .zera_posicao    (s_zera_posicao),
        .conta_posicao   (s_conta_posicao),
        .zera_timer      (s_zera_timer),
        .conta_timer     (s_conta_timer),
        .medir           (s_medir),
        .transmitir      (s_transmitir),
        .echo            (echo),
        .trigger         (trigger),
        .pwm             (pwm),
        .saida_serial    (saida_serial),
        .fim_timer       (s_fim_timer),
        .fim_medida      (s_fim_medida),
        .fim_transmissao (s_fim_transmissao),
        .db_posicao      (db_posicao),
        .db_angulo       (),
        .db_medida       (db_medida)
    );

    assign db_estado = s_estado;

endmodule

`default_nettype wire
