`default_nettype none
`timescale 1ns/1ns

module tx_serial_7E1_tb;

    reg        clock_in;
    reg        reset_in;
    reg        partida_in;
    reg  [6:0] dados_ascii_7_in;
    wire       saida_serial_out;
    wire       pronto_out;
    wire       db_partida_out;
    wire       db_saida_serial_out;
    wire [3:0] db_estado_out;

    // DUT refatorado para EXP5
    tx_serial_7E1 u_dut (
        .clock           (clock_in),
        .reset           (reset_in),
        .partida         (partida_in),
        .dados_ascii     (dados_ascii_7_in),
        .saida_serial    (saida_serial_out),
        .pronto          (pronto_out),
        .db_partida      (db_partida_out),
        .db_saida_serial (db_saida_serial_out),
        .db_estado       (db_estado_out)
    );

    wire db_tick_out = u_dut.u_contador_tick.fim;

    localparam CLOCK_PERIOD = 20; // 50 MHz
    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    reg [6:0] vetor_teste [0:3];
    integer caso;
    integer errors = 0;
    integer bit_idx;
    reg       exp_paridade;
    reg [6:0] exp_dado;

    initial begin
        #(2000000 * CLOCK_PERIOD);
        $display("[ERRO] Watchdog timeout alcancado na simulacao!");
        $finish;
    end

    initial begin
        $dumpfile("tx_serial_7E1_tb.vcd");
        $dumpvars(0, tx_serial_7E1_tb);

        $display("Inicio da simulacao: tx_serial_7E1");

        vetor_teste[0] = 7'b0110101;  // 35h ('5') -> 4 uns -> paridade par = 0
        vetor_teste[1] = 7'b1010101;  // 55h ('U') -> 4 uns -> paridade par = 0
        vetor_teste[2] = 7'b1111110;  // 7Eh ('~') -> 6 uns -> paridade par = 0
        vetor_teste[3] = 7'b1111111;  // 7Fh (DEL) -> 7 uns -> paridade par = 1

        clock_in         = 1'b0;
        reset_in         = 1'b0;
        partida_in       = 1'b0;
        dados_ascii_7_in = 7'b0000000;
        errors           = 0;

        @(negedge clock_in);
        reset_in = 1'b1;
        #(20 * CLOCK_PERIOD);
        @(negedge clock_in);
        reset_in = 1'b0;
        #(50 * CLOCK_PERIOD);

        for (caso = 0; caso < 4; caso = caso + 1) begin
            exp_dado     = vetor_teste[caso];
            exp_paridade = ^exp_dado;

            dados_ascii_7_in = exp_dado;
            #(20 * CLOCK_PERIOD);

            @(negedge clock_in);
            partida_in = 1'b1;
            #(25 * CLOCK_PERIOD);
            @(negedge clock_in);
            partida_in = 1'b0;

            // 1. Start bit
            @(posedge db_tick_out);
            #(5 * CLOCK_PERIOD);
            if (saida_serial_out !== 1'b0) begin
                $display("[ERRO] Caso %0d: Start bit invalido! Esperado 0, obtido %b", caso, saida_serial_out);
                errors = errors + 1;
            end

            // 2. 7 bits de dados
            for (bit_idx = 0; bit_idx < 7; bit_idx = bit_idx + 1) begin
                @(posedge db_tick_out);
                #(5 * CLOCK_PERIOD);
                if (saida_serial_out !== exp_dado[bit_idx]) begin
                    $display("[ERRO] Caso %0d: Bit %0d invalido! Esperado %b, obtido %b", 
                             caso, bit_idx, exp_dado[bit_idx], saida_serial_out);
                    errors = errors + 1;
                end
            end

            // 3. Bit de paridade par
            @(posedge db_tick_out);
            #(5 * CLOCK_PERIOD);
            if (saida_serial_out !== exp_paridade) begin
                $display("[ERRO] Caso %0d: Bit de paridade invalido! Esperado %b, obtido %b", 
                             caso, exp_paridade, saida_serial_out);
                errors = errors + 1;
            end

            // 4. Stop bit
            @(posedge db_tick_out);
            #(5 * CLOCK_PERIOD);
            if (saida_serial_out !== 1'b1) begin
                $display("[ERRO] Caso %0d: Stop bit invalido! Esperado 1, obtido %b", caso, saida_serial_out);
                errors = errors + 1;
            end

            // 5. Espera pronto
            wait (pronto_out == 1'b1);
            $display("[OK] Caso %0d finalizado com sucesso!", caso);

            #(100 * CLOCK_PERIOD);
        end

        #(20 * CLOCK_PERIOD);
        if (errors == 0) begin
            $display("SUCCESS: ALL TESTBENCH CHECKS PASSED!");
        end else begin
            $display("FAILURE: %0d error(s) detected!", errors);
        end
        $finish;
    end

endmodule

`default_nettype wire
