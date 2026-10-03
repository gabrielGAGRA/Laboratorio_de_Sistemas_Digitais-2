`default_nettype none

/*
 *  Descricao : Fluxo de dados do circuito de interface com sensor ultrassonico
 *              de distancia HC-SR04 com deteccao de timeout.
 */

module interface_hcsr04_fd #(
    parameter TIMEOUT_TICKS = 50_000_000, // 1 s a 50 MHz
    parameter TIMEOUT_BITS  = 26
)(
    input  wire        clock,
    input  wire        pulso,
    input  wire        zera,
    input  wire        gera,
    input  wire        registra,
    input  wire        zera_timeout,
    input  wire        conta_timeout,
    input  wire        timeout_sel,
    output wire        fim_medida,
    output wire        fim_timeout,
    output wire        trigger,
    output wire        fim,
    output wire [11:0] distancia
);

    wire [11:0] s_medida;
    wire [11:0] s_dado_reg;

    // Pulso de trigger de 10us (500 clocks a 50MHz)
    gerador_pulso #(
        .LARGURA(500) 
    ) u_gerador_pulso (
        .clock (clock),
        .reset (zera),
        .gera  (gera),
        .para  (1'b0), 
        .pulso (trigger),
        .pronto()
    );

    // Contador de cm (R=2941 clocks, N=12)
    contador_cm #(
        .R(2941), 
        .N(12)
    ) u_contador_cm (
        .clock  (clock),
        .reset  (zera),
        .pulso  (pulso),
        .digito2(s_medida[11:8]),
        .digito1(s_medida[7:4]),
        .digito0(s_medida[3:0]),
        .fim    (fim),
        .pronto (fim_medida)
    );

    // Watchdog de timeout
    contador_m #(
        .M(TIMEOUT_TICKS),
        .N(TIMEOUT_BITS)
    ) u_contador_timeout (
        .clock   (clock),
        .zera_as (1'b0),
        .zera_s  (zera_timeout),
        .conta   (conta_timeout),
        .Q       (),
        .fim     (fim_timeout),
        .meio    ()
    );

    // MUX de selecao de dado (999 cm sentinela no timeout)
    assign s_dado_reg = (timeout_sel) ? 12'h999 : s_medida;

    registrador_n #(
        .N(12)
    ) u_registrador (
        .clock (clock),
        .clear (1'b0),
        .enable(registra),
        .D     (s_dado_reg),
        .Q     (distancia)
    );

endmodule

`default_nettype wire
