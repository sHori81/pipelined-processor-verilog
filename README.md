# Pipelined 16-bit Processor on FPGA (Verilog)

16bitの独自命令セット（SIMPLEアーキテクチャ）のプロセッサを**Verilog HDLで設計し、FPGAボード上で動かした**ものです。
大学の授業「計算機科学実験及演習3（プロセッサ設計）」で、**3人のチームで開発**しました。

## 概要

| 項目 | 内容 |
|---|---|
| 言語・ツール | Verilog HDL, Intel Quartus Prime, ModelSim, Python（アセンブラ） |
| FPGA | Intel Cyclone IV E（EP4CE30F23I7） |
| 命令 | 16bit固定長、汎用レジスタ8本（各16bit） |
| 構成 | IFを2段に分けた**6段パイプライン**（IF1 / IF2 / ID / EX / MEM / WB）、ハーバード構成 |
| 高速化 | **フォワーディング**、**ハザード検出とストール**、**2bit飽和カウンタによる分岐予測**（32エントリのBHT/BTB）と予測ミス時のフラッシュ |
| 入出力 | キーパッドからの数値入力、7セグメントLEDへの出力・デバッグ表示 |
| 性能計測 | 実行サイクル数を数える性能カウンタ |

最初に5フェーズで1命令ずつ実行する構成を作り（`processor_top.v`）、そのあとパイプライン化しました（`piplined/`）。

## 自分の担当

チーム開発のため、すべてを自分で書いたわけではありません。主に次の部分を担当しました。

- **データパスの基本部品**：レジスタファイル、命令レジスタ、AR/BRなどのレジスタと、それらの接続
- **ハーバード構成への変更**：命令メモリとデータメモリを分けた
- **命令の追加**：即値命令 `ADDI` / `SUBI` / `CMPI` / `ANDI` / `LUI` の追加と、条件分岐命令の修正
- **ソートプログラムの作成と高速化**：基数ソートを独自のアセンブリで書き、ダブルバッファ方式・8bit幅の基数ソート・整列済みの検知などで改良を重ねた（`test_assembler/radixsort_8bit_v1〜v8.s`）
- **性能評価**：実行サイクル数を数えるカウンタを追加し、32bitで7セグに表示できるようにした
- **設計書・レポート**：方式設計仕様書、機能設計仕様書、性能評価レポートの作成

## ファイル構成

```
top_module.v               FPGAボードとつながる最上位モジュール
piplined/                  パイプライン版CPU（現在の実装）
  pipelined_processor_top.v  CPU本体
  id.v                       命令デコード・レジスタ読み出し・分岐判定
  fowarding_unit.v           フォワーディング
  reg_IFID.v など            パイプラインレジスタ
predictor.v                分岐予測器
hazard_detection.v         ハザード検出
alu.v, shifter.v           演算器
processor_top.v            5フェーズ版CPU（最初の実装）
*.vt                       テストベンチ
*.mif, *.hex               命令メモリ・データメモリの初期値
test_assembler/            アセンブラ（simple_asm.py）とアセンブリのプログラム
docs/DESIGN.md             各モジュールの入出力・命令形式などの詳しい設計資料
```

## アセンブラ

`test_assembler/simple_asm.py` は、独自のアセンブリを16bitの機械語（`.hex` / `.mif`）に変換します。ラベル、`.ORG`、`.WORD`、`.SPACE` に対応しています。

```bash
python test_assembler/simple_asm.py test_assembler/radixsort_8bit_v6.s --mif -o radixsort_8bit_v6.mif
```

## 動かし方

Quartus Primeで `simple.qpf` を開き、コンパイルしてFPGAボードに書き込みます。

## クレジット

チーム13のメンバー3人で開発しました。SIMPLEアーキテクチャの仕様は京都大学「計算機科学実験及演習3」の配布資料によるものです。
