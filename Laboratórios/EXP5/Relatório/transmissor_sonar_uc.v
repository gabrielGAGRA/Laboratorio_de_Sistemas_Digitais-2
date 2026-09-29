`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : transmissor_sonar_uc.v
 * --------------------------------------------------------------------------
 *  Descricao : Unidade de Controle do transmissor de dados do sonar.
 *              Controla o envio sequencial dos 8 caracteres ASCII:
 *              1. Espera comando transmitir=1
 *              2. Dispara partida serial para cada caractere
 *              3. Aguarda pronto_serial
 *              4. Incrementa indice ate o 8o caractere e conclui
 * --------------------------------------------------------------------------
 */

module transmissor_sonar_uc (
    input  wire       clock,
    input  wire       reset,
    input  wire       transmitir,
    input  wire       pronto_serial,
    input  wire       fim_caracteres,
    output reg        zera_indice,
    output reg        conta_indice,
    output reg        partida_serial,
    output reg        pronto,
    output wire [3:0] db_estado
);

    // Estados da FSM
    localparam [2:0] STATE_IDLE      = 3'b000,
                     STATE_SEND      = 3'b001,
                     STATE_WAIT_CHAR = 3'b010,
                     STATE_NEXT      = 3'b011,
                     STATE_DONE      = 3'b100;

    reg [2:0] estado_q, estado_d;

    // Registrador de estado
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_q <= STATE_IDLE;
        end else begin
            estado_q <= estado_d;
        end
    end

    // Logica de proximo estado
    always @* begin
        estado_d = estado_q;

        case (estado_q)
            STATE_IDLE: begin
                if (transmitir) begin
                    estado_d = STATE_SEND;
                end else begin
                    estado_d = STATE_IDLE;
                end
            end

            STATE_SEND: begin
                estado_d = STATE_WAIT_CHAR;
            end

            STATE_WAIT_CHAR: begin
                if (pronto_serial) begin
                    estado_d = STATE_NEXT;
                end else begin
                    estado_d = STATE_WAIT_CHAR;
                end
            end

            STATE_NEXT: begin
                if (fim_caracteres) begin
                    estado_d = STATE_DONE;
                end else begin
                    estado_d = STATE_SEND;
                end
            end

            STATE_DONE: begin
                estado_d = STATE_IDLE;
            end

            default: begin
                estado_d = STATE_IDLE;
            end
        endcase
    end

    // Logica de saida combinacional (Moore)
    always @* begin
        zera_indice    = 1'b0;
        conta_indice   = 1'b0;
        partida_serial = 1'b0;
        pronto         = 1'b0;

        case (estado_q)
            STATE_IDLE: begin
                zera_indice = 1'b1;
            end

            STATE_SEND: begin
                partida_serial = 1'b1;
            end

            STATE_WAIT_CHAR: begin
                // Aguarda fim do caractere serial
            end

            STATE_NEXT: begin
                if (!fim_caracteres) begin
                    conta_indice = 1'b1;
                end
            end

            STATE_DONE: begin
                pronto = 1'b1;
            end

            default: begin
                zera_indice = 1'b1;
            end
        endcase
    end

    assign db_estado = {1'b0, estado_q};

endmodule

`default_nettype wire
