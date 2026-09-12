/* --------------------------------------------------------------------------
 *  Arquivo   : exp3_sensor.v
 * --------------------------------------------------------------------------
 *  Descricao : circuito de teste do componente interface_hcsr04
 *              inclui componentes para dispositivos externos:
 *              detector de borda e codificadores de displays de 7 segmentos
 *
 *              Usar para sintetizar projeto no Intel Quartus Prime (DE0-CV)
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 *      09/09/2024  1.1     Edson Midorikawa  revisao
 * --------------------------------------------------------------------------
 */

`default_nettype none

module exp3_sensor (
    input  wire       clock,
    input  wire       reset,
    input  wire       medir,
    input  wire       echo,
    output wire       trigger,
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire       pronto,
    output wire       db_medir,
    output wire       db_echo,
    output wire       db_trigger,
    output wire [6:0] db_estado
);

    // Sinais internos
    wire        s_medir;
    wire        s_trigger;
    wire [11:0] s_medida;
    wire [3:0]  s_estado;

    // Circuito de interface com sensor
    interface_hcsr04 u_interface (
        .clock    (clock    ),
        .reset    (reset    ),
        .medir    (s_medir  ),
        .echo     (echo     ),
        .trigger  (s_trigger),
        .medida   (s_medida ),
        .pronto   (pronto   ),
        .db_estado(s_estado )
    );

    // Displays para medida (3 dígitos BCD: centena, dezena, unidade)
    hexa7seg u_hex0 (
        .hexa   ({1'b0, s_medida[3:0]}), 
        .display(hex0                 )
    );

    hexa7seg u_hex1 (
        .hexa   ({1'b0, s_medida[7:4]}), 
        .display(hex1                 )
    );

    hexa7seg u_hex2 (
        .hexa   ({1'b0, s_medida[11:8]}), 
        .display(hex2                  )
    );

    // Trata entrada medir (detector de borda de subida)
    edge_detector u_edge_detector (
        .clock(clock  ),
        .reset(reset  ),
        .sinal(medir  ), 
        .pulso(s_medir)
    );

    // Sinal de depuração: estado da UC da interface
    hexa7seg u_hex5 (
        .hexa   ({1'b0, s_estado}), 
        .display(db_estado      )
    );

    // Sinais de saída
    assign trigger    = s_trigger;
    assign db_echo    = echo;
    assign db_trigger = s_trigger;
    assign db_medir   = medir;

endmodule

`default_nettype wire