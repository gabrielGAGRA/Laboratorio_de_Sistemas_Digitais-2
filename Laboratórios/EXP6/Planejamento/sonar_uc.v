`default_nettype none

/* 
 *  Descricao : Unidade de Controle do Sistema de Sonar Modificado (FSM).
 *              Controla o ciclo de operacao com bifurcacao de estados:
 *              - Ramo Modo 0 (Localizacao): varredura angular com avanco do servo
 *              - Ramo Modo 1 (Atencao): operacao com posicao angular congelada
 */

module sonar_uc (
    input  wire       clock,
    input  wire       reset,
    input  wire       ligar,
    input  wire       modo,
    input  wire       fim_timer,
    input  wire       fim_medida,
    input  wire       fim_transmissao,
    output reg        zera_posicao,
    output reg        conta_posicao,
    output reg        zera_timer,
    output reg        conta_timer,
    output reg        medir,
    output reg        transmitir,
    output reg        fim_posicao,
    output wire [3:0] db_estado
);

    // Estados Comuns e de Coordenacao
    localparam [3:0] STATE_INICIAL             = 4'h0, // 0
                     STATE_PREPARA_SERVO       = 4'h1; // 1

    // Ramo Modo 0: Localizacao / Varredura Normal
    localparam [3:0] STATE_ESPERA_TIMER_0      = 4'h2, // 2
                     STATE_DISPARA_MEDIDA_0    = 4'h3, // 3
                     STATE_ESPERA_MEDIDA_0     = 4'h4, // 4
                     STATE_DISPARA_TX_0        = 4'h5, // 5
                     STATE_ESPERA_TX_0         = 4'h6, // 6
                     STATE_PROXIMA_POSICAO_0   = 4'h7; // 7

    // Ramo Modo 1: Atencao / Posicao Estatica
    localparam [3:0] STATE_ESPERA_TIMER_1      = 4'hA, // 10
                     STATE_DISPARA_MEDIDA_1    = 4'hB, // 11
                     STATE_ESPERA_MEDIDA_1     = 4'hC, // 12
                     STATE_DISPARA_TX_1        = 4'hD, // 13
                     STATE_ESPERA_TX_1         = 4'hE, // 14
                     STATE_FIM_CICLO_1         = 4'hF; // 15

    reg [3:0] estado_q, estado_d;

    // Registrador de estado
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_q <= STATE_INICIAL;
        end else begin
            estado_q <= estado_d;
        end
    end

    // Logica de proximo estado (transicoes com bifurcacao)
    always @* begin
        case (estado_q)
            STATE_INICIAL: begin
                if (ligar) begin
                    estado_d = STATE_PREPARA_SERVO;
                end else begin
                    estado_d = STATE_INICIAL;
                end
            end

            STATE_PREPARA_SERVO: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (modo) begin
                    estado_d = STATE_ESPERA_TIMER_1;
                end else begin
                    estado_d = STATE_ESPERA_TIMER_0;
                end
            end

            // ==========================================
            // Sequencia de Estados: Modo 0 (Localizacao)
            // ==========================================
            STATE_ESPERA_TIMER_0: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_timer) begin
                    estado_d = STATE_DISPARA_MEDIDA_0;
                end else begin
                    estado_d = STATE_ESPERA_TIMER_0;
                end
            end

            STATE_DISPARA_MEDIDA_0: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else begin
                    estado_d = STATE_ESPERA_MEDIDA_0;
                end
            end

            STATE_ESPERA_MEDIDA_0: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_medida) begin
                    estado_d = STATE_DISPARA_TX_0;
                end else begin
                    estado_d = STATE_ESPERA_MEDIDA_0;
                end
            end

            STATE_DISPARA_TX_0: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else begin
                    estado_d = STATE_ESPERA_TX_0;
                end
            end

            STATE_ESPERA_TX_0: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_transmissao) begin
                    estado_d = STATE_PROXIMA_POSICAO_0;
                end else begin
                    estado_d = STATE_ESPERA_TX_0;
                end
            end

            STATE_PROXIMA_POSICAO_0: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (modo) begin
                    estado_d = STATE_ESPERA_TIMER_1;
                end else begin
                    estado_d = STATE_ESPERA_TIMER_0;
                end
            end

            // ==========================================
            // Sequencia de Estados: Modo 1 (Atencao)
            // ==========================================
            STATE_ESPERA_TIMER_1: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_timer) begin
                    estado_d = STATE_DISPARA_MEDIDA_1;
                end else begin
                    estado_d = STATE_ESPERA_TIMER_1;
                end
            end

            STATE_DISPARA_MEDIDA_1: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else begin
                    estado_d = STATE_ESPERA_MEDIDA_1;
                end
            end

            STATE_ESPERA_MEDIDA_1: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_medida) begin
                    estado_d = STATE_DISPARA_TX_1;
                end else begin
                    estado_d = STATE_ESPERA_MEDIDA_1;
                end
            end

            STATE_DISPARA_TX_1: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else begin
                    estado_d = STATE_ESPERA_TX_1;
                end
            end

            STATE_ESPERA_TX_1: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_transmissao) begin
                    estado_d = STATE_FIM_CICLO_1;
                end else begin
                    estado_d = STATE_ESPERA_TX_1;
                end
            end

            STATE_FIM_CICLO_1: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (!modo) begin
                    estado_d = STATE_ESPERA_TIMER_0;
                end else begin
                    estado_d = STATE_ESPERA_TIMER_1;
                end
            end

            default: begin
                estado_d = STATE_INICIAL;
            end
        endcase
    end

    // Logica de saidas combinacionais (Moore)
    always @* begin
        // Valores padrao
        zera_posicao  = 1'b0;
        conta_posicao = 1'b0;
        zera_timer    = 1'b0;
        conta_timer   = 1'b0;
        medir         = 1'b0;
        transmitir    = 1'b0;
        fim_posicao   = 1'b0;

        case (estado_q)
            STATE_INICIAL: begin
                zera_posicao = 1'b0; // Preserva posicao angular
                zera_timer   = 1'b1;
            end

            STATE_PREPARA_SERVO: begin
                zera_timer = 1'b1;
            end

            // Ramo Modo 0
            STATE_ESPERA_TIMER_0: begin
                conta_timer = 1'b1;
            end

            STATE_DISPARA_MEDIDA_0: begin
                medir = 1'b1;
            end

            STATE_ESPERA_MEDIDA_0: begin
                // Aguarda medida
            end

            STATE_DISPARA_TX_0: begin
                transmitir = 1'b1;
            end

            STATE_ESPERA_TX_0: begin
                // Aguarda transmissao
            end

            STATE_PROXIMA_POSICAO_0: begin
                conta_posicao = 1'b1;
                fim_posicao   = 1'b1;
                zera_timer    = 1'b1;
            end

            // Ramo Modo 1
            STATE_ESPERA_TIMER_1: begin
                conta_timer = 1'b1;
            end

            STATE_DISPARA_MEDIDA_1: begin
                medir = 1'b1;
            end

            STATE_ESPERA_MEDIDA_1: begin
                // Aguarda medida
            end

            STATE_DISPARA_TX_1: begin
                transmitir = 1'b1;
            end

            STATE_ESPERA_TX_1: begin
                // Aguarda transmissao
            end

            STATE_FIM_CICLO_1: begin
                conta_posicao = 1'b0; // Mantem a posicao fixa
                fim_posicao   = 1'b0;
                zera_timer    = 1'b1;
            end

            default: begin
                zera_posicao = 1'b0;
                zera_timer   = 1'b1;
            end
        endcase
    end

    assign db_estado = estado_q;

endmodule

`default_nettype wire
