`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : sonar_uc.v
 * --------------------------------------------------------------------------
 *  Descricao : Unidade de Controle do Sistema de Sonar (FSM).
 *              Controla o ciclo de varredura:
 *              1. Espera ligar=1
 *              2. Inicializacao do servomotor na posicao 000
 *              3. Temporizacao de repouso (2s real / 200us simulacao)
 *              4. Medicao de distancia (HC-SR04)
 *              5. Transmissao serial de bloco ASCII ("AAA,DDD#")
 *              6. Avanco do servomotor e geracao de pulso fim_posicao
 * --------------------------------------------------------------------------
 */

module sonar_uc (
    input  wire       clock,
    input  wire       reset,
    input  wire       ligar,
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

    localparam [3:0] STATE_INICIAL            = 4'b0000, // 0
                     STATE_PREPARA_SERVO      = 4'b0001, // 1
                     STATE_ESPERA_TIMER       = 4'b0010, // 2
                     STATE_DISPARA_MEDIDA     = 4'b0011, // 3
                     STATE_ESPERA_MEDIDA      = 4'b0100, // 4
                     STATE_DISPARA_TRANSMISSAO= 4'b0101, // 5
                     STATE_ESPERA_TRANSMISSAO = 4'b0110, // 6
                     STATE_PROXIMA_POSICAO    = 4'b0111; // 7

    reg [3:0] estado_q, estado_d;

    // Registrador de estado
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_q <= STATE_INICIAL;
        end else begin
            estado_q <= estado_d;
        end
    end

    // Logica de transicao de estados
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
                end else begin
                    estado_d = STATE_ESPERA_TIMER;
                end
            end

            STATE_ESPERA_TIMER: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_timer) begin
                    estado_d = STATE_DISPARA_MEDIDA;
                end else begin
                    estado_d = STATE_ESPERA_TIMER;
                end
            end

            STATE_DISPARA_MEDIDA: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else begin
                    estado_d = STATE_ESPERA_MEDIDA;
                end
            end

            STATE_ESPERA_MEDIDA: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_medida) begin
                    estado_d = STATE_DISPARA_TRANSMISSAO;
                end else begin
                    estado_d = STATE_ESPERA_MEDIDA;
                end
            end

            STATE_DISPARA_TRANSMISSAO: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else begin
                    estado_d = STATE_ESPERA_TRANSMISSAO;
                end
            end

            STATE_ESPERA_TRANSMISSAO: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else if (fim_transmissao) begin
                    estado_d = STATE_PROXIMA_POSICAO;
                end else begin
                    estado_d = STATE_ESPERA_TRANSMISSAO;
                end
            end

            STATE_PROXIMA_POSICAO: begin
                if (!ligar) begin
                    estado_d = STATE_INICIAL;
                end else begin
                    estado_d = STATE_ESPERA_TIMER;
                end
            end

            default: begin
                estado_d = STATE_INICIAL;
            end
        endcase
    end

    // Logica de saidas combinacionais (Moore)
    always @* begin
        zera_posicao  = 1'b0;
        conta_posicao = 1'b0;
        zera_timer    = 1'b0;
        conta_timer   = 1'b0;
        medir         = 1'b0;
        transmitir    = 1'b0;
        fim_posicao   = 1'b0;

        case (estado_q)
            STATE_INICIAL: begin
                zera_posicao = 1'b1;
                zera_timer   = 1'b1;
            end

            STATE_PREPARA_SERVO: begin
                zera_timer = 1'b1;
            end

            STATE_ESPERA_TIMER: begin
                conta_timer = 1'b1;
            end

            STATE_DISPARA_MEDIDA: begin
                medir = 1'b1;
            end

            STATE_ESPERA_MEDIDA: begin
                // Apenas aguarda
            end

            STATE_DISPARA_TRANSMISSAO: begin
                transmitir = 1'b1;
            end

            STATE_ESPERA_TRANSMISSAO: begin
                // Apenas aguarda
            end

            STATE_PROXIMA_POSICAO: begin
                conta_posicao = 1'b1;
                fim_posicao   = 1'b1;
                zera_timer    = 1'b1;
            end

            default: begin
                zera_posicao = 1'b1;
                zera_timer   = 1'b1;
            end
        endcase
    end

    assign db_estado = estado_q;

endmodule

`default_nettype wire
