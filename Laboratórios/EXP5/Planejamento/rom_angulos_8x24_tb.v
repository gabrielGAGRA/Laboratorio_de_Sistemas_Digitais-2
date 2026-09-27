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

  initial begin
    $dumpfile("rom_angulos_8x24_tb.vcd");
    $dumpvars(0, rom_angulos_8x24_tb);

    // ajusta endereco para valor inicial da varredura
    endereco = 3'b000;
    errors   = 0;

    // varredura percorre todos os enderecos da ROM
    for (i = 0; i < 8; i = i + 1) begin
      #10; // atraso para visualizacao da saida

      $display("Endereco: %0d, Saida esperada: %h, Saida da ROM: %h", 
               i, dut.tabela_angulos[i], saida); 

      if (saida !== dut.tabela_angulos[i]) begin
        $display("Erro no endereco %0d: Esperado=%h, Saida=%h", 
                 i, dut.tabela_angulos[i], saida);
        errors = errors + 1;
      end

      endereco = endereco + 3'd1;
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