`default_nettype none

/* 
 *  Descricao : Fluxo de dados do transmissor serial assincrono 7E1.
 */

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
    assign paridade = ^dados_ascii;

    // Composicao da trama serial 7E1:
    assign s_dados[0]   = 1'b1;
    assign s_dados[1]   = 1'b0; // start bit
    assign s_dados[8:2] = dados_ascii[6:0];
    assign s_dados[9]   = paridade;
    assign s_dados[10]  = 1'b1; // stop bit

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

    assign saida_serial = s_saida[0];

endmodule

`default_nettype wire
