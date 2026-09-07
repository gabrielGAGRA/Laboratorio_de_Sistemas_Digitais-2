// ---------------------------------------------------------------------------
// Modulo: piano_top
// Descricao: Top-Level do Piano. Interliga Fluxo de Dados e Controle.
// ---------------------------------------------------------------------------
module piano_top #(
    parameter DEBOUNCE_TECLA = 100_000, // 2ms 
    parameter DEBOUNCE_CONTROLE  = 200_000 // 4ms
) (
    input        CLOCK_50,
    input        reset_n,       // Ativo em baixo
    input  [6:0] gpio_keys,     
    input        btn_modo,      
    input        btn_musica,    
    input        btn_intensidade, // LED (PWM)
    input        btn_oitava_up,
    input        btn_oitava_down,
    input        btn_sustenido,
    
    // Saídas Físicas
    output       buzzer,
    output [6:0] led_vermelho,
    output       led_sustenido,
    output       led_oitava_up,
    output       led_oitava_down,
    
    // RF_STATUS_HEX
    output [6:0] hex5_modo,
    output [6:0] hex4_oitava,
    output [6:0] hex3_musica_dezena,
    output [6:0] hex2_musica_unidade,
    output [6:0] hex1_nota,
    output [6:0] hex0_sustenido
);

    wire reset = ~reset_n;

    // Sinais UC <-> Fluxo de Dados
    wire [1:0] fsm_modo_ativo;
    wire fsm_zera_end, fsm_conta_end, fsm_escreve_ram;
    wire fd_tem_nota_ativa, fd_acerto_nota, fd_fim_musica;
    wire [4:0] dbg_estado;
    wire [9:0] fd_endereco_ram;
    wire [2:0] fd_id_nota;
    wire [5:0] s_sel_musica;
    wire [6:0] s_db_botoes;
    wire fd_mudou_modo;
    wire fd_mudou_musica;
    wire s_pwm_out;
    wire fd_pulso_bpm;
    wire [1:0] fd_volume;
    wire fd_mostra_vol;
    
    wire fsm_tecla_pressionada_nivel = |s_db_botoes;
    wire fsm_tecla_pressionada;
    edge_detector ed_tecla_demo (
        .clock(CLOCK_50),
        .reset(reset),
        .sinal(fsm_tecla_pressionada_nivel),
        .pulso(fsm_tecla_pressionada)
    );

    // UC (RF_MODOS)
    unidade_controle fsm_inst (
        .clock(CLOCK_50),
        .reset(reset),
        .mudou_modo(fd_mudou_modo),
        .mudou_musica(fd_mudou_musica),
        .tem_nota_ativa(fd_tem_nota_ativa),
        .tecla_pressionada(fsm_tecla_pressionada),
        .acerto_nota(fd_acerto_nota),
        .fim_musica(fd_fim_musica),
        .pulso_bpm(fd_pulso_bpm),
        .modo_ativo(fsm_modo_ativo),
        .escreve_ram(fsm_escreve_ram),
        .zera_endereco(fsm_zera_end),
        .conta_endereco(fsm_conta_end),
        .estado_hex(dbg_estado)
    );


    wire [2:0] s_oitava_atual;
    wire       s_sustenido_atual;
    
    fluxo_dados #(
        .DEBOUNCE_TECLA(DEBOUNCE_TECLA),
        .DEBOUNCE_CONTROLE(DEBOUNCE_CONTROLE)
    ) fluxo_inst (
        .clock(CLOCK_50),
        .reset(reset),
        .botoes(gpio_keys),
        .btn_modo(~btn_modo),
        .btn_musica(~btn_musica),
        .btn_intensidade(~btn_intensidade),
        .btn_oitava_up(~btn_oitava_up),
        .btn_oitava_down(~btn_oitava_down),
        .btn_sustenido(btn_sustenido),
        .modo_ativo(fsm_modo_ativo),
        .escreve_ram(fsm_escreve_ram),
        .conta_endereco(fsm_conta_end),
        .zera_endereco(fsm_zera_end),
        .buzzer(buzzer),
        .leds(hex1_nota),
        .mudou_modo(fd_mudou_modo),
        .mudou_musica(fd_mudou_musica),
        .tem_nota_ativa(fd_tem_nota_ativa),
        .acerto_nota(fd_acerto_nota),
        .fim_musica(fd_fim_musica),
        .pulso_bpm(fd_pulso_bpm),
        .s_endereco_ram(fd_endereco_ram),
        .s_id_para_led(fd_id_nota),
        .out_sel_musica(s_sel_musica),
        .db_botoes(s_db_botoes),
        .pwm_out(s_pwm_out),
        .oitava_atual(s_oitava_atual),
        .sustenido_atual(s_sustenido_atual),
        .led_oitava_up(led_oitava_up),
        .led_oitava_down(led_oitava_down),
        .out_volume(fd_volume),
        .mostra_vol(fd_mostra_vol)
    );

    // Mapeamento extra de LEDs físicos
    assign led_sustenido = (fsm_modo_ativo == 2'd1) ? s_sustenido_atual : 1'b0;

    // DECODIFICADORES PARA DISPLAYS (RF_STATUS_HEX)

    // HEX5: Modo atual ou Centena do Volume
    wire [6:0] hex5_normal;
    hexa7seg disp5_inst (.hexa({3'b000, fsm_modo_ativo}), .display(hex5_normal));

    assign hex5_modo = fd_mostra_vol ?
                       ((fd_volume == 2'd0) ? 7'h79 : 7'h7F) : // Mostra '1' ou apaga
                       hex5_normal;

    // HEX4: Oitava atual ou Dezena do Volume (0, 7, 5)
    wire [6:0] hex4_normal;
    hexa7seg disp4_inst (.hexa({2'b00, s_oitava_atual}), .display(hex4_normal));

    assign hex4_oitava = fd_mostra_vol ?
                         ((fd_volume == 2'd0) ? 7'h40 :  // '0'
                          (fd_volume == 2'd1) ? 7'h78 :  // '7'
                                                7'h12) : // '5'
                         hex4_normal;

    // HEX3: Dezena da Música ou Unidade do Volume (sempre 0 ou 5)
    wire [6:0] hex3_normal;
    wire [5:0] actual_idx = s_sel_musica;
    // Se modo livre (0), apaga display (5'h1F é default apagado). Se for menor que 10, apaga dezena.
    wire [4:0] dez_idx = (fsm_modo_ativo == 2'd0) ? 5'h1F : ((actual_idx / 10) == 0) ? 5'h1F : (actual_idx / 10);
    hexa7seg disp3_inst (.hexa(dez_idx), .display(hex3_normal));

    assign hex3_musica_dezena = fd_mostra_vol ?
                         ((fd_volume == 2'd0) ? 7'h40 :  // '0'
                          (fd_volume == 2'd1) ? 7'h12 :  // '5'
                                                7'h40) : // '0'
                         hex3_normal;

    // HEX2: Unidade da Música ou Letra 'P' (Percentual)
    wire [6:0] hex2_normal;
    wire [4:0] uni_idx = (fsm_modo_ativo == 2'd0) ? 5'h1F : (actual_idx % 10);
    hexa7seg disp2_inst (.hexa(uni_idx), .display(hex2_normal));

    assign hex2_musica_unidade = fd_mostra_vol ?
                                 7'h0C : // Letra 'P' ativa em baixo
                                 hex2_normal;

    // HEX1: A nota conectada diretamente no 'leds' da instancia do fluxo_dados

    // HEX0: Sustenido
    display_sustenido disp0_inst (
        .sustenido(s_sustenido_atual),
        .display(hex0_sustenido)
    );

    // Multiplexador para acender LED vermelho (indicador da base selecionada/nota base do Cifra)
    // Acende no modo Aprendizado (1) e também no modo Demonstracao (3)
    wire [6:0] raw_led = ((fsm_modo_ativo == 2'd1 || fsm_modo_ativo == 2'd3) && fd_id_nota != 0) ? (7'b0000001 << (fd_id_nota - 1)) : 7'b0000000;
    
    // Mascara com PWM para alterar itensidade
    assign led_vermelho = raw_led & {7{s_pwm_out}};

endmodule