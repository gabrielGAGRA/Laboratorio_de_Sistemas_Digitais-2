`default_nettype none

/* 
 *  Descricao : Top-level do nucleo do Sistema de Sonar Modificado (conforme
 *              Figuras 1 e 2 da apostila de EXP6).
 *              Integra a Unidade de Controle com bifurcacao de modos e o Fluxo
 *              de Dados estrutural com recepcao serial 7E1.
 */

module sonar #(
    parameter M_INTERVALO   = 100_000_000, // 2s a 50MHz
    parameter N_INTERVALO   = 27,
    parameter TIMEOUT_TICKS = 50_000_000,  // 1s a 50MHz
    parameter TIMEOUT_BITS  = 26
) (
    input  wire        clock,
    input  wire        reset,
    input  wire        ligar,
    input  wire        echo,
    input  wire        entrada_serial,
    output wire        trigger,
    output wire        pwm,
    output wire        saida_serial,
    output wire        fim_posicao,
    // Sinais de depuracao e monitoramento
    output wire        db_modo,
    output wire [2:0]  db_posicao,
    output wire [23:0] db_angulo,
    output wire [11:0] db_medida,
    output wire [3:0]  db_estado,
    output wire [3:0]  db_estado_hcsr04,
    output wire [3:0]  db_estado_tx,
    output wire [6:0]  db_dados_tx,
    output wire [3:0]  db_estado_rx,
    output wire [6:0]  db_dados_rx,
    output wire [3:0]  db_estado_tx_sonar,
    output wire [2:0]  db_indice_tx_sonar,
    output wire [6:0]  db_char_tx
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
    wire s_modo;
    wire [3:0] s_estado;

    // Unidade de Controle
    sonar_uc u_uc (
        .clock           (clock),
        .reset           (reset),
        .ligar           (ligar),
        .modo            (s_modo),
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
        .M_INTERVALO  (M_INTERVALO),
        .N_INTERVALO  (N_INTERVALO),
        .TIMEOUT_TICKS(TIMEOUT_TICKS),
        .TIMEOUT_BITS (TIMEOUT_BITS)
    ) u_fd (
        .clock             (clock),
        .reset             (reset),
        .zera_posicao      (s_zera_posicao),
        .conta_posicao     (s_conta_posicao),
        .zera_timer        (s_zera_timer),
        .conta_timer       (s_conta_timer),
        .medir             (s_medir),
        .transmitir        (s_transmitir),
        .echo              (echo),
        .entrada_serial    (entrada_serial),
        .trigger           (trigger),
        .pwm               (pwm),
        .saida_serial      (saida_serial),
        .fim_timer         (s_fim_timer),
        .fim_medida        (s_fim_medida),
        .fim_transmissao   (s_fim_transmissao),
        .modo              (s_modo),
        .db_modo           (db_modo),
        .db_posicao        (db_posicao),
        .db_angulo         (db_angulo),
        .db_medida         (db_medida),
        .db_estado_hcsr04  (db_estado_hcsr04),
        .db_estado_tx      (db_estado_tx),
        .db_dados_tx       (db_dados_tx),
        .db_estado_rx      (db_estado_rx),
        .db_dados_rx       (db_dados_rx),
        .db_estado_tx_sonar(db_estado_tx_sonar),
        .db_indice_tx_sonar(db_indice_tx_sonar),
        .db_char_tx        (db_char_tx)
    );

    assign db_estado = s_estado;

endmodule

`default_nettype wire
