`default_nettype none
`timescale 1ns/1ns

/* 
 *  Descricao : Testbench para o receptor serial assincrono rx_serial_7E1.
 *              Valida recepcao de quadros 7E1 a 115200 bauds.
 */

module rx_serial_tb;

    // Sinais para conectar ao DUT
    reg        clock_in;
    reg        reset_in;
    reg        sinal_serial;
    wire       pronto_out;
    wire [6:0] dados_ascii_out;
    wire       paridade_out;
    wire       paridade_par_out;
    wire       db_clock;
    wire       db_tick;
    wire [3:0] db_estado;

    // Configuracoes de temporizacao
    localparam CLOCK_PERIOD = 20;               
    localparam BIT_PERIOD   = 434 * CLOCK_PERIOD; // ~8680 ns

    // Gerador de clock
    always #(CLOCK_PERIOD / 2) clock_in = ~clock_in;

    // Instancia do DUT
    rx_serial_7E1 uut (
        .clock        (clock_in),
        .reset        (reset_in),
        .RX           (sinal_serial),
        .pronto       (pronto_out),
        .dados_ascii  (dados_ascii_out),
        .paridade     (paridade_out),
        .paridade_par (paridade_par_out),
        .db_clock     (db_clock),
        .db_tick      (db_tick),
        .db_estado    (db_estado)
    );

    task UART_WRITE_BYTE;
        input [7:0] data_in;
        integer i;
        begin
            // Start Bit (0)
            sinal_serial = 1'b0;
            #BIT_PERIOD;

            // 8 Bits de Dados / Paridade
            for (i = 0; i < 8; i = i + 1) begin
                sinal_serial = data_in[i];
                #BIT_PERIOD;
            end

            // 2 Stop Bits (1)
            sinal_serial = 1'b1;
            #(2 * BIT_PERIOD);
        end
    endtask

    // Variaveis de teste
    reg [7:0] casos_teste [0:7];
    integer caso_idx;
    integer erros;

    initial begin
        // Inicializacao dos casos de teste
        casos_teste[0] = 8'b00110101; // 0x35: dado=0x35 ('5'), paridade=0 (total 4 '1's -> Par OK)
        casos_teste[1] = 8'b11010101; // 0xD5: dado=0x55 ('U'), paridade=1 (total 5 '1's -> Erro)
        casos_teste[2] = 8'b11111101; // 0xFD: dado=0x7D ('}'), paridade=1 (total 7 '1's -> Erro)
        casos_teste[3] = 8'b10110101; // 0xB5: dado=0x35 ('5'), paridade=1 (total 5 '1's -> Erro)
        casos_teste[4] = 8'b01000001; // 0x41: dado=0x41 ('A'), paridade=0 (total 2 '1's -> Par OK)
        casos_teste[5] = 8'b11000001; // 0xC1: dado=0x41 ('A'), paridade=1 (total 3 '1's -> Erro)
        casos_teste[6] = 8'b01100001; // 0x61: dado=0x61 ('a' atencao), paridade=0 (total 3 '1's -> Erro paridade)
        casos_teste[7] = 8'b11100001; // 0xE1: dado=0x61 ('a' atencao), paridade=1 (total 4 '1's -> Par OK)

        clock_in     = 1'b0;
        reset_in     = 1'b0;
        sinal_serial = 1'b1;
        erros        = 0;

        $display("Inicio da Simulacao");

        // Reset inicial
        reset_in = 1'b1;
        #(5 * CLOCK_PERIOD);
        reset_in = 1'b0;
        #BIT_PERIOD;

        // Loop sobre os casos de teste
        for (caso_idx = 0; caso_idx < 8; caso_idx = caso_idx + 1) begin
            $display("[Teste %0d] Enviando byte serial: 0x%02h", caso_idx + 1, casos_teste[caso_idx]);
            #(2 * BIT_PERIOD);
            UART_WRITE_BYTE(casos_teste[caso_idx]);
            #(2 * CLOCK_PERIOD);

            if (dados_ascii_out !== casos_teste[caso_idx][6:0]) begin
                $display("  ERRO: dados_ascii_out esperado=0x%02h, obtido=0x%02h",
                         casos_teste[caso_idx][6:0], dados_ascii_out);
                erros = erros + 1;
            end else begin
                $display("  OK: dados_ascii_out = 0x%02h (char '%c'), paridade_par = %b",
                         dados_ascii_out, dados_ascii_out, paridade_par_out);
            end
            #(2 * BIT_PERIOD);
        end

        if (erros == 0) begin
            $display("Resultado: SUCESSO!");
        end else begin
            $display("Resultado: FALHA COM %0d ERRO(S)", erros);
        end

        $finish;
    end

endmodule

`default_nettype wire
