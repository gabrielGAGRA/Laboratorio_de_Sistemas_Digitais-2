`default_nettype none

module deslocador_n #(
    parameter N = 4
) (
    input  wire         clock,
    input  wire         reset,
    input  wire         carrega,
    input  wire         desloca,
    input  wire         entrada_serial,
    input  wire [N-1:0] dados,
    output wire [N-1:0] saida
);

    reg [N-1:0] dados_q;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            dados_q <= {N{1'b1}}; // Inicializa repouso com todos os bits em 1
        end else begin
            if (carrega) begin
                dados_q <= dados;
            end else if (desloca) begin
                dados_q <= {entrada_serial, dados_q[N-1:1]}; // Deslocamento a direita
            end
        end
    end

    assign saida = dados_q;

endmodule

`default_nettype wire