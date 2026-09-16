/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench aprimorado e auto-verificavel para o circuito de
 *              interface com o sensor ultrassonico de distancia HC-SR04
 *              Contempla 7 casos de teste cobrindo limites fisicos, bancada,
 *              truncamento e arredondamento simetrico.
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module interface_hcsr04_tb;

    // Declaração de sinais de estímulo e monitoramento
    reg         clock_in = 0;
    reg         reset_in = 0;
    reg         medir_in = 0;
    reg         echo_in  = 0;
    wire        trigger_out;
    wire [11:0] medida_out;
    wire        pronto_out;
    wire [3:0]  db_estado_out;

    // Variáveis de controle de teste
    integer caso;
    integer erros = 0;
    reg [31:0] larguraPulso;

    // Configurações do clock: 50 MHz (periodo = 20ns, semi-periodo = 10ns)
    parameter clockPeriod = 20;
    always #(clockPeriod/2) clock_in = ~clock_in;

    // Componente a ser testado (DUT)
    interface_hcsr04 dut (
        .clock    (clock_in     ),
        .reset    (reset_in     ),
        .medir    (medir_in     ),
        .echo     (echo_in      ),
        .trigger  (trigger_out  ),
        .medida   (medida_out   ),
        .pronto   (pronto_out   ),
        .db_estado(db_estado_out)
    );

    // Arrays para os casos de teste
    localparam NUM_CASOS = 7;
    reg [31:0] casos_tempo     [0:NUM_CASOS-1]; // tempo em us
    reg [11:0] casos_esperados [0:NUM_CASOS-1]; // medida esperada em BCD (12 bits)

    initial begin
        // Inicializacao dos casos de teste
        // Caso 0: 2 cm -> 118 us (limite fisico inferior do HC-SR04)
        casos_tempo[0]     = 118;
        casos_esperados[0] = 12'h002;

        // Caso 1: 15 cm -> 882 us (obstaculo proximo em bancada)
        casos_tempo[1]     = 882;
        casos_esperados[1] = 12'h015;

        // Caso 2: 74 cm -> 4353 us (distancia intermediaria nominal)
        casos_tempo[2]     = 4353;
        casos_esperados[2] = 12'h074;

        // Caso 3: 74.79 cm -> 4399 us (arredondar para cima >= 0.5 cm -> 75 cm)
        casos_tempo[3]     = 4399;
        casos_esperados[3] = 12'h075;

        // Caso 4: 100 cm -> 5882 us (distancia de referencia de 1 metro)
        casos_tempo[4]     = 5882;
        casos_esperados[4] = 12'h100;

        // Caso 5: 100.29 cm -> 5899 us (truncar para baixo < 0.5 cm -> 100 cm)
        casos_tempo[5]     = 5899;
        casos_esperados[5] = 12'h100;

        // Caso 6: 250 cm -> 14706 us (limite tipico do espaco de bancada/laboratorio)
        casos_tempo[6]     = 14706;
        casos_esperados[6] = 12'h250;

        $display("===================================================================");
        $display("   INICIO DA SIMULACAO AUTO-VERIFICAVEL: interface_hcsr04_tb");
        $display("===================================================================");

        // Valores iniciais
        medir_in = 0;
        echo_in  = 0;
        erros    = 0;

        // Reset inicial do circuito
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000); // 2 us
        reset_in = 0;
        @(negedge clock_in);

        // Espera de estabilizacao de 100 us
        #(100_000);

        // Execucao dos casos de teste
        for (caso = 1; caso <= NUM_CASOS; caso = caso + 1) begin
            larguraPulso = casos_tempo[caso-1] * 1000; // converte us para ns

            $display("\n--- Caso de Teste %0d: Pulso de Eco = %0d us (Esperado: %x cm) ---", 
                     caso, casos_tempo[caso-1], casos_esperados[caso-1]);

            // 1) Envia pulso de medicao (medir_in ativo por 5 clocks)
            @(negedge clock_in);
            medir_in = 1;
            #(5*clockPeriod);
            medir_in = 0;

            // 2) Aguarda geracao do pulso de trigger
            wait (trigger_out == 1'b1);
            $display("  [%0t ns] Trigger ativado!", $time);
            wait (trigger_out == 1'b0);
            $display("  [%0t ns] Trigger desativado.", $time);

            // 3) Emula atraso de propagacao do sensor (~400 us)
            #(400_000);

            // 4) Emula eco retornado pelo sensor HC-SR04
            $display("  [%0t ns] Gerando pulso de eco (duracao: %0d us)...", $time, casos_tempo[caso-1]);
            echo_in = 1;
            #(larguraPulso);
            echo_in = 0;

            // 5) Aguarda conclusao da medicao pela interface
            wait (pronto_out == 1'b1);
            $display("  [%0t ns] Sinal pronto_out ativado!", $time);

            // 6) Verificacao automatica do valor medido em BCD
            if (medida_out === casos_esperados[caso-1]) begin
                $display("  [SUCESSO] Caso %0d: Medida = %x cm (Esperado = %x cm)", 
                         caso, medida_out, casos_esperados[caso-1]);
            end else begin
                $display("  [FALHA] Caso %0d: Medida = %x cm (Esperado = %x cm) [ERRO!]", 
                         caso, medida_out, casos_esperados[caso-1]);
                erros = erros + 1;
            end

            // 7) Intervalo de repouso entre medicoes (100 us)
            #(100_000);
        end

        // Relatório final de conformidade
        $display("\n===================================================================");
        if (erros == 0) begin
            $display("   RESULTADO: TODOS OS %0d CASOS DE TESTE PASSARAM COM SUCESSO!", NUM_CASOS);
        end else begin
            $display("   RESULTADO: FALHA! Foram detectados %0d erro(s) na simulacao.", erros);
        end
        $display("===================================================================");

        $finish;
    end

endmodule
