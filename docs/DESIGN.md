# プロセッサ設計演習

- 設計資料
https://isle3hw.kuis.kyoto-u.ac.jp/simple_v40.pdf
- スライド
https://isle3hw.kuis.kyoto-u.ac.jp/simple_lecture2026.pdf
- 講義サイト
https://isle3hw.kuis.kyoto-u.ac.jp/#rep1

## READMEの位置づけ

このREADMEは、リポジトリ内の現在のVerilogコードとアセンブラをもとに、プロセッサ全体の構成、主要モジュール、入出力、命令セット、制御方式を整理したメモである。

現在の実機トップは `top_module.v` で、そこから `piplined/pipelined_processor_top.v` を呼び出している。旧来の5フェーズ実装 `processor_top.v` も残っているが、トップレベルから直接使われているのはパイプライン版である。

## 現在の全体構成

### トップレベル

- `top_module.v`
  - FPGAボード外部との接続を担当する最上位モジュール。
  - キーパッド入力を16bitの外部入力値に変換する。
  - パイプラインCPU本体 `pipelined_processor_top` を動かす。
  - CPUの外部出力、PC、サイクル数、入力値を7セグ表示へ渡す。

- `piplined/pipelined_processor_top.v`
  - 現在のCPU本体。
  - 命令メモリの読み出し遅延に合わせてIFを2段に分けた、6段相当のパイプライン構成を持つ。
  - PLL、リセット同期、実行/停止制御、命令メモリ、データメモリ、分岐予測、ハザード検出、フォワーディング、外部入出力、性能カウンタをまとめている。

### 補助表示・外部入出力

- `keypad_decimal_input.v`
  - 13bitのキーパッド入力から16bit符号付き値を生成する。

- `main_seg_display.v`
  - CPUの外部出力値をメイン側7セグへ表示する。

- `seg7_reg_display.v`
  - PC、サイクル数、入力値などのデバッグ値を7セグへ表示する。

- `seg7_snoop_display.v`
  - データメモリ書き込みを監視して表示するための補助モジュール。
  - 現在の `top_module.v` からは直接使われていない。

- `seg7decoder.v`
  - 4bit値、マイナス表示、ブランク指定から7セグ出力を作る。

- `signed_decimal_8digits.v`
  - 16bit符号付き値を10進8桁表示用のBCD相当データへ変換する。

- `debouncer.v`
  - 物理ボタン入力を同期・整形する。

## 現在の主要モジュールと入出力

この節は、各 `.v` ファイルの `module` 宣言に合わせている。

### `top_module`

ファイル: `top_module.v`

役割:

- ボード全体の最上位。
- キーパッド、実行ボタン、入力確定ボタン、7セグ表示、CPU本体を接続する。

入力:

- `clk`: ボード側クロック。
- `sel_clk`: 7セグ表示など低速/選択用に使うクロック。
- `rst`: リセット。
- `exec`: 実行/停止トグル用入力。
- `keypad_keys[12:0]`: キーパッド入力。
- `input_enter`: 外部入力確定用入力。

出力:

- `wait_for_input`: CPUが外部入力待ちであることを示す。
- `main_seg_a_out[7:0]`, `main_seg_b_out[7:0]`, `main_seg_sel[7:0]`: メイン表示用7セグ出力。
- `seg_a_out[7:0]` から `seg_h_out[7:0]`: デバッグ表示用7セグ出力。
- `seg_sel[8:0]`: デバッグ表示用桁選択。

### `pipelined_processor_top`

ファイル: `piplined/pipelined_processor_top.v`

役割:

- 現在のCPU本体。
- 内部クロック生成、リセット同期、パイプライン制御、メモリ、分岐予測、外部入出力を統合する。

入力:

- `clk_20m`: PLL入力クロック。
- `rst_n`: アクティブローリセット。
- `exec`: 実行/停止指示。
- `external_input[15:0]`: 外部からCPUへ渡す16bit入力値。
- `input_enter`: IN命令待ち解除用の入力確定信号。

出力:

- `external_output[15:0]`: OUT命令で保持される外部出力値。
- `wait_for_input`: IN命令により入力待ちであることを示す。
- `pc_output[15:0]`: 現在または表示用のPC値。
- `cycle_count[31:0]`: 実行中のサイクル数。

内部で使う主なモジュール:

- `my_pll`: 内部クロック生成。
- `debouncer`: `exec` と `input_enter` のチャタリング除去。
- `run_state_module`: 実行状態の保持。
- `pipelined_pc`: PC更新。
- `inst_main_memory`: 命令メモリ。
- `data_main_memory`: データメモリ。
- `reg_if`, `reg_ifid`, `reg_idex`, `reg_exmem`, `reg_memwb`: パイプラインレジスタ。
- `id`: 命令デコード、レジスタ読み出し、制御信号生成。
- `calculator`: ALU/シフタ。
- `predictor`: 分岐予測。
- `hazard_detection`: ロード/IN/フラグ依存の検出。
- `forwarding_unit`: データフォワーディング。
- `sort_performance_counter`: サイクル数計測。

### `pipelined_pc`

ファイル: `piplined/pipelined_pc.v`

役割:

- パイプライン版のPCレジスタ。
- `run_state` が有効なときだけ、次PCを取り込む。

入力:

- `clk`
- `rst`
- `run_state`
- `pc_input[15:0]`

出力:

- `pc_output[15:0]`

### `run_state_module`

ファイル: `piplined/run_state_module.v`

役割:

- CPUが実行中か停止中かを管理する。
- `exec` の押下で実行状態を切り替える。
- `wait_for_input` 中は `input_enter` を待つ。
- `is_halt` が来ると実行を停止する。

入力:

- `clk`
- `rst`
- `exec`
- `wait_for_input`
- `input_enter`
- `is_halt`

出力:

- `run_state`

### `id`

ファイル: `piplined/id.v`

役割:

- 命令語を分解する。
- レジスタファイルを読み出す。
- WB段からの書き戻しを受ける。
- ALU/シフタ入力、メモリ書き込みデータ、分岐先、制御信号を生成する。
- 条件分岐の成立判定もここで行う。

入力:

- `instruction[15:0]`: デコード対象命令。
- `clk`, `rst`, `flush`
- `write_back_data[15:0]`: WB段からの書き戻しデータ。
- `write_back_enable`: レジスタファイル書き込み有効。
- `write_back_address[2:0]`: 書き戻し先レジスタ。
- `pc_now[15:0]`: 分岐先計算に使うPC。
- `data_szcv_in[3:0]`: 条件分岐判定に使うSZCVフラグ。
- `forwarded_data_a[15:0]`, `forwarded_data_b[15:0]`: フォワーディング後のオペランド。

出力:

- `op3_output[3:0]`: ALU/シフタ操作コード。
- `sel_shifter`: シフタ選択。
- `data_a[15:0]`, `data_b[15:0]`: EX段へ渡す演算入力。
- `data_write_to_main_memory[15:0]`: ST命令でメモリへ書く値。
- `diff_4bit[3:0]`: シフト量。
- `pc_jump[15:0]`: 分岐先PC。
- `jump_enable`: 分岐成立または無条件分岐。
- `address_write_to_reg_file[2:0]`: 書き戻し先レジスタ。
- `reg_write_enable_output`: レジスタ書き込み有効。
- `is_st`, `is_alu`, `is_ld`, `is_in`, `is_out`, `is_halt`: 命令種別。
- `szcv_update_enable`: SZCV更新有効。
- `data_a_raw[15:0]`, `data_b_raw[15:0]`: フォワーディング判定用の生データ。
- `address_a_out[2:0]`, `address_b_out[2:0]`: フォワーディング判定用レジスタ番号。
- `is_branch`: 分岐命令かどうか。

### `reg_file`

ファイル: `reg_file.v`

役割:

- 8本の16bit汎用レジスタを持つ。
- 非同期読み出し、クロック同期書き込み。
- リセット時は全レジスタを0にする。

入力:

- `clk`, `rst`, `write_enable`
- `address_a[2:0]`, `address_b[2:0]`
- `address_write[2:0]`
- `data_write[15:0]`

出力:

- `data_a[15:0]`
- `data_b[15:0]`

### `calculator`

ファイル: `calculator.v`

役割:

- ALUとシフタをまとめた演算器。
- `sel_shifter` が0ならALU、1ならシフタの結果を出す。

入力:

- `data_a[15:0]`
- `data_b[15:0]`
- `op3[3:0]`
- `sel_shifter`
- `diff_4bit[3:0]`

出力:

- `data_output[15:0]`
- `alu_pure_output[15:0]`
- `data_szcv[3:0]`

### `alu`

ファイル: `alu.v`

役割:

- 16bit算術論理演算を行う。
- 結果に基づいて `S`, `Z`, `C`, `V` フラグを生成する。

入力:

- `data_a[15:0]`
- `data_b[15:0]`
- `op3[3:0]`

出力:

- `data_output[15:0]`
- `data_szcv[3:0]`

`op3` の対応:

- `0000`: ADD。`data_b + data_a`
- `0001`: SUB。`data_b - data_a`
- `0010`: AND。`data_b & data_a`
- `0011`: OR。`data_b | data_a`
- `0100`: XOR。`data_b ^ data_a`
- `0101`: CMP。`data_b - data_a` を計算して主にフラグ用に使う。
- `0110`: MOV。`data_a`

フラグ:

- `S`: 結果の最上位ビット。
- `Z`: 結果が0なら1。
- `C`: ADDでは桁上がり、SUB/CMPでは借りを表す。
- `V`: 符号付き加減算のオーバーフロー。

### `shifter`

ファイル: `shifter.v`

役割:

- 16bit値のシフト/ローテートを行う。
- `S`, `Z`, `C`, `V` フラグを生成する。

入力:

- `data_b[15:0]`
- `op3[3:0]`
- `diff[3:0]`

出力:

- `data_output[15:0]`
- `data_szcv[3:0]`

`op3` の対応:

- `1000`: SLL。左論理シフト。
- `1001`: SLR。左ローテートとして実装されている。
- `1010`: SRL。右論理シフト。
- `1011`: SRA。右算術シフト。

注意:

- `SLR` という命令名はアセンブラ側にも存在するが、コード上の処理は左ローテートに見える。
- `V` は常に0。

### `predictor`

ファイル: `predictor.v`

役割:

- 分岐予測器。
- 32エントリのBHT/BTB相当の構造を持つ。
- 2bit飽和カウンタにより taken/not taken を予測する。

入力:

- `PC_input[15:0]`
- `clk`
- `rst`
- `update_enable`
- `PC_update[15:0]`
- `branch_order`
- `actual_address[15:0]`
- `actual_jump`

出力:

- `jump_enable`
- `jump_address[15:0]`

### `hazard_detection`

ファイル: `hazard_detection.v`

役割:

- パイプラインで即座にフォワーディングできない依存を検出する。
- 現在はロード命令、IN命令、SZCV更新直後の条件分岐を主に見る。

入力:

- `is_ld_ex`
- `is_in_ex`
- `szcv_update_enable_ex`
- `ex_dest_addr[2:0]`
- `instruction_id[15:0]`

出力:

- `hazard_detected`

検出対象:

- EX段のLD/IN結果をID段命令が読む場合。
- EX段でSZCVを更新する直後にID段が条件分岐する場合。

### `forwarding_unit`

ファイル: `piplined/fowarding_unit.v`

役割:

- ID段で読んだレジスタ値に対して、後続段の結果を転送する。
- ファイル名は `fowarding_unit.v` と綴られているが、モジュール名は `forwarding_unit`。

入力:

- `address_a[2:0]`, `address_b[2:0]`
- `data_a_raw[15:0]`, `data_b_raw[15:0]`
- `ex_reg_write_en`
- `ex_dest_addr[2:0]`
- `ex_result[15:0]`
- `mem_reg_write_en`
- `mem_dest_addr[2:0]`
- `mem_result[15:0]`

出力:

- `forwarded_data_a[15:0]`
- `forwarded_data_b[15:0]`

### パイプラインレジスタ群

#### `reg_if`

ファイル: `piplined/reg_if.v`

入力:

- `clk`, `rst`, `write_enable`
- `pc_input[15:0]`
- `valid_input`

出力:

- `pc_output[15:0]`
- `valid_output`

役割:

- 命令メモリの読み出し遅延に合わせてIF段のPCとvalidを保持する。

#### `reg_ifid`

ファイル: `piplined/reg_IFID.v`

入力:

- `clk`, `rst`, `write_enable`
- `ir_input[15:0]`
- `pc_input[15:0]`
- `valid_input`
- `pred_en_input`
- `pred_pc_input[15:0]`

出力:

- `ir_output[15:0]`
- `pc_output[15:0]`
- `valid_output`
- `pred_en_output`
- `pred_pc_output[15:0]`

役割:

- IF段からID段へ命令、PC、有効ビット、分岐予測情報を渡す。

#### `reg_idex`

ファイル: `piplined/reg_IDEX.v`

入力:

- `clk`, `rst`, `flush`, `write_enable`
- `reg_write_enable_input`, `is_st_input`, `is_alu_input`, `is_ld_input`, `is_in_input`, `is_out_input`, `is_halt_input`
- `szcv_update_enable_input`
- `sel_shifter_input`
- `op3_input[3:0]`
- `data_a_input[15:0]`, `data_b_input[15:0]`
- `address_write_to_reg_file_input[2:0]`
- `data_write_to_main_memory_input[15:0]`
- `diff_4bit_input[3:0]`
- `sel_out_input[2:0]`

出力:

- 上記入力に対応するEX段向け信号。

役割:

- ID段で作った制御信号とオペランドをEX段へ渡す。

#### `reg_exmem`

ファイル: `piplined/reg_exmem.v`

入力:

- `clk`, `rst`, `flush`, `write_enable`
- `reg_write_enable_input`, `is_st_input`, `is_ld_input`, `is_in_input`, `is_halt_input`
- `szcv_update_enable_input`
- `alu_result_input[15:0]`
- `alu_szcv_input[3:0]`
- `address_write_to_reg_file_input[2:0]`
- `data_write_to_main_memory_input[15:0]`

出力:

- 上記入力に対応するMEM段向け信号。

役割:

- EX段の演算結果、フラグ、メモリアクセス制御、書き戻し制御をMEM段へ渡す。

#### `reg_memwb`

ファイル: `piplined/reg_memwb.v`

入力:

- `clk`, `rst`, `flush`, `write_enable`
- `reg_write_enable_input`, `is_ld_input`, `is_in_input`, `is_halt_input`
- `alu_result_input[15:0]`
- `memory_data_input[15:0]`
- `address_write_to_reg_file_input[2:0]`

出力:

- `reg_write_enable_output`, `is_ld_output`, `is_in_output`, `is_halt_output`
- `address_write_to_reg_file_output[2:0]`
- `alu_result_output[15:0]`
- `memory_data_output[15:0]`

役割:

- MEM段の結果をWB段へ渡す。

### メモリ

#### `inst_main_memory`

ファイル: `inst_main_memory.v`

役割:

- 命令メモリ。
- Quartus生成RAM系のモジュール。

入力:

- `address[13:0]`
- `clock`
- `data[15:0]`
- `addressstall`
- `wren`

出力:

- `q[15:0]`

#### `data_main_memory`

ファイル: `data_main_memory.v`

役割:

- データメモリ。
- Quartus生成RAM系のモジュール。

入力:

- `address[13:0]`
- `clock`
- `data[15:0]`
- `wren`

出力:

- `q[15:0]`

#### `main_memory`

ファイル: `main_memory.v`

役割:

- 汎用的なVerilog記述のメモリ。
- 現在のパイプライン本体では、生成RAMに置き換えられている箇所が多い。

入力:

- `clk`, `write_enable`, `read_enable`
- `address_bus[15:0]`
- `data_input[15:0]`

出力:

- `data_output[15:0]`

### 外部入出力・性能計測

#### `keypad_decimal_input`

ファイル: `keypad_decimal_input.v`

入力:

- `clk`
- `rst`
- `keys[12:0]`

出力:

- `value[15:0]`

役割:

- キーパッド入力を16bit値へ変換する。

#### `sort_performance_counter`

ファイル: `sort_performance_counter.v`

入力:

- `clk`
- `rst`
- `run_state`
- `halt`

出力:

- `cycle_count[31:0]`

役割:

- 実行中のサイクル数を数える。
- ソートなどの実行性能確認に使う。

### 旧5フェーズ実装/補助レジスタ

以下は `processor_top.v` 側で使われている、または旧実装の構成要素として残っているモジュールである。現在の `top_module.v` からは直接CPU本体としては使われていない。

#### `processor_top`

ファイル: `processor_top.v`

役割:

- 5フェーズ制御の旧CPUトップと思われる。
- `phase_counter`, `PC`, `reg_input`, `reg_a`, `reg_b`, `decoder`, `reg_output`, `reg_memory`, `reg_szcv` などを使う。

注意:

- 現在の `decoder.v` のポート宣言と、`processor_top.v` 内の `decoder` インスタンス接続名には不一致が見える。
- `reg_file.v` のポート宣言と、`processor_top.v` で接続している `data_reg_0` から `data_reg_7` にも不一致が見える。
- そのため、旧実装は現在のトップ構成とは別管理の可能性がある。

#### `phase_counter`

ファイル: `phase_counter.v`

入力:

- `clk`
- `rst`
- `input_enter`
- `exec`
- `wait_for_input`

出力:

- `p1`, `p2`, `p3`, `p4`, `p5`

役割:

- 5フェーズ制御用のフェーズ信号を作る。
- `exec` の立ち上がりで実行状態をトグルする。
- `wait_for_input` 中は `input_enter` の立ち上がりまでPhase 4で止まる。

#### `PC`

ファイル: `PC.v`

入力:

- `clk`
- `rst`
- `pc_input[15:0]`
- `jump_enable`
- `p1`
- `p5`

出力:

- `pc_output[15:0]`

役割:

- 5フェーズ実装用PC。
- `p1` で通常インクリメントする。
- `p5 && jump_enable` で分岐先をロードする。

#### `reg_input`

ファイル: `reg_input.v`

入力:

- `clk`, `rst`, `write_enable`
- `data_input[15:0]`

出力:

- `op1[1:0]`
- `address_a[2:0]`
- `address_b[2:0]`
- `op2[2:0]`
- `cond[2:0]`
- `op3[3:0]`
- `dif4[3:0]`
- `dif8[7:0]`

役割:

- 命令レジスタ。
- 16bit命令を各フィールドに分解して保持する。

#### `reg_a`, `reg_b`

ファイル: `reg_a.v`, `reg_b.v`

入力:

- `clk`, `rst`, `write_enable`
- `data_a_in[15:0]` または `data_b_in[15:0]`

出力:

- `data_a_out[15:0]` または `data_b_out[15:0]`

役割:

- 旧5フェーズ実装のA/Bオペランド保持レジスタ。

#### `reg_memory`

ファイル: `reg_memory.v`

入力:

- `data_memory_in[15:0]`
- `clk`
- `rst`
- `write_enable`

出力:

- `data_memory_out[15:0]`

役割:

- メモリ読み出し値や外部入力値を一時保持するMDR相当のレジスタ。

#### `reg_output`

ファイル: `reg_output.v`

入力:

- `data_output_in[15:0]`
- `clk`
- `rst`
- `write_enable`

出力:

- `data_output_out[15:0]`

役割:

- ALU/デコーダ結果を一時保持するDR相当のレジスタ。

#### `reg_szcv`

ファイル: `reg_szcv.v`

入力:

- `data_szcv_in[3:0]`
- `clk`
- `rst`
- `write_enable`

出力:

- `data_szcv_out[3:0]`

役割:

- `S`, `Z`, `C`, `V` フラグを保持する。

#### `decoder`

ファイル: `decoder.v`

現在の宣言上の入力:

- `data_a_input[15:0]`
- `data_b_input[15:0]`
- `op3[3:0]`
- `data_szcv_in[3:0]`
- `cond[2:0]`
- `sel_shifter`

現在の宣言上の出力:

- `data_output[15:0]`
- `data_szcv_out[3:0]`
- `jump_enable`

注意:

- ファイル内部では `op1`, `op2`, `diff_4bit`, `diff_8bit`, `pc_in`, `data_a`, `data_b` など、宣言上のポートに存在しない名前も使われている。
- `processor_top.v` 側の接続は、これらを入力として渡す意図に見える。
- READMEでは現状の宣言を記録するにとどめ、実装修正はここでは行わない。

## パイプラインCPUの設計

### 基本方針

現在のCPU本体は、`pipelined_processor_top` を中心とした、IFを2段に分ける6段相当のパイプライン構成である。

大まかな段は次のように読める。

- IF1: PCに基づいて命令メモリから命令を読む。
- IF2: 命令メモリの出力を受け取り、IF/IDレジスタへ書き込む。
- ID: 命令をデコードし、レジスタを読み、制御信号を作る。
- EX: ALU/シフタで演算する。
- MEM: データメモリまたは外部入力にアクセスする。
- WB: レジスタファイルへ結果を書き戻す。

命令は16bit固定長で、汎用レジスタは `R0` から `R7` までの8本、各16bitである。

### クロックとリセット

`pipelined_processor_top` は外部入力 `clk_20m` を `my_pll` に通して内部クロック `clk` を生成する。

リセットは次のように処理される。

- 外部リセット `rst_n` とPLLの `pll_locked` を組み合わせて `rst_async_n` を作る。
- 内部クロックで数段同期し、`rst` を生成する。
- 各パイプラインレジスタや制御モジュールは、この `rst` を使う。

この構成により、PLLがロックする前にCPU内部が走り出すことを避けている。

### 実行状態

実行/停止は `run_state_module` が管理する。

- `exec` ボタンは `debouncer` に通される。
- 押下パルスで実行状態を切り替える。
- `IN` 命令で入力待ちになると、`input_enter` まで進行を止める。
- `HLT` 命令がWB段まで到達すると停止する。

`pipelined_processor_top` では、パイプラインの各段ごとに次のような更新許可信号を作っている。

- `run_state_pc`
- `run_state_if`
- `run_state_ifid`
- `run_state_idex`
- `run_state_exmem`
- `run_state_memwb`

特にストールやHALTドレイン中はPCやIF/IDの更新を止め、後段だけを流すような制御が入っている。

### IF段

IF段では、`pipelined_pc` が現在のPCを保持する。

`instruction_address_bus = pc_now` として命令メモリへアドレスを渡し、`inst_main_memory` から命令語を読む。

分岐予測器 `predictor` が有効な場合は、次PCとして予測先を使う。予測しない場合は通常の `PC + 1` を使う。

命令メモリの遅延に合わせるため、`reg_if` でPCとvalidを1段保持し、予測結果も内部レジスタで遅延させている。

### ID段

ID段では `reg_ifid` から命令とPCを受け取り、`id` モジュールで処理する。

`id` が行う主な処理:

- 命令フィールドの分解。
- 命令種別の判定。
- レジスタファイル読み出し。
- WB段からの同一サイクル書き戻しの反映。
- ALU/シフタ入力の選択。
- ST命令用のメモリ書き込みデータ生成。
- レジスタ書き戻し先の決定。
- 分岐条件判定。
- `pc_jump` の生成。
- `is_ld`, `is_st`, `is_in`, `is_out`, `is_halt` などの制御信号生成。

即値命令では、8bit即値を符号拡張して使うものと、LUIのように上位8bitへ配置するものがある。

### EX段

EX段では `calculator` が演算を行う。

`calculator` は内部で `alu` と `shifter` の両方を持ち、`sel_shifter` によって出力を選ぶ。

ALU命令や即値演算では `alu` を使う。シフト/ローテート命令では `shifter` を使う。

OUT命令では、EX段付近で外部出力値を保持する。現在のコードでは `persistent_external_output` に出力値を保存し、`external_output` として出している。

### MEM段

MEM段では、データメモリまたは外部入力を扱う。

- ST命令: `data_main_memory` へ書き込む。
- LD命令: `data_main_memory` から読む。
- IN命令: `external_input` をメモリ読み出し値のように扱い、WB段へ流す。

現在の `pipelined_processor_top.v` では、データメモリアドレスとして `datamem_address_bus = data_b_ex + data_a_ex` が使われている。

### WB段

WB段では、レジスタファイルへ書き戻す値を選ぶ。

- LD/IN命令: `memory_data_wb`
- それ以外の書き戻し命令: `alu_result_wb`

書き戻しは `id` 内部の `reg_file` インスタンスに戻る形になっている。

### ハザード制御

`hazard_detection` は、ID段命令とEX段命令の依存関係を見てストールを出す。

現在見る依存:

- EX段がLD命令で、そのロード結果をID段命令が読む。
- EX段がIN命令で、その入力結果をID段命令が読む。
- EX段でSZCV更新があり、ID段が条件分岐をする。

`stall = valid_id && hazard_detected` となっており、ストール時はPCやIF/IDの更新を止める。

### フォワーディング

`forwarding_unit` は、ID段で読まれた `data_a_raw`, `data_b_raw` に対して、後続段の結果を転送する。

優先順位はコード上、EX側の結果を先に見て、次にMEM側の結果を見る構成である。

これにより、単純なALU依存ではストールせずに次命令へ値を渡せる。

### 分岐予測とフラッシュ

`predictor` は、PC下位ビットを使ってBHT/BTBを引く。

- BHTは2bit飽和カウンタ。
- BTBは予測分岐先アドレス。
- validと簡単なtagも持つ。

ID段で実際の分岐可否と分岐先が確定したあと、予測と違えば `misprediction` となり、PCを回復先へ向ける。

`reg_ifid` にはフラッシュ制御が入り、予測ミスやHALTドレイン時に若い命令を消す。

## 命令形式

現在の命令形式は、`test_assembler/simple_asm.py` と `piplined/id.v` の実装を基準に整理する。

### 共通フィールド

16bit命令語はおおむね次のフィールドに分解される。

- `op1 = instruction[15:14]`
- `address_a = instruction[13:11]`
- `op2 = instruction[13:11]`
- `address_b = instruction[10:8]`
- `cond = instruction[10:8]`
- `op3 = instruction[7:4]`
- `diff_8bit = instruction[7:0]`
- `diff_4bit = instruction[3:0]`

命令種別により、同じビット位置をレジスタ番号として使う場合と、命令サブコードとして使う場合がある。

### LD

形式:

- `LD Ra, d(Rb)`

符号化:

- `op1 = 00`
- `Ra = instruction[13:11]`
- `Rb = instruction[10:8]`
- `d = instruction[7:0]`

意味:

- `Ra <- MEM[Rb + sign_extend(d)]`

書き戻し:

- 書き戻し先は `Ra`。

### ST

形式:

- `ST Ra, d(Rb)`

符号化:

- `op1 = 01`
- `Ra = instruction[13:11]`
- `Rb = instruction[10:8]`
- `d = instruction[7:0]`

意味:

- `MEM[Rb + sign_extend(d)] <- Ra`

### 即値/分岐系

`op1 = 10` の命令群。

`op2 = instruction[13:11]` で命令を区別する。

### レジスタ演算/シフト/入出力/HALT

`op1 = 11` の命令群。

`op3 = instruction[7:4]` で演算や特殊命令を区別する。

## 追加した命令

この節は、過去READMEにあった「追加した命令」を残しつつ、現在のアセンブラと `id.v` に合わせて整理したものである。

### 即値命令

即値ロード形式で `op2` の予約領域を使って命令を追加している。

| 命令 | op1 | op2 | 形式 | 意味 |
| --- | --- | --- | --- | --- |
| `LI` | `10` | `000` | `LI Rb, d` | `Rb <- sign_extend_or_raw8(d)` 相当。実装上は8bit値を16bitへ拡張してMOVする。 |
| `ADDI` | `10` | `001` | `ADDI Rb, d` | `Rb <- Rb + sign_extend(d)` |
| `SUBI` | `10` | `010` | `SUBI Rb, d` | `Rb <- Rb - sign_extend(d)` |
| `CMPI` | `10` | `011` | `CMPI Rb, d` | `Rb - sign_extend(d)` の結果でSZCVを更新する。レジスタへは書き戻さない。 |
| `ANDI` | `10` | `101` | `ANDI Rb, d` | `Rb <- Rb & sign_extend(d)` |
| `LUI` | `10` | `110` | `LUI Rb, d` | `Rb <- {d, 8'h00}` |

メモ:

- `op2 = 100` は無条件分岐 `B` に使われている。
- `op2 = 111` は条件分岐に使われている。
- `LI` は追加命令というより既存/基本命令扱いに近いが、現在の即値命令群としてここに含めている。

### NOP

`NOP` 命令は `0x0000`。

アセンブラ `simple_asm.py` でも `NOP` は引数なしで `0x0000` を出力する。

### IN

形式:

- `IN Rd`
- アセンブラ上は任意の4bit即値を第2引数に取れるが、通常は省略できる。

符号化:

- `op1 = 11`
- `address_b = Rd`
- `op3 = 1100`

意味:

- 外部入力値を `Rd` に取り込む。
- CPUは `wait_for_input` を出し、`input_enter` を待つ。

### OUT

形式:

- `OUT Rs`
- アセンブラ上は任意の4bit即値を第2引数に取れるが、通常は省略できる。

符号化:

- `op1 = 11`
- `address_a = Rs`
- `op3 = 1101`

意味:

- `Rs` の値を外部出力レジスタに保持する。
- `top_module` 側でこの値がメイン7セグ表示に渡される。

### HLT

形式:

- `HLT`

符号化:

- `op1 = 11`
- `op3 = 1111`

意味:

- 命令がWB段まで流れたあと、実行状態を停止する。
- `pipelined_processor_top` では、HLTを見つけたあと後続の若い命令を止めながら、HLT自身をコミットさせる制御が入っている。

## 命令セットの制限

この節は、過去READMEにあった「命令セットの制限」を残しつつ、現在のアセンブラ・実装に合わせて読みやすく整理したものである。

### ロード/ストア方式

本プロセッサはロード/ストア型である。

- メモリからレジスタへ読む命令は `LD`。
- レジスタからメモリへ書く命令は `ST`。
- 算術論理演算は基本的にレジスタ上の値、または即値とレジスタの組み合わせで行う。

### レジスタ数

汎用レジスタは `R0` から `R7` までの8本である。

命令中のレジスタ番号は3bitなので、これ以上のレジスタは現在の命令形式では直接指定できない。

### 即値幅

多くの即値・変位は8bitである。

アセンブラでは、8bit即値について次の範囲を許している。

- 符号付き即値/変位: `-128` から `127`
- `enc_imm8` を使う即値: `-128` から `255`

実機側では、通常の即値演算は `diff_8bit` を符号拡張して使う。

### LUIの注意

`LUI` は8bit即値を上位8bitに配置する。

- `LUI Rb, d` は `Rb <- {d, 8'h00}`。
- 16bit定数を作る場合は、`LUI` と `ADDI` などを組み合わせる。

注意:

- `ADDI` は即値を符号拡張するため、下位8bitが `0x80` から `0xFF` の値を単純に足すと負数として扱われる。
- そのため、任意の16bit値を作るときは、下位バイトが負数扱いになるケースを意識する必要がある。

### 条件分岐

条件分岐はSZCVフラグを参照する。

現在の条件:

- `BE`: `Z = 1`
- `BLT`: `S ^ V = 1`
- `BLE`: `Z | (S ^ V) = 1`
- `BNE`: `Z = 0`

条件分岐直前にSZCVを更新する命令がある場合、パイプライン上の依存が発生するため、`hazard_detection` がストールを入れる。

### ハザード上の制限

ロードやINの直後に、その結果を読む命令が来ると、通常のフォワーディングだけでは間に合わない可能性がある。

現在の実装では `hazard_detection` がこれを検出し、ストールする。

対象:

- `LD` の直後にロード先レジスタを読む。
- `IN` の直後に入力先レジスタを読む。
- SZCV更新命令の直後に条件分岐する。

### 未使用/予約領域

命令空間には未使用または予約扱いの組み合わせが残っている。

現在確認できる割り当て:

- `op1 = 00`: LD
- `op1 = 01`: ST
- `op1 = 10, op2 = 000`: LI
- `op1 = 10, op2 = 001`: ADDI
- `op1 = 10, op2 = 010`: SUBI
- `op1 = 10, op2 = 011`: CMPI
- `op1 = 10, op2 = 100`: B
- `op1 = 10, op2 = 101`: ANDI
- `op1 = 10, op2 = 110`: LUI
- `op1 = 10, op2 = 111`: 条件分岐
- `op1 = 11, op3 = 0000`: ADD
- `op1 = 11, op3 = 0001`: SUB
- `op1 = 11, op3 = 0010`: AND
- `op1 = 11, op3 = 0011`: OR
- `op1 = 11, op3 = 0100`: XOR
- `op1 = 11, op3 = 0101`: CMP
- `op1 = 11, op3 = 0110`: MOV
- `op1 = 11, op3 = 1000`: SLL
- `op1 = 11, op3 = 1001`: SLR/左ローテート相当
- `op1 = 11, op3 = 1010`: SRL
- `op1 = 11, op3 = 1011`: SRA
- `op1 = 11, op3 = 1100`: IN
- `op1 = 11, op3 = 1101`: OUT
- `op1 = 11, op3 = 1111`: HLT

`op1 = 11, op3 = 1110` は、現時点では明確な命令として確認していない。

## アセンブラ

ファイル:

- `test_assembler/simple_asm.py`

役割:

- 独自アセンブリを16bit機械語へ変換する。
- `.hex` と `.mif` 出力に対応する。
- ラベル、`.ORG`, `.WORD`, `.SPACE` に対応する。

対応命令:

- `LD`
- `ST`
- `LI`
- `ADDI`
- `SUBI`
- `CMPI`
- `ANDI`
- `LUI`
- `B`
- `BE`
- `BLT`
- `BLE`
- `BNE`
- `ADD`
- `SUB`
- `AND`
- `OR`
- `XOR`
- `CMP`
- `MOV`
- `SLL`
- `SLR`
- `SRL`
- `SRA`
- `IN`
- `OUT`
- `NOP`
- `HLT`

使用例:

```powershell
python test_assembler/simple_asm.py test_assembler/calculator_v3.s -o calculator.mif --mif
```

## 現在のファイル整理メモ

### 実機・現行パスで重要なファイル

- `top_module.v`
- `piplined/pipelined_processor_top.v`
- `piplined/id.v`
- `piplined/pipelined_pc.v`
- `piplined/reg_if.v`
- `piplined/reg_IFID.v`
- `piplined/reg_IDEX.v`
- `piplined/reg_exmem.v`
- `piplined/reg_memwb.v`
- `piplined/run_state_module.v`
- `piplined/fowarding_unit.v`
- `hazard_detection.v`
- `predictor.v`
- `calculator.v`
- `alu.v`
- `shifter.v`
- `reg_file.v`
- `inst_main_memory.v`
- `data_main_memory.v`
- `keypad_decimal_input.v`
- `main_seg_display.v`
- `seg7_reg_display.v`
- `seg7decoder.v`
- `signed_decimal_8digits.v`
- `sort_performance_counter.v`

### 旧実装/比較用と思われるファイル

- `processor_top.v`
- `PC.v`
- `phase_counter.v`
- `reg_input.v`
- `reg_a.v`
- `reg_b.v`
- `reg_memory.v`
- `reg_output.v`
- `reg_szcv.v`
- `decoder.v`
- `main_memory.v`

### テストベンチ

- `processor_top.vt`
- `piplined/pipelined_processor_top_tb.v`
- `alu.vt`
- `decoder.vt`
- `hazard_detection.vt`
- `predictor.vt`
- `reg_a.vt`
- `reg_szcv.vt`
- `shifter.vt`
- `phase_counter.vt`

## 現状の注意点

### ディレクトリ名

パイプライン実装のディレクトリ名は `piplined` になっている。

一般的な綴りは `pipelined` だが、現在のコード・プロジェクト参照に合わせるなら、この名前を前提に扱う。

### フォワーディングユニットのファイル名

ファイル名は `piplined/fowarding_unit.v` だが、モジュール名は `forwarding_unit`。

これも現在のコードに合わせて記録している。

### 旧`processor_top`周辺の不一致

`processor_top.v` は、現在の `top_module.v` からは使われていない。

また、少なくとも次の不一致が見える。

- `processor_top.v` が `decoder` に接続しているポート名と、`decoder.v` の宣言が一致していない。
- `processor_top.v` が `reg_file` に接続している `data_reg_0` から `data_reg_7` は、現在の `reg_file.v` の宣言には存在しない。

そのため、旧5フェーズ実装を再利用する場合は、この周辺を先に確認する必要がある。

### 表示系の信号幅

`top_module.v` の `seg_sel` は `[8:0]` で、`processor_top.v` の7セグ出力では `[7:0]` の箇所もある。

現在の実機トップでは `top_module.v` 側の接続を基準にする。

## 今後READMEに追記できそうなこと

現時点で無理に断定しなかったが、必要なら次を追加で整理できる。

- Quartusプロジェクト上で実際にトップ指定されているモジュール。
- `.qsf` に登録されているファイル一覧と、不要ファイルの候補。
- `inst_main_memory` / `data_main_memory` が参照している初期化MIF。
- 各テストアセンブリの目的。
- ソートプログラムのメモリ配置。
- 分岐予測の精度や性能カウンタの使い方。
- 7セグ表示の桁割り当て。
