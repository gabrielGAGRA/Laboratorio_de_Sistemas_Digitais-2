`default_nettype none

/*
 *  Descricao : Unidade de controle do circuito de recepcao serial assincrona.
 *              Implementa superamostragem de tick (meio do bit).
 */

module rx_serial_uc (
    input  wire       clock,
    input  wire       reset,
    input  wire       RX,
    input  wire       tick,
    input  wire       fim,
    output reg        registra,
    output reg        zera,
    output reg        zera_tick,
    output reg        conta,
    output reg        carrega,
    output reg        desloca,
    output reg        pronto,
    output wire [3:0] db_estado
);

    localparam [3:0] STATE_INICIAL    = 4'd0,  // 4'b0000
                     STATE_PREPARACAO = 4'd2,  // 4'b0010
                     STATE_ESPERA     = 4'd3,  // 4'b0011
                     STATE_RECEPCAO   = 4'd7,  // 4'b0111
                     STATE_REGISTRAR  = 4'd9,  // 4'b1001
                     STATE_FINAL_RX   = 4'd15; // 4'b1111

    reg [3:0] estado_q, estado_d;

    // Memoria de estado (processo sequencial)
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_q <= STATE_INICIAL;
        end else begin
            estado_q <= estado_d;
        end
    end

    // Logica de proximo estado (processo combinacional)
    always @* begin
        case (estado_q)
            STATE_INICIAL: begin
                estado_d = RX ? STATE_INICIAL : STATE_PREPARACAO;
            end

            STATE_PREPARACAO: begin
                estado_d = STATE_ESPERA;
            end

            STATE_ESPERA: begin
                if (tick) begin
                    estado_d = STATE_RECEPCAO;
                end else if (fim) begin
                    estado_d = STATE_REGISTRAR;
                end else begin
                    estado_d = STATE_ESPERA;
                end
            end

            STATE_RECEPCAO: begin
                estado_d = STATE_ESPERA;
            end

            STATE_REGISTRAR: begin
                estado_d = STATE_FINAL_RX;
            end

            STATE_FINAL_RX: begin
                estado_d = STATE_INICIAL;
            end

            default: begin
                estado_d = STATE_INICIAL;
            end
        endcase
    end

    // Logica de saida (maquina de Moore)
    always @* begin
        // Valores padrao (prevencao de latches)
        registra  = 1'b0;
        zera      = 1'b0;
        zera_tick = 1'b0;
        conta     = 1'b0;
        carrega   = 1'b0;
        desloca   = 1'b0;
        pronto    = 1'b0;

        case (estado_q)
            STATE_INICIAL: begin
                zera = 1'b1;
            end

            STATE_PREPARACAO: begin
                carrega   = 1'b1;
                zera_tick = 1'b1;
            end

            STATE_ESPERA: begin
                // Apenas aguarda condicoes de tick ou fim
            end

            STATE_RECEPCAO: begin
                desloca = 1'b1;
                conta   = 1'b1;
            end

            STATE_REGISTRAR: begin
                registra = 1'b1;
            end

            STATE_FINAL_RX: begin
                pronto = 1'b1;
            end

            default: begin
                zera = 1'b1;
            end
        endcase
    end

    assign db_estado = estado_q;

endmodule

`default_nettype wire
