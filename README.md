# EMUZ80-6502RAM derived Project

奥江 聡さん(@S_Okue)の作成された[EMUZ80-6502RAM](https://github.com/satoshiokue/EMUZ80-6502RAM)をいろいろいじっています。

## Unimon + VTLC02 イメージ

ファイル名: [EMUZ80-6502RAM_unimon_vtlc02_Q43.hex](./EMUZ80-6502RAM_unimon_vtlc02_Q43.hex)

奥江さんがROMイメージ内にひそかに導入されていた[Universal Monitor for 6502](https://electrelic.com/electrelic/node/1317) をACIAポートのアドレスを修正して動作するようにしました。

VTL2の6502版である[VTLC02](https://github.com/barrym95838/6502-Assembly)の入出力ルーチンを改変して動作するようにしました。

### 起動方法

電源オンORリセットでEhBASICが起動したあと、以下の操作で起動することができます。

unimon

```basic
CALL $F600
```

VTL

```basic
CALL $F100
```

## VTLC02

オリジナルからの改変場所を [vtlc02_emuz6502.diff](./vtlc02_emuz6502.diff) にあげています。

[ACME Cross-Assembler](https://github.com/martinpiper/ACME)でアセンブルできるように疑似命令などを修正しています。

### VTLC02-GM

コードネーム "GM" として、自分好みに機能追加しています。読み方は「ジム」です。

※上記の「Unimon + VTLC02 イメージ」には含まれておらず、個別のファイルとして公開しています。

- [vtlc02_gm.asm](./vtlc02_gm.asm) ... 機能追加したVTLC02のソースコードです。ACMEでアセンブルできます。
- [vtlc02_gm.ihex](./vtlc02_gm.ihex) ... 上記をアセンブルしたiHexファイルです。UnimonからLコマンドでロードできます。
- [test_gm.vtl](./test_gm.vtl) ... GMの機能が正しく動いているか確認するためのテストコードです。内部構造の変更についての確認も含んでいます。

#### 起動方法

プログラムが大きくなりすぎて`$F100`から`$F600`の1280バイトに収まらなくなってしまったので開始位置を`$EA00`に移動しました。
unimonからLコマンドでihexファイルを読み込んだ後Gコマンドで起動するアドレスが変わりました。

```
G EA00
```

メモリ上のプログラムが初期化されないホットスタートアドレスは`$EA1B`です。

#### 追加機能

- 16進リテラル
  - 0で始まる数値列は16進数として解釈されます

例

```vtl
?=0F12
3858
OK
```

- 16進プリント
  - `?$=数値`というコマンドで0～255の範囲の整数を16進形式で表示できます
  - 16進2桁という制約のため範囲を超えると`00`にオーバーラップします
  - `?$$=数値`というコマンドで0～65535の範囲の整数を16進4桁で表示できます

例

```vtl
?$=255
FF
OK
?$=256
00
OK
?$$=256
0100
OK
?$$=65535
FFFF
OK
```

- マルチステートメント
  - 1行の中にスペース区切りで複数の命令を書くことができます

- インデント機能の廃止
  - マルチステートメントのために、《インデントや可視性のために空白を無視する機能》を廃止しました

- IF文
  - `;=条件式`というコマンドで条件式が真のとき行の後ろの文を実行します

例

```vtl
10 ?="what is A ? "; A=?
20 ;=A>11 ?="A="; ?=A ?=", A is greater than or equals to 11"
```

- GOSUB / RETURN
  - `!=行番号` でサブルーチン呼び出し、`]` で呼び出し元に復帰します。

例

```vtl
100 ?=1 ?=2 !=500 ?=3 ?=4
110 ?=5 ?=""
120 #=0FFFF
500 ?=6 !=800 ?=7 ] ?=8
510 ?=9
800 ?=10 ?=11 ] ?=12
```

実行結果

```
12610117345

OK
```

- DO-UNTIL
  - `{` でループ開始、`}=条件文`で条件が成立したらループ終了します。

例

```vtl
100 I=1 {
110 ?="I="; ?=I ?="" 
120 I=I+1
130 }=I>10
```

実行結果

```
#=1
I=1
I=2
I=3
I=4
I=5
I=6
I=7
I=8
I=9

OK
```

- カンマ演算子の追加、ポインタ変数2種の廃止
  - 引数スタックに値を置くための「カンマ演算子`,`」を追加しました。
  - 以下に説明するシステム変数 `{< " @}` を廃止しました。
- マシン語サブルーチンコールステートメントの変更
  - `>=呼び出すルーチンのアドレス,ルーチンに渡すレジスタ値` という形に変更しました。
  - サブルーチンのアドレスを指定するためのシステム変数`{"}`を廃止しました。
  - サブルーチンから戻ってきたときのレジスタ`A`と`X`の値をシステム変数`{>}`にセットするように変更しました。
- POKE/PEEKの構文変更
  - POKEは`@=書き込み先アドレス,書き込む値`という形に変更しました。
  - PEEKのための`@`演算子を`ベースアドレス@オフセット`という形で定義しました。
  - 従来のPOKE/PEEKのためのポインタ変数`{<}`とPEEKのためのシステム変数`{@}`を廃止しました。

例

```vtl
110 A=&+100    ) 読み書きするアドレスを用意
120 @=A,0FF    ) 値 0xff をメモリに書き込み
130 ?$=A@0     ) メモリから読み込んで表示
140 ?$=&@100   ) オフセットを使って同じアドレスを指定
```

- 複数プログラムの共存、切替機能
  - プログラム開始アドレスポインタ `=` を追加しました
    - `==1234` とすると元のプログラムを消さずにプログラムの格納アドレスを変更できます
    - （アドレスが重複していない場合に限る）
  - 内部的にプログラム終了マーク `EOF (== 0xff)` を導入しました
  - NEWコマンド `&=0` と SEARCH-ENDコマンド `==0` を実装しました

GAME言語では CHANGE-PROGRAM は `=1234`、 SEARCH-END は `==` となっていますが、  
VTLのシンプルな文法を崩さないために、GAME言語とは少し異なるステートメントになっています。

例

```
10 ?="HELLO, WORLD"             新しいプログラムを入力します
#=1                             RUNコマンド
HELLO, WORLD                    文字列が表示されます

OK
?==                             開始アドレスは現在 1024
1024
OK
?=&                             終了アドレスは現在 1044
1044
OK
==1050                          新しい開始アドレスを設定

OK
&=0                             NEWコマンドを実行

OK
0                               LISTコマンドを実行してもプログラムは空

OK
10 ?="WELCOME TO NEW WORLD"     先ほどと違うプログラムを入力
#=1                             RUNコマンド
WELCOME TO NEW WORLD            新しい文字列が表示されます

OK
0                               LISTコマンド
10 ?="WELCOME TO NEW WORLD"

OK
?==                             開始アドレスは先ほど設定した 1050
1050
OK
?=&                             終了アドレスは 1078
1078
OK
==1024                          最初の開始アドレスに戻します

OK
==0                             SEARCH-ENDコマンドでプログラムの終了アドレスを正しい値に再設定します
                                （これをやらないと暴走します）
OK
?==                             設定された値になっています
1024
OK
?=&                             最初の値に正しく再設定されています
1044
OK
0                               LISTコマンド
10 ?="HELLO, WORLD"

OK
#=1                             実行します
HELLO, WORLD                    うまく動きました

OK

```

少しややこしいのでまとめると、新しい領域にプログラムを作成する場合
1. `==XXXX` （CHANGE-PROGRAM）で開始アドレス`=`を切り替え
2. `&=0` （NEW）で終了アドレス`&`と`EOF`を設定

既存のプログラムに切り替える場合
1. `==XXXX` （CHANGE-PROGRAM）で開始アドレス`=`を切り替え
2. `==0` （SEARCH-END）で`EOF`をもとに終了アドレス`&`を設定

となります。
