// ---------------------------------------------------------------------------
// Modulo: guarda_oitava
// Descricao: Controla oitava atual, incrementando ou decrementando.
// ---------------------------------------------------------------------------
module guarda_oitava (
    input            clock,
    input            reset,
    input            btn_up_pulse,
    input            btn_down_pulse,
    output reg [2:0] oitava_atual
);

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            oitava_atual <= 3'b100;
        end else begin
            if (btn_up_pulse) begin
                if (oitava_atual < 3'b111)
                    oitava_atual <= oitava_atual + 1'b1;
            end else if (btn_down_pulse) begin
                if (oitava_atual > 3'b100)
                    oitava_atual <= oitava_atual - 1'b1;
            end
        end
    end

endmodule
