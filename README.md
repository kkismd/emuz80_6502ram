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

## VTLC02-GM

コードネーム "GM" として、自分好みに機能追加しています。読み方は「ジム」です。

- [vtlc02_gm.asm](./vtlc02_gm.asm) ... 機能追加したVTLC01のソースコードです。ACMEでアセンブルできます。
- [vtlc02_gm.ihex](./vtlc02_gm.ihex) ... 上記をアセンブルしたiHexファイルです。UnimonからLコマンドでロードできます。
- [test_gm.vtl](./test_gm.vtl) ... GMの機能が正しく動いているか確認するためのテストコードです。内部構造の変更についての確認も含んでいます。

現状の追加機能リスト

- 16進リテラル
  - 0で始まる数値列は16進数として解釈されます

例

```vtl
?=0F12
3858
OK
```

今のところ以上です。
