`default_nettype none

/* --------------------------------------------------------------------------
 *  Arquivo   : transmissor_sonar.v
 * --------------------------------------------------------------------------
 *  Descricao : Transmissor de dados do sonar.
 *              Recebe angulo (24 bits ASCII) e distancia (12 bits BCD)
 *              e transmite em bloco uma mensagem de 8 caracteres ASCII
 *              no formato "AAA,DDD#" via tx_serial_7E1 (115200 bauds, 7E1).
 * --------------------------------------------------------------------------
 */

module transmissor_sonar (
    input  wire        clock,
    input  wire        reset,
    input  wire        transmitir,
    input  wire [23:0] angulo,
    input  wire [11:0] distancia,
    output wire        saida_serial,
    output wire        pronto,
    output wire        db_partida,
    output wire        db_saida_serial,
    output wire [3:0]  db_estado
);

    // Estados da FSM interna
    localparam [2:0] STATE_IDLE      = 3'b000,
                     STATE_SEND      = 3'b001,
                     STATE_WAIT_CHAR = 3'b010,
                     STATE_NEXT      = 3'b011,
                     STATE_DONE      = 3'b100;

    reg [2:0] estado_q, estado_d;
    reg [2:0] indice_q, indice_d;
    reg [6:0] s_dado_ascii;
    reg       s_partida;
    reg       s_pronto;

    wire s_pronto_serial;
    wire s_saida_serial;

    // Multiplexador dos 8 caracteres ASCII
    always @* begin
        case (indice_q)
            3'd0:    s_dado_ascii = angulo[22:16];             // Centena angulo
            3'd1:    s_dado_ascii = angulo[14:8];              // Dezena angulo
            3'd2:    s_dado_ascii = angulo[6:0];               // Unidade angulo
            3'd3:    s_dado_ascii = 7'h2C;                     // ',' (virgula)
            3'd4:    s_dado_ascii = {3'b011, distancia[11:8]}; // Centena BCD distancia
            3'd5:    s_dado_ascii = {3'b011, distancia[7:4]};  // Dezena BCD distancia
            3'd6:    s_dado_ascii = {3'b011, distancia[3:0]};  // Unidade BCD distancia
            3'd7:    s_dado_ascii = 7'h23;                     // '#' (hashtag)
            default: s_dado_ascii = 7'h20;
        endcase
    end

    // Instanciacao do transmissor serial assincrono 7E1 refatorado
    tx_serial_7E1 u_tx_serial_7E1 (
        .clock           (clock),
        .reset           (reset),
        .partida         (s_partida),
        .dados_ascii     (s_dado_ascii),
        .saida_serial    (s_saida_serial),
        .pronto          (s_pronto_serial),
        .db_partida      (),
        .db_saida_serial (),
        .db_estado       ()
    );

    // Registrador de estado e indice
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_q <= STATE_IDLE;
            indice_q <= 3'd0;
        end else begin
            estado_q <= estado_d;
            indice_q <= indice_d;
        end
    end

    // Logica de transicao de estado e proximo indice
    always @* begin
        estado_d  = estado_q;
        indice_d  = indice_q;
        s_partida = 1'b0;
        s_pronto  = 1'b0;

        case (estado_q)
            STATE_IDLE: begin
                indice_d = 3'd0;
                if (transmitir) begin
                    estado_d = STATE_SEND;
                end
            end

            STATE_SEND: begin
                s_partida = 1'b1;
                estado_d  = STATE_WAIT_CHAR;
            end

            STATE_WAIT_CHAR: begin
                if (s_pronto_serial) begin
                    estado_d = STATE_NEXT;
                end
            end

            STATE_NEXT: begin
                if (indice_q == 3'd7) begin
                    estado_d = STATE_DONE;
                end else begin
                    indice_d = indice_q + 3'd1;
                    estado_d = STATE_SEND;
                end
            end

            STATE_DONE: begin
                s_pronto = 1'b1;
                estado_d = STATE_IDLE;
            end

            default: begin
                estado_d = STATE_IDLE;
            end
        endcase
    end

    // Saidas
    assign saida_serial    = s_saida_serial;
    assign pronto          = s_pronto;
    assign db_partida      = s_partida;
    assign db_saida_serial = s_saida_serial;
    assign db_estado       = {1'b0, estado_q};

endmodule

`default_nettype wire
