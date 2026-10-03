`default_nettype none

/* 
 *  Descricao : Fluxo de dados do circuito de recepcao serial assincrona
 *              para comunicacao serial 7E1 (7 bits de dados, paridade par, 1 stop bit).
 */

module rx_serial_7E1_fd (
    input  wire       clock,
    input  wire       reset,
    input  wire       zera,
    input  wire       conta,
    input  wire       registra,
    input  wire       carrega,
    input  wire       desloca,
    input  wire       RX,
    output wire [7:0] dados, // dados_ascii + paridade
    output wire       fim
);

    wire [10:0] s_saida;

    // Deslocador de 11 bits (Start + 7 Dados + Paridade + 2 Stop)
    deslocador_n #(
        .N(11)
    ) u_deslocador (
        .clock          (clock),
        .reset          (reset),
        .carrega        (carrega),
        .desloca        (desloca),
        .entrada_serial (RX),
        .dados          (11'h7FF), // Repouso em '1'
        .saida          (s_saida)
    );

    // Contador de 11 bits de amostragem
    contador_m #(
        .M(11),
        .N(4)
    ) u_contador (
        .clock   (clock),
        .zera_as (reset),
        .zera_s  (zera),
        .conta   (conta),
        .Q       (),
        .fim     (fim),
        .meio    ()
    );

    // Registrador paralelo de saida (7 dados + 1 paridade = 8 bits)
    registrador_n #(
        .N(8)
    ) u_registrador (
        .clock  (clock),
        .clear  (reset),
        .enable (registra),
        .D      (s_saida[9:2]),
        .Q      (dados)
    );

endmodule

`default_nettype wire
