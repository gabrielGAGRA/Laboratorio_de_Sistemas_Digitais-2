---
name: verilog-file-merger
description: Consolidates Verilog (.v) and testbench files from a lab directory into at most 8 structured package files for external LLM context upload.
---

# Verilog File Merger

---

## 1. Como Executar

### Especificando Destino e Limite Customizado

### Gerando como `.txt`

```bash
python .agents/skills/verilog-file-merger/scripts/merge_verilog.py \
  --src Laboratórios/EXP5/Planejamento \
  --dst Laboratórios/EXP5/Planejamento_txt \
  --max-files 8 \
  --ext .txt
```

---

## 2. Lógica de Agrupamento

A LLM deve sempre definir o mapeamento no arquivo [groups.json](./groups.json):

1. **Definição prévia pela LLM**: Antes de executar o comando, a LLM analisa os arquivos de `--src` e preenche o dicionário JSON `{ "1_pacote.txt": ["mod.v", "mod_tb.v"], ... }`.
2. **Validação estrita**: O script valida se o total de arquivos gerados é $\le$ `--max-files` (padrão: 8), alerta se algum arquivo foi esquecido e gera sempre a saída em formato `.txt`.
3. **Delimitadores Visuais**: Cada arquivo individual inserido no pacote recebe um cabeçalho claro (`// ARQUIVO: nome.v`), preservando a legibilidade para os modelos externos.