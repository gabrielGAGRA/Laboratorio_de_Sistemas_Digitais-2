`default_nettype none
`timescale 1ns/1ns

/*
 * Arquivo   : mux_4x1_n_tb.v
 * ----------------------------------------------------------------
 * Descricao : Testbench auto-verificavel em Verilog-2001 para o
 *             multiplexador parametrizavel mux_4x1_n.
 * ----------------------------------------------------------------
 */

// OBS: Tivemos que mudar pra verilog 2001, como eram os arquivos das 
// outras experiencias, mas ele veio em .sv, então tivemos que mudar 
// pra .v e 

module mux_4x1_n_tb;

    localparam BITS = 4;
    localparam NUM_CASOS = 10;

    reg  [BITS-1:0] d3_in;
    reg  [BITS-1:0] d2_in;
    reg  [BITS-1:0] d1_in;
    reg  [BITS-1:0] d0_in;
    reg  [1:0]      sel_in;
    wire [BITS-1:0] mux_out;

    // Componente sob teste (DUT)
    mux_4x1_n #(
        .BITS(BITS)
    ) u_dut (
        .D3     (d3_in),
        .D2     (d2_in),
        .D1     (d1_in),
        .D0     (d0_in),
        .SEL    (sel_in),
        .MUX_OUT(mux_out)
    );

    // Vetores de teste
    reg [BITS-1:0] casos_d3        [0:NUM_CASOS-1];
    reg [BITS-1:0] casos_d2        [0:NUM_CASOS-1];
    reg [BITS-1:0] casos_d1        [0:NUM_CASOS-1];
    reg [BITS-1:0] casos_d0        [0:NUM_CASOS-1];
    reg [1:0]      casos_sel       [0:NUM_CASOS-1];
    reg [BITS-1:0] casos_esperados [0:NUM_CASOS-1];

    integer caso;
    integer errors;

    initial begin
        // Inicializacao dos casos de teste
        // Caso 0: entradas em 0, SEL = 0
        casos_d3[0] = 4'h0; casos_d2[0] = 4'h0; casos_d1[0] = 4'h0; casos_d0[0] = 4'h0; casos_sel[0] = 2'b00; casos_esperados[0] = 4'h0;
        // Caso 1: entradas em F, SEL = 3
        casos_d3[1] = 4'hF; casos_d2[1] = 4'hF; casos_d1[1] = 4'hF; casos_d0[1] = 4'hF; casos_sel[1] = 2'b11; casos_esperados[1] = 4'hF;
        // Caso 2: entradas 3,2,1,0, SEL = 0
        casos_d3[2] = 4'h3; casos_d2[2] = 4'h2; casos_d1[2] = 4'h1; casos_d0[2] = 4'h0; casos_sel[2] = 2'b00; casos_esperados[2] = 4'h0;
        // Caso 3: entradas 3,2,1,0, SEL = 1
        casos_d3[3] = 4'h3; casos_d2[3] = 4'h2; casos_d1[3] = 4'h1; casos_d0[3] = 4'h0; casos_sel[3] = 2'b01; casos_esperados[3] = 4'h1;
        // Caso 4: entradas 3,2,1,0, SEL = 2
        casos_d3[4] = 4'h3; casos_d2[4] = 4'h2; casos_d1[4] = 4'h1; casos_d0[4] = 4'h0; casos_sel[4] = 2'b10; casos_esperados[4] = 4'h2;
        // Caso 5: entradas 3,2,1,0, SEL = 3
        casos_d3[5] = 4'h3; casos_d2[5] = 4'h2; casos_d1[5] = 4'h1; casos_d0[5] = 4'h0; casos_sel[5] = 2'b11; casos_esperados[5] = 4'h3;
        // Caso 6: entradas iguais, SEL = 2
        casos_d3[6] = 4'h3; casos_d2[6] = 4'h3; casos_d1[6] = 4'h3; casos_d0[6] = 4'h3; casos_sel[6] = 2'b10; casos_esperados[6] = 4'h3;
        // Caso 7: entradas variadas, SEL = 0
        casos_d3[7] = 4'hE; casos_d2[7] = 4'h2; casos_d1[7] = 4'hC; casos_d0[7] = 4'h5; casos_sel[7] = 2'b00; casos_esperados[7] = 4'h5;
        // Caso 8: entradas variadas, SEL = 3
        casos_d3[8] = 4'h5; casos_d2[8] = 4'hB; casos_d1[8] = 4'h5; casos_d0[8] = 4'hB; casos_sel[8] = 2'b11; casos_esperados[8] = 4'h5;
        // Caso 9: entradas variadas, SEL = 0
        casos_d3[9] = 4'h1; casos_d2[9] = 4'h2; casos_d1[9] = 4'h3; casos_d0[9] = 4'h4; casos_sel[9] = 2'b00; casos_esperados[9] = 4'h4;

        d3_in  = {BITS{1'b0}};
        d2_in  = {BITS{1'b0}};
        d1_in  = {BITS{1'b0}};
        d0_in  = {BITS{1'b0}};
        sel_in = 2'b00;
        errors = 0;

        $display("===================================================================");
        $display("   INICIO DA SIMULACAO AUTO-VERIFICAVEL: mux_4x1_n_tb");
        $display("===================================================================");

        // Percorre todos os casos de teste
        for (caso = 0; caso < NUM_CASOS; caso = caso + 1) begin
            d3_in  = casos_d3[caso];
            d2_in  = casos_d2[caso];
            d1_in  = casos_d1[caso];
            d0_in  = casos_d0[caso];
            sel_in = casos_sel[caso];

            #20;

            if (mux_out !== casos_esperados[caso]) begin
                $display("  [FALHA] Caso %0d: SEL=%b, D0=%h, D1=%h, D2=%h, D3=%h | MUX_OUT=%h (Esperado=%h)",
                         caso, sel_in, d0_in, d1_in, d2_in, d3_in, mux_out, casos_esperados[caso]);
                errors = errors + 1;
            end else begin
                $display("  [OK]    Caso %0d: SEL=%b, D0=%h, D1=%h, D2=%h, D3=%h | MUX_OUT=%h",
                         caso, sel_in, d0_in, d1_in, d2_in, d3_in, mux_out);
            end
        end

        // Relatorio final
        $display("===================================================================");
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
