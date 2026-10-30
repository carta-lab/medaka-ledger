# アプリで使う画像（Firefly用プロンプト）

のりさんがAdobe Fireflyで作り、アプリに取り込む画像の一覧。
画像が無い間は、アプリが水面を描いて代わりにする（`DECISIONS.md` J）。

## 全部に共通する指定

- 種類：写真（Fireflyの設定で「写真」を選ぶ）。
- 世界観：屋外の飼育場の、朝のやわらかい光。水は澄んだ青緑。アプリの色（青緑 `#0B7A85`、深い青緑 `#0B3C49`）に合う。
- めだかの体の確認：口が上向き、目が大きい、背びれが尾びれの近く（体の後ろ寄り）にある、体は細長い。金魚やグッピーに見える絵は使わない。
- 入れないもの：文字、ロゴ、透かし、人の手や顔、水槽の飾り（城、ブクブク）、ありえない色の魚。
- 書き出し：長辺2400px以上のJPEGかPNG。
- 使う前に確かめること：生成画像をアプリとApp Storeで使えるかを、Adobeの利用条件で確かめる。
- 一言：飼育者は魚をよく見ている。AIの絵で品種の特徴がずれていると、かえって信用を落とす。品種が分かる画像は、いずれ実物の写真に替えるのが望ましい。

プロンプトは英語の方が意図どおりに出やすいので、英語を先に書く。日本語は意味の確認用。

---

## 1. ホームの見出し（HomeHero）

- 使う場所：ホームの一番上。日付と季節の文字を、左下に白で重ねる。
- 縦横比：16:9
- 構図：真上から見た水面。めだかは右上寄りに置き、左下は暗めで何もない余白にする（文字を載せるため）。

```
Top-down view of the water surface of an outdoor ceramic water lily pot, a few small orange-red Japanese rice fish (medaka, Oryzias latipes) swimming near the surface in the upper right, floating water hyacinth leaves at the edge, clear teal-green water, soft dappled morning sunlight filtering through leaves creating gentle caustic light patterns on the water, the lower left area is darker and empty, calm and fresh atmosphere, realistic nature photography, shallow depth of field
```

日本語の意味：屋外の陶器の睡蓮鉢を真上から見た水面。右上に朱赤のめだか数匹。縁にホテイアオイの葉。澄んだ青緑の水。葉越しの朝の木漏れ日が、水面に光の揺らぎを作る。左下は暗く何もない。

光：
- 方向：右上からの斜光（左下を暗く残すため）。
- 質感：木漏れ日のやわらかい光。影は柔らかい。
- 色と時間帯：朝。やや寒色寄り。
- 効果：水面のきらめき（コースティクス）。

## 2. 案内1（OnboardingIntro）

- 使う場所：初回の案内の1ページ目「めだか台帳へようこそ」。
- 縦横比：4:3
- 構図：やや高い位置から、棚に並んだ飼育容器を斜めに見下ろす。

```
Outdoor backyard medaka breeding area, rows of gray plastic storage containers and white styrofoam boxes filled with green water lined up on a wooden rack, some containers with floating water plants, early morning golden sunlight from the side, long soft shadows, a sense of a carefully kept hobby space, realistic photography, no people
```

日本語の意味：屋外の裏庭のめだか飼育場。灰色のプラスチック容器と白い発泡スチロール箱が木の棚に並び、緑の水が入っている。朝の金色の横からの光、長くやわらかい影。人はいない。

光：
- 方向：横からの低い光（容器の並びに影の流れを作る）。
- 質感：やわらかい。長い影。
- 色と時間帯：日の出直後のゴールデンアワー。暖色。
- 効果：空気中の淡い光のかすみ（強くしない）。

## 3. 案内2・容器（OnboardingTanks）

- 使う場所：案内の2ページ目「容器を登録」。
- 縦横比：4:3
- 構図：容器1つを斜め上から。

```
Close-up of a single outdoor plastic tub for raising medaka fish, seen from a high angle, green water with a few small orange medaka fish, a floating water hyacinth, a small handwritten-style blank label tag on the rim without any text, soft morning light, realistic photography
```

日本語の意味：屋外のめだか用の容器1つを斜め上から。緑の水に朱色のめだか数匹、ホテイアオイ。縁に白い名札（文字なし）。朝のやわらかい光。

光：
- 方向：斜め前から。
- 質感：やわらかい。
- 色と時間帯：朝。
- 効果：なし。

注意：名札に文字が出たら使わない（文字は入れない方針）。

## 4. 案内3・系統（OnboardingStrain）

- 使う場所：案内の3ページ目「系統を登録」。
- 縦横比：4:3
- 構図：真横から、水槽越しに3匹が並ぶ。

```
Side view through clear glass of three ornamental Japanese medaka fish swimming in clean water: one deep orange-red fish, one silver-white fish with a glowing bluish line along its back, and one white fish with red and black patches, slender bodies with upturned mouths, large eyes and the dorsal fin set far back near the tail, plain soft teal background, gentle top light, macro photography, high detail
```

日本語の意味：澄んだ水の中、ガラス越しに真横から見た3匹の改良めだか。深い朱赤の1匹、背中に青白く光る線のある銀白の1匹、白地に赤と黒の斑の1匹。細い体、上向きの口、大きな目、尾の近くの背びれ。背景は無地の淡い青緑。

光：
- 方向：真上から（めだかを上から照らす飼育の光に近い）。
- 質感：やわらかい。
- 色と時間帯：中立。
- 効果：背景だけ軽くぼかす。

注意：3匹のそれぞれが楊貴妃、幹之、三色に見えるかを、のりさんの目で確かめる。品種名は画面に出さない（絵が特徴を外していても、品種を名乗らない）。

## 5. Proの画面（PaywallHero）

- 使う場所：Paywallの一番上。
- 縦横比：16:9

```
Low angle view just below the water surface of a school of small orange medaka fish swimming toward the light, warm late afternoon sunlight shining through the water, soft bokeh light particles, serene and rich atmosphere, realistic underwater photography
```

日本語の意味：水面のすぐ下から見上げた、光に向かって泳ぐ朱色のめだかの群れ。夕方の暖かい光が水を通り、玉ボケの光の粒。

光：
- 方向：逆光（水面の上から）。
- 質感：やわらかい。
- 色と時間帯：夕方。暖色。
- 効果：玉ボケ、光の粒。

---

## 画像の渡し方

1. Fireflyで作った画像を、上の名前（例：`HomeHero.jpg`）で保存する。
2. Googleドライブに入れて、私にファイル名を伝える。私がドライブから取り込み、アプリに組み込む。ドライブから取り込めなかったときは、別の方法を相談する。
3. 取り込んだら、CIのスクリーンショットで見え方を確かめて報告する。
