`default_nettype none
`timescale 1ns/1ns

module exp4_desafio_tb;

    // 1. Sinais internos de estimulo e monitoramento
    reg        clock_in;
    reg        reset_in;
    reg        mensurar_in;
    reg        echo_in;
    wire       trigger_out;
    wire       saida_serial_out;
    wire [6:0] medida0_out;
    wire [6:0] medida1_out;
    wire [6:0] medida2_out;
    wire       pronto_out;
    wire       db_mensurar_out;
    wire       db_echo_out;
    wire       db_trigger_out;
    wire       db_saida_serial_out;
    wire       db_espera_2s_out;
    wire       db_segunda_medida_out;
    wire [6:0] db_estado_out;

    // Periodo do clock: 50 MHz (T = 20ns, semi-periodo = 10ns)
    localparam CLOCK_PERIOD = 20;
    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    // Fast simulation parameter para o intervalo: 5000 ciclos = 100 us
    localparam SIM_M_INTERVALO = 5000;
    localparam SIM_N_INTERVALO = 13;

    // 2. Instanciacao do DUT com override para simulacao rapida
    exp4_desafio #(
        .M_INTERVALO (SIM_M_INTERVALO),
        .N_INTERVALO (SIM_N_INTERVALO)
    ) dut (
        .clock             (clock_in),
        .reset             (reset_in),
        .mensurar          (mensurar_in),
        .echo              (echo_in),
        .trigger           (trigger_out),
        .saida_serial      (saida_serial_out),
        .medida0           (medida0_out),
        .medida1           (medida1_out),
        .medida2           (medida2_out),
        .pronto            (pronto_out),
        .db_mensurar       (db_mensurar_out),
        .db_echo           (db_echo_out),
        .db_trigger        (db_trigger_out),
        .db_saida_serial   (db_saida_serial_out),
        .db_espera_2s      (db_espera_2s_out),
        .db_segunda_medida (db_segunda_medida_out),
        .db_estado         (db_estado_out)
    );

    integer errors = 0;

    // Decodificador de display de 7 segmentos para verificacao
    function [6:0] bcd_to_7seg;
        input [3:0] bcd;
        case (bcd)
            4'h0: bcd_to_7seg = 7'b1000000;
            4'h1: bcd_to_7seg = 7'b1111001;
            4'h2: bcd_to_7seg = 7'b0100100;
            4'h3: bcd_to_7seg = 7'b0110000;
            4'h4: bcd_to_7seg = 7'b0011001;
            4'h5: bcd_to_7seg = 7'b0010010;
            4'h6: bcd_to_7seg = 7'b0000010;
            4'h7: bcd_to_7seg = 7'b1111000;
            4'h8: bcd_to_7seg = 7'b0000000;
            4'h9: bcd_to_7seg = 7'b0010000;
            default: bcd_to_7seg = 7'b1111111;
        endcase
    endfunction

    // Task para recepcao de 1 byte serial 115200 7E1 (LSB primeiro)
    task uart_receive_byte;
        output [6:0] data_out;
        output       parity_err_out;
        output       stop_err_out;
        reg [6:0]    rx_shift;
        integer      i;
        localparam BAUD_PERIOD = 8680; // 434 * 20 ns = 8680 ns
        begin
            // Aguarda borda de descida do start bit
            @(negedge saida_serial_out);
            // Posiciona no centro do start bit (0.5 baud)
            #(BAUD_PERIOD / 2);
            if (saida_serial_out !== 1'b0) begin
                $display("  [UART RX ERRO] Start bit invalido! Esperado 0, obtido %b", saida_serial_out);
            end

            // Amostra os 7 bits de dados (centro de cada bit)
            for (i = 0; i < 7; i = i + 1) begin
                #(BAUD_PERIOD);
                rx_shift[i] = saida_serial_out;
            end

            // Amostra bit de paridade par
            #(BAUD_PERIOD);
            parity_err_out = (saida_serial_out !== (^rx_shift));
            if (parity_err_out) begin
                $display("  [UART RX ERRO] Bit de paridade invalido! Obtido: %b, Esperado: %b", saida_serial_out, ^rx_shift);
            end

            // Amostra stop bit
            #(BAUD_PERIOD);
            stop_err_out = (saida_serial_out !== 1'b1);
            if (stop_err_out) begin
                $display("  [UART RX ERRO] Stop bit invalido! Esperado 1, obtido %b", saida_serial_out);
            end

            data_out = rx_shift;

            // Avanca alem do meio do stop bit para nao confundir com proximo start
            #(BAUD_PERIOD / 2);
        end
    endtask

    // Task para simular um ciclo de eco ultrassonico e receber a saida serial da medida
    task executa_e_verifica_medida;
        input integer tempo_eco_us;
        input [11:0]  medida_esperada_bcd;
        input [6:0]   char_c;
        input [6:0]   char_d;
        input [6:0]   char_u;
        input         espera_segunda;

        reg [6:0] b0, b1, b2, b3;
        reg       p0, p1, p2, p3;
        reg       s0, s1, s2, s3;
        begin
            // Espera trigger do sensor
            wait (trigger_out == 1'b1);
            $display("    [%0t ns] Trigger ativado pelo circuito!", $time);
            wait (trigger_out == 1'b0);
            $display("    [%0t ns] Trigger desativado.", $time);

            // Verifica sinal de depuracao de segunda medida
            if (db_segunda_medida_out !== espera_segunda) begin
                $display("    [FALHA] db_segunda_medida incorreto! Obtido: %b, Esperado: %b",
                         db_segunda_medida_out, espera_segunda);
                errors = errors + 1;
            end

            // Intervalo tipico entre trigger e eco (400 us)
            #(400_000);

            // Gera pulso de eco
            $display("    [%0t ns] Gerando pulso de eco (duracao: %0d us)...", $time, tempo_eco_us);
            echo_in = 1'b1;
            #(tempo_eco_us * 1000);
            echo_in = 1'b0;

            // Recebe 4 caracteres seriais
            $display("    [%0t ns] Aguardando transmissao serial 115200 7E1...", $time);
            uart_receive_byte(b0, p0, s0);
            uart_receive_byte(b1, p1, s1);
            uart_receive_byte(b2, p2, s2);
            uart_receive_byte(b3, p3, s3);

            $display("    Bytes recebidos: '%c' (0x%02h), '%c' (0x%02h), '%c' (0x%02h), '%c' (0x%02h)",
                     b0, b0, b1, b1, b2, b2, b3, b3);

            // Verificacao dos caracteres
            if (b0 !== char_c || p0 || s0) begin
                $display("    [FALHA] Centena incorreta! Obtido: 0x%02h ('%c'), Esperado: 0x%02h ('%c')",
                         b0, b0, char_c, char_c);
                errors = errors + 1;
            end
            if (b1 !== char_d || p1 || s1) begin
                $display("    [FALHA] Dezena incorreta! Obtido: 0x%02h ('%c'), Esperado: 0x%02h ('%c')",
                         b1, b1, char_d, char_d);
                errors = errors + 1;
            end
            if (b2 !== char_u || p2 || s2) begin
                $display("    [FALHA] Unidade incorreta! Obtido: 0x%02h ('%c'), Esperado: 0x%02h ('%c')",
                         b2, b2, char_u, char_u);
                errors = errors + 1;
            end
            if (b3 !== 7'h23 || p3 || s3) begin
                $display("    [FALHA] Terminador incorreto! Obtido: 0x%02h ('%c'), Esperado: 0x23 ('#')",
                         b3, b3);
                errors = errors + 1;
            end

            // Verificacao dos displays de 7 segmentos
            if (medida2_out !== bcd_to_7seg(medida_esperada_bcd[11:8])) begin
                $display("    [FALHA] Display HEX2 incorreto! Obtido: %b, Esperado: %b",
                         medida2_out, bcd_to_7seg(medida_esperada_bcd[11:8]));
                errors = errors + 1;
            end
            if (medida1_out !== bcd_to_7seg(medida_esperada_bcd[7:4])) begin
                $display("    [FALHA] Display HEX1 incorreto! Obtido: %b, Esperado: %b",
                         medida1_out, bcd_to_7seg(medida_esperada_bcd[7:4]));
                errors = errors + 1;
            end
            if (medida0_out !== bcd_to_7seg(medida_esperada_bcd[3:0])) begin
                $display("    [FALHA] Display HEX0 incorreto! Obtido: %b, Esperado: %b",
                         medida0_out, bcd_to_7seg(medida_esperada_bcd[3:0]));
                errors = errors + 1;
            end
        end
    endtask

    // Watchdog timer para evitar travamento da simulacao
    initial begin
        #(200_000_000); // 200 ms de limite de simulacao
        $display("\n[ERRO] Watchdog timeout alcancado na simulacao!");
        $finish;
    end

    // Procedimento principal de teste
    initial begin
        $dumpfile("exp4_desafio.vcd");
        $dumpvars(0, exp4_desafio_tb);

        $display("===================================================================");
        $display("   INICIO DA SIMULACAO AUTO-VERIFICAVEL: exp4_desafio_tb");
        $display("===================================================================");

        // Inicializacao dos estimulos
        clock_in    = 1'b0;
        reset_in    = 1'b0;
        mensurar_in = 1'b1; // Repouso do botao da placa DE0-CV (ativo em baixo)
        echo_in     = 1'b0;
        errors      = 0;

        // Reset global
        #(2 * CLOCK_PERIOD);
        reset_in = 1'b1;
        #(2_000); // 2 us
        @(negedge clock_in);
        reset_in = 1'b0;
        $display("... reset global aplicado com sucesso");
        #(50_000); // 50 us de estabilizacao

        // -------------------------------------------------------------
        // PLANO DE TESTES - CASO 1: Duas medidas consecutivas DIFERENTES
        // Medida 1: 15 cm (882 us)  -> '0', '1', '5', '#'
        // Intervalo de 2s (simulado: 5000 ciclos / 100 us)
        // Medida 2: 74 cm (4353 us) -> '0', '7', '4', '#'
        // -------------------------------------------------------------
        $display("\n=================================================================");
        $display(">>> TESTE 1: Medidas consecutivas DIFERENTES (15 cm e 74 cm) <<<");
        $display("=================================================================");

        // Envia pulso mensurar (ativo em baixo, 2 ciclos de clock)
        @(negedge clock_in);
        mensurar_in = 1'b0;
        #(2 * CLOCK_PERIOD);
        mensurar_in = 1'b1;

        $display("  [Medida 1] Executando 1a medida (15 cm)...");
        executa_e_verifica_medida(882, 12'h015, 7'h30, 7'h31, 7'h35, 1'b0);

        // Verifica entrada no intervalo de espera (db_espera_2s deve ir para 1)
        wait (db_espera_2s_out == 1'b1);
        $display("  [Intervalo] Sinal db_espera_2s ativado com sucesso em %0t ns", $time);

        // Aguarda transicao para a 2a medida (db_espera_2s desce e trigger ativa)
        wait (db_espera_2s_out == 1'b0);
        $display("  [Intervalo] Fim do intervalo de espera em %0t ns", $time);

        $display("  [Medida 2] Executando 2a medida (74 cm)...");
        executa_e_verifica_medida(4353, 12'h074, 7'h30, 7'h37, 7'h34, 1'b1);

        // Aguarda finalizacao do ciclo completo (pronto_out)
        wait (pronto_out == 1'b1);
        $display("  [Conclusao] Sinal pronto ativado em %0t ns!", $time);

        if (errors == 0) begin
            $display("  >>> TESTE 1 CONCLUIDO COM SUCESSO! <<<");
        end else begin
            $display("  >>> TESTE 1 DETECTOU ERRO(S)! <<<");
        end

        // Intervalo entre testes
        #(100_000);

        // -------------------------------------------------------------
        // PLANO DE TESTES - CASO 2: Duas medidas consecutivas IGUAIS
        // Medida 1: 172 cm (10118 us) -> '1', '7', '2', '#'
        // Intervalo de 2s (simulado: 5000 ciclos / 100 us)
        // Medida 2: 172 cm (10118 us) -> '1', '7', '2', '#'
        // -------------------------------------------------------------
        $display("\n=================================================================");
        $display(">>> TESTE 2: Medidas consecutivas IGUAIS (172 cm e 172 cm) <<<");
        $display("=================================================================");

        @(negedge clock_in);
        mensurar_in = 1'b0;
        #(2 * CLOCK_PERIOD);
        mensurar_in = 1'b1;

        $display("  [Medida 1] Executando 1a medida (172 cm)...");
        executa_e_verifica_medida(10118, 12'h172, 7'h31, 7'h37, 7'h32, 1'b0);

        wait (db_espera_2s_out == 1'b1);
        $display("  [Intervalo] Sinal db_espera_2s ativado com sucesso em %0t ns", $time);

        wait (db_espera_2s_out == 1'b0);
        $display("  [Intervalo] Fim do intervalo de espera em %0t ns", $time);

        $display("  [Medida 2] Executando 2a medida (172 cm)...");
        executa_e_verifica_medida(10118, 12'h172, 7'h31, 7'h37, 7'h32, 1'b1);

        wait (pronto_out == 1'b1);
        $display("  [Conclusao] Sinal pronto ativado em %0t ns!", $time);

        if (errors == 0) begin
            $display("  >>> TESTE 2 CONCLUIDO COM SUCESSO! <<<");
        end else begin
            $display("  >>> TESTE 2 DETECTOU ERRO(S)! <<<");
        end

        // -------------------------------------------------------------
        // Relatorio de Conformidade Final
        // -------------------------------------------------------------
        $display("\n===================================================================");
        if (errors == 0) begin
            $display("------------------------------------------------------------");
            $display("SUCCESS: ALL TESTBENCH CHECKS PASSED!");
            $display("------------------------------------------------------------");
            $display("   RESULTADO: TODOS OS TESTES DO DESAFIO PASSARAM COM SUCESSO!");
        end else begin
            $display("------------------------------------------------------------");
            $display("FAILURE: %0d error(s) detected!", errors);
            $display("------------------------------------------------------------");
        end
        $display("===================================================================\n");

        $finish;
    end

endmodule

`default_nettype wire
