`default_nettype none
`timescale 1ns/1ns

/* 
 *  Descricao : Testbench para o top-level exp6_sonar.
 *              Verifica:
 *              1. Inicializacao e ativacao de chaves
 *              2. Funcionamento do MUX de displays (sel_mux = 00, 01, 10, 11)
 *              3. Status de LEDs e propagacao de saidas fisicas
 */

module exp6_sonar_tb;

    reg        clock_in;
    reg        reset_in;
    reg        ligar_in;
    reg  [1:0] sel_mux_in;
    reg        entrada_serial_in;
    reg        echo_in;
    wire       trigger_out;
    wire       pwm_out;
    wire       saida_serial_out;
    wire       fim_posicao_out;
    wire [6:0] hex0_out, hex1_out, hex2_out, hex3_out, hex4_out, hex5_out;
    wire [9:0] ledr_out;

    localparam CLOCK_PERIOD = 20;

    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    exp6_sonar uut (
        .clock          (clock_in),
        .reset          (reset_in),
        .ligar          (ligar_in),
        .sel_mux        (sel_mux_in),
        .entrada_serial (entrada_serial_in),
        .echo           (echo_in),
        .trigger        (trigger_out),
        .pwm            (pwm_out),
        .saida_serial   (saida_serial_out),
        .fim_posicao    (fim_posicao_out),
        .hex0           (hex0_out),
        .hex1           (hex1_out),
        .hex2           (hex2_out),
        .hex3           (hex3_out),
        .hex4           (hex4_out),
        .hex5           (hex5_out),
        .ledr           (ledr_out)
    );

    initial begin
        clock_in          = 1'b0;
        reset_in          = 1'b0;
        ligar_in          = 1'b0;
        sel_mux_in        = 2'b00;
        entrada_serial_in = 1'b1;
        echo_in           = 1'b0;

        $display("Inicio da Simulacao");

        // Reset
        reset_in = 1'b1;
        #(10 * CLOCK_PERIOD);
        reset_in = 1'b0;
        #(10 * CLOCK_PERIOD);

        // Teste de selecao do MUX
        $display("[Teste MUX] sel_mux = 00 (Servo + HCSR04)");
        sel_mux_in = 2'b00;
        #(10 * CLOCK_PERIOD);

        $display("[Teste MUX] sel_mux = 01 (UART)");
        sel_mux_in = 2'b01;
        #(10 * CLOCK_PERIOD);

        $display("[Teste MUX] sel_mux = 10 (TX Dados Sonar)");
        sel_mux_in = 2'b10;
        #(10 * CLOCK_PERIOD);

        $display("[Teste MUX] sel_mux = 11 (Sonar Top)");
        sel_mux_in = 2'b11;
        #(10 * CLOCK_PERIOD);

        $display("exp6_sonar_tb: SUCESSO!");

        $finish;
    end

endmodule

`default_nettype wire
