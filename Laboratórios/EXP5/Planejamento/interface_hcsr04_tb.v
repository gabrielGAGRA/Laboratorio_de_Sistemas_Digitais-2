`default_nettype none
`timescale 1ns/1ns

module interface_hcsr04_tb;

    reg         clock_in = 0;
    reg         reset_in = 0;
    reg         medir_in = 0;
    reg         echo_in  = 0;
    wire        trigger_out;
    wire [11:0] medida_out;
    wire        pronto_out;
    wire        db_reset_out;
    wire        db_medir_out;
    wire [3:0]  db_estado_out;

    integer caso;
    integer erros = 0;
    reg [31:0] larguraPulso;

    parameter clockPeriod = 20;
    always #(clockPeriod/2) clock_in = ~clock_in;

    interface_hcsr04 dut (
        .clock    (clock_in     ),
        .reset    (reset_in     ),
        .medir    (medir_in     ),
        .echo     (echo_in      ),
        .trigger  (trigger_out  ),
        .medida   (medida_out   ),
        .pronto   (pronto_out   ),
        .db_reset (db_reset_out ),
        .db_medir (db_medir_out ),
        .db_estado(db_estado_out)
    );

    localparam NUM_CASOS = 7;
    reg [31:0] casos_tempo     [0:NUM_CASOS-1];
    reg [11:0] casos_esperados [0:NUM_CASOS-1];

    initial begin
        $dumpfile("interface_hcsr04_tb.vcd");
        $dumpvars(0, interface_hcsr04_tb);

        casos_tempo[0]     = 118;   casos_esperados[0] = 12'h002;
        casos_tempo[1]     = 882;   casos_esperados[1] = 12'h015;
        casos_tempo[2]     = 4353;  casos_esperados[2] = 12'h074;
        casos_tempo[3]     = 4399;  casos_esperados[3] = 12'h075;
        casos_tempo[4]     = 5882;  casos_esperados[4] = 12'h100;
        casos_tempo[5]     = 5899;  casos_esperados[5] = 12'h100;
        casos_tempo[6]     = 14706; casos_esperados[6] = 12'h250;

        medir_in = 0;
        echo_in  = 0;
        erros    = 0;

        #(2*clockPeriod);
        reset_in = 1;
        #(2_000);
        reset_in = 0;
        @(negedge clock_in);

        #(100_000);

        for (caso = 1; caso <= NUM_CASOS; caso = caso + 1) begin
            larguraPulso = casos_tempo[caso-1] * 1000;

            @(negedge clock_in);
            medir_in = 1;
            #(5*clockPeriod);
            medir_in = 0;

            wait (trigger_out == 1'b1);
            wait (trigger_out == 1'b0);

            #(400_000);

            echo_in = 1;
            #(larguraPulso);
            echo_in = 0;

            wait (pronto_out == 1'b1);

            if (medida_out === casos_esperados[caso-1]) begin
                $display("  [SUCESSO] Caso %0d: Medida = %x cm (Esperado = %x cm)", 
                         caso, medida_out, casos_esperados[caso-1]);
            end else begin
                $display("  [FALHA] Caso %0d: Medida = %x cm (Esperado = %x cm)", 
                         caso, medida_out, casos_esperados[caso-1]);
                erros = erros + 1;
            end

            #(100_000);
        end

        if (erros == 0) begin
            $display("\nSUCCESS: ALL TESTBENCH CHECKS PASSED!");
        end else begin
            $display("\nFAILURE: %0d error(s) detected!", erros);
        end

        $finish;
    end

endmodule

`default_nettype wire
