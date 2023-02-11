# EMUZ80-6502RAM derived Project

奥江 聡さん(@S_Okue)の作成された[EMUZ80-6502RAM](https://github.com/satoshiokue/EMUZ80-6502RAM)をいろいろいじっています。

## Unimon + VTLC02 イメージ

ファイル名: [EMUZ80-6502RAM_unimon_vtlc02_Q43.hex](./EMUZ80-6502RAM_unimon_vtlc02_Q43.hex)

奥江さんがROMイメージ内にひそかに導入されていた[Universal Monitor for 6502](https://electrelic.com/electrelic/node/1317) をACIAポートのアドレスを修正して動作するようにしました。

VTL2の6502版である[VTLC02](https://github.com/barrym95838/6502-Assembly)の入出力ルーチンを改変して動作するようにしました。

### 起動方法

電源オンORリセットでEhBASICが起動したあと、以下の操作で起動することができます。

unimon
```
CALL $F600
```

VTL
```
CALL $F100
```

## VTLC02

オリジナルからの改変場所を [vtlc02_emuz6502.diff](./vtlc02_emuz6502.diff) にあげています。

[ACME Cross-Assembler](https://github.com/martinpiper/ACME)でアセンブルできるように疑似命令などを修正しています。
