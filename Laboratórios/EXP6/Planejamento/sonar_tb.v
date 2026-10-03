`default_nettype none
`timescale 1ns/1ns

/* 
 *  Descricao : Testbench abrangente para o nucleo do Sistema de Sonar Modificado.
 *              Valida:
 *              1. Inicializacao e varredura angular em Modo 0 (Normal)
 *              2. Transicao para Modo 1 (Atencao) via envio serial de 'a' (0xE1)
 *              3. Permanencia e congelamento de posicao angular no Modo 1
 *              4. Imunidade a caracteres invalidos e erros de paridade
 *              5. Retorno ao Modo 0 via envio serial de 'v' (0xF6) e retomada
 *                 do avanco angular a partir da posicao pausada
 */

module sonar_tb;

    // Sinais de conexao com o DUT
    reg        clock_in;
    reg        reset_in;
    reg        ligar_in;
    reg        echo_in;
    reg        entrada_serial_in;
    wire       trigger_out;
    wire       pwm_out;
    wire       saida_serial_out;
    wire       fim_posicao_out;
    wire       db_modo_out;
    wire [2:0] db_posicao_out;
    wire [23:0] db_angulo_out;
    wire [11:0] db_medida_out;
    wire [3:0] db_estado_out;

    // Configuracoes de temporizacao
    localparam CLOCK_PERIOD = 20;              
    localparam BIT_PERIOD   = 434 * CLOCK_PERIOD; 

    // Gerador de clock
    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    // Instancia do DUT com temporizador encurtado para simulacao rapida
    sonar #(
        .M_INTERVALO  (10_000), 
        .N_INTERVALO  (14),
        .TIMEOUT_TICKS(50_000),
        .TIMEOUT_BITS (16)
    ) uut (
        .clock             (clock_in),
        .reset             (reset_in),
        .ligar             (ligar_in),
        .echo              (echo_in),
        .entrada_serial    (entrada_serial_in),
        .trigger           (trigger_out),
        .pwm               (pwm_out),
        .saida_serial      (saida_serial_out),
        .fim_posicao       (fim_posicao_out),
        .db_modo           (db_modo_out),
        .db_posicao        (db_posicao_out),
        .db_angulo         (db_angulo_out),
        .db_medida         (db_medida_out),
        .db_estado         (db_estado_out),
        .db_estado_hcsr04  (),
        .db_estado_tx      (),
        .db_dados_tx       (),
        .db_estado_rx      (),
        .db_dados_rx       (),
        .db_estado_tx_sonar(),
        .db_indice_tx_sonar(),
        .db_char_tx        ()
    );

    // Procedimento para emular envio serial de um byte
    task ENVIAR_BYTE_SERIAL;
        input [7:0] byte_serial;
        integer b;
        begin
            // Start Bit (0)
            entrada_serial_in = 1'b0;
            #BIT_PERIOD;

            // 8 Bits de Dados
            for (b = 0; b < 8; b = b + 1) begin
                entrada_serial_in = byte_serial[b];
                #BIT_PERIOD;
            end

            // 2 Stop Bits (1)
            entrada_serial_in = 1'b1;
            #(2 * BIT_PERIOD);
        end
    endtask

    // Procedimento para emular a resposta de eco do sensor HC-SR04
    task EMULAR_RESPOSTA_ECHO;
        input integer largura_us;
        begin
            // Aguarda borda de subida do Trigger
            @(posedge trigger_out);
            // Aguarda borda de descida do Trigger
            @(negedge trigger_out);
            // Atraso de propagacao acustica inicial (10 us)
            #(10_000);
            // Inicio do pulso de eco
            echo_in = 1'b1;
            #(largura_us * 1000);
            // Fim do pulso de eco
            echo_in = 1'b0;
        end
    endtask

    // Processo de resposta automatica de eco para manter os ciclos fluindo
    reg echo_auto_enable;
    initial begin
        echo_auto_enable = 1'b1;
        forever begin
            if (echo_auto_enable) begin
                EMULAR_RESPOSTA_ECHO(58 * 15); // Emula 15 cm de distancia (58us/cm * 15 = 870us)
            end else begin
                @(posedge clock_in);
            end
        end
    end

    integer erros;
    reg [2:0] posicao_salva;

    initial begin
        clock_in          = 1'b0;
        reset_in          = 1'b0;
        ligar_in          = 1'b0;
        echo_in           = 1'b0;
        entrada_serial_in = 1'b1;
        erros             = 0;

        $display("Inicio da Simulacao: sonar_tb");

        // 1. Reset inicial
        reset_in = 1'b1;
        #(10 * CLOCK_PERIOD);
        reset_in = 1'b0;
        #(10 * CLOCK_PERIOD);

        // 2. Ativacao do Sonar (ligar = 1) no Modo 0
        $display("[Etapa 1] Ativando Sonar no Modo 0 (Localizacao)...");
        ligar_in = 1'b1;

        // Aguarda 2 avancos de posicao no Modo 0
        @(posedge fim_posicao_out);
        $display("  Posicao avancada para: %0d, db_modo = %0b", db_posicao_out, db_modo_out);
        if (db_modo_out !== 1'b0) begin
            $display("  ERRO: db_modo esperado=0, obtido=%0b", db_modo_out);
            erros = erros + 1;
        end

        @(posedge fim_posicao_out);
        posicao_salva = db_posicao_out;
        $display("  Posicao avancada para: %0d, db_modo = %0b", posicao_salva, db_modo_out);

        // 3. Envio serial do comando 'a' (Atencao: 0x61, paridade 1 -> 0xE1)
        $display("[Etapa 2] Enviando comando 'a' (Atencao)...");
        ENVIAR_BYTE_SERIAL(8'hE1);
        #(5 * CLOCK_PERIOD);

        if (db_modo_out !== 1'b1) begin
            $display("  ERRO: db_modo nao transicionou para 1 apos comando 'a'");
            erros = erros + 1;
        end else begin
            $display("  OK: Transicao confirmada para Modo 1 (Atencao)");
        end

        // 4. Verificacao de que no Modo 1 a posicao permanece FIXA por varios ciclos
        $display("[Etapa 3] Verificando congelamento de posicao no Modo 1...");
        #(200_000 * 3); // Aguarda tempo de ~3 ciclos de medicao

        if (db_posicao_out !== posicao_salva) begin
            $display("  ERRO: Posicao alterada no Modo 1! Esperado=%0d, Obtido=%0d",
                     posicao_salva, db_posicao_out);
            erros = erros + 1;
        end else begin
            $display("  OK: Posicao permaneceu congelada em %0d no Modo 1", db_posicao_out);
        end

        // 5. Envio de caractere invalido (ex: 'x' = 0x78) -> deve ser ignorado
        $display("[Etapa 4] Enviando caractere invalido 'x' (0x78)...");
        ENVIAR_BYTE_SERIAL(8'h78);
        #(5 * CLOCK_PERIOD);

        if (db_modo_out !== 1'b1) begin
            $display("  ERRO: Caractere invalido corrompeu o modo!");
            erros = erros + 1;
        end else begin
            $display("  OK: Modo 1 inalterado apos caractere invalido");
        end

        // 6. Envio de 'a' com erro de paridade (0x61 com paridade 0 -> 0x61) -> deve ser ignorado
        $display("[Etapa 5] Enviando 'a' com paridade corrompida (0x61)...");
        ENVIAR_BYTE_SERIAL(8'h61);
        #(5 * CLOCK_PERIOD);

        if (db_modo_out !== 1'b1) begin
            $display("  ERRO: Byte com erro de paridade afetou o sistema!");
            erros = erros + 1;
        end else begin
            $display("  OK: Paridade incorreta rejeitada com sucesso");
        end

        // 7. Envio do comando 'v' (Voltar: 0x76, paridade 1 -> 0xF6)
        $display("[Etapa 6] Enviando comando 'v' (Voltar ao Modo 0)...");
        ENVIAR_BYTE_SERIAL(8'hF6);
        #(5 * CLOCK_PERIOD);

        if (db_modo_out !== 1'b0) begin
            $display("  ERRO: db_modo nao retornou para 0 apos comando 'v'");
            erros = erros + 1;
        end else begin
            $display("  OK: Retorno confirmado para Modo 0 (Localizacao)");
        end

        // 8. Verificacao de que o avanco de posicao e retomado a partir da posicao salva
        $display("[Etapa 7] Verificando retomada do avanco angular...");
        @(posedge fim_posicao_out);
        $display("  Posicao avancou para: %0d", db_posicao_out);

        if (db_posicao_out !== ((posicao_salva + 1) % 8)) begin
            $display("  ERRO: Retomada fora da sequencia! Esperado=%0d, Obtido=%0d",
                     (posicao_salva + 1) % 8, db_posicao_out);
            erros = erros + 1;
        end else begin
            $display("  OK: Avanco sequencial continuou perfeitamente a partir da posicao pausada");
        end

        // Conclusao
        if (erros == 0) begin
            $display("Resultado: TESTES DO SONA PASSARAM!");
        end else begin
            $display("Resultado: FALHA COM %0d ERRO(S)", erros);
        end

        $finish;
    end

endmodule

`default_nettype wire
