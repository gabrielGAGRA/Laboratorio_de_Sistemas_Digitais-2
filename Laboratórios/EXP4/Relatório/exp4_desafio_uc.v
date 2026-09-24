`default_nettype none

module exp4_desafio_uc (
    input  wire       clock,
    input  wire       reset,
    input  wire       mensurar,       // Pulso de 1 ciclo vindo do edge_detector
    input  wire       pronto_sensor,  // Pulso de fim de medida da interface_hcsr04
    input  wire       pronto_serial,  // Pulso de fim de envio da tx_serial_7E1
    input  wire       fim_timer,      // Sinal de fim da contagem do intervalo de 2s
    input  wire       fim_medidas,    // Sinal de que a segunda medida esta em andamento/concluida
    output reg        medir,          // Pulso de disparo para o sensor
    output reg        partida,        // Pulso de disparo para a UART
    output reg  [1:0] sel_letra,      // Seletor do MUX 4x1 (0: C, 1: D, 2: U, 3: #)
    output reg        conta_timer,    // Habilita temporizador do intervalo de 2s
    output reg        zera_timer,     // Limpa temporizador de 2s
    output reg        conta_medida,   // Incrementa o contador de medidas
    output reg        zera_medida,    // Limpa o contador de medidas
    output reg        pronto,         // Trena finalizou ciclo completo da medida dupla
    output reg        db_espera_2s,   // Depuracao: circuito aguardando intervalo de 2s
    output reg  [3:0] db_estado       // Estado da FSM para depuracao (0 a 13)
);

    // Estados da FSM (Moore)
    localparam [3:0] STATE_INICIAL        = 4'd0,
                     STATE_INICIA_MEDIDA   = 4'd1,
                     STATE_ESPERA_MEDIDA   = 4'd2,
                     STATE_ENVIA_CENTENA   = 4'd3,
                     STATE_ESPERA_CENTENA  = 4'd4,
                     STATE_ENVIA_DEZENA    = 4'd5,
                     STATE_ESPERA_DEZENA   = 4'd6,
                     STATE_ENVIA_UNIDADE   = 4'd7,
                     STATE_ESPERA_UNIDADE  = 4'd8,
                     STATE_ENVIA_FINAL     = 4'd9,
                     STATE_ESPERA_FINAL    = 4'd10,
                     STATE_PREPARA_2S      = 4'd11,
                     STATE_ESPERA_2S       = 4'd12,
                     STATE_FIM             = 4'd13;

    // Registradores de estado
    reg [3:0] estado_q;
    reg [3:0] estado_d;

    // Memoria de estado
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_q <= STATE_INICIAL;
        end else begin
            estado_q <= estado_d;
        end
    end

    // Logica de proximo estado
    always @* begin
        estado_d = estado_q; // Default para evitar latches

        case (estado_q)
            STATE_INICIAL: begin
                if (mensurar) begin
                    estado_d = STATE_INICIA_MEDIDA;
                end else begin
                    estado_d = STATE_INICIAL;
                end
            end

            STATE_INICIA_MEDIDA: begin
                estado_d = STATE_ESPERA_MEDIDA;
            end

            STATE_ESPERA_MEDIDA: begin
                if (pronto_sensor) begin
                    estado_d = STATE_ENVIA_CENTENA;
                end else begin
                    estado_d = STATE_ESPERA_MEDIDA;
                end
            end

            STATE_ENVIA_CENTENA: begin
                estado_d = STATE_ESPERA_CENTENA;
            end

            STATE_ESPERA_CENTENA: begin
                if (pronto_serial) begin
                    estado_d = STATE_ENVIA_DEZENA;
                end else begin
                    estado_d = STATE_ESPERA_CENTENA;
                end
            end

            STATE_ENVIA_DEZENA: begin
                estado_d = STATE_ESPERA_DEZENA;
            end

            STATE_ESPERA_DEZENA: begin
                if (pronto_serial) begin
                    estado_d = STATE_ENVIA_UNIDADE;
                end else begin
                    estado_d = STATE_ESPERA_DEZENA;
                end
            end

            STATE_ENVIA_UNIDADE: begin
                estado_d = STATE_ESPERA_UNIDADE;
            end

            STATE_ESPERA_UNIDADE: begin
                if (pronto_serial) begin
                    estado_d = STATE_ENVIA_FINAL;
                end else begin
                    estado_d = STATE_ESPERA_UNIDADE;
                end
            end

            STATE_ENVIA_FINAL: begin
                estado_d = STATE_ESPERA_FINAL;
            end

            STATE_ESPERA_FINAL: begin
                if (pronto_serial) begin
                    if (fim_medidas) begin
                        estado_d = STATE_FIM;
                    end else begin
                        estado_d = STATE_PREPARA_2S;
                    end
                end else begin
                    estado_d = STATE_ESPERA_FINAL;
                end
            end

            STATE_PREPARA_2S: begin
                estado_d = STATE_ESPERA_2S;
            end

            STATE_ESPERA_2S: begin
                if (fim_timer) begin
                    estado_d = STATE_INICIA_MEDIDA;
                end else begin
                    estado_d = STATE_ESPERA_2S;
                end
            end

            STATE_FIM: begin
                estado_d = STATE_INICIAL;
            end

            default: begin
                estado_d = STATE_INICIAL;
            end
        endcase
    end

    // Logica de saida (FSM Moore)
    always @* begin
        // Valores default para prevencao de latches
        medir        = 1'b0;
        partida      = 1'b0;
        sel_letra    = 2'b00;
        conta_timer  = 1'b0;
        zera_timer   = 1'b0;
        conta_medida = 1'b0;
        zera_medida  = 1'b0;
        pronto       = 1'b0;
        db_espera_2s = 1'b0;
        db_estado    = estado_q;

        case (estado_q)
            STATE_INICIAL: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b1;
                conta_medida = 1'b0;
                zera_medida  = 1'b1;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_INICIA_MEDIDA: begin
                medir        = 1'b1;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b1;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ESPERA_MEDIDA: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ENVIA_CENTENA: begin
                medir        = 1'b0;
                partida      = 1'b1;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ESPERA_CENTENA: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ENVIA_DEZENA: begin
                medir        = 1'b0;
                partida      = 1'b1;
                sel_letra    = 2'b01;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ESPERA_DEZENA: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b01;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ENVIA_UNIDADE: begin
                medir        = 1'b0;
                partida      = 1'b1;
                sel_letra    = 2'b10;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ESPERA_UNIDADE: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b10;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ENVIA_FINAL: begin
                medir        = 1'b0;
                partida      = 1'b1;
                sel_letra    = 2'b11;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_ESPERA_FINAL: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b11;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end

            STATE_PREPARA_2S: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b1;
                conta_medida = 1'b1;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b1;
            end

            STATE_ESPERA_2S: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b1;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b1;
            end

            STATE_FIM: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b1;
                conta_medida = 1'b0;
                zera_medida  = 1'b1;
                pronto       = 1'b1;
                db_espera_2s = 1'b0;
            end

            default: begin
                medir        = 1'b0;
                partida      = 1'b0;
                sel_letra    = 2'b00;
                conta_timer  = 1'b0;
                zera_timer   = 1'b0;
                conta_medida = 1'b0;
                zera_medida  = 1'b0;
                pronto       = 1'b0;
                db_espera_2s = 1'b0;
            end
        endcase
    end

endmodule

`default_nettype wire
