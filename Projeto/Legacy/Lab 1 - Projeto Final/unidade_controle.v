// ---------------------------------------------------------------------------
// Modulo: unidade_controle
// Descricao: FSM de controle do Piano (Gerencia estados Musicais e de Modo)
// ---------------------------------------------------------------------------
module unidade_controle (
    input clock,
    input reset,
    
    // Entradas
    input mudou_modo,       
    input mudou_musica,
    input tem_nota_ativa,
    input tecla_pressionada,   
    input acerto_nota,      
    input fim_musica,      
    input pulso_bpm,
    
    // Saidas de Estado
    output reg [1:0] modo_ativo, 
    output reg escreve_ram,
    output reg zera_endereco,
    output reg conta_endereco,
    output reg [4:0] estado_hex // Para depuracao so
);

    // Estados da UC
    parameter INICIAL           = 5'd0;
    parameter LIVRE             = 5'd1;
    
    // Aprendizado
    parameter INICIA_MUSICA     = 5'd2;
    parameter ESPERA_NOTA       = 5'd3;  
    parameter COMPARA_NOTA      = 5'd4;  
    parameter PROXIMO           = 5'd5;  
    parameter ESPERA_SOLTAR     = 5'd6;  
    parameter FIM_MUSICA_ST     = 5'd7; 
    parameter LE_RAM_MODO1      = 5'd16;

    // Gravacao
    parameter INICIA_GRAVACAO   = 5'd8;
    parameter GRAV_ESPERA_NOTA  = 5'd9;
    parameter GRAV_ARMAZENA     = 5'd10;
    parameter GRAV_PROXIMO      = 5'd11;
    parameter GRAV_SOLTAR       = 5'd12;
    
    // Demonstracao
    parameter INICIA_DEMO       = 5'd15;
    parameter DEMO_TOCA_NOTA    = 5'd13;
    parameter DEMO_PROXIMO      = 5'd14;

    reg [4:0] state, next_state;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            state <= INICIAL;
        end else begin
            state <= next_state; 
        end
    end

    // Logica de proximo estado e saidas
    always @(*) begin
        // Valores padrao
        next_state = state;
        modo_ativo = 2'd0;
        escreve_ram = 1'b0;
        zera_endereco = 1'b0;
        conta_endereco = 1'b0;
        estado_hex = 5'd0;

        case (state)
            INICIAL: begin
                zera_endereco = 1'b1;
                estado_hex = 5'h0; 
                modo_ativo = 2'd0;
                next_state = LIVRE; 
            end

            LIVRE: begin
                zera_endereco = 1'b1;    
                estado_hex = 5'h0; 
                modo_ativo = 2'd0;
                if (mudou_modo) next_state = INICIA_MUSICA;
            end
            
            // ---------------- APRENDIZADO ----------------
            INICIA_MUSICA: begin
                modo_ativo = 2'd1;
                zera_endereco = 1'b1;    
                estado_hex = 5'h1;
                next_state = ESPERA_NOTA;
            end

            ESPERA_NOTA: begin
                modo_ativo = 2'd1;
                estado_hex = 5'h1; 
                if (mudou_modo) next_state = INICIA_GRAVACAO;
                else if (mudou_musica) next_state = INICIA_MUSICA;
                else if (tem_nota_ativa) next_state = COMPARA_NOTA;
            end
            

            COMPARA_NOTA: begin
                modo_ativo = 2'd1;
                estado_hex = 5'h1;
                if (mudou_modo) next_state = INICIA_GRAVACAO;
                else if (mudou_musica) next_state = INICIA_MUSICA;
                else if (acerto_nota) next_state = ESPERA_SOLTAR;
                else if (!tem_nota_ativa) next_state = ESPERA_NOTA; 
            end

            ESPERA_SOLTAR: begin
                modo_ativo = 2'd1;
                estado_hex = 5'h1; 
                if (mudou_modo) next_state = INICIA_GRAVACAO;
                else if (mudou_musica) next_state = INICIA_MUSICA;
                else if (!tem_nota_ativa) begin
                    if (fim_musica) next_state = FIM_MUSICA_ST;
                    else next_state = PROXIMO;
                end
            end

            PROXIMO: begin
                modo_ativo = 2'd1;
                estado_hex = 5'h1; 
                conta_endereco = 1'b1; 
                next_state = LE_RAM_MODO1; 
            end
            
            LE_RAM_MODO1: begin 
                modo_ativo = 2'd1;
                estado_hex = 5'h1;
                next_state = ESPERA_NOTA;
            end

            FIM_MUSICA_ST: begin
                modo_ativo = 2'd1;
                estado_hex = 5'h1;
                if (mudou_modo) next_state = INICIA_GRAVACAO;
            end
            
            // ---------------- GRAVACAO ----------------
            INICIA_GRAVACAO: begin
                modo_ativo = 2'd2;
                zera_endereco = 1'b1;
                estado_hex = 5'h2;
                next_state = GRAV_ESPERA_NOTA;
            end

            GRAV_ESPERA_NOTA: begin
                modo_ativo = 2'd2;
                estado_hex = 5'h2;
                if (mudou_modo) next_state = INICIA_DEMO;
                else if (tem_nota_ativa) next_state = GRAV_ARMAZENA;
            end

            GRAV_ARMAZENA: begin
                modo_ativo = 2'd2;
                estado_hex = 5'h2;
                escreve_ram = 1'b1;
                next_state = GRAV_PROXIMO;
            end

            GRAV_PROXIMO: begin
                modo_ativo = 2'd2;
                estado_hex = 5'h2;
                conta_endereco = 1'b1;
                next_state = GRAV_SOLTAR;
            end

            GRAV_SOLTAR: begin
                modo_ativo = 2'd2;
                estado_hex = 5'h2;
                if (mudou_modo) next_state = INICIA_DEMO;
                else if (!tem_nota_ativa) begin
                    if (fim_musica) next_state = GRAV_ESPERA_NOTA; 
                    else next_state = GRAV_ESPERA_NOTA;
                end
            end
            
            // ---------------- DEMONSTRACAO ----------------
            INICIA_DEMO: begin
                modo_ativo = 2'd3;
                zera_endereco = 1'b1;
                estado_hex = 5'h3;
                if (mudou_modo) next_state = LIVRE;
                else if (mudou_musica) next_state = INICIA_DEMO;
                else if (tecla_pressionada) next_state = DEMO_TOCA_NOTA;
            end
            
            DEMO_TOCA_NOTA: begin
                modo_ativo = 2'd3;
                estado_hex = 5'h3;
                if (mudou_modo) next_state = LIVRE;
                else if (mudou_musica) next_state = INICIA_DEMO;
                else if (pulso_bpm) begin
                    if (fim_musica) next_state = INICIA_DEMO;
                    else next_state = DEMO_PROXIMO;
                end
            end
            
            DEMO_PROXIMO: begin
                modo_ativo = 2'd3;
                estado_hex = 5'h3;
                conta_endereco = 1'b1;
                if (mudou_modo) next_state = LIVRE;
                else if (mudou_musica) next_state = INICIA_DEMO;
                else next_state = DEMO_TOCA_NOTA;
            end

            default: next_state = INICIAL;
        endcase
    end
endmodule
