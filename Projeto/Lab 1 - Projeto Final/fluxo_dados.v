// ---------------------------------------------------------------------------
// Modulo: fluxo_dados
// Descricao: Caminho de dados unificado para modos.
// ---------------------------------------------------------------------------
module fluxo_dados #(
    parameter DEBOUNCE_TECLA = 100_000, // Aqui a latencia é importante. Medimos quase 1ms, usaremos 2ms.
    parameter DEBOUNCE_CONTROLE  = 400_000 // Medimos 4ms de debounce, usaremos 8ms por segurança 
) (
    input        clock,
    input        reset,

    // -- Entradas --
    input  [6:0] botoes,
    input        btn_modo,
    input        btn_musica,
    input        btn_intensidade, 
    input        btn_oitava_up,
    input        btn_oitava_down,
    input        btn_sustenido,

    // -- Entradas da unidade de controle --
    input  [1:0] modo_ativo,
    input        escreve_ram,
    input        conta_endereco,
    input        zera_endereco,

    // -- Saídas Físicas --
    output       buzzer,
    output [6:0] leds,

    // -- Status --
    output       mudou_modo,       
    output       mudou_musica,
    output       tem_nota_ativa,  
    output       acerto_nota,      
    output       fim_musica,       
    output       pulso_bpm,        
    output [9:0] s_endereco_ram,  
    output [2:0] s_id_para_led,    
    output [5:0] out_sel_musica,   
    output [6:0] db_botoes,        
    output       pwm_out,
    output [2:0] oitava_atual,
    output       sustenido_atual,
    output       led_oitava_up,
    output       led_oitava_down,
    output [1:0] out_volume,
    output       mostra_vol
);

    wire [6:0] s_botoes_db;
    wire s_btn_modo_db, s_btn_musica_db, s_btn_intensidade_db;
    wire s_btn_oitava_up_db, s_btn_oitava_down_db, s_btn_sustenido_db;
    
    // Debouncers (TECLA)
    debounce #(.WIDTH(7), .TEMPO_FILTRO(DEBOUNCE_TECLA)) db_notas (
        .clock(clock), .reset(reset), .in(botoes), .out(s_botoes_db)
    );
    debounce #(.WIDTH(1), .TEMPO_FILTRO(DEBOUNCE_TECLA)) db_sustenido (
        .clock(clock), .reset(reset), .in(btn_sustenido), .out(s_btn_sustenido_db)
    );

    // Debouncers (CONTROLE)
    debounce #(.WIDTH(1), .TEMPO_FILTRO(DEBOUNCE_CONTROLE)) db_modo (
        .clock(clock), .reset(reset), .in(btn_modo), .out(s_btn_modo_db)
    );
    debounce #(.WIDTH(1), .TEMPO_FILTRO(DEBOUNCE_CONTROLE)) db_musica (
        .clock(clock), .reset(reset), .in(btn_musica), .out(s_btn_musica_db)
    );
    debounce #(.WIDTH(1), .TEMPO_FILTRO(DEBOUNCE_CONTROLE)) db_intensidade (
        .clock(clock), .reset(reset), .in(btn_intensidade), .out(s_btn_intensidade_db)
    );
    debounce #(.WIDTH(1), .TEMPO_FILTRO(DEBOUNCE_CONTROLE)) db_oitava_up (
        .clock(clock), .reset(reset), .in(btn_oitava_up), .out(s_btn_oitava_up_db)
    );
    debounce #(.WIDTH(1), .TEMPO_FILTRO(DEBOUNCE_CONTROLE)) db_oitava_down (
        .clock(clock), .reset(reset), .in(btn_oitava_down), .out(s_btn_oitava_down_db)
    );

// --- Lógica de Combinação (MODO + INTENSIDADE) ---
    wire s_modo_pressed = s_btn_modo_db;
    reg r_modo_prev;
    always @(posedge clock) r_modo_prev <= s_modo_pressed;
    wire s_modo_released = (~s_modo_pressed && r_modo_prev);

    reg combo_ativo;
    // 0 = 100%, 1 = 50%, 2 = 25%
    reg [1:0] estado_vol;
    reg [25:0] timer_display_vol;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            combo_ativo <= 0;
            estado_vol <= 0;
            timer_display_vol <= 0;
        end else begin
            // Se está a SEGURAR o MODO e clica na INTENSIDADE (Comportamento Shift)
            if (s_modo_pressed && s_btn_intensidade_pulse) begin
                combo_ativo <= 1; // Regista que o combo foi usado
                timer_display_vol <= 26'd50_000_000; // Display ativo por 1s
                
                // Cicla o volume (0, 1, 2)
                if (estado_vol == 2'd2) estado_vol <= 2'd0;
                else estado_vol <= estado_vol + 1'b1;
            end 
            // Quando solta o botão modo, limpa a flag do combo
            else if (~s_modo_pressed) begin
                combo_ativo <= 0;
            end

            if (timer_display_vol > 0) timer_display_vol <= timer_display_vol - 1;
        end
    end

    // O Modo só muda quando o botão é SOLTO E se não tiver sido usado como Shift
    assign mudou_modo = s_modo_released && !combo_ativo;
    assign out_volume = estado_vol;
    assign mostra_vol = (timer_display_vol > 0);

    wire s_btn_musica_pulse;
    edge_detector ed_musica (.clock(clock), .reset(reset), .sinal(s_btn_musica_db), .pulso(s_btn_musica_pulse));
    assign mudou_musica = s_btn_musica_pulse;
    
    wire s_btn_intensidade_pulse;
    edge_detector ed_intensidade (.clock(clock), .reset(reset), .sinal(s_btn_intensidade_db), .pulso(s_btn_intensidade_pulse));
    
    wire s_btn_oitava_up_pulse;
    edge_detector ed_oit_up (.clock(clock), .reset(reset), .sinal(s_btn_oitava_up_db), .pulso(s_btn_oitava_up_pulse));
    
    wire s_btn_oitava_down_pulse;
    edge_detector ed_oit_down (.clock(clock), .reset(reset), .sinal(s_btn_oitava_down_db), .pulso(s_btn_oitava_down_pulse));

    // Seletor de musica
    wire [5:0] s_sel_musica;
    contador_m #(.M(40), .N(6)) contador_musica (
        .clock(clock), .zera_as(1'b0), .zera_s(reset), .conta(s_btn_musica_pulse),
        .Q(s_sel_musica), .fim(), .meio()
    );

    wire [5:0] mux_sel = (modo_ativo == 2'd2) ? 6'd39 : s_sel_musica;
    assign out_sel_musica = mux_sel;
    assign db_botoes = s_botoes_db;

    // Gerenciador de oitava livre
    wire [2:0] s_oitava_livre;
    guarda_oitava oitava_inst (
        .clock(clock), .reset(reset),
        .btn_up_pulse(s_btn_oitava_up_pulse), .btn_down_pulse(s_btn_oitava_down_pulse),
        .oitava_atual(s_oitava_livre)
    );

    wire [2:0] s_nota_tocada;
    wire       s_tem_nota;
    wire [17:0] s_n_ticks;
    
    wire [6:0] s_dado_ram;
    wire [2:0] s_nota_esperada = s_dado_ram[2:0]; 
    wire s_sustenido_esperado = s_dado_ram[3];
    wire [2:0] s_oitava_esperada = s_dado_ram[6:4];

    wire s_ativo_apre_demo = (modo_ativo == 2'd1 || modo_ativo == 2'd3);
    wire [2:0] s_oitava_atual_uso = (s_ativo_apre_demo && s_nota_esperada != 3'd0) ? s_oitava_esperada : s_oitava_livre;
    wire s_sustenido_atual_uso = (s_ativo_apre_demo && s_nota_esperada != 3'd0) ? s_sustenido_esperado : s_btn_sustenido_db;

    assign oitava_atual = s_oitava_atual_uso;
    assign sustenido_atual = s_sustenido_atual_uso;
    assign led_oitava_up = (s_ativo_apre_demo && s_nota_esperada != 3'd0) ? s_led_up : 1'b0;
    assign led_oitava_down = (s_ativo_apre_demo && s_nota_esperada != 3'd0) ? s_led_down : 1'b0;

    // 1. Logica de Áudio
    logica_notas_prioridade logic_inst (
        .clock(clock), .reset(reset),
        .botoes(s_botoes_db), .nota_id(s_nota_tocada), .tem_nota(s_tem_nota)
    );
    
    wire s_is_demo = (modo_ativo == 2'd3);
    reg r_nota_ativa_bpm; 
    wire [2:0] s_nota_tocada_final = s_is_demo ? s_nota_esperada : s_nota_tocada;
    wire s_tem_nota_final = s_is_demo ? (s_nota_esperada != 3'd0 && r_nota_ativa_bpm) : s_tem_nota;

    frequency_lut lut_inst (
        .nota_id(s_nota_tocada_final), 
        .sustenido(s_sustenido_atual_uso),
        .oitava(s_oitava_atual_uso),
        .n_ticks(s_n_ticks)
    );

    // Descodificador: Traduz o estado 0,1,2 num valor 4-bits para o multiplicador do Áudio
    reg [3:0] s_nivel_volume;
    always @(*) begin
        case (estado_vol)
            2'd0: s_nivel_volume = 4'hF; // Volume Máximo (15)
            2'd1: s_nivel_volume = 4'h8; // Volume Médio (~50%)
            2'd2: s_nivel_volume = 4'h4; // Volume Baixo (~25%)
            default: s_nivel_volume = 4'hF;
        endcase
    end

    gerador_audio audio_inst (
        .clock(clock), 
        .reset(reset),
        .fim_contagem(s_n_ticks), 
        .habilitar(s_tem_nota_final),
        .nivel_volume(s_nivel_volume),
        .buzzer(buzzer)
    );

    // 2. Logica de Memória e Endereçamento
    wire cont_fim;
    contador_m #(.M(1024), .N(10)) contador_addr (
        .clock(clock), .zera_as(1'b0), .zera_s(zera_endereco), .conta(conta_endereco),
        .Q(s_endereco_ram), .fim(cont_fim), .meio()
    );

    wire [6:0] d_ram0, d_ram1, d_ram2, d_ram3, d_ram4, d_ram5, d_ram6, d_ram7;
    wire [6:0] d_ram8, d_ram9, d_ram10, d_ram11, d_ram12, d_ram13, d_ram14;
    wire [6:0] d_ram15, d_ram16, d_ram17, d_ram18, d_ram19, d_ram20, d_ram21;
	 wire [6:0] d_ram22, d_ram23, d_ram24, d_ram25, d_ram26, d_ram27, d_ram28;
	 wire [6:0] d_ram29, d_ram30, d_ram31, d_ram32, d_ram33, d_ram34, d_ram35;
	 wire [6:0] d_ram36, d_ram37, d_ram38;

    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Axel_F.txt")) mem0 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram0));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Bad_Romance.txt")) mem1 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram1));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Beat_It.txt")) mem2 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram2));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Careless_Whisper.txt")) mem3 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram3));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Clair_de_Lune.txt")) mem4 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram4));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Clocks.txt")) mem5 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram5));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Do_Re_Mi_Fa.txt")) mem6 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram6));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Epitafio.txt")) mem7 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram7));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Fukashigi_No_Carte.txt")) mem8 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram8));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Fur_Elise.txt")) mem9 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram9));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Golden.txt")) mem10 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram10));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Golden_Wind.txt")) mem11 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram11));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Harry_Potter.txt")) mem12 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram12));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Head_Over_Heels.txt")) mem13 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram13));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Hey_Jude.txt")) mem14 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram14));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Homem_Aranha_1900.txt")) mem15 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram15));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Imperial_March.txt")) mem16 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram16));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Interestelar.txt")) mem17 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram17));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Korobeiniki.txt")) mem18 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram18));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Lugar_Ao_Sol.txt")) mem19 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram19));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Magnetic.txt")) mem20 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram20));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Mario.txt")) mem21 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram21));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Minecraft_Sweden.txt")) mem22 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram22));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Moonlight_Sonata_3mvt.txt")) mem23 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram23));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Morning_Flower.txt")) mem24 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram24));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Never_Gonna_Give_You_Up.txt")) mem25 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram25));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Numb.txt")) mem26 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram26));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Pink_Panther.txt")) mem27 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram27));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Radio_Ga_Ga.txt")) mem28 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram28));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Sadness_And_Sorrow.txt")) mem29 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram29));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Someone_Like_You.txt")) mem30 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram30));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Star_Wars_Main_Theme.txt")) mem31 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram31));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Sweet_Child_O_Mine.txt")) mem32 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram32));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Take_On_Me.txt")) mem33 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram33));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Trem_Das_Onze.txt")) mem34 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram34));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Undertale_Megalovania.txt")) mem35 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram35));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/We_Are_Number_One.txt")) mem36 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram36));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/When_Love_Takes_Over.txt")) mem37 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram37));
    sync_rom #(.DATA_WIDTH(7), .ADDR_WIDTH(10), .INIT_FILE("Musicas/Zelda_Lost_Woods.txt")) mem38 (.clock(clock), .address(s_endereco_ram), .data_out(d_ram38));


    wire [6:0] d_ram39;
    wire [6:0] nota_paragravar = {s_oitava_livre, s_btn_sustenido_db, s_nota_tocada};
    
    sync_ram #(.DATA_WIDTH(7), .ADDR_WIDTH(10)) mem_gravacao (
        .clock(clock), 
        .we(escreve_ram), 
        .address(s_endereco_ram), 
        .data_in(nota_paragravar), 
        .data_out(d_ram39)
    );

    mux_musicas seletor_musicas_inst (
        .sel(mux_sel),
        .d0(d_ram0), .d1(d_ram1), .d2(d_ram2), .d3(d_ram3),
        .d4(d_ram4), .d5(d_ram5), .d6(d_ram6), .d7(d_ram7),
        .d8(d_ram8), .d9(d_ram9), .d10(d_ram10), .d11(d_ram11),
        .d12(d_ram12), .d13(d_ram13), .d14(d_ram14), .d15(d_ram15),
        .d16(d_ram16), .d17(d_ram17), .d18(d_ram18), .d19(d_ram19),
        .d20(d_ram20), .d21(d_ram21), .d22(d_ram22), .d23(d_ram23),
        .d24(d_ram24), .d25(d_ram25), .d26(d_ram26), .d27(d_ram27),
        .d28(d_ram28), .d29(d_ram29), .d30(d_ram30), .d31(d_ram31),
        .d32(d_ram32), .d33(d_ram33), .d34(d_ram34), .d35(d_ram35),
        .d36(d_ram36), .d37(d_ram37), .d38(d_ram38), .d39(d_ram39),
        .out(s_dado_ram)
    );


    assign s_id_para_led = (modo_ativo == 2'd1 || modo_ativo == 2'd3) ? s_nota_esperada : s_nota_tocada;

    // 3. Logica Visual e Comparação
    decodificador_cifra decoder_cifra_inst (
        .nota_id(s_id_para_led),
        .display(leds)
    );

    wire s_led_up, s_led_down;
    led_oitava indicador_erro_oitava (
        .oitava_certa(s_oitava_esperada),
        .oitava_atual(s_oitava_livre),
        .led_up(s_led_up), .led_down(s_led_down)
    );

    
    wire s_match_cru = (s_nota_tocada == s_nota_esperada) && s_tem_nota && (modo_ativo == 2'd1);

    assign tem_nota_ativa = s_tem_nota_final;
    assign acerto_nota = s_match_cru;
    assign fim_musica = (modo_ativo == 2'd2) ? cont_fim : (s_nota_esperada == 3'd0);

    // 4. Modulação de LED (PWM)
    reg [2:0] estado_intensidade;
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            estado_intensidade <= 3'd0;
        // O LED SÓ muda se o botão Modo NÃO estiver pressionado
        end else if (s_btn_intensidade_pulse && !s_modo_pressed) begin
            if (estado_intensidade == 3'd4) estado_intensidade <= 3'd0;
            else estado_intensidade <= estado_intensidade + 1'b1;
        end
    end
    
    reg [3:0] s_duty_cycle;
    always @(*) begin
        case (estado_intensidade)
            3'd0: s_duty_cycle = 4'hF; 
            3'd1: s_duty_cycle = 4'hC; 
            3'd2: s_duty_cycle = 4'h8; 
            3'd3: s_duty_cycle = 4'h4; 
            3'd4: s_duty_cycle = 4'h0; 
            default: s_duty_cycle = 4'hF;
        endcase
    end

    gerador_pwm pwm_inst (
        .clock(clock), .reset(reset), .duty_cycle(s_duty_cycle), .pwm_out(pwm_out)
    );


    // ---------------- DEMONSTRACAO (BPM) ----------------
    reg [31:0] ciclos_por_beat;
    always @(*) begin
        case (s_sel_musica)
            6'd0:  ciclos_por_beat = 21739130; // 138 bpm (Axel_F.txt)
            6'd1:  ciclos_por_beat = 25210084; // 119 bpm (Bad_Romance.txt)
            6'd2:  ciclos_por_beat = 25641026; // 117 bpm (Beat_It.txt)
            6'd3:  ciclos_por_beat = 19607843; // 153 bpm (Careless_Whisper.txt)
            6'd4:  ciclos_por_beat = 39473684; // 76 bpm  (Clair_de_Lune.txt)
            6'd5:  ciclos_por_beat = 17341040; // 173 bpm (Clocks.txt)
            6'd6:  ciclos_por_beat = 30000000; // 100 bpm (Do_Re_Mi_Fa.txt)
            6'd7:  ciclos_por_beat = 26785714; // 112 bpm (Epitafio.txt)
            6'd8:  ciclos_por_beat = 31250000; // 96 bpm  (Fukashigi_No_Carte.txt)
            6'd9: ciclos_por_beat = 20833333; // 144 bpm (Fur_Elise.txt)
            6'd10: ciclos_por_beat = 24390243; // 123 bpm (Golden.txt)
            6'd11: ciclos_por_beat = 22222222; // 135 bpm (Golden_Wind.txt)
            6'd12: ciclos_por_beat = 41095890; // 73 bpm  (Harry_Potter.txt)
            6'd13: ciclos_por_beat = 31578947; // 95 bpm  (Head_Over_Heels.txt)
            6'd14: ciclos_por_beat = 40540540; // 74 bpm  (Hey_Jude.txt)
            6'd15: ciclos_por_beat = 25423728; // 118 bpm (Homem_Aranha_1900.txt)
            6'd16: ciclos_por_beat = 29126214; // 103 bpm (Imperial_March.txt)
            6'd17: ciclos_por_beat = 30000000; // 100 bpm (Interestelar.txt)
            6'd18: ciclos_por_beat = 30612245; // 98 bpm  (Korobeiniki.txt)
            6'd19: ciclos_por_beat = 21276596; // 141 bpm (Lugar_Ao_Sol.txt)
            6'd20: ciclos_por_beat = 11450380; // 524 bpm (Magnetic.txt)
            6'd21: ciclos_por_beat = 30000000; // 100 bpm (Mario.txt)
            6'd22: ciclos_por_beat = 40540540; // 74 bpm  (Minecraft_Sweden.txt)
            6'd23:  ciclos_por_beat = 13636363; // 220 bpm (Moonlight_Sonata_3mvt.txt)
            6'd24: ciclos_por_beat = 21428571; // 140 bpm (Morning_Flower.txt)
            6'd25: ciclos_por_beat = 26548673; // 113 bpm (Never_Gonna_Give_You_Up.txt)
            6'd26: ciclos_por_beat = 27272727; // 110 bpm (Numb.txt)
            6'd27: ciclos_por_beat = 25862069; // 116 bpm (Pink_Panther.txt)
            6'd28: ciclos_por_beat = 26086956; // 115 bpm (Radio_Ga_Ga.txt)
            6'd29: ciclos_por_beat = 21428571; // 140 bpm (Sadness_And_Sorrow.txt)
            6'd30: ciclos_por_beat = 22222222; // 135 bpm (Someone_Like_You.txt)
            6'd31: ciclos_por_beat = 36144578; // 83 bpm  (Star_Wars_Main_Theme.txt)
            6'd32: ciclos_por_beat = 24000000; // 125 bpm (Sweet_Child_O_Mine.txt)
            6'd33: ciclos_por_beat = 35714285; // 84 bpm  (Take_On_Me.txt)
            6'd34: ciclos_por_beat = 32608695; // 92 bpm  (Trem_Das_Onze.txt)
            6'd35: ciclos_por_beat = 25000000; // 120 bpm (Undertale_Megalovania.txt)
            6'd36: ciclos_por_beat = 18518519; // 162 bpm (We_Are_Number_One.txt)
            6'd37: ciclos_por_beat = 23076923; // 130 bpm (When_Love_Takes_Over.txt)
            6'd38: ciclos_por_beat = 21428571; // 140 bpm (Zelda_Lost_Woods.txt)
            default: ciclos_por_beat = 30_000_000; // 100 bpm default
        endcase
    end

    reg [31:0] contador_bpm;
    reg r_pulso_bpm;
    assign pulso_bpm = r_pulso_bpm;

    localparam LOG2_LINHAS_POR_BEAT = 1; 
    wire [31:0] ciclos_reais_linha = ciclos_por_beat >> LOG2_LINHAS_POR_BEAT;

    // Pulso mínimo (2ms) apenas para resetar o envelope do gerador de áudio
    localparam CICLOS_SILENCIO_FIXO = 32'd100_000;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            contador_bpm <= 0;
            r_pulso_bpm <= 0;
            r_nota_ativa_bpm <= 0;
        end else if (modo_ativo == 2'd3) begin
            if (zera_endereco) begin 
                // Preso no Estado INICIA_DEMO, aguardando inicio via botao
                contador_bpm <= 0;
                r_pulso_bpm <= 0;
                r_nota_ativa_bpm <= 0;
            end else begin
                if (contador_bpm >= ciclos_reais_linha - 1) begin
                    contador_bpm <= 0;
                    r_pulso_bpm <= 1;
                end else begin
                    contador_bpm <= contador_bpm + 1;
                    r_pulso_bpm <= 0;
                end
                
                // Aplica o silencio fixo no final da nota.
                // Se a nota for muito rapida (menor que o silencio), fallback para 50%
                if (ciclos_reais_linha > CICLOS_SILENCIO_FIXO) begin
                    r_nota_ativa_bpm <= (contador_bpm < (ciclos_reais_linha - CICLOS_SILENCIO_FIXO));
                end else begin
                    r_nota_ativa_bpm <= (contador_bpm < (ciclos_reais_linha >> 1));
                end
            end
        end else begin
            contador_bpm <= 0;
            r_pulso_bpm <= 0;
            r_nota_ativa_bpm <= 0;
        end
    end

endmodule