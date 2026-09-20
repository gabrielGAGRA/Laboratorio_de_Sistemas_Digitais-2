/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04_uc.v
 * --------------------------------------------------------------------------
 *  Descricao : unidade de controle do circuito de interface com sensor
 *              ultrassonico de distancia HC-SR04
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */

`default_nettype none

module interface_hcsr04_uc (
    input  wire       clock,
    input  wire       reset,
    input  wire       medir,
    input  wire       echo,
    input  wire       fim_medida,
    output reg        zera,
    output reg        gera,
    output reg        registra,
    output reg        pronto,
    output reg  [3:0] db_estado 
);

    // Tipos e sinais
    reg [2:0] estado_q, estado_d;

    // Parâmetros para os estados
    localparam [2:0] INICIAL       = 3'b000;
    localparam [2:0] PREPARACAO    = 3'b001;
    localparam [2:0] ENVIA_TRIGGER = 3'b010;
    localparam [2:0] ESPERA_ECHO   = 3'b011;
    localparam [2:0] MEDIDA        = 3'b100;
    localparam [2:0] ARMAZENAMENTO = 3'b101;
    localparam [2:0] FINAL_MEDIDA  = 3'b110;

    // Estado
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
                if (medir)
                    estado_d = PREPARACAO;
                else
                    estado_d = INICIAL;
            end

            PREPARACAO: begin
                estado_d = ENVIA_TRIGGER;
            end

            ENVIA_TRIGGER: begin
                estado_d = ESPERA_ECHO;
            end

            ESPERA_ECHO: begin
                if (echo)
                    estado_d = MEDIDA;
                else
                    estado_d = ESPERA_ECHO;
            end

            MEDIDA: begin
                if (fim_medida)
                    estado_d = ARMAZENAMENTO;
                else
                    estado_d = MEDIDA;
            end

            ARMAZENAMENTO: begin
                estado_d = FINAL_MEDIDA;
            end

            FINAL_MEDIDA: begin
                estado_d = INICIAL;
            end

            default: begin
                estado_d = INICIAL;
            end
        endcase
    end

    // Saídas de controle (Moore)
    always @(*) begin
        zera      = 1'b0;
        gera      = 1'b0;
        registra  = 1'b0;
        pronto    = 1'b0;
        db_estado = 4'b1110;

        case (estado_q)
            INICIAL: begin
                db_estado = 4'b0000;
            end

            PREPARACAO: begin
                zera      = 1'b1;
                db_estado = 4'b0001;
            end

            ENVIA_TRIGGER: begin
                gera      = 1'b1;
                db_estado = 4'b0010;
            end

            ESPERA_ECHO: begin
                db_estado = 4'b0011;
            end

            MEDIDA: begin
                db_estado = 4'b0100;
            end

            ARMAZENAMENTO: begin
                registra  = 1'b1;
                db_estado = 4'b0101;
            end

            FINAL_MEDIDA: begin
                pronto    = 1'b1;
                db_estado = 4'b1111;
            end

            default: begin
                zera      = 1'b0;
                gera      = 1'b0;
                registra  = 1'b0;
                pronto    = 1'b0;
                db_estado = 4'b1110;
            end
        endcase
    end

endmodule

`default_nettype wire
