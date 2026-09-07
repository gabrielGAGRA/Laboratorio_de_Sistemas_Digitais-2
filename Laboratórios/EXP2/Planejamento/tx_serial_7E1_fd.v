 module tx_serial_7E1_fd (
    input        clock        ,
    input        reset        ,
    input        zera         ,
    input        conta        ,
    input        carrega      ,
    input        desloca      ,
    input  [6:0] dados_ascii  ,
    output       saida_serial ,
    output       fim
);

    wire [10:0] s_dados;
    wire [10:0] s_saida;
    wire [2:0]  s_paridade;

    assign s_paridade = dados_ascii[0] + dados_ascii[1] + dados_ascii[2] + dados_ascii[3] + dados_ascii[4] + dados_ascii[5] + dados_ascii[6];

    // composicao dos dados seriais
    assign s_dados[0]   = 1'b1;             // repouso
    assign s_dados[1]   = 1'b0;             // start bit
    assign s_dados[8:2] = dados_ascii[6:0]; // dado
    assign s_dados[9]   = s_paridade[0];    // paridade
    assign s_dados[10]  = 1'b1;             // stop bit
  
    // Instanciação do deslocador_n
    deslocador_n #(
        .N(11) 
    ) U1 (
        .clock         (clock  ),
        .reset         (reset  ),
        .carrega       (carrega),
        .desloca       (desloca),
        .entrada_serial(1'b1   ), 
        .dados         (s_dados),
        .saida         (s_saida)
    );
    
    // Instanciação do contador_m
    contador_m #(
        .M(12),
        .N(4)
    ) U2 (
        .clock   (clock),
        .zera_as (1'b0 ),
        .zera_s  (zera ),
        .conta   (conta),
        .Q       (     ), // porta Q em aberto (desconectada)
        .fim     (fim  ),
        .meio    (     )  // porta meio em aberto (desconectada)
    );
    
    // Saida serial do transmissor
    assign saida_serial = s_saida[0];
  
endmodule
