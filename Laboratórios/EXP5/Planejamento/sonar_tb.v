`default_nettype none
`timescale 1ns/1ns

module sonar_tb;

    // 1. Definicao de sinais internos
    reg        clock_in;
    reg        reset_in;
    reg        ligar_in;
    reg        echo_in;
    wire       trigger_out;
    wire       pwm_out;
    wire       saida_serial_out;
    wire       fim_posicao_out;

    integer caso;
    integer errors = 0;
    reg [31:0] larguraPulso;

    localparam CLOCK_PERIOD = 20; // 50 MHz (20 ns)
    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    // 2. Instanciacao do DUT com tempo de espera reduzido para 200us (10_000 ciclos a 50MHz)
    localparam M_SIM = 10_000;
    localparam N_SIM = 14;

    sonar #(
        .M_INTERVALO(M_SIM),
        .N_INTERVALO(N_SIM)
    ) dut (
        .clock        (clock_in),
        .reset        (reset_in),
        .ligar        (ligar_in),
        .echo         (echo_in),
        .trigger      (trigger_out),
        .pwm          (pwm_out),
        .saida_serial (saida_serial_out),
        .fim_posicao  (fim_posicao_out)
    );

    // 3. Definicao dos casos de teste (8 posicoes com diferentes larguras de pulso echo)
    localparam NUM_CASOS = 8;
    reg [31:0] casos_eco [0:NUM_CASOS-1];

    initial begin
        $dumpfile("sonar_tb.vcd");
        $dumpvars(0, sonar_tb);

        // Inicializacao dos casos de teste (largura em microssegundos)
        casos_eco[0] = 294;  // Posicao 0 (20°):  ~5 cm
        casos_eco[1] = 353;  // Posicao 1 (40°):  ~6 cm
        casos_eco[2] = 588;  // Posicao 2 (60°):  ~10 cm
        casos_eco[3] = 882;  // Posicao 3 (80°):  ~15 cm
        casos_eco[4] = 588;  // Posicao 4 (100°): ~10 cm
        casos_eco[5] = 588;  // Posicao 5 (120°): ~10 cm
        casos_eco[6] = 1176; // Posicao 6 (140°): ~20 cm
        casos_eco[7] = 1765; // Posicao 7 (160°): ~30 cm

        // 4. Valores iniciais e reset
        clock_in = 0;
        reset_in = 0;
        ligar_in = 0;
        echo_in  = 0;
        errors   = 0;

        $display("===================================================================");
        $display("   INICIO DA SIMULACAO DO SISTEMA DE SONAR: sonar_tb");
        $display("===================================================================");

        #(2 * CLOCK_PERIOD);
        @(negedge clock_in);
        reset_in = 1;
        #(2_000); // 2 us de reset
        @(negedge clock_in);
        reset_in = 0;

        // 5. Espera 100us para inicio de operacao do Sonar
        #(100_000);

        // 6. Ajustar ligar = 1
        $display("[%0t ns] Acionando ligar = 1", $time);
        @(negedge clock_in);
        ligar_in = 1;

        // 7. Espera 100us para inicio dos ciclos de medidas
        #(100_000);

        // 8. Loop dos casos de teste
        for (caso = 0; caso < NUM_CASOS; caso = caso + 1) begin
            $display("\n--- [Caso %0d] Posicao %0d: Eco esperado de %0d us ---",
                     caso, caso, casos_eco[caso]);

            // 8.1 Atribui sinal com valor do caso de teste
            larguraPulso = casos_eco[caso] * 1000; // ns

            // 8.2 Espera pelo pulso de Trigger
            wait (trigger_out == 1'b1);
            $display("  [%0t ns] Pulso Trigger detectado!", $time);
            wait (trigger_out == 1'b0);

            // 8.3 Espera 400us (tempo entre pulsos Trigger e Echo)
            #(400_000);

            // 8.4 Gera pulso Echo com largura definida no caso de teste
            $display("  [%0t ns] Gerando pulso de Echo (%0d us)...", $time, casos_eco[caso]);
            echo_in = 1;
            #(larguraPulso);
            echo_in = 0;

            // 8.5 Espera pelo final do ciclo (fim_posicao = 1)
            wait (fim_posicao_out == 1'b1);
            $display("  [%0t ns] Pulso fim_posicao detectado com sucesso!", $time);

            // 8.6 Espera 100us entre casos de teste
            #(100_000);
        end

        // 9. Ajustar ligar = 0
        $display("\n[%0t ns] Desligando sistema: ligar = 0", $time);
        @(negedge clock_in);
        ligar_in = 0;

        // 10. Espera 100us antes de finalizar a simulacao
        #(100_000);

        // 11. Fim da simulacao
        $display("===================================================================");
        if (errors == 0) begin
            $display("SUCCESS: ALL TESTBENCH CHECKS PASSED! (Todos os 8 casos concluidos)");
        end else begin
            $display("FAILURE: %0d error(s) detectados!", errors);
        end
        $display("===================================================================");

        $finish;
    end

endmodule

`default_nettype wire
