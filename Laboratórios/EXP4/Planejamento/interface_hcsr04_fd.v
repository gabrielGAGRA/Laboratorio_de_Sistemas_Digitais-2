/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04_fd.v
 * --------------------------------------------------------------------------
 *  Descricao : fluxo de dados do circuito de interface com sensor ultrassonico
 *              de distancia HC-SR04
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */

`default_nettype none

module interface_hcsr04_fd (
    input  wire        clock,
    input  wire        pulso,
    input  wire        zera,
    input  wire        gera,
    input  wire        registra,
    output wire        fim_medida,
    output wire        trigger,
    output wire        fim,
    output wire [11:0] distancia
);

    // Sinais internos
    wire [11:0] s_medida;

    // (U1) pulso de 10us (500 clocks de 20ns a 50MHz)
    gerador_pulso #(
        .largura(500) 
    ) U1 (
        .clock (clock  ),
        .reset (zera   ),
        .gera  (gera   ),
        .para  (1'b0   ), 
        .pulso (trigger),
        .pronto(       )
    );

    // (U2) medida em cm (R=2941 clocks, N=12)
    contador_cm #(
        .R(2941), 
        .N(12  )
    ) U2 (
        .clock  (clock         ),
        .reset  (zera          ),
        .pulso  (pulso         ),
        .digito2(s_medida[11:8]),
        .digito1(s_medida[7:4] ),
        .digito0(s_medida[3:0] ),
        .fim    (fim           ),
        .pronto (fim_medida    )
    );

    // (U3) registrador de saida (12 bits BCD)
    registrador_n #(
        .N(12)
    ) U3 (
        .clock (clock    ),
        .clear (1'b0     ),
        .enable(registra ),
        .D     (s_medida ),
        .Q     (distancia)
    );

endmodule

`default_nettype wire
