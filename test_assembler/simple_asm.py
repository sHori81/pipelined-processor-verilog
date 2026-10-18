from __future__ import annotations

import argparse
import ast
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class AsmError(Exception):
    pass


LABEL_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$")
REG_RE = re.compile(r"^[Rr]([0-7])$")
MEM_RE = re.compile(r"^\s*(.*?)\s*\(\s*([Rr][0-7])\s*\)\s*$")


ALU_OP3 = {
    "ADD": 0b0000,
    "SUB": 0b0001,
    "AND": 0b0010,
    "OR":  0b0011,
    "XOR": 0b0100,
    "CMP": 0b0101,
    "MOV": 0b0110,
}

SHIFT_OP3 = {
    "SLL": 0b1000,
    "SLR": 0b1001,
    "SRL": 0b1010,
    "SRA": 0b1011,
}

COND = {
    "BE":  0b000,
    "BLT": 0b001,
    "BLE": 0b010,
    "BNE": 0b011,
}

IMM_OP2 = {
    "LI":   0b000,
    "ADDI": 0b001,
    "SUBI": 0b010,
    "CMPI": 0b011,
    # 100 は B
    "ANDI": 0b101,
    "LUI":  0b110,
}


@dataclass
class Statement:
    addr: int
    op: str
    args: List[str]
    line_no: int
    source: str


def strip_comment(line: str) -> str:
    cut = len(line)
    for marker in ("//", ";", "#"):
        i = line.find(marker)
        if i != -1:
            cut = min(cut, i)
    return line[:cut].strip()


def split_operands(s: str) -> List[str]:
    if not s.strip():
        return []
    parts: List[str] = []
    cur: List[str] = []
    depth = 0
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth < 0:
                raise AsmError("too many ')'")
        if ch == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if depth != 0:
        raise AsmError("unclosed '('")
    parts.append("".join(cur).strip())
    return parts


def parse_reg(s: str) -> int:
    m = REG_RE.match(s.strip())
    if not m:
        raise AsmError(f"expected register R0..R7, got {s!r}")
    return int(m.group(1))


def parse_mem_operand(s: str) -> Tuple[str, int]:
    m = MEM_RE.match(s)
    if not m:
        raise AsmError(f"expected memory operand like d(Rb), got {s!r}")
    disp = m.group(1).strip()
    rb = parse_reg(m.group(2))
    if disp == "":
        disp = "0"
    return disp, rb


def names_in_expr(expr: str) -> set[str]:
    try:
        tree = ast.parse(expr, mode="eval")
    except SyntaxError:
        return set()
    return {node.id for node in ast.walk(tree) if isinstance(node, ast.Name)}


def eval_expr(expr: str, symbols: Dict[str, int]) -> int:
    expr = expr.strip()
    if expr == "":
        raise AsmError("empty expression")

    try:
        tree = ast.parse(expr, mode="eval")
    except SyntaxError as e:
        raise AsmError(f"bad expression {expr!r}") from e

    def ev(node: ast.AST) -> int:
        if isinstance(node, ast.Expression):
            return ev(node.body)

        if isinstance(node, ast.Constant) and isinstance(node.value, int):
            return int(node.value)

        if isinstance(node, ast.Name):
            if node.id not in symbols:
                raise AsmError(f"undefined label {node.id!r}")
            return symbols[node.id]

        if isinstance(node, ast.UnaryOp):
            v = ev(node.operand)
            if isinstance(node.op, ast.UAdd):
                return v
            if isinstance(node.op, ast.USub):
                return -v
            if isinstance(node.op, ast.Invert):
                return ~v

        if isinstance(node, ast.BinOp):
            a = ev(node.left)
            b = ev(node.right)

            if isinstance(node.op, ast.Add):
                return a + b
            if isinstance(node.op, ast.Sub):
                return a - b
            if isinstance(node.op, ast.Mult):
                return a * b
            if isinstance(node.op, ast.FloorDiv):
                return a // b
            if isinstance(node.op, ast.Mod):
                return a % b
            if isinstance(node.op, ast.LShift):
                return a << b
            if isinstance(node.op, ast.RShift):
                return a >> b
            if isinstance(node.op, ast.BitAnd):
                return a & b
            if isinstance(node.op, ast.BitOr):
                return a | b
            if isinstance(node.op, ast.BitXor):
                return a ^ b

        raise AsmError(f"unsupported expression {expr!r}")

    return ev(tree)


def require_range(value: int, lo: int, hi: int, what: str) -> None:
    if not (lo <= value <= hi):
        raise AsmError(f"{what} out of range: {value} not in [{lo}, {hi}]")
    

def enc_u4(value: int) -> int:
    require_range(value, 0, 15, "4-bit immediate")
    return value & 0xF


def enc_s8(value: int) -> int:
    require_range(value, -128, 127, "8-bit signed immediate/displacement")
    return value & 0xFF


def enc_word(value: int) -> int:
    require_range(value, -32768, 0xFFFF, "16-bit word")
    return value & 0xFFFF

def enc_imm8(value: int) -> int:
    # 即値は最終的には 8bit パターンなので、
    # -128..127 の符号付き表記と 0..255 の16進表記の両方を許可する。
    require_range(value, -128, 255, "8-bit immediate")
    return value & 0xFF

def parse_source(text: str) -> Tuple[List[Statement], Dict[str, int]]:
    statements: List[Statement] = []
    symbols: Dict[str, int] = {}
    pc = 0

    for line_no, raw in enumerate(text.splitlines(), start=1):
        line = strip_comment(raw)
        if not line:
            continue

        while True:
            m = LABEL_RE.match(line)
            if not m:
                break

            label, rest = m.group(1), m.group(2)

            if label in symbols:
                raise AsmError(f"line {line_no}: duplicate label {label!r}")

            symbols[label] = pc
            line = rest.strip()

            if not line:
                break

        if not line:
            continue

        head, *tail = line.split(None, 1)
        op = head.upper()
        rest = tail[0] if tail else ""
        args = split_operands(rest)

        if op == ".ORG":
            if len(args) != 1:
                raise AsmError(f"line {line_no}: .ORG needs 1 argument")
            pc = eval_expr(args[0], symbols)
            require_range(pc, 0, 0xFFFF, ".ORG address")
            continue

        statements.append(Statement(pc, op, args, line_no, raw.rstrip("\n")))

        if op == ".WORD":
            if len(args) < 1:
                raise AsmError(f"line {line_no}: .WORD needs at least 1 argument")
            pc += len(args)

        elif op == ".SPACE":
            if len(args) != 1:
                raise AsmError(f"line {line_no}: .SPACE needs 1 argument")
            n = eval_expr(args[0], symbols)
            require_range(n, 0, 0xFFFF, ".SPACE count")
            pc += n

        else:
            pc += 1

        if pc > 0x10000:
            raise AsmError(f"line {line_no}: program exceeds 64KW address space")

    return statements, symbols


def encode_instruction(st: Statement, symbols: Dict[str, int]) -> List[int]:
    op = st.op
    args = st.args

    def expr(x: str) -> int:
        return eval_expr(x, symbols)

    try:
        if op == ".WORD":
            return [enc_word(expr(a)) for a in args]

        if op == ".SPACE":
            if len(args) != 1:
                raise AsmError(".SPACE needs 1 argument")
            n = expr(args[0])
            require_range(n, 0, 0xFFFF, ".SPACE count")
            return [0] * n

        if op in ALU_OP3:
            if len(args) != 2:
                raise AsmError(f"{op} needs 2 operands: {op} Rd, Rs")

            rd = parse_reg(args[0])
            rs = parse_reg(args[1])
            op3 = ALU_OP3[op]

            word = (0b11 << 14) | (rs << 11) | (rd << 8) | (op3 << 4)
            return [word]

        if op in SHIFT_OP3:
            if len(args) != 2:
                raise AsmError(f"{op} needs 2 operands: {op} Rd, d")

            rd = parse_reg(args[0])
            d = enc_u4(expr(args[1]))
            op3 = SHIFT_OP3[op]

            word = (0b11 << 14) | (0 << 11) | (rd << 8) | (op3 << 4) | d
            return [word]

        if op == "NOP":
            if args:
                raise AsmError("NOP takes no operands")

            return [0x0000]

        if op == "IN":
            if len(args) not in (1, 2):
                raise AsmError("IN needs 1 operand: IN Rd")

            rd = parse_reg(args[0])
            d = enc_u4(expr(args[1])) if len(args) == 2 else 0

            word = (0b11 << 14) | (0 << 11) | (rd << 8) | (0b1100 << 4) | d
            return [word]

        if op == "OUT":
            if len(args) not in (1, 2):
                raise AsmError("OUT needs 1 operand: OUT Rs")

            rs = parse_reg(args[0])
            d = enc_u4(expr(args[1])) if len(args) == 2 else 0

            word = (0b11 << 14) | (rs << 11) | (0 << 8) | (0b1101 << 4) | d
            return [word]

        # --- ここから NOP の処理を追加 ---
        if op == "NOP":
            if args:
                raise AsmError("NOP takes no operands")
            
            return [0x0000]
        # --- ここまで ---

        if op == "HLT":
            if args:
                raise AsmError("HLT takes no operands")

            word = (0b11 << 14) | (0b1111 << 4)
            return [word]

        if op in ("LD", "ST"):
            if len(args) != 2:
                raise AsmError(f"{op} needs 2 operands: {op} Ra, d(Rb)")

            ra = parse_reg(args[0])
            disp_expr, rb = parse_mem_operand(args[1])
            d = enc_s8(expr(disp_expr))
            op1 = 0b00 if op == "LD" else 0b01

            word = (op1 << 14) | (ra << 11) | (rb << 8) | d
            return [word]

        if op in IMM_OP2:
            if len(args) != 2:
                raise AsmError(f"{op} needs 2 operands: {op} Rb, d")

            rb = parse_reg(args[0])
            d = enc_imm8(expr(args[1]))
            op2 = IMM_OP2[op]

            word = (0b10 << 14) | (op2 << 11) | (rb << 8) | d
            return [word]

        if op == "B":
            if len(args) != 1:
                raise AsmError("B needs 1 operand: B label_or_offset")

            raw = args[0]
            value = expr(raw)

            # ラベルが含まれる場合は「飛び先アドレス」とみなし、
            # 数値だけの場合は「PC相対変位そのもの」とみなす。
            offset = value - (st.addr + 1) if names_in_expr(raw) else value
            d = enc_s8(offset)

            word = (0b10 << 14) | (0b100 << 11) | d
            return [word]

        if op in COND:
            if len(args) != 1:
                raise AsmError(f"{op} needs 1 operand: {op} label_or_offset")

            raw = args[0]
            value = expr(raw)

            offset = value - (st.addr + 1) if names_in_expr(raw) else value
            d = enc_s8(offset)
            cond = COND[op]

            word = (0b10 << 14) | (0b111 << 11) | (cond << 8) | d
            return [word]

        raise AsmError(f"unknown operation {op!r}")

    except AsmError as e:
        raise AsmError(f"line {st.line_no}: {e}\n  {st.source}") from e


def assemble(text: str) -> Tuple[List[int], List[Tuple[int, int, str]], Dict[str, int]]:
    statements, symbols = parse_source(text)
    words_by_addr: Dict[int, int] = {}
    listing: List[Tuple[int, int, str]] = []

    for st in statements:
        words = encode_instruction(st, symbols)

        for i, w in enumerate(words):
            addr = st.addr + i

            if addr in words_by_addr:
                raise AsmError(f"line {st.line_no}: address 0x{addr:04X} is already used")

            words_by_addr[addr] = w
            listing.append((addr, w, st.source))

    if not words_by_addr:
        return [], listing, symbols

    max_addr = max(words_by_addr)
    memory = [0] * (max_addr + 1)

    for addr, word in words_by_addr.items():
        memory[addr] = word

    return memory, listing, symbols

def parse_int_auto(s: str) -> int:
    return int(s, 0)


def clean_source_for_mif_comment(source: str) -> str:
    # 元のアセンブリ行からコメントを落として、MIFの -- コメント用に整える
    s = strip_comment(source).strip()
    s = s.replace("--", "- -")
    return s


def emit_zero_range(lines: List[str], start: int, end: int, addr_digits: int, data_digits: int) -> None:
    if start > end:
        return

    zero = "0" * data_digits

    if start == end:
        lines.append(f"{start:0{addr_digits}X} : {zero};")
    else:
        lines.append(f"[{start:0{addr_digits}X}..{end:0{addr_digits}X}] : {zero};")


def format_mif(
    memory: List[int],
    listing: List[Tuple[int, int, str]],
    depth: int = 32768,
    width: int = 16,
    with_comments: bool = True,
) -> str:
    if depth <= 0:
        raise AsmError("MIF depth must be positive")

    if width <= 0:
        raise AsmError("MIF width must be positive")

    if len(memory) > depth:
        raise AsmError(
            f"program/data image is too large for MIF depth {depth}: "
            f"needs address 0x{len(memory) - 1:04X}"
        )

    addr_digits = max(4, ((depth - 1).bit_length() + 3) // 4)
    data_digits = max(4, (width + 3) // 4)
    data_mask = (1 << width) - 1

    explicit: Dict[int, Tuple[int, str]] = {}

    for addr, word, source in listing:
        if addr >= depth:
            raise AsmError(
                f"address 0x{addr:04X} is outside MIF depth {depth}"
            )

        comment = clean_source_for_mif_comment(source)

        # .SPACE は大量のゼロ行を出さず、範囲ゼロ埋めに任せる
        if comment.upper().startswith(".SPACE"):
            continue

        explicit[addr] = (word & data_mask, comment)

    lines: List[str] = [
        f"DEPTH = {depth};",
        f"WIDTH = {width};",
        "ADDRESS_RADIX = HEX;",
        "DATA_RADIX = HEX;",
        "",
        "CONTENT",
        "BEGIN",
        "",
    ]

    cursor = 0

    for addr in sorted(explicit.keys()):
        if cursor < addr:
            emit_zero_range(lines, cursor, addr - 1, addr_digits, data_digits)

        word, comment = explicit[addr]

        if with_comments and comment:
            lines.append(
                f"{addr:0{addr_digits}X} : {word:0{data_digits}X};    -- {comment}"
            )
        else:
            lines.append(
                f"{addr:0{addr_digits}X} : {word:0{data_digits}X};"
            )

        cursor = addr + 1

    if cursor < depth:
        emit_zero_range(lines, cursor, depth - 1, addr_digits, data_digits)

    lines.append("END;")

    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Assembler for SIMPLE 16-bit CPU")
    parser.add_argument("input", help="assembly source file")
    parser.add_argument("-o", "--output", help="output file; default: stdout")
    parser.add_argument(
        "--format",
        choices=["hex", "mif"],
        default=None,
        help="output format. If omitted, .mif output filename automatically selects MIF",
    )
    parser.add_argument("--mif", action="store_true", help="shortcut for --format mif")
    parser.add_argument("--mif-depth", type=parse_int_auto, default=32768, help="MIF DEPTH")
    parser.add_argument("--mif-width", type=parse_int_auto, default=16, help="MIF WIDTH")
    parser.add_argument("--mif-no-comments", action="store_true", help="omit source comments in MIF")
    parser.add_argument("--dump", action="store_true", help="print address, machine word, and source")
    parser.add_argument("--symbols", action="store_true", help="print symbol table to stderr")

    args = parser.parse_args(argv)

    try:
        text = Path(args.input).read_text(encoding="utf-8")
        memory, listing, symbols = assemble(text)

        if args.symbols:
            for name, addr in sorted(symbols.items(), key=lambda x: x[1]):
                print(f"{name:20s} = 0x{addr:04X} ({addr})", file=sys.stderr)

        out_format = args.format

        if args.mif:
            out_format = "mif"

        if out_format is None:
            if args.output and Path(args.output).suffix.lower() == ".mif":
                out_format = "mif"
            else:
                out_format = "hex"

        if out_format == "mif":
            out = format_mif(
                memory,
                listing,
                depth=args.mif_depth,
                width=args.mif_width,
                with_comments=not args.mif_no_comments,
            )
        elif args.dump:
            out = "\n".join(
                f"{addr:04X}: {word:04X}    {src}"
                for addr, word, src in listing
            )
        else:
            out = "\n".join(f"{word:04X}" for word in memory)

        if args.output:
            Path(args.output).write_text(out + ("\n" if out else ""), encoding="utf-8")
        else:
            print(out)

        return 0

    except AsmError as e:
        print(f"assemble error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())