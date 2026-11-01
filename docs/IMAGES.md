# アプリで使う画像（Firefly用プロンプト）

のりさんがAdobe Fireflyで作り、アプリに取り込む画像の一覧。
アプリのデザインは「飼育者の台帳」（`DECISIONS.md` 付録1、J）。画像も写真ではなく、生成りの紙に描いた手描きの線画と淡彩にそろえる。
画像が届くまでは、アプリが線で描いた絵で代える。

## 全部に共通する指定

- 種類：アート（Fireflyの設定で「アート」を選ぶ）。
- 作風：生成りの和紙に、細いペンの線画と、薄い水彩の色。余白を多く残す。線は少し揺れていてよい（手で描いた感じ）。
- 色：墨の線、淡い青緑の水、朱赤のめだか。ほかの色は少しだけ。アプリの色（青緑 `#0A6F79`、朱 `#B5402A`、生成り `#F6F3EC`）に合う。
- めだかの体の確認：口が上向き、目が大きい、背びれが尾びれの近く（体の後ろ寄り）にある、体は細長い。金魚やグッピーに見える絵は使わない。
- 入れないもの：文字、ロゴ、透かし、署名、人の手や顔、水槽の飾り、グラデーションの背景、光る効果。
- 書き出し：長辺2400px以上のPNG。背景は生成りのまま（透明にしない）。
- 使う前に確かめること：生成画像をアプリとApp Storeで使えるかを、Adobeの利用条件で確かめる。

プロンプトは英語の方が意図どおりに出やすいので、英語を先に書く。日本語は意味の確認用。
共通の作風の部分（`Style:` 以下）は、全部の画像で同じ文をそのまま使う。

```
Style: delicate hand-drawn ink line illustration with light transparent watercolor washes on off-white washi paper, slightly wobbly pen lines, generous empty space, muted palette of sumi black, pale teal water and vermilion fish, no text, no gradient background
```

---

## 1. ホームの見出し（HomeHero）

- 使う場所：ホームの右上（いまは線で描いた睡蓮鉢を出している場所）。
- 縦横比：1:1
- 構図：真上から見た睡蓮鉢。鉢は画面の中央に、まわりに紙の余白。

```
Top-down view of a round ceramic water lily pot, two small vermilion Japanese rice fish (medaka) and one silver medaka swimming in pale teal water, two floating water lily pads with a notch, a few small ripples. Style: delicate hand-drawn ink line illustration with light transparent watercolor washes on off-white washi paper, slightly wobbly pen lines, generous empty space, muted palette of sumi black, pale teal water and vermilion fish, no text, no gradient background
```

日本語の意味：真上から見た丸い陶器の睡蓮鉢。淡い青緑の水に、朱赤のめだか2匹と銀のめだか1匹。切れ込みのある浮き葉2枚と、小さな波紋。

光：
- 方向：左上からのやわらかい光（鉢の縁の右下にだけ薄い影の色を置く）。
- 質感：やわらかい。影は水彩のにじみで薄く。
- 色と時間帯：朝。やや寒色。
- 効果：水面の白い紙の残し（ハイライト）だけ。光る効果は使わない。

## 2. 案内1（OnboardingIntro）

- 使う場所：初回の案内の1ページ目「めだか台帳へようこそ」。
- 縦横比：4:3

```
A small backyard medaka breeding corner: a wooden rack with several plastic tubs and styrofoam boxes holding green water and floating plants, a watering can beside it, seen from a slight high angle. Style: delicate hand-drawn ink line illustration with light transparent watercolor washes on off-white washi paper, slightly wobbly pen lines, generous empty space, muted palette of sumi black, pale teal water and vermilion fish, no text, no gradient background
```

日本語の意味：裏庭の小さなめだかの飼育場。木の棚にプラスチックの容器と発泡スチロール箱が並び、緑の水と浮き草。横にじょうろ。少し高い位置から。

光：
- 方向：右からの低い朝の光（容器の左側に薄い影）。
- 質感：やわらかい。
- 色と時間帯：日の出のあと。わずかに暖色。
- 効果：なし。

## 3. 案内2・容器（OnboardingTanks）

- 使う場所：案内の2ページ目「容器を登録」。
- 縦横比：4:3

```
Three different medaka containers side by side: a gray plastic tub, a white styrofoam box and a round ceramic water lily pot, each with a small blank paper tag tied to the rim, a few medaka visible in the water. Style: delicate hand-drawn ink line illustration with light transparent watercolor washes on off-white washi paper, slightly wobbly pen lines, generous empty space, muted palette of sumi black, pale teal water and vermilion fish, no text, no gradient background
```

日本語の意味：灰色のプラスチック容器、白い発泡スチロール箱、丸い陶器の睡蓮鉢の3つが並ぶ。それぞれの縁に、何も書いていない紙の名札。水の中にめだかが少し。

光：
- 方向：左上から。
- 質感：やわらかい。
- 色と時間帯：昼前。中立。
- 効果：なし。

注意：名札に文字が出たら使わない。

## 4. 案内3・系統（OnboardingStrain）

- 使う場所：案内の3ページ目「系統を登録」。
- 縦横比：4:3
- 構図：真横から見た3匹を、図鑑の挿絵のように横に並べる。

```
Naturalist field-guide style side views of three ornamental medaka fish arranged in a row: one deep orange-red fish, one silver-white fish with a bluish line along its back, and one white fish with red and black patches, slender bodies with upturned mouths, large eyes and the dorsal fin set far back near the tail. Style: delicate hand-drawn ink line illustration with light transparent watercolor washes on off-white washi paper, slightly wobbly pen lines, generous empty space, muted palette of sumi black, pale teal water and vermilion fish, no text, no gradient background
```

日本語の意味：図鑑の挿絵のように、真横から見た改良めだか3匹を横に並べる。深い朱赤の1匹、背中に青白い線のある銀白の1匹、白地に赤と黒の斑の1匹。細い体、上向きの口、大きな目、尾の近くの背びれ。

光：
- 方向：真上から（背の側を明るく、腹の側に薄い影の色）。
- 質感：やわらかい。
- 色と時間帯：中立。
- 効果：なし。

注意：3匹が楊貴妃、幹之、三色に見えるかを、のりさんの目で確かめる。品種名は画面に出さない。

## 5. Proの画面（PaywallHero）

- 使う場所：Paywallの一番上。
- 縦横比：16:9

```
A quiet wide scene of a row of water lily pots on a wooden bench at dusk, a few medaka near the surface of one pot, a small paper lantern glowing softly. Style: delicate hand-drawn ink line illustration with light transparent watercolor washes on off-white washi paper, slightly wobbly pen lines, generous empty space, muted palette of sumi black, pale teal water and vermilion fish, no text, no gradient background
```

日本語の意味：夕暮れ、木の縁台に睡蓮鉢が並ぶ静かな横長の景色。1つの鉢の水面近くにめだかが数匹。小さな紙の提灯がやわらかく灯る。

光：
- 方向：画面右の提灯からの小さな光。
- 質感：やわらかい。
- 色と時間帯：夕暮れ。暖色の灯りと、青みの影。
- 効果：提灯のまわりに水彩のにじみ。光る効果（グロー）は使わない。

---

## 画像の渡し方

1. Fireflyで作った画像を、上の名前（例：`HomeHero.png`）で保存する。
2. Googleドライブに入れて、私にファイル名を伝える。私がドライブから取り込み、アプリに組み込む。ドライブから取り込めなかったときは、別の方法を相談する。
3. 取り込んだら、CIのスクリーンショットで見え方を確かめて報告する。
