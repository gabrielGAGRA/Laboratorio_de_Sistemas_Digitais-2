`default_nettype none

/* 
 *  Descricao : Circuito de recepcao serial assincrona para comunicacao 7E1
 *              (7 bits de dados, paridade par, 1 stop bit) a 115200 bauds.
 */

module rx_serial_7E1 (
    input  wire       clock,
    input  wire       reset,
    input  wire       RX,
    output wire       pronto,
    output wire [6:0] dados_ascii,
    output wire       paridade,
    output wire       paridade_par,
    output wire       db_clock,
    output wire       db_tick,
    output wire [3:0] db_estado
);

    wire       s_zera;
    wire       s_zera_tick;
    wire       s_registra;
    wire       s_conta;
    wire       s_carrega;
    wire       s_desloca;
    wire       s_tick;
    wire       s_fim;
    wire [3:0] s_estado;
    wire [7:0] s_dados;

    // Fluxo de dados
    rx_serial_7E1_fd u_fd (
        .clock    (clock),
        .reset    (reset),
        .zera     (s_zera),
        .conta    (s_conta),
        .carrega  (s_carrega),
        .desloca  (s_desloca),
        .RX       (RX),
        .dados    (s_dados),
        .registra (s_registra),
        .fim      (s_fim)
    );

    // Unidade de controle
    rx_serial_uc u_uc (
        .clock     (clock),
        .reset     (reset),
        .RX        (RX),
        .tick      (s_tick),
        .fim       (s_fim),
        .registra  (s_registra),
        .zera      (s_zera),
        .zera_tick (s_zera_tick),
        .conta     (s_conta),
        .carrega   (s_carrega),
        .desloca   (s_desloca),
        .pronto    (pronto),
        .db_estado (s_estado)
    );

    // Gerador de tick para amostragem no meio do bit (50MHz / 115200 bauds = 434 ciclos)
    contador_m #(
        .M(434),
        .N(9)
    ) u_tick (
        .clock   (clock),
        .zera_as (1'b0),
        .zera_s  (s_zera_tick),
        .conta   (1'b1),
        .Q       (),
        .fim     (),
        .meio    (s_tick)
    );

    // Saida de dados ASCII e paridade
    assign dados_ascii  = s_dados[6:0];
    assign paridade     = s_dados[7];
    assign paridade_par = ~^s_dados; // XNOR de reducao para paridade par

    // Saidas de depuracao
    assign db_clock  = clock;
    assign db_tick   = s_tick;
    assign db_estado = s_estado;

endmodule

`default_nettype wire
