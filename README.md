passive_mainloop
===

テスト用のやつ。  
Delayerのremain_hookでキューの処理を要求された時だけイベントループを回します。

これをgtkプラグインが入っている環境に入れてはいけません。動かなくなるよ。

## メモ
- Signal USR1を送ると、Delayer.runを1回実行する
- 環境変数 ALLEN を "1" に設定して起動すると、250msに1回はDelayer.runを実行する

## install

```
mkdir -p ~/.mikutter/plugin && git clone https://github.com/shibafu528/mikutter_passive_mainloop.git ~/.mikutter/plugin/passive_mainloop
```
