`default_nettype none

module tx_serial_7E1 (
    input  wire       clock,
    input  wire       reset,
    input  wire       partida,
    input  wire [6:0] dados_ascii,
    output wire       saida_serial,
    output wire       pronto,
    output wire       db_clock,
    output wire       db_tick,
    output wire       db_partida,
    output wire       db_saida_serial,
    output wire [6:0] db_estado
);

    wire       s_reset;
    wire       s_partida;
    wire       s_partida_ed;
    wire       s_zera;
    wire       s_conta;
    wire       s_carrega;
    wire       s_desloca;
    wire       s_tick;
    wire       s_fim;
    wire       s_saida_serial;
    wire [3:0] s_estado;

    // Sinais de reset e partida (ativos em alto)
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
        .partida   (s_partida_ed),
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
    // Fator de divisao para 115.200 bauds: 50.000.000 / 115.200 = 434 (9 bits)
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

    // Detector de borda para tratar pulsos da partida
    edge_detector u_edge_detector (
        .clock (clock),
        .reset (reset),
        .sinal (s_partida),
        .pulso (s_partida_ed)
    );

    // Saida serial
    assign saida_serial = s_saida_serial;

    // Sinais de depuracao
    assign db_clock        = clock;
    assign db_tick         = s_tick;
    assign db_partida      = s_partida;
    assign db_saida_serial = s_saida_serial;

    // Decodificador 7 segmentos para exibicao do estado da UC (HEX0)
    hexa7seg u_hexa7seg ( 
        .hexa    (s_estado), 
        .display (db_estado)
    );

endmodule

`default_nettype wire