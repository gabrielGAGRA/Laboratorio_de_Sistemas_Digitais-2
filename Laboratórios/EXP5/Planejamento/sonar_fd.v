`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : sonar_fd.v
 * --------------------------------------------------------------------------
 *  Descricao : Fluxo de dados do Sistema de Sonar.
 *              Integra o controle de 8 posicoes do servo, memoria ROM de
 *              angulos, interface com o sensor HC-SR04, transmissao serial
 *              de 8 caracteres e temporizador de repouso parametrizavel.
 * --------------------------------------------------------------------------
 */

module sonar_fd #(
    parameter M_INTERVALO = 100_000_000, // 2 segundos a 50 MHz (ajustavel em TB)
    parameter N_INTERVALO = 27
) (
    input  wire        clock,
    input  wire        reset,
    input  wire        zera_posicao,
    input  wire        conta_posicao,
    input  wire        zera_timer,
    input  wire        conta_timer,
    input  wire        medir,
    input  wire        transmitir,
    input  wire        echo,
    output wire        trigger,
    output wire        pwm,
    output wire        saida_serial,
    output wire        fim_timer,
    output wire        fim_medida,
    output wire        fim_transmissao,
    output wire [2:0]  db_posicao,
    output wire [23:0] db_angulo,
    output wire [11:0] db_medida
);

    wire [2:0]  s_posicao;
    wire [23:0] s_angulo;
    wire [11:0] s_distancia;

    // 1. Contador de 8 posicoes do servomotor (000 a 111)
    contador_m #(
        .M(8),
        .N(3)
    ) u_contador_posicao (
        .clock   (clock),
        .zera_as (reset),
        .zera_s  (zera_posicao),
        .conta   (conta_posicao),
        .Q       (s_posicao),
        .fim     (),
        .meio    ()
    );

    // 2. Memoria ROM de angulos em ASCII (8 palavras de 24 bits)
    rom_angulos_8x24 u_rom_angulos (
        .endereco (s_posicao),
        .saida    (s_angulo)
    );

    // 3. Controle do servomotor (8 posicoes com pulsos PWM)
    controle_servo_8 u_controle_servo (
        .clock       (clock),
        .reset       (reset),
        .posicao     (s_posicao),
        .controle    (pwm),
        .db_reset    (),
        .db_posicao  (),
        .db_controle ()
    );

    // 4. Interface com o sensor ultrassonico HC-SR04
    interface_hcsr04 u_interface_hcsr04 (
        .clock     (clock),
        .reset     (reset),
        .medir     (medir),
        .echo      (echo),
        .trigger   (trigger),
        .medida    (s_distancia),
        .pronto    (fim_medida),
        .db_reset  (),
        .db_medir  (),
        .db_estado ()
    );

    // 5. Transmissao em bloco dos dados do sonar (8 caracteres ASCII "AAA,DDD#")
    transmissor_sonar u_transmissor_sonar (
        .clock           (clock),
        .reset           (reset),
        .transmitir      (transmitir),
        .angulo          (s_angulo),
        .distancia       (s_distancia),
        .saida_serial    (saida_serial),
        .pronto          (fim_transmissao),
        .db_partida      (),
        .db_saida_serial (),
        .db_estado       ()
    );

    // 6. Temporizador de repouso (2s real ou 200us em simulacao)
    contador_m #(
        .M(M_INTERVALO),
        .N(N_INTERVALO)
    ) u_timer_intervalo (
        .clock   (clock),
        .zera_as (reset),
        .zera_s  (zera_timer),
        .conta   (conta_timer),
        .Q       (),
        .fim     (fim_timer),
        .meio    ()
    );

    // Sinais de monitoramento
    assign db_posicao = s_posicao;
    assign db_angulo  = s_angulo;
    assign db_medida  = s_distancia;

endmodule

`default_nettype wire
