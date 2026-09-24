`default_nettype none

module exp4_desafio #(
    parameter M_INTERVALO = 100_000_000,
    parameter N_INTERVALO = 27
)(
    input  wire       clock,
    input  wire       reset,
    input  wire       mensurar,
    input  wire       echo,
    output wire       trigger,
    output wire       saida_serial,
    output wire [6:0] medida0,           // Display HEX0 (Unidade BCD)
    output wire [6:0] medida1,           // Display HEX1 (Dezena BCD)
    output wire [6:0] medida2,           // Display HEX2 (Centena BCD)
    output wire       pronto,            // LEDR0
    output wire       db_mensurar,       // LEDR1
    output wire       db_echo,           // Scope CH2+ / GPIO_1_D35
    output wire       db_trigger,        // Scope CH1+ / GPIO_1_D33
    output wire       db_saida_serial,   // Protocol DIO7 / GPIO_0_D35
    output wire       db_espera_2s,      // LEDR2 / DIO
    output wire       db_segunda_medida, // LEDR3 / DIO
    output wire [6:0] db_estado          // Display HEX5
);

    // Sinais internos
    wire        s_mensurar;
    wire [11:0] s_medida;
    wire [3:0]  s_estado;
    wire        s_trigger;
    wire        s_saida_serial;
    wire        s_pronto;
    wire        s_medir;
    wire        s_partida;
    wire [1:0]  s_sel_letra;
    wire        s_pronto_sensor;
    wire        s_pronto_serial;
    wire        s_conta_timer;
    wire        s_zera_timer;
    wire        s_fim_timer;
    wire        s_conta_medida;
    wire        s_zera_medida;
    wire        s_fim_medidas;
    wire        s_espera_2s;
    wire        s_segunda_medida;

    // Detector de borda para o sinal mensurar (ativo em baixo no botao da placa)
    edge_detector u_edge_detector (
        .clock (clock),
        .reset (reset),
        .sinal (~mensurar),
        .pulso (s_mensurar)
    );

    // Instanciacao da Unidade de Controle
    exp4_desafio_uc u_uc (
        .clock         (clock),
        .reset         (reset),
        .mensurar      (s_mensurar),
        .pronto_sensor (s_pronto_sensor),
        .pronto_serial (s_pronto_serial),
        .fim_timer     (s_fim_timer),
        .fim_medidas   (s_fim_medidas),
        .medir         (s_medir),
        .partida       (s_partida),
        .sel_letra     (s_sel_letra),
        .conta_timer   (s_conta_timer),
        .zera_timer    (s_zera_timer),
        .conta_medida  (s_conta_medida),
        .zera_medida   (s_zera_medida),
        .pronto        (s_pronto),
        .db_espera_2s  (s_espera_2s),
        .db_estado     (s_estado)
    );

    // Instanciacao do Fluxo de Dados
    exp4_desafio_fd #(
        .M_INTERVALO(M_INTERVALO),
        .N_INTERVALO(N_INTERVALO)
    ) u_fd (
        .clock             (clock),
        .reset             (reset),
        .echo              (echo),
        .medir             (s_medir),
        .partida           (s_partida),
        .sel_letra         (s_sel_letra),
        .conta_timer       (s_conta_timer),
        .zera_timer        (s_zera_timer),
        .conta_medida      (s_conta_medida),
        .zera_medida       (s_zera_medida),
        .trigger           (s_trigger),
        .saida_serial      (s_saida_serial),
        .medida            (s_medida),
        .pronto_sensor     (s_pronto_sensor),
        .pronto_serial     (s_pronto_serial),
        .fim_timer         (s_fim_timer),
        .fim_medidas       (s_fim_medidas),
        .db_segunda_medida (s_segunda_medida),
        .db_tick           ()
    );

    // Decodificadores para os displays de 7 segmentos (HEX0 a HEX2)
    hexa7seg u_hex0 (
        .hexa   ({1'b0, s_medida[3:0]}),
        .display(medida0)
    );

    hexa7seg u_hex1 (
        .hexa   ({1'b0, s_medida[7:4]}),
        .display(medida1)
    );

    hexa7seg u_hex2 (
        .hexa   ({1'b0, s_medida[11:8]}),
        .display(medida2)
    );

    // Decodificador para o display de estado (HEX5)
    hexa7seg u_hex5 (
        .hexa   ({1'b0, s_estado}),
        .display(db_estado)
    );

    // Atribuicao de saidas funcionais e de depuracao
    assign trigger           = s_trigger;
    assign saida_serial      = s_saida_serial;
    assign pronto            = s_pronto;
    assign db_mensurar       = ~mensurar;
    assign db_echo           = echo;
    assign db_trigger        = s_trigger;
    assign db_saida_serial   = s_saida_serial;
    assign db_espera_2s      = s_espera_2s;
    assign db_segunda_medida = s_segunda_medida;

endmodule

`default_nettype wire
