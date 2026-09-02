// ---------------------------------------------------------------------------
// Modulo: debounce
// Descricao: Filtro generico e parametrizavel para debouncing de botoes mecanicos.
// ---------------------------------------------------------------------------
module debounce #(
    parameter WIDTH = 1, 
    parameter TEMPO_FILTRO = 100_000
) (
    input clock,
    input reset,
    input [WIDTH-1:0] in,
    output reg [WIDTH-1:0] out
);

    reg [19:0] contadores [WIDTH-1:0];
    reg [WIDTH-1:0] sync0;
    reg [WIDTH-1:0] sync1;
    integer i;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            out <= {WIDTH{1'b0}};
            sync0 <= {WIDTH{1'b0}};
            sync1 <= {WIDTH{1'b0}};
            for (i = 0; i < WIDTH; i = i + 1) begin
                contadores[i] <= 0;
            end
        end else begin
            sync0 <= in;
            sync1 <= sync0;

            for (i = 0; i < WIDTH; i = i + 1) begin
                if (sync1[i] == out[i]) begin
                    contadores[i] <= 0;
                end else begin
                    contadores[i] <= contadores[i] + 1'b1;
                    if (contadores[i] >= TEMPO_FILTRO) begin
                        out[i] <= sync1[i];
                        contadores[i] <= 0;
                    end
                end
            end
        end
    end

endmodule