`default_nettype none

module tx_serial_7E1_tb;

    // Sinais de estimulo e monitoramento
    reg        clock_in;
    reg        reset_in;
    reg        partida_in;
    reg  [6:0] dados_ascii_7_in;
    wire       saida_serial_out;
    wire       pronto_out;
    wire       db_clock_out;
    wire       db_tick_out;
    wire       db_partida_out;
    wire       db_saida_serial_out;
    wire [6:0] db_estado_out;

    // Componente sob teste (DUT)
    tx_serial_7E1 u_dut (
        .clock           (clock_in),
        .reset           (reset_in),
        .partida         (partida_in),
        .dados_ascii     (dados_ascii_7_in),
        .saida_serial    (saida_serial_out),
        .pronto          (pronto_out),
        .db_clock        (db_clock_out),
        .db_tick         (db_tick_out),
        .db_partida      (db_partida_out),
        .db_saida_serial (db_saida_serial_out),
        .db_estado       (db_estado_out)
    );

    // Periodo de clock de 50 MHz (T = 20ns, semi-periodo = 10ns)
    localparam CLOCK_PERIOD = 20;

    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    // Vetores de teste
    reg [6:0] vetor_teste [0:3];
    integer caso;
    integer errors = 0;
    integer bit_idx;
    reg       exp_paridade;
    reg [6:0] exp_dado;

    // Watchdog para evitar loops infinitos em caso de falha de hardware
    initial begin
        #(2000000 * CLOCK_PERIOD);
        $display("[ERRO] Watchdog timeout alcancado na simulacao!");
        $finish;
    end

    // Geracao de estimulos e verificacao automatica
    initial begin
        $display("Inicio da simulacao: tx_serial_7E1");

        // Casos de teste especificados no roteiro
        vetor_teste[0] = 7'b0110101;  // 35h ('5') -> 4 uns -> paridade par = 0
        vetor_teste[1] = 7'b1010101;  // 55h ('U') -> 4 uns -> paridade par = 0
        vetor_teste[2] = 7'b1111110;  // 7Eh ('~') -> 6 uns -> paridade par = 0
        vetor_teste[3] = 7'b1111111;  // 7Fh (DEL) -> 7 uns -> paridade par = 1

        // Inicializacao dos sinais
        clock_in         = 1'b0;
        reset_in         = 1'b0;
        partida_in       = 1'b0;
        dados_ascii_7_in = 7'b0000000;
        errors           = 0;

        // Reset global
        @(negedge clock_in);
        reset_in = 1'b1;
        #(20 * CLOCK_PERIOD);
        @(negedge clock_in);
        reset_in = 1'b0;
        $display("... reset aplicado com sucesso");
        #(50 * CLOCK_PERIOD);

        // Execucao dos casos de teste
        for (caso = 0; caso < 4; caso = caso + 1) begin
            exp_dado     = vetor_teste[caso];
            exp_paridade = ^exp_dado;

            // Configuracao dos dados de entrada
            dados_ascii_7_in = exp_dado;
            #(20 * CLOCK_PERIOD);

            $display("[INFO] Iniciando Caso %0d: dado=7'h%02h (%07b), paridade esperada=%b", 
                     caso, exp_dado, exp_dado, exp_paridade);

            // Pulso de partida
            @(negedge clock_in);
            partida_in = 1'b1;
            #(25 * CLOCK_PERIOD);
            @(negedge clock_in);
            partida_in = 1'b0;

            // 1. Verificacao do Start bit (apos tick 1 + atualizacao do registrador)
            @(posedge db_tick_out);
            #(5 * CLOCK_PERIOD);
            if (saida_serial_out !== 1'b0) begin
                $display("[ERRO] Caso %0d: Start bit invalido! Esperado 0, obtido %b", caso, saida_serial_out);
                errors = errors + 1;
            end

            // 2. Verificacao dos 7 bits de dados (LSB primeiro, ticks 2 a 8)
            for (bit_idx = 0; bit_idx < 7; bit_idx = bit_idx + 1) begin
                @(posedge db_tick_out);
                #(5 * CLOCK_PERIOD);
                if (saida_serial_out !== exp_dado[bit_idx]) begin
                    $display("[ERRO] Caso %0d: Bit %0d invalido! Esperado %b, obtido %b", 
                             caso, bit_idx, exp_dado[bit_idx], saida_serial_out);
                    errors = errors + 1;
                end
            end

            // 3. Verificacao do bit de paridade par (tick 9)
            @(posedge db_tick_out);
            #(5 * CLOCK_PERIOD);
            if (saida_serial_out !== exp_paridade) begin
                $display("[ERRO] Caso %0d: Bit de paridade invalido! Esperado %b, obtido %b", 
                             caso, exp_paridade, saida_serial_out);
                errors = errors + 1;
            end

            // 4. Verificacao do Stop bit (esperado 1'b1, tick 10)
            @(posedge db_tick_out);
            #(5 * CLOCK_PERIOD);
            if (saida_serial_out !== 1'b1) begin
                $display("[ERRO] Caso %0d: Stop bit invalido! Esperado 1, obtido %b", caso, saida_serial_out);
                errors = errors + 1;
            end

            // 5. Espera sinal de pronto
            wait (pronto_out == 1'b1);
            $display("[OK] Caso %0d finalizado com sucesso!", caso);

            // Intervalo entre casos de teste
            #(100 * CLOCK_PERIOD);
        end

        // Relatorio final de verificacao
        #(20 * CLOCK_PERIOD);
        $display("----------------------------------------");
        if (errors == 0) begin
            $display("SUCCESS: ALL TESTBENCH CHECKS PASSED!");
        end else begin
            $display("FAILURE: %0d error(s) detected!", errors);
        end
        $display("----------------------------------------");
        $finish;
    end

endmodule

`default_nettype wire