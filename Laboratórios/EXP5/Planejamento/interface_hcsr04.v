`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04.v
 * --------------------------------------------------------------------------
 *  Descricao : Circuito de interface com sensor ultrassonico de distancia HC-SR04
 *              Versao refatorada para o Sistema de Sonar (EXP5).
 * --------------------------------------------------------------------------
 */

module interface_hcsr04 (
    input  wire        clock,
    input  wire        reset,
    input  wire        medir,
    input  wire        echo,
    output wire        trigger,
    output wire [11:0] medida,
    output wire        pronto,
    output wire        db_reset,
    output wire        db_medir,
    output wire [3:0]  db_estado
);

    // Sinais internos
    wire        s_zera;
    wire        s_gera;
    wire        s_registra;
    wire        s_fim_medida;
    wire [11:0] s_medida;
    wire [3:0]  s_estado;

    // Unidade de controle
    interface_hcsr04_uc u_uc (
        .clock     (clock),
        .reset     (reset),
        .medir     (medir),
        .echo      (echo),
        .fim_medida(s_fim_medida),
        .zera      (s_zera),
        .gera      (s_gera),
        .registra  (s_registra),
        .pronto    (pronto),
        .db_estado (s_estado)
    );

    // Fluxo de dados
    interface_hcsr04_fd u_fd (
        .clock     (clock),
        .pulso     (echo), 
        .zera      (s_zera),
        .gera      (s_gera),
        .registra  (s_registra),
        .fim_medida(s_fim_medida),
        .trigger   (trigger),
        .fim       (),  // (desconectado)
        .distancia (s_medida)
    );

    // Atribuicao de saidas
    assign medida    = s_medida;
    assign db_reset  = reset;
    assign db_medir  = medir;
    assign db_estado = s_estado;

endmodule

`default_nettype wire
