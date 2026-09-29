`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : tx_serial_7E1.v
 * --------------------------------------------------------------------------
 *  Descricao : Transmissor serial assincrono 7E1 (7 bits de dados,
 *              paridade par, 1 stop bit) a 115200 bauds.
 *              Versao refatorada para o Sistema de Sonar (EXP5).
 * --------------------------------------------------------------------------
 */

module tx_serial_7E1 (
    input  wire       clock,
    input  wire       reset,
    input  wire       partida,
    input  wire [6:0] dados_ascii,
    output wire       saida_serial,
    output wire       pronto,
    output wire       db_partida,
    output wire       db_saida_serial,
    output wire [3:0] db_estado
);

    wire       s_reset;
    wire       s_partida;
    wire       s_zera;
    wire       s_conta;
    wire       s_carrega;
    wire       s_desloca;
    wire       s_tick;
    wire       s_fim;
    wire       s_saida_serial;
    wire [3:0] s_estado;

    assign s_reset   = reset;
    assign s_partida = partida;

    // Fluxo de dados (datapath)
    tx_serial_7E1_fd u_tx_serial_7E1_fd (
        .clock        (clock),
        .reset        (s_reset),
        .zera         (s_zera),
        .conta        (s_conta),
        .carrega      (s_carrega),
        .desloca      (s_desloca),
        .dados_ascii  (dados_ascii),
        .saida_serial (s_saida_serial),
        .fim          (s_fim)
    );

    // Unidade de controle (FSM)
    tx_serial_7E1_uc u_tx_serial_7E1_uc (
        .clock     (clock),
        .reset     (s_reset),
        .partida   (s_partida),
        .tick      (s_tick),
        .fim       (s_fim),
        .zera      (s_zera),
        .conta     (s_conta),
        .carrega   (s_carrega),
        .desloca   (s_desloca),
        .pronto    (pronto),
        .db_estado (s_estado)
    );

    // Gerador de tick de baud rate
    // Divisao para 115.200 bauds: 50.000.000 / 115.200 = 434 (9 bits)
    contador_m #(
        .M(434), 
        .N(9) 
    ) u_contador_tick (
        .clock   (clock),
        .zera_as (1'b0),
        .zera_s  (s_zera),
        .conta   (1'b1),
        .Q       (),
        .fim     (s_tick),
        .meio    ()
    );

    // Atribuicao de saidas
    assign saida_serial    = s_saida_serial;
    assign db_partida      = s_partida;
    assign db_saida_serial = s_saida_serial;
    assign db_estado       = s_estado;

endmodule

`default_nettype wire
