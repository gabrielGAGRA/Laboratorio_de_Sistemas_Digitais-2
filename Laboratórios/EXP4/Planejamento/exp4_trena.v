`default_nettype none

module exp4_trena (
    input  wire       clock,
    input  wire       reset,
    input  wire       mensurar,
    input  wire       echo,
    output wire       trigger,
    output wire       saida_serial,
    output wire [6:0] medida0,          // Display HEX0 (Unidade BCD)
    output wire [6:0] medida1,          // Display HEX1 (Dezena BCD)
    output wire [6:0] medida2,          // Display HEX2 (Centena BCD)
    output wire       pronto,           // LEDR0
    output wire       db_mensurar,      // LEDR1
    output wire       db_echo,          // Scope CH2+ / GPIO_1_D35
    output wire       db_trigger,       // Scope CH1+ / GPIO_1_D33
    output wire       db_saida_serial,  // Protocol DIO7 / GPIO_0_D35
    output wire [6:0] db_estado         // Display HEX5
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

    // Detector de borda para o sinal mensurar (padrao EXP3)
    edge_detector u_edge_detector (
        .clock (clock),
        .reset (reset),
        .sinal (mensurar),
        .pulso (s_mensurar)
    );

    // Instanciacao da Unidade de Controle
    exp4_trena_uc u_uc (
        .clock         (clock),
        .reset         (reset),
        .mensurar      (s_mensurar),
        .pronto_sensor (s_pronto_sensor),
        .pronto_serial (s_pronto_serial),
        .medir         (s_medir),
        .partida       (s_partida),
        .sel_letra     (s_sel_letra),
        .pronto        (s_pronto),
        .db_estado     (s_estado)
    );

    // Instanciacao do Fluxo de Dados
    exp4_trena_fd u_fd (
        .clock         (clock),
        .reset         (reset),
        .echo          (echo),
        .medir         (s_medir),
        .partida       (s_partida),
        .sel_letra     (s_sel_letra),
        .trigger       (s_trigger),
        .saida_serial  (s_saida_serial),
        .medida        (s_medida),
        .pronto_sensor (s_pronto_sensor),
        .pronto_serial (s_pronto_serial),
        .db_tick       ()
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
    assign trigger         = s_trigger;
    assign saida_serial    = s_saida_serial;
    assign pronto          = s_pronto;
    assign db_mensurar     = mensurar;
    assign db_echo         = echo;
    assign db_trigger      = s_trigger;
    assign db_saida_serial = s_saida_serial;

endmodule

`default_nettype wire
