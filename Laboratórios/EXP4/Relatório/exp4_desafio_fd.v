`default_nettype none

module exp4_desafio_fd #(
    parameter M_INTERVALO = 100_000_000,
    parameter N_INTERVALO = 27
)(
    input  wire        clock,
    input  wire        reset,
    input  wire        echo,
    input  wire        medir,
    input  wire        partida,
    input  wire [1:0]  sel_letra,
    input  wire        conta_timer,
    input  wire        zera_timer,
    input  wire        conta_medida,
    input  wire        zera_medida,
    output wire        trigger,
    output wire        saida_serial,
    output wire [11:0] medida,
    output wire        pronto_sensor,
    output wire        pronto_serial,
    output wire        fim_timer,
    output wire        fim_medidas,
    output wire        db_segunda_medida,
    output wire        db_tick
);

    wire [11:0] s_medida;
    wire [6:0]  s_dado_ascii;
    wire [1:0]  s_conta_medida_q;

    // Interface com o sensor ultrassonico
    interface_hcsr04 u_sensor (
        .clock     (clock),
        .reset     (reset),
        .medir     (medir),
        .echo      (echo),
        .trigger   (trigger),
        .medida    (s_medida),
        .pronto    (pronto_sensor),
        .db_estado ()
    );

    // Multiplexador ASCII (4x1 de 7 bits)
    // Conversao BCD -> ASCII: adiciona bits 3'b011 na frente do digito BCD (4 bits)
    // Terminador '#' : 7'h23 (7'b0100011)
    mux_4x1_n #(
        .BITS(7)
    ) u_mux_ascii (
        .D0     ({3'b011, s_medida[11:8]}), // sel_letra == 2'b00 (Centena)
        .D1     ({3'b011, s_medida[7:4] }), // sel_letra == 2'b01 (Dezena)
        .D2     ({3'b011, s_medida[3:0] }), // sel_letra == 2'b10 (Unidade)
        .D3     (7'h23                   ), // sel_letra == 2'b11 ('#')
        .SEL    (sel_letra               ),
        .MUX_OUT(s_dado_ascii            )
    );

    // Transmissor Serial 115200 7E1 refatorado (sem edge_detector e sem hexa7seg)
    tx_serial_7E1 u_tx (
        .clock           (clock),
        .reset           (reset),
        .partida         (partida),
        .dados_ascii     (s_dado_ascii),
        .saida_serial    (saida_serial),
        .pronto          (pronto_serial),
        .db_clock        (),
        .db_tick         (db_tick),
        .db_partida      (),
        .db_saida_serial (),
        .db_estado       ()
    );

    // Temporizador de intervalo de 2 segundos (M = 100_000_000 ciclos a 50 MHz)
    contador_m #(
        .M(M_INTERVALO),
        .N(N_INTERVALO)
    ) u_timer_2s (
        .clock   (clock),
        .zera_as (reset),
        .zera_s  (zera_timer),
        .conta   (conta_timer),
        .Q       (),
        .fim     (fim_timer),
        .meio    ()
    );

    // Contador de medidas (M = 2, N = 2 bits)
    // Q = 0 (1a medida), Q = 1 (2a medida, fim = 1)
    contador_m #(
        .M(2),
        .N(2)
    ) u_contador_medidas (
        .clock   (clock),
        .zera_as (reset),
        .zera_s  (zera_medida),
        .conta   (conta_medida),
        .Q       (s_conta_medida_q),
        .fim     (fim_medidas),
        .meio    ()
    );

    assign medida            = s_medida;
    assign db_segunda_medida = s_conta_medida_q[0];

endmodule

`default_nettype wire
