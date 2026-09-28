import argparse
import json
import sys
from pathlib import Path
from typing import Dict, List, Set


def find_groups_file(custom_path: str = None, src_dir: Path = None, dst_dir: Path = None) -> Path:
    """Localiza o arquivo de definicao de grupos especificado pela LLM."""
    if custom_path:
        p = Path(custom_path).resolve()
        if p.is_file():
            return p
        print(f"Erro: Arquivo de grupos customizado '{p}' nao encontrado.")
        sys.exit(1)

    skill_root = Path(__file__).resolve().parent.parent
    candidates = [
        skill_root / "groups.json",
        src_dir / "groups.json" if src_dir else None,
        dst_dir / "groups.json" if dst_dir else None,
        Path.cwd() / "groups.json",
    ]

    for cand in candidates:
        if cand and cand.is_file():
            return cand

    print("Erro: Nenhum arquivo 'groups.json' encontrado.")
    print("A LLM deve SEMPRE definir o mapeamento dos grupos em 'groups.json' antes de executar o script.")
    print("O script nao realiza agrupamento heuristico automatico.")
    sys.exit(1)


def load_groups(groups_file: Path) -> Dict[str, List[str]]:
    """Carrega e valida o dicionario de grupos da LLM."""
    try:
        with open(groups_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            raise ValueError("O conteudo de groups.json deve ser um dicionario JSON { 'pacote.txt': ['arq1.v', ...] }.")
        return data
    except Exception as e:
        print(f"Erro ao ler '{groups_file}': {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Consolida arquivos Verilog em formato .txt a partir de especificacao da LLM"
    )
    parser.add_argument("--src", required=True, help="Diretorio de origem contendo os arquivos .v")
    parser.add_argument("--dst", required=True, help="Diretorio de destino dos arquivos consolidados (.txt)")
    parser.add_argument("--max-files", type=int, default=8, help="Numero maximo de arquivos consolidados permitidos (default: 8)")
    parser.add_argument("--ext", default=".txt", help="Extensao obrigatoria de saida (sempre .txt)")
    parser.add_argument("--groups", default=None, help="Caminho opcional para arquivo JSON com os grupos da LLM")

    args = parser.parse_args()

    src_dir = Path(args.src).resolve()
    if not src_dir.is_dir():
        print(f"Erro: Diretorio de origem '{src_dir}' nao existe.")
        sys.exit(1)

    dst_dir = Path(args.dst).resolve()
    dst_dir.mkdir(parents=True, exist_ok=True)

    # Forca extensao .txt conforme especificacao
    out_ext = args.ext if args.ext.startswith(".") else f".{args.ext}"
    if out_ext != ".txt":
        print(f"Aviso: Extensao alterada para '.txt' conforme padrao obrigatorio.")
        out_ext = ".txt"

    # Carrega definicao explicita feita pela LLM
    groups_path = find_groups_file(args.groups, src_dir=src_dir, dst_dir=dst_dir)
    groups = load_groups(groups_path)

    # Validacao 1: Quantidade maxima de arquivos
    if len(groups) > args.max_files:
        print(f"Erro: O mapeamento da LLM contem {len(groups)} arquivos, mas o limite e de no maximo {args.max_files} arquivos.")
        sys.exit(1)

    # Validacao 2: Verificacao de presenca dos arquivos na pasta de origem
    all_src_v = {f.name for f in src_dir.glob("*.v") if f.is_file()}
    mapped_files: Set[str] = set()
    missing_files: List[str] = []

    for pkg_name, file_list in groups.items():
        for fname in file_list:
            mapped_files.add(fname)
            if not (src_dir / fname).is_file():
                missing_files.append(fname)

    if missing_files:
        print(f"Aviso: Os seguintes arquivos especificados em 'groups.json' nao existem em '{src_dir}':")
        for mf in missing_files:
            print(f"  - {mf}")

    unmapped = sorted(all_src_v - mapped_files)
    if unmapped:
        print(f"Aviso: {len(unmapped)} arquivo(s) .v presentes em '{src_dir}' nao foram incluidos no mapeamento:")
        for uf in unmapped:
            print(f"  - {uf}")

    print(f"Origem : {src_dir}")
    print(f"Destino: {dst_dir}")
    print(f"Grupos : {groups_path.name} ({len(groups)} arquivos <= limite {args.max_files})\n")

    for pkg_name, file_list in groups.items():
        stem = Path(pkg_name).stem
        out_filename = f"{stem}{out_ext}"
        out_path = dst_dir / out_filename

        with open(out_path, "w", encoding="utf-8") as out_f:
            out_f.write("// " + "=" * 76 + "\n")
            out_f.write(f"// PACOTE CONSOLIDADO: {out_filename}\n")
            out_f.write(f"// Arquivos incluidos ({len(file_list)}):\n")
            for f in file_list:
                out_f.write(f"//   - {f}\n")
            out_f.write("// " + "=" * 76 + "\n\n")

            for fname in file_list:
                fpath = src_dir / fname
                if not fpath.is_file():
                    continue
                content = fpath.read_text(encoding="utf-8", errors="replace")
                out_f.write("// " + "-" * 76 + "\n")
                out_f.write(f"// ARQUIVO: {fname}\n")
                out_f.write("// " + "-" * 76 + "\n\n")
                out_f.write(content.strip())
                out_f.write("\n\n")

        size_kb = out_path.stat().st_size / 1024
        print(f"  -> {out_filename:30s} ({size_kb:6.1f} KB) [{len(file_list)} arquivos]")

    print(f"\nSucesso: {len(groups)} arquivos .txt gerados em {dst_dir}")


if __name__ == "__main__":
    main()
