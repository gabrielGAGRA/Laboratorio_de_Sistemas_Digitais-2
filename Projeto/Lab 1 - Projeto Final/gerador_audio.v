// ---------------------------------------------------------------------------
// Modulo: gerador_audio (Versao Piano)
// Descricao: Simula a dinamica de um piano com ataque rapido e 
// decaimento longo ate o silencio.
// ---------------------------------------------------------------------------
module gerador_audio (
    input        clock,       
    input        reset,
    input [17:0] fim_contagem,  
    input        habilitar,     
    input  [3:0] nivel_volume,  
    output       buzzer
);

    // 1. Geração da Onda Base (Duty cycle estreito para som mais "fino")
    reg [17:0] contador_freq;
    reg        onda_quadrada;
    wire [17:0] threshold = (fim_contagem >> 4); // 6.25% - som mais percussivo

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            contador_freq <= 18'd0;
            onda_quadrada <= 1'b0;
        end else if (habilitar || envelope_val > 0) begin
            if (contador_freq >= fim_contagem) contador_freq <= 18'd0;
            else contador_freq <= contador_freq + 1'b1;
            onda_quadrada <= (contador_freq < threshold);
        end else begin
            contador_freq <= 18'd0;
            onda_quadrada <= 1'b0;
        end
    end

    // 2. Envelope ADSR Estilo Piano
    reg [9:0]  envelope_val;
    reg [19:0] timer_envelope;
    reg        habilitar_antigo;
    
    // Estados do Envelope
    localparam IDLE    = 2'd0;
    localparam ATTACK  = 2'd1;
    localparam DECAY   = 2'd2;
    localparam RELEASE = 2'd3;
    reg [1:0] estado_adsr;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            envelope_val <= 10'd0;
            timer_envelope <= 20'd0;
            estado_adsr <= IDLE;
            habilitar_antigo <= 1'b0;
        end else begin
            habilitar_antigo <= habilitar;

            case (estado_adsr)
                IDLE: begin
                    if (habilitar && !habilitar_antigo) begin
                        estado_adsr <= ATTACK;
                        timer_envelope <= 20'd0;
                    end else begin
                        envelope_val <= 10'd0;
                    end
                end

                ATTACK: begin
                    // Ataque muito rapido (rampa de ~2ms para evitar estalo)
                    if (timer_envelope >= 20'd100) begin 
                        timer_envelope <= 20'd0;
                        if (envelope_val >= 10'd1000) estado_adsr <= DECAY;
                        else envelope_val <= envelope_val + 10'd20; // Sobe em degraus grandes
                    end else timer_envelope <= timer_envelope + 1'b1;
                end

                DECAY: begin
                    if (!habilitar) begin
                        estado_adsr <= RELEASE;
                        timer_envelope <= 20'd0;
                    end else begin
                        // Decaimento: mantemos o tempo, mas cortamos no limiar de trepidação
                        if (timer_envelope >= 20'd150_000) begin 
                            timer_envelope <= 20'd0;
                            // Threshold de 150 para evitar o ruído mecânico do buzzer
                            if (envelope_val > 10'd150) envelope_val <= envelope_val - 1'b1;
                            else begin
                                envelope_val <= 10'd0; // Corte abrupto (Noise Gate)
                                estado_adsr <= IDLE;
                            end
                        end else timer_envelope <= timer_envelope + 1'b1;
                    end
                end

                RELEASE: begin
                    if (habilitar) begin 
                        estado_adsr <= ATTACK;
                        timer_envelope <= 20'd0;
                    end else begin
                        // Release otimizado: ~68ms total a 50MHz
                        if (timer_envelope >= 20'd20_000) begin
                            timer_envelope <= 20'd0;
                            
                            // Subtrai de 5 em 5 para uma queda natural, mas rápida
                            if (envelope_val > 10'd150) begin
                                envelope_val <= envelope_val - 10'd5;
                            end else begin
                                envelope_val <= 10'd0; // Noise gate: corta a trepidação
                                estado_adsr <= IDLE;
                            end
                        end else timer_envelope <= timer_envelope + 1'b1;
                    end
                end
            endcase
        end
    end

    // 3. Ganho e PWM (Mesma logica anterior)
    wire [13:0] calc_ganho = envelope_val * nivel_volume;
    wire [9:0] volume_final = calc_ganho[13:4];
    reg [9:0] contador_pwm_hf;
    
    always @(posedge clock or posedge reset) begin
        if (reset) contador_pwm_hf <= 10'd0;
        else if (contador_pwm_hf >= 10'd1000) contador_pwm_hf <= 10'd0;
        else contador_pwm_hf <= contador_pwm_hf + 1'b1;
    end

    assign buzzer = onda_quadrada & (contador_pwm_hf < volume_final);

endmodule
