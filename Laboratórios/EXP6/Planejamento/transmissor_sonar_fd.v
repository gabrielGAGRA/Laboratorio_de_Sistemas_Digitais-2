`default_nettype none

/* 
 *  Descricao : Fluxo de dados do transmissor de dados do sonar.
 *              Contem o contador de indice de 8 caracteres (0 a 7),
 *              o multiplexador ASCII 8x1 e o transmissor serial tx_serial_7E1.
 */

module transmissor_sonar_fd (
    input  wire        clock,
    input  wire        reset,
    input  wire        zera_indice,
    input  wire        conta_indice,
    input  wire        partida_serial,
    input  wire [23:0] angulo,
    input  wire [11:0] distancia,
    output wire        fim_caracteres,
    output wire        saida_serial,
    output wire        pronto_serial,
    output wire        db_partida,
    output wire        db_saida_serial,
    output wire [2:0]  db_indice,
    output wire [6:0]  db_dados_ascii
);

    reg  [2:0] indice_q;
    reg  [6:0] s_dado_ascii;
    wire       s_saida_serial;

    // Contador de indice de caracteres (0 a 7)
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            indice_q <= 3'd0;
        end else if (zera_indice) begin
            indice_q <= 3'd0;
        end else if (conta_indice) begin
            indice_q <= indice_q + 3'd1;
        end
    end

    assign fim_caracteres = (indice_q == 3'd7);

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

    // Instanciacao do transmissor serial assincrono 7E1
    tx_serial_7E1 u_tx_serial_7E1 (
        .clock           (clock),
        .reset           (reset),
        .partida         (partida_serial),
        .dados_ascii     (s_dado_ascii),
        .saida_serial    (s_saida_serial),
        .pronto          (pronto_serial),
        .db_partida      (),
        .db_saida_serial (),
        .db_estado       ()
    );

    assign saida_serial    = s_saida_serial;
    assign db_partida      = partida_serial;
    assign db_saida_serial = s_saida_serial;
    assign db_indice       = indice_q;
    assign db_dados_ascii  = s_dado_ascii;

endmodule

`default_nettype wire
