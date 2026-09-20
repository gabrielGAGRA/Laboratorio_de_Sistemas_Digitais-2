/* --------------------------------------------------------------------------
 *  Arquivo   : contador_cm_uc.v
 * --------------------------------------------------------------------------
 *  Descricao : unidade de controle do componente contador_cm
 *              
 *              incrementa contagem de cm a cada sinal de tick enquanto
 *              o pulso de entrada permanece ativo
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */

`default_nettype none

module contador_cm_uc (
    input  wire clock,
    input  wire reset,
    input  wire pulso,
    input  wire tick,
    output reg  zera_tick,
    output reg  conta_tick,
    output reg  zera_bcd,
    output reg  conta_bcd,
    output reg  pronto
);

    // Tipos e sinais
    reg [2:0] estado_q, estado_d;

    // Parâmetros para os estados
    localparam [2:0] INICIAL     = 3'b000;
    localparam [2:0] PREPARA     = 3'b001;
    localparam [2:0] ESPERA_TICK = 3'b010;
    localparam [2:0] INCREMENTA  = 3'b011;
    localparam [2:0] FINAL       = 3'b100;

    // Memória de estado
    always @(posedge clock or posedge reset) begin
        if (reset)
            estado_q <= INICIAL;
        else
            estado_q <= estado_d;
    end

    // Lógica de próximo estado
    always @(*) begin
        case (estado_q)
            INICIAL: begin
                if (pulso)
                    estado_d = PREPARA;
                else
                    estado_d = INICIAL;
            end

            PREPARA: begin
                if (pulso)
                    estado_d = ESPERA_TICK;
                else
                    estado_d = FINAL;
            end

            ESPERA_TICK: begin
                if (~pulso)
                    estado_d = FINAL;
                else if (tick)
                    estado_d = INCREMENTA;
                else
                    estado_d = ESPERA_TICK;
            end

            INCREMENTA: begin
                if (~pulso)
                    estado_d = FINAL;
                else
                    estado_d = ESPERA_TICK;
            end

            FINAL: begin
                estado_d = INICIAL;
            end

            default: begin
                estado_d = INICIAL;
            end
        endcase
    end

    // Lógica de saída (Moore)
    always @(*) begin
        zera_tick  = 1'b0;
        conta_tick = 1'b0;
        zera_bcd   = 1'b0;
        conta_bcd  = 1'b0;
        pronto     = 1'b0;

        case (estado_q)
            INICIAL: begin
                // Mantem contadores estaveis
            end

            PREPARA: begin
                zera_tick = 1'b1;
                zera_bcd  = 1'b1;
            end

            ESPERA_TICK: begin
                conta_tick = 1'b1;
            end

            INCREMENTA: begin
                conta_tick = 1'b1;
                conta_bcd  = 1'b1;
            end

            FINAL: begin
                pronto = 1'b1;
            end

            default: begin
                zera_tick  = 1'b0;
                conta_tick = 1'b0;
                zera_bcd   = 1'b0;
                conta_bcd  = 1'b0;
                pronto     = 1'b0;
            end
        endcase
    end

endmodule

`default_nettype wire
