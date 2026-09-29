`default_nettype none

module tx_serial_7E1_fd (
    input  wire       clock,
    input  wire       reset,
    input  wire       zera,
    input  wire       conta,
    input  wire       carrega,
    input  wire       desloca,
    input  wire [6:0] dados_ascii,
    output wire       saida_serial,
    output wire       fim
);

    wire [10:0] s_dados;
    wire [10:0] s_saida;
    wire        paridade;

    // Calculo da paridade par (even parity)
    // Se numero de 1s em dados_ascii for impar, paridade = 1 (total de 1s torna-se par)
    // Se numero de 1s em dados_ascii for par, paridade = 0 (total de 1s mantem-se par)
    assign paridade = ^dados_ascii;

    // Composicao da trama serial 7E1 (11 bits total considerando repouso inicial):
    // Bit 0:  1'b1 (repouso alinhado na saida durante carregamento)
    // Bit 1:  1'b0 (start bit)
    // Bits 8..2: 7 bits de dados (LSB primeiro)
    // Bit 9:  bit de paridade par
    // Bit 10: 1'b1 (stop bit)
    assign s_dados[0]   = 1'b1;
    assign s_dados[1]   = 1'b0;
    assign s_dados[8:2] = dados_ascii[6:0];
    assign s_dados[9]   = paridade;
    assign s_dados[10]  = 1'b1;

    // Instanciacao do registrador de deslocamento
    deslocador_n #(
        .N(11) 
    ) u_deslocador_n (
        .clock          (clock),
        .reset          (reset),
        .carrega        (carrega),
        .desloca        (desloca),
        .entrada_serial (1'b1),
        .dados          (s_dados),
        .saida          (s_saida)
    );

    // Instanciacao do contador de bits
    // M=12 conta 12 estados (0 a 11): 1 carga/alinhamento + 1 start + 7 dados + 1 paridade + 1 stop + 1 retorno
    contador_m #(
        .M(12),
        .N(4)
    ) u_contador_m (
        .clock   (clock),
        .zera_as (1'b0),
        .zera_s  (zera),
        .conta   (conta),
        .Q       (),
        .fim     (fim),
        .meio    ()
    );

    // Saida serial do transmissor (bit menos significativo do deslocador)
    assign saida_serial = s_saida[0];

endmodule

`default_nettype wire
