`default_nettype none

/* 
 *  Descricao : Top-level para a placa FPGA Cyclone V DE0-CV (EXP6).
 *              Instancia o nucleo do Sistema de Sonar Modificado (sonar.v),
 *              sincronizadores modulares de 2 flip-flops para entradas
 *              assincronas, multiplexador 4x1 de 24 bits para monitoramento
 *              em tempo real nos displays HEX5..HEX0 e mapeamento de LEDs LEDR.
 */

module exp6_sonar (
    input  wire       clock,
    input  wire       reset,
    input  wire       ligar,
    input  wire [1:0] sel_mux,
    input  wire       entrada_serial,
    input  wire       echo,
    output wire       trigger,
    output wire       pwm,
    output wire       saida_serial,
    output wire       fim_posicao,
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire [6:0] hex3,
    output wire [6:0] hex4,
    output wire [6:0] hex5,
    output wire [9:0] ledr
);

    // Sinais sincronizados
    wire       s_reset_sinc;
    wire       s_ligar_sinc;
    wire [1:0] s_sel_mux_sinc;
    wire       s_rx_sinc;
    wire       s_echo_sinc;

    // Sinais de monitoramento do nucleo
    wire        s_db_modo;
    wire [2:0]  s_db_posicao;
    wire [23:0] s_db_angulo;
    wire [11:0] s_db_medida;
    wire [3:0]  s_db_estado;
    wire [3:0]  s_db_estado_hcsr04;
    wire [3:0]  s_db_estado_tx;
    wire [6:0]  s_db_dados_tx;
    wire [3:0]  s_db_estado_rx;
    wire [6:0]  s_db_dados_rx;
    wire [3:0]  s_db_estado_tx_sonar;
    wire [2:0]  s_db_indice_tx_sonar;
    wire [6:0]  s_db_char_tx;

    // 1. Sincronizadores modulares de 2 estagios
    sincronizador #(
        .WIDTH     (1),
        .INIT_VALUE(1'b1)
    ) u_sync_reset (
        .clock   (clock),
        .reset   (reset),
        .async_in(1'b0),
        .sync_out(s_reset_sinc)
    );

    sincronizador #(
        .WIDTH     (1),
        .INIT_VALUE(1'b0)
    ) u_sync_ligar (
        .clock   (clock),
        .reset   (s_reset_sinc),
        .async_in(ligar),
        .sync_out(s_ligar_sinc)
    );

    sincronizador #(
        .WIDTH     (2),
        .INIT_VALUE(2'b00)
    ) u_sync_sel_mux (
        .clock   (clock),
        .reset   (s_reset_sinc),
        .async_in(sel_mux),
        .sync_out(s_sel_mux_sinc)
    );

    sincronizador #(
        .WIDTH     (1),
        .INIT_VALUE(1'b1) // Linha serial em repouso nivel alto
    ) u_sync_rx (
        .clock   (clock),
        .reset   (s_reset_sinc),
        .async_in(entrada_serial),
        .sync_out(s_rx_sinc)
    );

    sincronizador #(
        .WIDTH     (1),
        .INIT_VALUE(1'b0)
    ) u_sync_echo (
        .clock   (clock),
        .reset   (s_reset_sinc),
        .async_in(echo),
        .sync_out(s_echo_sinc)
    );

    // 2. Instanciacao do nucleo do Sonar Modificado
    sonar #(
        .M_INTERVALO  (100_000_000), // 2 segundos a 50 MHz
        .N_INTERVALO  (27),
        .TIMEOUT_TICKS(50_000_000),  // 1 segundo a 50 MHz
        .TIMEOUT_BITS (26)
    ) u_sonar (
        .clock             (clock),
        .reset             (s_reset_sinc),
        .ligar             (s_ligar_sinc),
        .echo              (s_echo_sinc),
        .entrada_serial    (s_rx_sinc),
        .trigger           (trigger),
        .pwm               (pwm),
        .saida_serial      (saida_serial),
        .fim_posicao       (fim_posicao),
        .db_modo           (s_db_modo),
        .db_posicao        (s_db_posicao),
        .db_angulo         (s_db_angulo),
        .db_medida         (s_db_medida),
        .db_estado         (s_db_estado),
        .db_estado_hcsr04  (s_db_estado_hcsr04),
        .db_estado_tx      (s_db_estado_tx),
        .db_dados_tx       (s_db_dados_tx),
        .db_estado_rx      (s_db_estado_rx),
        .db_dados_rx       (s_db_dados_rx),
        .db_estado_tx_sonar(s_db_estado_tx_sonar),
        .db_indice_tx_sonar(s_db_indice_tx_sonar),
        .db_char_tx        (s_db_char_tx)
    );

    // 3. Multiplexador 4x1 de 24 bits para os Displays HEX5..HEX0
    reg [4:0] s_hexa0, s_hexa1, s_hexa2, s_hexa3, s_hexa4, s_hexa5;

    always @* begin
        case (s_sel_mux_sinc)
            // 2'b00: Servomotor + HC-SR04
            2'b00: begin
                s_hexa5 = {2'b00, s_db_posicao};
                s_hexa4 = {1'b0, s_db_estado_hcsr04};
                s_hexa3 = 5'h1f; // Apagado
                s_hexa2 = {1'b0, s_db_medida[11:8]}; // Centena BCD
                s_hexa1 = {1'b0, s_db_medida[7:4]};  // Dezena BCD
                s_hexa0 = {1'b0, s_db_medida[3:0]};  // Unidade BCD
            end

            // 2'b01: UART TX e RX
            2'b01: begin
                s_hexa5 = {1'b0, s_db_estado_tx};
                s_hexa4 = {2'b00, s_db_dados_tx[6:4]};
                s_hexa3 = {1'b0, s_db_dados_tx[3:0]};
                s_hexa2 = {1'b0, s_db_estado_rx};
                s_hexa1 = {2'b00, s_db_dados_rx[6:4]};
                s_hexa0 = {1'b0, s_db_dados_rx[3:0]};
            end

            // 2'b10: TX Dados Sonar
            2'b10: begin
                s_hexa5 = {1'b0, s_db_estado_tx_sonar};
                s_hexa4 = {2'b00, s_db_indice_tx_sonar};
                s_hexa3 = {2'b00, s_db_char_tx[6:4]};
                s_hexa2 = {1'b0, s_db_char_tx[3:0]};
                s_hexa1 = 5'h1f; // Apagado
                s_hexa0 = 5'h1f; // Apagado
            end

            // 2'b11: Sonar Top + Angulo
            2'b11: begin
                s_hexa5 = {1'b0, s_db_estado};
                s_hexa4 = {4'b0000, s_db_modo};
                s_hexa3 = 5'h1f; // Apagado
                s_hexa2 = {1'b0, s_db_angulo[19:16]}; // Centena ASCII BCD ('0' ou '1')
                s_hexa1 = {1'b0, s_db_angulo[11:8]};  // Dezena ASCII BCD ('2' a '6')
                s_hexa0 = {1'b0, s_db_angulo[3:0]};   // Unidade ASCII BCD ('0')
            end

            default: begin
                s_hexa5 = 5'h1f;
                s_hexa4 = 5'h1f;
                s_hexa3 = 5'h1f;
                s_hexa2 = 5'h1f;
                s_hexa1 = 5'h1f;
                s_hexa0 = 5'h1f;
            end
        endcase
    end

    // Decodificadores para 7 segmentos
    hexa7seg u_hex0 (.hexa(s_hexa0), .display(hex0));
    hexa7seg u_hex1 (.hexa(s_hexa1), .display(hex1));
    hexa7seg u_hex2 (.hexa(s_hexa2), .display(hex2));
    hexa7seg u_hex3 (.hexa(s_hexa3), .display(hex3));
    hexa7seg u_hex4 (.hexa(s_hexa4), .display(hex4));
    hexa7seg u_hex5 (.hexa(s_hexa5), .display(hex5));

    // 4. Mapeamento dos 10 LEDs
    assign ledr[0]   = fim_posicao;
    assign ledr[1]   = s_rx_sinc;
    assign ledr[2]   = trigger;
    assign ledr[3]   = s_echo_sinc;
    assign ledr[4]   = saida_serial;
    assign ledr[5]   = pwm;
    assign ledr[7:6] = s_sel_mux_sinc;
    assign ledr[8]   = s_ligar_sinc;
    assign ledr[9]   = s_db_modo;

endmodule

`default_nettype wire
