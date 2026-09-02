// ---------------------------------------------------------------------------
// Modulo: mux_musicas
// Descricao: Seletor de dados das memorias ROM (musicas) e RAM (gravacao)
// ---------------------------------------------------------------------------
module mux_musicas (
    input [5:0] sel,
    input [6:0] d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, d16, d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27, d28, d29, d30, d31, d32, d33, d34, d35, d36, d37, d38,
    output reg [6:0] out
);
    always @(*) begin
        case(sel)
            6'd0: out = d0;
            6'd1: out = d1;
            6'd2: out = d2;
            6'd3: out = d3;
            6'd4: out = d4;
            6'd5: out = d5;
            6'd6: out = d6;
            6'd7: out = d7;
            6'd8: out = d8;
            6'd9: out = d9;
            6'd10: out = d10;
            6'd11: out = d11;
            6'd12: out = d12;
            6'd13: out = d13;
            6'd14: out = d14;
            6'd15: out = d15;
            6'd16: out = d16;
            6'd17: out = d17;
            6'd18: out = d18;
            6'd19: out = d19;
            6'd20: out = d20;
            6'd21: out = d21;
            6'd22: out = d22;
            6'd23: out = d23;
            6'd24: out = d24;
            6'd25: out = d25;
            6'd26: out = d26;
            6'd27: out = d27;
            6'd28: out = d28;
            6'd29: out = d29;
            6'd30: out = d30;
            6'd31: out = d31;
			6'd32: out = d32;
            6'd33: out = d33;
            6'd34: out = d34;
            6'd35: out = d35;
            6'd36: out = d36;
            6'd37: out = d37;
            6'd38: out = d38;
				6'd39: out = d39;
            default: out = 7'b0;
        endcase
    end
endmodule
