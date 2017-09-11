---

title: トランスコード後ビデオの画質評価とノイズ検出
date: 2017-09-01 00:10 JST
tags: SSIM, PSNR, ffmpeg, Noise

---

動画のトランスコード後に、もとの素材からどのくらい画質劣化が発生したのかを調べる方法について調べた。
画質の評価方法にはいくつか種類があるが、今回はPSNRとSSIMを利用し映像劣化やノイズがどの程度検出できるのかについて検証した。

検証の結果、SSIMやPSNRといった指標を活用することで、
トランスコード後の画面全体にのったノイズ（ブロックノイズやモスキートノイズ等）の検出が可能であるということがわかった。

## はじめに

ProResやDNxHDと言った中間コーデックは無圧縮の動画並みの品質を持っているが、そのまま配信するにはデータ量が大きすぎる。
動画をエンドユーザに配信するためには、コンテンツをMPEG2やH.264といった配信用のフォーマットに変換する必要がある。

MPEGやh264は編集には適さないが、高い映像品質を維持したままデータサイズを大幅に抑えることができるため、
テレビ放送やBD/DVD、及びVODなどの動画配信サービスで利用されている。 
これらのフォーマットでは、元の素材から人間にはわかりづらい領域のデータを削ったり、
前後のフレームからの差分情報だけを保持するなどしてデータ量削減を行っている。

データ量を抑えようとすればするほどより多くの情報を削るため、
動画のトランスコードの仕方によっては目に見えて映像劣化がわかってしまう。
これらの劣化は、ブロックノイズやモスキートノイズとなって映像に現れる。
動きの早いシーンではフレーム間予測がうまく働かずにデータ量が増えてしまうが、
映像に割り当てられるデータ量には上限があるため、こういったシーンではノイズがより多く発生する可能性がある。
また色の移り変わりの激しい箇所やシーンでも同様にノイズが発生する可能性がある。

今回はffmpeg及びPSNRとSSIMを使いトランスコード前の素材から、トランスコード後の映像がどの程度劣化したかを調べる方法を調査した。
また、トランスコード後の動画のノイズ検出についての調査考察を行った。

## ピークS/N比, PSNR

ピークS/N比はPSNR(Peak singal-to-noise Ratio)とも呼ばれるが、画質評価のための指標である。
元の画像と圧縮後の画像を比較し、どの程度品質が劣化したのかを評価する。

ピークS/N比の前に、単純なS/N比について説明する。
S/N比とは信号(Signal)と雑音(Noise)の比率のことであり、以下の式で表される。P\_s は 元の信号、P\_n はノイズであり、結果の単位はdBで表される。

<center>

![SN Ratio](articles/image/snratio_wiki.png)

図: S/N比 [Wikipedia SN]より引用

</center>

S/N比を用いることで、雑音の影響がどの程度あるのかを評価することができる。
雑音P\_n が限りなく0に近い場合はノイズがほぼないということであり、この場合はS/N比は無限に近づく。
すなわち、**S/N比が大きければ大きいほど、ノイズが少ない**ということである。

次にピークS/N比について説明する。ピークS/N比は以下式で表される。

<center>

![PSNR](articles/image/psnr02.png)

図: ピークS/N比 [Wikipedia PSNR]より引用

</center>

ここでいうMAX\_I は元(入力)の画像の最大画素値である。
8ビットの画像ならば、MAX\_Iは255の値を取ることとなる。
MSEとは平均二乗誤差のことであるが、これは以下のように表現される。

<center>

![PSNR MSE](articles/image/psnr01.png)

図: ピークS/N比 MSE [Wikipedia PSNR]より引用

</center>

I(i,j)は入力画像の1画素(位置はX座標i, Y座標jとする）、K(i,j)は変換後画像の1画素を表す。
話を単純にするために、モノクロ画像の画像を評価することを考える。
I(i,j)は元の画像の1画素の明るさであり、例えば0-255までの値をとることとする。K(i,j)は変換後の1画素をあらわし、これも0-255までとることとする。
I(i,j) から K(i,j) を引くことにより、元の画素との違い（すなわち誤差）がわかる。

次に全体を二乗し1/mn をかけているが、これは平均二乗誤差である。
平均二乗誤差は統計ではデータ全体のばらつきをもとめる際に利用される。
詳しくは統計の書籍を参考にしていただきたいが、ばらつきを求める際、単純にすべての値を足し引きしていくと誤差が正しく検出できない。
例えば、とある値は誤差+10 であり、別の値では誤差-10 と検出された場合、すべてを足し合わせると0となってしまい誤差は無いように見えてしまう。
二乗し平均を取ることで、ばらつきを適切に検出することができる。

これらを踏まえてもう一度PSNRの式をみてみる。
S/N比のS(元の信号)にあたる部分が元の画像の最大画素値、そしてN(雑音)に当たる部分がもとの画像と出力後の画像との差分である。
**雑音が少なければ少ない(すなわち元の画像との差分が少ない）ほど、PSNRは大きな値を取る**こととなる。

[JIMA guideline]によると、PSNR の数値目安は以下のとおりである。

<center class="table">

| PSNR [dB] | 主観評価 |
|:----:|:--------:|
|40 〜 ∞ | 元の画像と圧縮画像の区別がつかない |
|30 〜 40 | 拡大すれば劣化がわかるレベル |
|30以下| 明らかに劣化がわかる |

</center>

### PSNR の利点・欠点

PSNR の計算式をみてわかるが、画像全体のノイズ（画像劣化）を求めて値を算出している。
すなわち、動画や画像が全体的に劣化している場合はPSNRが低い値がでることになる。
**全体的な画質の評価を行う場合、PSNRを用いるのは有効な手段**である。

一方、画像をみて劣化していると感じるのは、全体的なものよりも画像の部分的なノイズかもしれない。
**ブロックノイズやモスキートノイズが部分的に発生している場合は、PSNRではうまく劣化を検出できない**こととなる。


## Structural Similarity, SSIM

PSNRでは、部分的な画像劣化の検出が難しいことがわかった。
この欠点を解決した画質評価の手法が、SSIM (Structural Similarity) である。

SSIMの計算式は以下のとおりであるが、これはPSNRと違い式をみただけでは直感的にはよくわからない。

<center>

![SSIM](articles/image/ssim_algo.png)

図: SSIM [Wikipedia SSIM]より引用

</center>

書いている本人も意味は理解はしていないので、詳しい説明は専門書を参考されたい。

SSIMでは画像全体の誤差を利用するのではなく、元の画像と出力後の画像の局所的な領域の誤差を求めていく。
そしてそれらの平均をとり最終的なSSIM値を求めている。
これにより**部分的にノイズが発生している場合もうまく検出が可能**となる。

SSIMの場合、値は1 〜 0の範囲を取ることとなる。
1が最も高品質（画像劣化のない状態）であり、0が最も低品質である。
[JIMA guideline]によると、SSIMの数値目安は以下のとおりである。

<center class="table">

| SSIM | 主観評価 |
|:----:|:--------:|
|0.98以上 | 元の画像と圧縮画像の区別がつかない |
|0.90 〜 0.98 | 拡大すれば劣化がわかるレベル |
|0.90以下 | 明らかに劣化がわかる |

</center>


## トランスコード後の動画のノイズ検知検証

PSNR, SSIMを用いることで、画像の劣化を評価できることがわかった。
画像の劣化がわかるということは、すなわち動画トランスコード後のブロックノイズやモスキートノイズなども検出できる可能性がある。
ここで、どの程度のノイズが検出できるのか検証を行ってみることとする。

### 検証用オリジナル動画

検証用の動画として、以下形式の動画を用意した。動画は 小林さんちのメイドラゴン [Maidragon] のOP部分を利用する。
このアニメのOPは、俗に言うエンコ殺し動画であり、エンコードには向いていない(ノイズがでやすい）シーンが存在しているため、
今回検証に利用することとした。
なお、一部編集(シーンカットとTC焼き込み)を行ったためオリジナルの素材はProResとしているが、
ProRes変換前はMPEG2であり、MPEG2の時点ですでにノイズが乗っている場合があるがご容赦いただきたい。

- Video: ProRes yuv422p10le progressive, 1280x720, 23.976fps
- Audio: pcm\_s16le 48000 Hz, stereo

オリジナル素材のビットレートは以下のとおりである。

<center>

![Maidragon OP Prores](articles/image/maidragon_original_prores_bitrate.png)

図: 検証用オリジナル素材ビットレート メイドラゴンOP Prores422 1280x720

</center>

各シーンは以下のとおりである。

<center class="table">

| Frame | TC | シーン | 備考 |
|:----:|:----:|:----:|:----:|
|1|00:00:00:00| ![scene0](articles/image/kobayashisan/original_scene/0.png) | スタート。シーンの移り変わりが激しいが大きな動きはなし。407fまで続く|
|407|00:00:16:23| ![scene407](articles/image/kobayashisan/original_scene/407.png) | OPタイトル。動きは少ない |
|578|00:00:24:02| ![scene578](articles/image/kobayashisan/original_scene/578.png) | シーン変化|
|796|00:00:33:04| ![scene1218](articles/image/kobayashisan/original_scene/1218.png) | シーン変化、以後しばらくシーン変化が続く |
|1564|00:01:05:04| ![scene1564](articles/image/kobayashisan/original_scene/1564.png) | エンコ殺しシーンスタート。キャラクタが残像を残しながら激しく動き回る。1729Frameまで続く|
|1729|00:01:12:01| ![scene1729](articles/image/kobayashisan/original_scene/1729.png) | 以降動きが激しいシーンとそうでないシーンがいくつか続きEND |

</center>


### 検証用トランスコード後の動画

画質劣化を確認するための動画を用意する。

- Video: h264 yuv422p 1280x720, 23.976fps
- Audio: aac 48000 Hz, stereo

H264でエンコードを行う場合、通常CRF(Constant Rate Factor)値を調整し画質調整を行うが、
今回は以下4パターンのAVR(平均ビットレート)を指定し、画質の劣化を検証する。

1. ABR 10000k
2. ABR 3000k
3. ABR 1000k
4. ABR 500k

ffmpeg では以下コマンドを利用することで、AVRを指定したエンコードが可能である。

<center>

```
ffmpeg -i Maidragon_OP_Original.mov -b:v 10000k -c:v libx264 enc.mp4
```

</center>

変換後の各フレーム毎のビットレートは以下のとおりである。

<center class="table">

| Pattern | ABR | Bitrate Graph |
|:----:|:----:|:----:|
|1| 10000k | ![10000](articles/image/kobayashisan/bt10000_enc.png) |
|2| 3000| ![3000](articles/image/kobayashisan/bt3000_enc.png) |
|3| 1000| ![1000](articles/image/kobayashisan/bt1000_enc.png) |
|4| 500| ![500](articles/image/kobayashisan/bt500_enc.png) |

</center>


これらの素材に対し、各フレームごとのPSNRとSSIMを求める。

PSNRはffmpegでは以下コマンドで求めることができる。

<center>

```
ffmpeg -i オリジナル動画Path -i 変換後動画Path -filter_complex psnr=psnr.log -an -f null -
```

</center>

SSIMはffmpegでは以下コマンドで求めることができる。

<center>

```
ffmpeg -i オリジナル動画Path -i 変換後動画Path -filter_complex ssim=stats.txt -an -f null -
```

</center>



### PSNR SSIM 検証結果

各ビットレートの動画のPSNRを出力した結果は以下のとおりである。

<center>

![psnr result](articles/image/kobayashisan/psnr_result_maidragon.png)

図: トランスコード後動画 各ビットレートのPSNR出力結果

</center>

PSNR 40dB以上は劣化がわからず、PSNR 30dBより下回った場合は、目に見えて劣化がわかるということである。
よって、Bitrate 1000kとBitrate 500k の動画は品質が低いシーンが存在するということになる。


次に、各ビットレートの動画のSSIMを出力した結果は以下のとおりである。

<center>

![ssim result](articles/image/kobayashisan/SSIM_results_maidragon.png)

図: トランスコード後動画 各ビットレートのSSIM出力結果

</center>

SSIMの場合、0.98以上は元画像と区別がつかず、0.90以下の場合は品質劣化が目に見えてわかるということである。
よって、PSNR同様 Bitrate 1000kとBitrate 500k の動画は品質が低いシーンが存在するということになる。

エンコ殺しのシーンは 65秒から7秒程度続くが、このあたりではPSNR/SSIM値が大きく下がっていることがわかる。
その他シーンでも動きが大きかったりシーンの移り変わりのある箇所ではPSNR/SSIM値が下がっているようにみえる。

ここで、いくつかスコアが良かったシーンと悪かったシーンのサムネイルを比較してみる。
抽出箇所とPSNR, SSIMは以下のとおりである。

<center class="table">

| Frame | TC | 実時間 (sec) | 1000k PSNR [dB] | 500k PSNR [dB] | 1000k SSIM | 500k SSIM | 備考 |
|---|---|---|---|---|---|---|---|---|
| 745 | 00:00:31:01 | 31.0727 | 44.29 | 41.28| 0.989092|0.984172 | スコアが良かったシーン |
| 1680|00:01:10:00|70.070|30.53|26.85|0.814229 |0.708519 | スコアが悪いシーン |
|1931|00:01:20:11|80.538| 33.14|29.88| 0.918353|0.866596 | スコアがそこそこ悪いシーン |

</center>

抽出サムネイルは以下のとおりである。


<center class="table">

| 実時間 | Bitrate | サムネイル |
|---|---|---|---|
| 31.0727 | オリジナル | ![orig31](articles/image/kobayashisan/scene/original_745f_30sec.png) | 
| 31.0727 | 1000k | ![bt1000](articles/image/kobayashisan/scene/bt1000_745f_30sec.png) | 
| 31.0727 | 500k| ![bt500](articles/image/kobayashisan/scene/bt500_745f_30sec.png) | 
| 70.070 | オリジナル | ![orig31](articles/image/kobayashisan/scene/original_1680f_70sec.png) | 
| 70.070 | 1000k | ![bt1000](articles/image/kobayashisan/scene/bt1000_1680f_70sec.png) | 
| 70.070 | 500k| ![bt500](articles/image/kobayashisan/scene/bt500_1680f_70sec.png) | 
| 80.538 | オリジナル | ![orig31](articles/image/kobayashisan/scene/original_1931f_80sec.png) | 
| 80.538 | 1000k | ![bt1000](articles/image/kobayashisan/scene/bt1000_1931f_80sec.png) | 
| 80.538 | 500k| ![bt500](articles/image/kobayashisan/scene/bt500_1931f_80sec.png) | 

</center>


31秒のサムネイルは500kであっても高品質を保っているようにみえる。
色合いが変化しているのとタイムコード部分にノイズがでているが、SSIMは0.98 以上なので良い結果ということであろう。

70秒付近のサムネイルは1000k, 500k ともスコアが悪かったところであるが、500kだと画面全体にブロックノイズが現れている。
このシーンが特にスコアが悪かった箇所であるが、この結果より画像劣化の激しいシーンやノイズの載ったシーンが抽出できたことがわかる。

80秒付近のシーンは1000kはそこそこ良いスコアだが500kの場合は劣化が激しいシーンである。
500kのサムネイルをみると、全体的にモスキートノイズがのっていることがわかる。

### 結果の考察

PSNR/SSIMのスコアが低いということはノイズが激しいということであり、この指標を活用することでトランスコード後の
画面全体にのったノイズ（ブロックノイズやモスキートノイズ等）の検出が可能であることがわかった。

PSNR/SSIMの数値の差から部分的なノイズ検出をできるかと思ったが、今回はうまく検証することができなかった。
PSNRは全体的な画像の劣化を検出でき、SSIMは部分的な映像劣化を検出できるということであったが、
そうであればPSNRが高くSSIMが低ければ部分的なノイズが発生しているということになる。
しかし、今回検証した素材ではPSNRとSSIMとの数値的な差はほとんど見られなかった。

## まとめ

- PSNR/SSIMは画像の品質劣化を検出するための手法である
- PSNRは全体的な画像の劣化を評価でき、SSIMは部分的な劣化も考慮しての評価が可能である
- PSNR/SSIMを活用することでトランスコード後の映像の画像全体の映像品質劣化やノイズが検出できることがわかった
- 今回の検証ではPSNRとSSIMの違いはほとんどみられなかったため、部分的なノイズの検出については検証できなかった

## おわりに

今回PSNR/SSIMを使いノイズ検出の検討を行ったが、検証数が少ないため不十分な箇所もあるかもしれない。
また、部分的に発生したノイズが検出できるかどうかは今回検討できなかった。

今回の手法はあくまでトランスコード前の動画と後の動画を使ったノイズの検出であるため、
元の素材自体にすでにのっているノイズは検出できない。
元素材のみでノイズを検出する方法については、今後調査をおこなっていきたい。
たとえば、ブロックノイズやモスキートノイズがのった画像を機械学習させることでノイズ検出が可能ではないかと考えているが、うまくいくかはやってみないとわからない。

## 参考文献

- [Wikipedia SN] Wikipedia SN比, [https://ja.wikipedia.org/wiki/SN%E6%AF%94](https://ja.wikipedia.org/wiki/SN%E6%AF%94), 2017/08/30 アクセス
- [Wikipedia PSNR] Wikipedia ピーク信号対雑音比, [https://ja.wikipedia.org/wiki/%E3%83%94%E3%83%BC%E3%82%AF%E4%BF%A1%E5%8F%B7%E5%AF%BE%E9%9B%91%E9%9F%B3%E6%AF%94](https://ja.wikipedia.org/wiki/%E3%83%94%E3%83%BC%E3%82%AF%E4%BF%A1%E5%8F%B7%E5%AF%BE%E9%9B%91%E9%9F%B3%E6%AF%94), 2017/08/30 アクセス
- [JIMA guideline] 小箱雅彦, 電子化文書の画像圧縮ガイドライン、[http://www.jiima.or.jp/pdf/5_JIIMA_guideline.pdf](http://www.jiima.or.jp/pdf/5_JIIMA_guideline.pdf), 2017/08/30 アクセス
- [Wikipedia SSIM] Wikipedia Structural similarity, [https://en.wikipedia.org/wiki/Structural_similarity](https://en.wikipedia.org/wiki/Structural_similarity), 2017/08/30 アクセス
- [Maidragon] TVアニメ「小林さんちのメイドラゴン」, [http://maidragon.jp/](http://maidragon.jp/), 2017/08/30 アクセス
