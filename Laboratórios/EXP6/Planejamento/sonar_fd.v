`default_nettype none

/* 
 *  Descricao : Fluxo de dados do Sistema de Sonar Modificado.
 *              Integra o receptor serial 7E1 para recepcao de comandos ('a' e 'v'),
 *              registrador de modo, controle de 8 posicoes do servo, memoria ROM
 *              de angulos, interface HC-SR04, transmissor em bloco de 8 caracteres
 *              e temporizador de repouso parametrizavel.
 */

module sonar_fd #(
    parameter M_INTERVALO   = 100_000_000, // 2 segundos a 50 MHz
    parameter N_INTERVALO   = 27,
    parameter TIMEOUT_TICKS = 50_000_000,  // 1s a 50 MHz
    parameter TIMEOUT_BITS  = 26
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
    input  wire        entrada_serial,
    output wire        trigger,
    output wire        pwm,
    output wire        saida_serial,
    output wire        fim_timer,
    output wire        fim_medida,
    output wire        fim_transmissao,
    output wire        modo,
    // Sinais de depuracao e monitoramento
    output wire        db_modo,
    output wire [2:0]  db_posicao,
    output wire [23:0] db_angulo,
    output wire [11:0] db_medida,
    output wire [3:0]  db_estado_hcsr04,
    output wire [3:0]  db_estado_tx,
    output wire [6:0]  db_dados_tx,
    output wire [3:0]  db_estado_rx,
    output wire [6:0]  db_dados_rx,
    output wire [3:0]  db_estado_tx_sonar,
    output wire [2:0]  db_indice_tx_sonar,
    output wire [6:0]  db_char_tx
);

    // Caracteres de controle ASCII (7 bits)
    localparam [6:0] CHAR_ATENCAO = 7'h61; // 'a' (ASCII 97  = 7'b1100001)
    localparam [6:0] CHAR_VOLTAR  = 7'h76; // 'v' (ASCII 118 = 7'b1110110)

    wire [2:0]  s_posicao;
    wire [23:0] s_angulo;
    wire [11:0] s_distancia;

    // Sinais do receptor serial
    wire       s_rx_pronto;
    wire [6:0] s_rx_dados_ascii;
    wire       s_rx_paridade;
    wire       s_rx_paridade_par;
    wire [3:0] s_rx_db_estado;

    // Registrador de modo de operacao (0 = Localizacao, 1 = Atencao)
    reg modo_q;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            modo_q <= 1'b0; // Inicializa no modo normal de localizacao
        end else if (s_rx_pronto && s_rx_paridade_par) begin
            if (s_rx_dados_ascii == CHAR_ATENCAO) begin
                modo_q <= 1'b1; // Entra no modo de atencao
            end else if (s_rx_dados_ascii == CHAR_VOLTAR) begin
                modo_q <= 1'b0; // Retorna ao modo de localizacao
            end
            // Demais caracteres sao ignorados (mantem modo_q inalterado)
        end
    end

    // 1. Receptor serial assincrono 7E1 a 115200 bauds
    rx_serial_7E1 u_rx_serial (
        .clock        (clock),
        .reset        (reset),
        .RX           (entrada_serial),
        .pronto       (s_rx_pronto),
        .dados_ascii  (s_rx_dados_ascii),
        .paridade     (s_rx_paridade),
        .paridade_par (s_rx_paridade_par),
        .db_clock     (),
        .db_tick      (),
        .db_estado    (s_rx_db_estado)
    );

    // 2. Contador de 8 posicoes do servomotor (000 a 111)
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

    // 3. Memoria ROM de angulos em ASCII (8 palavras de 24 bits)
    rom_angulos_8x24 u_rom_angulos (
        .endereco (s_posicao),
        .saida    (s_angulo)
    );

    // 4. Controle do servomotor (8 posicoes com pulsos PWM)
    controle_servo_8 u_controle_servo (
        .clock       (clock),
        .reset       (reset),
        .posicao     (s_posicao),
        .controle    (pwm),
        .db_reset    (),
        .db_posicao  (),
        .db_controle ()
    );

    // 5. Interface com o sensor ultrassonico HC-SR04
    interface_hcsr04 #(
        .TIMEOUT_TICKS(TIMEOUT_TICKS),
        .TIMEOUT_BITS (TIMEOUT_BITS)
    ) u_interface_hcsr04 (
        .clock     (clock),
        .reset     (reset),
        .medir     (medir),
        .echo      (echo),
        .trigger   (trigger),
        .medida    (s_distancia),
        .pronto    (fim_medida),
        .db_reset  (),
        .db_medir  (),
        .db_estado (db_estado_hcsr04)
    );

    // 6. Transmissao em bloco dos dados do sonar (8 caracteres ASCII "AAA,DDD#")
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
        .db_estado       (db_estado_tx_sonar),
        .db_indice       (db_indice_tx_sonar),
        .db_dados_ascii  (db_char_tx)
    );

    // 7. Temporizador de repouso (2s real ou 200us em simulacao)
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

    // Conexoes de controle e status
    assign modo               = modo_q;
    assign db_modo            = modo_q;
    assign db_posicao         = s_posicao;
    assign db_angulo          = s_angulo;
    assign db_medida          = s_distancia;
    assign db_estado_rx       = s_rx_db_estado;
    assign db_dados_rx        = s_rx_dados_ascii;
    assign db_estado_tx       = 4'h0;
    assign db_dados_tx        = db_char_tx;

endmodule

`default_nettype wire
