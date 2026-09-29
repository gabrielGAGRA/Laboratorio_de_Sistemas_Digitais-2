`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : transmissor_sonar.v
 * --------------------------------------------------------------------------
 *  Descricao : Transmissor de dados do sonar.
 *              Recebe angulo (24 bits ASCII) e distancia (12 bits BCD)
 *              e transmite em bloco uma mensagem de 8 caracteres ASCII
 *              no formato "AAA,DDD#" integrando UC e FD.
 * --------------------------------------------------------------------------
 */

module transmissor_sonar (
    input  wire        clock,
    input  wire        reset,
    input  wire        transmitir,
    input  wire [23:0] angulo,
    input  wire [11:0] distancia,
    output wire        saida_serial,
    output wire        pronto,
    output wire        db_partida,
    output wire        db_saida_serial,
    output wire [3:0]  db_estado
);

    wire s_zera_indice;
    wire s_conta_indice;
    wire s_partida_serial;
    wire s_pronto_serial;
    wire s_fim_caracteres;

    // Unidade de Controle
    transmissor_sonar_uc u_uc (
        .clock          (clock),
        .reset          (reset),
        .transmitir     (transmitir),
        .pronto_serial  (s_pronto_serial),
        .fim_caracteres (s_fim_caracteres),
        .zera_indice    (s_zera_indice),
        .conta_indice   (s_conta_indice),
        .partida_serial (s_partida_serial),
        .pronto         (pronto),
        .db_estado      (db_estado)
    );

    // Fluxo de Dados
    transmissor_sonar_fd u_fd (
        .clock          (clock),
        .reset          (reset),
        .zera_indice    (s_zera_indice),
        .conta_indice   (s_conta_indice),
        .partida_serial (s_partida_serial),
        .angulo         (angulo),
        .distancia      (distancia),
        .fim_caracteres (s_fim_caracteres),
        .saida_serial   (saida_serial),
        .pronto_serial  (s_pronto_serial),
        .db_partida     (db_partida),
        .db_saida_serial(db_saida_serial)
    );

endmodule

`default_nettype wire
