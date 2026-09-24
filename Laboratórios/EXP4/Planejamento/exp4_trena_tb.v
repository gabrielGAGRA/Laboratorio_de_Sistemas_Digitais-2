`default_nettype none
`timescale 1ns/1ns

module exp4_trena_tb;

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
    wire [6:0] db_estado_out;

    // Periodo do clock: 50 MHz (T = 20ns, semi-periodo = 10ns)
    localparam CLOCK_PERIOD = 20;
    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    // 2. Instanciacao do DUT
    exp4_trena dut (
        .clock           (clock_in),
        .reset           (reset_in),
        .mensurar        (mensurar_in),
        .echo            (echo_in),
        .trigger         (trigger_out),
        .saida_serial    (saida_serial_out),
        .medida0         (medida0_out),
        .medida1         (medida1_out),
        .medida2         (medida2_out),
        .pronto          (pronto_out),
        .db_mensurar     (db_mensurar_out),
        .db_echo         (db_echo_out),
        .db_trigger      (db_trigger_out),
        .db_saida_serial (db_saida_serial_out),
        .db_estado       (db_estado_out)
    );

    // 3. Definicao dos casos de teste
    localparam NUM_CASOS = 5;
    reg [31:0] casos_tempo     [0:NUM_CASOS-1]; // tempo em us
    reg [11:0] casos_esperados [0:NUM_CASOS-1]; // medida esperada em BCD (12 bits)
    reg [6:0]  casos_ascii_c   [0:NUM_CASOS-1]; // caractere ASCII Centena
    reg [6:0]  casos_ascii_d   [0:NUM_CASOS-1]; // caractere ASCII Dezena
    reg [6:0]  casos_ascii_u   [0:NUM_CASOS-1]; // caractere ASCII Unidade

    integer caso;
    integer errors = 0;
    reg [31:0] larguraPulso;

    // Variaveis para recepcao serial UART
    reg [6:0] rx_byte0, rx_byte1, rx_byte2, rx_byte3;
    reg       rx_err_par0, rx_err_par1, rx_err_par2, rx_err_par3;
    reg       rx_err_stp0, rx_err_stp1, rx_err_stp2, rx_err_stp3;

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

    // Watchdog timer para evitar travamento da simulacao
    initial begin
        #(100_000_000); // 100 ms de simulacao
        $display("\n[ERRO] Watchdog timeout alcancado na simulacao!");
        $finish;
    end

    // Procedimento de teste principal
    initial begin
        // Dump VCD para analise e depuracao
        $dumpfile("exp4_trena.vcd");
        $dumpvars(0, exp4_trena_tb);

        // Inicializacao dos casos de teste
        // Caso 0: 2 cm -> 118 us
        casos_tempo[0]     = 118;
        casos_esperados[0] = 12'h002;
        casos_ascii_c[0]   = 7'h30; // '0'
        casos_ascii_d[0]   = 7'h30; // '0'
        casos_ascii_u[0]   = 7'h32; // '2'

        // Caso 1: 15 cm -> 882 us
        casos_tempo[1]     = 882;
        casos_esperados[1] = 12'h015;
        casos_ascii_c[1]   = 7'h30; // '0'
        casos_ascii_d[1]   = 7'h31; // '1'
        casos_ascii_u[1]   = 7'h35; // '5'

        // Caso 2: 74 cm -> 4353 us
        casos_tempo[2]     = 4353;
        casos_esperados[2] = 12'h074;
        casos_ascii_c[2]   = 7'h30; // '0'
        casos_ascii_d[2]   = 7'h37; // '7'
        casos_ascii_u[2]   = 7'h34; // '4'

        // Caso 3: 172 cm (caso de referencia do roteiro) -> 10118 us
        casos_tempo[3]     = 10118;
        casos_esperados[3] = 12'h172;
        casos_ascii_c[3]   = 7'h31; // '1'
        casos_ascii_d[3]   = 7'h37; // '7'
        casos_ascii_u[3]   = 7'h32; // '2'

        // Caso 4: 250 cm -> 14706 us
        casos_tempo[4]     = 14706;
        casos_esperados[4] = 12'h250;
        casos_ascii_c[4]   = 7'h32; // '2'
        casos_ascii_d[4]   = 7'h35; // '5'
        casos_ascii_u[4]   = 7'h30; // '0'

        $display("===================================================================");
        $display("   INICIO DA SIMULACAO AUTO-VERIFICAVEL: exp4_trena_tb");
        $display("===================================================================");

        // Inicializacao dos sinais
        clock_in    = 1'b0;
        reset_in    = 1'b0;
        mensurar_in = 1'b1; // Repouso do botao (ativo em baixo)
        echo_in     = 1'b0;
        errors      = 0;

        // Reset global do circuito
        #(2 * CLOCK_PERIOD);
        reset_in = 1'b1;
        #(2_000); // 2 us
        @(negedge clock_in);
        reset_in = 1'b0;
        $display("... reset aplicado com sucesso");
        #(100_000); // 100 us de estabilizacao

        // 4. Loop dos casos de teste
        for (caso = 0; caso < NUM_CASOS; caso = caso + 1) begin
            // 4.1 Atribui sinal com valor do caso de teste (largura de pulso echo)
            larguraPulso = casos_tempo[caso] * 1000; // converte us para ns

            $display("\n--- Caso de Teste %0d: Distancia = %0d cm (Pulso Echo = %0d us) ---",
                     caso,
                     (casos_esperados[caso][11:8]*100 + casos_esperados[caso][7:4]*10 + casos_esperados[caso][3:0]),
                     casos_tempo[caso]);

            // 4.2 Envia pulso mensurar (ativo em baixo no botao, duracao de 2 ciclos de clock)
            @(negedge clock_in);
            mensurar_in = 1'b0;
            #(2 * CLOCK_PERIOD);
            mensurar_in = 1'b1;

            // Espera trigger subir e descer
            wait (trigger_out == 1'b1);
            $display("  [%0t ns] Trigger ativado!", $time);
            wait (trigger_out == 1'b0);
            $display("  [%0t ns] Trigger desativado.", $time);

            // 4.3 Espera 400 us (tempo entre pulsos trigger e echo)
            #(400_000);

            // 4.4 Gera pulso echo com largura definida
            $display("  [%0t ns] Gerando pulso de eco (duracao: %0d us)...", $time, casos_tempo[caso]);
            echo_in = 1'b1;
            #(larguraPulso);
            echo_in = 1'b0;

            // 4.5 Espera e recebe a transmissao serial da medida (4 caracteres: C, D, U, '#')
            $display("  [%0t ns] Aguardando e decodificando transmissao serial 115200 7E1...", $time);
            uart_receive_byte(rx_byte0, rx_err_par0, rx_err_stp0);
            uart_receive_byte(rx_byte1, rx_err_par1, rx_err_stp1);
            uart_receive_byte(rx_byte2, rx_err_par2, rx_err_stp2);
            uart_receive_byte(rx_byte3, rx_err_par3, rx_err_stp3);

            // Aguarda sinal pronto da trena
            wait (pronto_out == 1'b1);
            $display("  [%0t ns] Sinal pronto_out ativado!", $time);

            // Verificacao dos caracteres recebidos
            $display("  Caracteres recebidos via UART: '%c' (0x%02h), '%c' (0x%02h), '%c' (0x%02h), '%c' (0x%02h)",
                     rx_byte0, rx_byte0, rx_byte1, rx_byte1, rx_byte2, rx_byte2, rx_byte3, rx_byte3);

            if (rx_byte0 !== casos_ascii_c[caso] || rx_err_par0 || rx_err_stp0) begin
                $display("  [FALHA] Centena serial incorreta! Obtido: 0x%02h ('%c'), Esperado: 0x%02h ('%c')",
                         rx_byte0, rx_byte0, casos_ascii_c[caso], casos_ascii_c[caso]);
                errors = errors + 1;
            end

            if (rx_byte1 !== casos_ascii_d[caso] || rx_err_par1 || rx_err_stp1) begin
                $display("  [FALHA] Dezena serial incorreta! Obtido: 0x%02h ('%c'), Esperado: 0x%02h ('%c')",
                         rx_byte1, rx_byte1, casos_ascii_d[caso], casos_ascii_d[caso]);
                errors = errors + 1;
            end

            if (rx_byte2 !== casos_ascii_u[caso] || rx_err_par2 || rx_err_stp2) begin
                $display("  [FALHA] Unidade serial incorreta! Obtido: 0x%02h ('%c'), Esperado: 0x%02h ('%c')",
                         rx_byte2, rx_byte2, casos_ascii_u[caso], casos_ascii_u[caso]);
                errors = errors + 1;
            end

            if (rx_byte3 !== 7'h23 || rx_err_par3 || rx_err_stp3) begin
                $display("  [FALHA] Terminador '#' serial incorreto! Obtido: 0x%02h ('%c'), Esperado: 0x23 ('#')",
                         rx_byte3, rx_byte3);
                errors = errors + 1;
            end

            // Verificacao dos displays de 7 segmentos
            if (medida2_out !== bcd_to_7seg(casos_esperados[caso][11:8])) begin
                $display("  [FALHA] Display HEX2 (Centena) incorreto! Obtido: %b, Esperado: %b",
                         medida2_out, bcd_to_7seg(casos_esperados[caso][11:8]));
                errors = errors + 1;
            end

            if (medida1_out !== bcd_to_7seg(casos_esperados[caso][7:4])) begin
                $display("  [FALHA] Display HEX1 (Dezena) incorreto! Obtido: %b, Esperado: %b",
                         medida1_out, bcd_to_7seg(casos_esperados[caso][7:4]));
                errors = errors + 1;
            end

            if (medida0_out !== bcd_to_7seg(casos_esperados[caso][3:0])) begin
                $display("  [FALHA] Display HEX0 (Unidade) incorreto! Obtido: %b, Esperado: %b",
                         medida0_out, bcd_to_7seg(casos_esperados[caso][3:0]));
                errors = errors + 1;
            end

            if (errors == 0) begin
                $display("  [SUCESSO] Caso %0d verificado com sucesso na UART e nos displays HEX!", caso);
            end

            // 4.6 Espera 100 us entre casos de teste
            #(100_000);
        end

        // 5. Fim da simulacao com relatorio de conformidade
        $display("\n===================================================================");
        if (errors == 0) begin
            $display("------------------------------------------------------------");
            $display("SUCCESS: ALL TESTBENCH CHECKS PASSED!");
            $display("------------------------------------------------------------");
            $display("   RESULTADO: TODOS OS %0d CASOS DE TESTE PASSARAM COM SUCESSO!", NUM_CASOS);
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
