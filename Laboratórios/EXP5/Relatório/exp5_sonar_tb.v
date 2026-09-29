`default_nettype none
`timescale 1ns/1ns

module exp5_sonar_tb;

    reg        clock;
    reg        reset;
    reg        ligar;
    reg        chave_depuracao;
    reg        echo;
    wire       trigger;
    wire       pwm;
    wire       saida_serial;
    wire       fim_posicao;
    wire [6:0] hex0;
    wire [6:0] hex1;
    wire [6:0] hex2;
    wire [6:0] hex3;
    wire [6:0] hex4;
    wire [6:0] hex5;
    wire [9:0] ledr;

    integer errors = 0;
    localparam CLOCK_PERIOD = 20; // 50 MHz
    always #(CLOCK_PERIOD / 2) clock = ~clock;

    // DUT
    exp5_sonar dut (
        .clock          (clock),
        .reset          (reset),
        .ligar          (ligar),
        .chave_depuracao(chave_depuracao),
        .echo           (echo),
        .trigger        (trigger),
        .pwm            (pwm),
        .saida_serial   (saida_serial),
        .fim_posicao    (fim_posicao),
        .hex0           (hex0),
        .hex1           (hex1),
        .hex2           (hex2),
        .hex3           (hex3),
        .hex4           (hex4),
        .hex5           (hex5),
        .ledr           (ledr)
    );

    initial begin
        // $dumpfile("exp5_sonar_tb.vcd");
        // $dumpvars(0, exp5_sonar_tb);

        clock           = 0;
        reset           = 0;
        ligar           = 0;
        chave_depuracao = 1; // Inicia em modo depuracao
        echo            = 0;

        $display("Inicio da simulacao: exp5_sonar_tb");

        // Reset
        @(negedge clock);
        reset = 1;
        #(100 * CLOCK_PERIOD);
        @(negedge clock);
        reset = 0;
        #(100 * CLOCK_PERIOD);

        // 1. Verifica estado inicial em modo depuracao (chave_depuracao = 1)
        if (hex3 !== 7'b1111111) begin
            $display("[ERRO] Em depuracao, HEX3 deve estar apagado (esperado 7'b1111111, obtido %b)", hex3);
            errors = errors + 1;
        end else begin
            $display("[SUCESSO] Modo depuracao: HEX3 apagado corretamente");
        end

        // 2. Alterna para modo funcional (chave_depuracao = 0): angulo 020 graus em HEX5..HEX3
        @(negedge clock);
        chave_depuracao = 0;
        #(10 * CLOCK_PERIOD);

        // 020 graus: HEX5 = '0' (7'b1000000), HEX4 = '2' (7'b0100100), HEX3 = '0' (7'b1000000)
        if (hex5 !== 7'b1000000 || hex4 !== 7'b0100100 || hex3 !== 7'b1000000) begin
            $display("[ERRO] Em modo funcional, angulo inicial 020 esperava HEX5=0, HEX4=2, HEX3=0. Obtido: HEX5=%b HEX4=%b HEX3=%b",
                     hex5, hex4, hex3);
            errors = errors + 1;
        end else begin
            $display("[SUCESSO] Modo funcional: HEX5..HEX3 exibem 020 graus com sucesso!");
        end

        // 3. Verifica conexao dos LEDs de status
        if (ledr[1] !== 1'b0) begin
            $display("[ERRO] LEDR[1] (ligar) deveria ser 0 inicialmente");
            errors = errors + 1;
        end

        @(negedge clock);
        ligar = 1;
        #(20 * CLOCK_PERIOD);

        if (ledr[1] !== 1'b1) begin
            $display("[ERRO] LEDR[1] (ligar) deveria ser 1 apos ligar");
            errors = errors + 1;
        end

        $display("exp5_sonar top-level verificado com sucesso!");

        if (errors == 0) begin
            $display("\nSUCCESS: ALL TESTBENCH CHECKS PASSED!");
        end else begin
            $display("\nFAILURE: %0d error(s) detected", errors);
        end

        $finish;
    end

endmodule

`default_nettype wire
