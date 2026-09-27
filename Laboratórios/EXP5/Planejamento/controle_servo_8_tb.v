`default_nettype none
`timescale 1ns/1ns

module controle_servo_8_tb;

    reg        clock;
    reg        reset;
    reg  [2:0] posicao;
    wire       controle;
    wire       db_reset;
    wire [2:0] db_posicao;
    wire       db_controle;

    integer errors = 0;
    integer caso = 0;

    localparam CLOCK_PERIOD = 20; // 50 MHz (20 ns)

    // Fast simulation parameters (scaled down to verify logic quickly)
    localparam TEST_PERIODO = 20000; // 20000 cycles = 400 us
    localparam W_000 = 700;
    localparam W_001 = 914;
    localparam W_010 = 1129;
    localparam W_011 = 1343;
    localparam W_100 = 1557;
    localparam W_101 = 1771;
    localparam W_110 = 1986;
    localparam W_111 = 2200;

    // DUT instantiation
    controle_servo_8 #(
        .CONF_PERIODO (TEST_PERIODO),
        .LARGURA_000  (W_000),
        .LARGURA_001  (W_001),
        .LARGURA_010  (W_010),
        .LARGURA_011  (W_011),
        .LARGURA_100  (W_100),
        .LARGURA_101  (W_101),
        .LARGURA_110  (W_110),
        .LARGURA_111  (W_111)
    ) dut (
        .clock       (clock),
        .reset       (reset),
        .posicao     (posicao),
        .controle    (controle),
        .db_reset    (db_reset),
        .db_posicao  (db_posicao),
        .db_controle (db_controle)
    );

    // Clock generator
    always #(CLOCK_PERIOD / 2) clock = ~clock;

    // Task to measure pulse width
    task check_pulse_width;
        input [2:0] pos_val;
        input integer expected_cycles;
        time t_start, t_end;
        integer measured_cycles;
        begin
            posicao = pos_val;
            // Wait for rising edge of controle
            @(posedge controle);
            t_start = $time;
            @(negedge controle);
            t_end = $time;
            measured_cycles = (t_end - t_start) / CLOCK_PERIOD;
            if (measured_cycles != expected_cycles) begin
                $display("ERRO no caso %0d: posicao=%b, medido=%0d ciclos, esperado=%0d ciclos",
                         caso, pos_val, measured_cycles, expected_cycles);
                errors = errors + 1;
            end else begin
                $display("OK caso %0d: posicao=%b, pulso=%0d ciclos (%0d ns)",
                         caso, pos_val, measured_cycles, (t_end - t_start));
            end
        end
    endtask

    initial begin
        $dumpfile("controle_servo_8_tb.vcd");
        $dumpvars(0, controle_servo_8_tb);

        clock = 0;
        reset = 1;
        posicao = 3'b000;

        #(5 * CLOCK_PERIOD);
        @(negedge clock);
        reset = 0;

        // Check debug output pass-through
        if (db_reset !== 1'b0) begin
            $display("ERRO: db_reset nao reflete reset");
            errors = errors + 1;
        end

        // Wait one period to load initial width
        @(posedge controle);
        @(negedge controle);

        caso = 1; check_pulse_width(3'b000, W_000);
        caso = 2; check_pulse_width(3'b001, W_001);
        caso = 3; check_pulse_width(3'b010, W_010);
        caso = 4; check_pulse_width(3'b011, W_011);
        caso = 5; check_pulse_width(3'b100, W_100);
        caso = 6; check_pulse_width(3'b101, W_101);
        caso = 7; check_pulse_width(3'b110, W_110);
        caso = 8; check_pulse_width(3'b111, W_111);

        if (errors == 0) begin
            $display("\nSUCCESS: ALL TESTBENCH CHECKS PASSED! (8/8 posicoes validadas)");
        end else begin
            $display("\nFAILURE: %0d error(s) detected", errors);
        end

        $finish;
    end

endmodule

`default_nettype wire
