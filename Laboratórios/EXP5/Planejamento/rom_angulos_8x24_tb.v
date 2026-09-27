`default_nettype none
`timescale 1ns / 1ns

/*
 * rom_angulos_8x24_tb.v
 */

module rom_angulos_8x24_tb;

  reg  [2:0] endereco;
  wire [23:0] saida;
  integer i;
  integer errors = 0;

  // instanciacao do modulo ROM 
  rom_angulos_8x24 dut (
    .endereco(endereco),
    .saida   (saida)
  );

  reg [23:0] esperada [0:7];

  initial begin
    esperada[0] = 24'h303230; // 0 = 020
    esperada[1] = 24'h303430; // 1 = 040
    esperada[2] = 24'h303630; // 2 = 060
    esperada[3] = 24'h303830; // 3 = 080
    esperada[4] = 24'h313030; // 4 = 100
    esperada[5] = 24'h313230; // 5 = 120
    esperada[6] = 24'h313430; // 6 = 140
    esperada[7] = 24'h313630; // 7 = 160

    $dumpfile("rom_angulos_8x24_tb.vcd");
    $dumpvars(0, rom_angulos_8x24_tb);

    // ajusta endereco para valor inicial da varredura
    endereco = 3'b000;
    errors   = 0;

    // varredura percorre todos os enderecos da ROM
    for (i = 0; i < 8; i = i + 1) begin
      endereco = i[2:0];
      #10; // atraso para visualizacao da saida

      $display("Endereco: %0d, Saida esperada: %h, Saida da ROM: %h", 
               i, esperada[i], saida); 

      if (saida !== esperada[i]) begin
        $display("Erro no endereco %0d: Esperado=%h, Saida=%h", 
                 i, esperada[i], saida);
        errors = errors + 1;
      end
    end

    if (errors == 0) begin
      $display("\nSUCCESS: ALL TESTBENCH CHECKS PASSED!");
    end else begin
      $display("\nFAILURE: %0d error(s) detected", errors);
    end

    $display("Fim dos testes!");
    $finish;
  end

endmodule

`default_nettype wire