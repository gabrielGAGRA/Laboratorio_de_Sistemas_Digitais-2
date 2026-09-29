`default_nettype none
`timescale 1ns/1ns

module transmissor_sonar_tb;

    reg         clock;
    reg         reset;
    reg         transmitir;
    reg  [23:0] angulo;
    reg  [11:0] distancia;
    wire        saida_serial;
    wire        pronto;
    wire        db_partida;
    wire        db_saida_serial;
    wire [3:0]  db_estado;

    integer errors = 0;
    integer byte_idx;
    integer bit_idx;
    reg [6:0] byte_recebido;
    reg       bit_paridade;

    localparam CLOCK_PERIOD = 20; // 50 MHz
    localparam BIT_PERIOD   = 434 * CLOCK_PERIOD; // 115200 bauds: 434 clocks (8680 ns)

    always #(CLOCK_PERIOD / 2) clock = ~clock;

    transmissor_sonar dut (
        .clock           (clock),
        .reset           (reset),
        .transmitir      (transmitir),
        .angulo          (angulo),
        .distancia       (distancia),
        .saida_serial    (saida_serial),
        .pronto          (pronto),
        .db_partida      (db_partida),
        .db_saida_serial (db_saida_serial),
        .db_estado       (db_estado)
    );

    // Array com os 8 caracteres esperados: "120,017#"
    reg [6:0] chars_esperados [0:7];

    initial begin
        #(2000000 * CLOCK_PERIOD);
        $display("[ERRO] Watchdog timeout alcancado na simulacao!");
        $finish;
    end

    initial begin
        $dumpfile("transmissor_sonar_tb.vcd");
        $dumpvars(0, transmissor_sonar_tb);

        chars_esperados[0] = 7'h31; // '1'
        chars_esperados[1] = 7'h32; // '2'
        chars_esperados[2] = 7'h30; // '0'
        chars_esperados[3] = 7'h2C; // ','
        chars_esperados[4] = 7'h30; // '0'
        chars_esperados[5] = 7'h31; // '1'
        chars_esperados[6] = 7'h37; // '7'
        chars_esperados[7] = 7'h23; // '#'

        clock      = 0;
        reset      = 0;
        transmitir = 0;
        angulo     = 24'h313230; // "120"
        distancia  = 12'h017;    // 017 cm

        // Reset
        @(negedge clock);
        reset = 1;
        #(5 * CLOCK_PERIOD);
        @(negedge clock);
        reset = 0;
        #(20 * CLOCK_PERIOD);

        $display("Iniciando transmissao do bloco de 8 caracteres: angulo=%h, distancia=%h", angulo, distancia);

        @(negedge clock);
        transmitir = 1;
        #(CLOCK_PERIOD);
        @(negedge clock);
        transmitir = 0;

        // Recebe e valida os 8 caracteres
        for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
            // 1. Aguarda borda de descida do start bit
            @(negedge saida_serial);
            // Salta para o meio do start bit (BIT_PERIOD / 2)
            #(BIT_PERIOD / 2);
            if (saida_serial !== 1'b0) begin
                $display("[ERRO] Byte %0d: Start bit invalido!", byte_idx);
                errors = errors + 1;
            end

            // 2. Amostra 7 bits de dados
            byte_recebido = 7'd0;
            for (bit_idx = 0; bit_idx < 7; bit_idx = bit_idx + 1) begin
                #(BIT_PERIOD);
                byte_recebido[bit_idx] = saida_serial;
            end

            // 3. Amostra paridade par
            #(BIT_PERIOD);
            bit_paridade = saida_serial;
            if (bit_paridade !== ^byte_recebido) begin
                $display("[ERRO] Byte %0d: Erro de paridade! Recebido=%b, esperado=%b",
                         byte_idx, bit_paridade, ^byte_recebido);
                errors = errors + 1;
            end

            // 4. Amostra stop bit
            #(BIT_PERIOD);
            if (saida_serial !== 1'b1) begin
                $display("[ERRO] Byte %0d: Stop bit invalido!", byte_idx);
                errors = errors + 1;
            end

            // Valida caractere recebido
            if (byte_recebido === chars_esperados[byte_idx]) begin
                $display("  [OK] Byte %0d: '%c' (7'h%02h)", byte_idx, byte_recebido, byte_recebido);
            end else begin
                $display("  [ERRO] Byte %0d: Recebido '%c' (7'h%02h), Esperado '%c' (7'h%02h)",
                         byte_idx, byte_recebido, byte_recebido,
                         chars_esperados[byte_idx], chars_esperados[byte_idx]);
                errors = errors + 1;
            end
        end

        // Aguarda sinal pronto do transmissor
        wait (pronto == 1'b1);
        $display("Sinal pronto ativado com sucesso!");

        #(50 * CLOCK_PERIOD);

        if (errors == 0) begin
            $display("\nSUCCESS: ALL TESTBENCH CHECKS PASSED! (Mensagem '120,017#' transmitida corretamente)");
        end else begin
            $display("\nFAILURE: %0d error(s) detected", errors);
        end

        $finish;
    end

endmodule

`default_nettype wire
