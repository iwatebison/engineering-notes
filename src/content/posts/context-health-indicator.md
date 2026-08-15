---
title: "VivaldiをChatGPT専用ブラウザにした話"
description: "Context Health IndicatorのPassive Pressure、Full Scan、CSS整形を実装し、VivaldiをChatGPT専用環境として使ってきた記録。"
pubDate: 2026-08-15
tags:
  - AI-assisted engineering
  - tooling
  - operations
draft: false
---

ChatGPTとのConversationは、少し相談するだけのつもりでも、調査や実装、検証、意思決定を重ねるうちに長くなっていく。

長いこと自体が悪いわけではない。ただ、「このConversationはまだ自然に続けられるのか」「そろそろ新しいConversationへ移った方がいいのか」が分かりにくい。そこで、その判断を補助するために作ったのがContext Health Indicatorだった。

実際に使ってみると、これはConversationの状態を表示するだけの機能ではなかった。CSSによる表示の整形も加わり、最終的には「VivaldiをChatGPT専用ブラウザとして使うための、自分用の拡張機能」と考えるのが一番しっくりくるようになった。

この記事では、その使い心地だけでなく、実際にどんな構成で、何を測り、どこまでを自動化しないことにしたのかも残しておく。

## なぜブラウザ版ChatGPTとVivaldiなのか

コーディングエージェントなどでは、コンテキストの自動圧縮のような仕組みがすでに使われている。一方で、ブラウザ版ChatGPTには、ブラウザ側の機能をそのまま利用できる利点がある。

自分の場合は、Vivaldiのペイン分割やCSSによる表示調整がその理由だった。複数の情報を並べて見たり、ChatGPTの画面を自分が使いやすい形に整えたりできる。この環境を手放して別の仕組みに全面的に移るのではなく、足りない部分を自分で補うことにした。

VivaldiはChromium系なので、拡張機能はManifest V3のWebExtensionとして作れる。今回の実装はTypeScriptで書き、Viteでbuildする構成にした。

## 実装の全体像

拡張機能は、大きく分けると次の構成になっている。

| Component | 役割 |
| --- | --- |
| Content script | Conversationの検出、Passive計測、Full Scan、Indicator表示を担当する |
| Background service worker | 開いているChatGPT tabの状態と、保存済みの集計結果を管理する |
| Shadow DOM indicator | `GREEN`、`YELLOW`、`ARCHIVE RECOMMENDED`と詳細panelを表示する |
| Popup | 複数windowを含むChatGPT tabの状態を一覧する |
| Options page | 閾値、表示位置、診断、Readabilityなどの設定を変更する |
| Local storage | 設定、Conversation識別子、title、時刻、集計値だけを保存する |

Manifestの権限は`storage`と`tabs`に絞り、host permissionも対応するChatGPTのoriginだけにしている。Content scriptは`document_idle`で読み込まれ、通常時はConversation本文を読むのではなく、まずscroll geometryだけを観測する。

UIはページ側のCSSに引きずられにくいよう、Shadow DOM内に配置した。ChatGPTのDOMへ依存する部分、Pressureの計算、保存、UI、CSS整形、移行操作を分けておくことで、どこかが壊れたときの影響範囲を小さくしている。

## 長いConversationを終えるのは意外と難しい

Conversationが長くなると、いくつかの負荷が積み重なる。

- 以前に決めた前提や例外が増える
- 根拠や成果物が過去のどこにあるのか探しにくくなる
- 新しいConversationへ何を引き継ぐべきか判断しにくくなる

それでも、今のConversationが動いているうちは、そのまま続けてしまう。自分から新しいChatを作り、必要な情報を整理して移行する作業には、思っていた以上に心理的な障壁があった。

そこでIndicatorは、「もうこのConversationを終了すべきだ」と決めるものではなく、切り替えを考えるための小さな観測値にした。

## Passive PressureとFull Scanを分けた

常にConversation本文を走査するのは重いし、そこまでの情報が毎回必要なわけでもない。そのため、通常時のPassive Pressureと、必要なときだけ実行するFull Scanを分けた。

### Passive Pressure

Passive Pressureが見るのは、scroll height、表示領域の高さ、equivalent screens、scrollbarのthumb ratio、viewport sizeなどのgeometryである。通常観測ではConversation本文を抽出しない。

スコアは、画面数、Conversationの経過日数、過去のFull Scan結果を組み合わせて作る。現在の主要なdefault設定は次のようになっている。

```ts
{
  greenMax: 54,
  yellowMax: 74,
  passiveScreensAtMax: 120,
  passiveScreenWeight: 70,
  passiveAgeWeight: 15,
  passiveHistoryWeight: 15,
  autoFullScanEnabled: false,
}
```

画面数はそのまま直線的に加算せず、対数比へ変換する。Conversationが少し伸びるたびに急激にスコアが変わらないようにするためだ。

VivaldiのTab Tilingでpane幅を変えると、折り返しが増えてscroll heightも変わる。resizeだけで状態が急変しないよう、resize-onlyの計測では直前のnormalized equivalent screensを保持するようにした。

### Full Scan

Full Scanは、詳細panelから明示的に開始する。ChatGPTの長いConversationは、画面外のturnがDOMから外れるvirtualized表示になるため、いま表示されているmessage数だけを数えても全体は分からない。

そこでFull Scanでは、次の順序でConversationを走査する。

1. 現在位置の「下端からの距離」を保存する
2. 上端へ移動し、lazy loadingでscroll領域が増えなくなるまで待つ
3. viewportの約80%ずつ下へ進みながら、表示されたturnを累積する
4. 下端も安定したことを確認する
5. 最初に保存した読書位置へ戻す

走査中にrouteが変わった場合や、scroll containerが失われた場合は中止する。上方向200回、下方向2000回、全体2分という上限も設けている。

## 変わり続けるDOMを一か所へ閉じ込める

ChatGPTのDOMは、拡張機能向けに公開された安定APIではない。そのため、selectorをあちこちへ直接書かず、DOM adapterへ集約した。

候補は次の順序で探す。

1. messageのauthor roleを示すsemantic attribute
2. Conversation turnを示すtest identifier
3. main領域内のarticle。ただしroleを推定できる場合だけ採用

messageを集計するときは要素をcloneし、button、navigation、copy／feedback control、非表示要素を取り除く。codeは通常文と分離し、同じ文字列へ係数を二重に適用しないようにした。

各turnには、可能ならturn indexを安定keyとして使う。同じturnがvirtualizationによってunmount、remountされても、そのkeyで上書きできる。Accumulatorが保持するのはrole、文字数、token推定用component、turn indexであり、message本文そのものではない。

## 100%を求めず、90%を実用上の境界にした

実装途中では、上下端まで走査できても一部のturnがDOMから取得できず、Full Scanが常にPartialになるケースがあった。そこで「missing turnが一つでもあれば失敗」ではなく、観測できた一意turn数を期待されるturn範囲で割るcoverageを導入した。

境界テストは次のようにしている。

| 観測結果 | 判定 |
| --- | --- |
| 239 / 244 turns = 97.95% | warningを残してCompleteとして採用 |
| 90 / 100 turns = 90% | Completeとして採用 |
| 89 / 100 turns = 89% | Partialのまま。Final Pressureへ採用しない |

ただし、coverageだけで成功を決めてはいない。上端と下端の到達・安定、selectorの検出、candidate capやmessage length capへ到達していないことも必要になる。

たとえcoverageが100%でも、route変更で中断した、selectorが壊れた、といった重大な失敗があれば採用しない。Partialで得たPressureは「観測済み範囲の下限」として診断に残すだけで、Full Scan PressureやFinal Pressureを置き換えない。

100%を取り切るためにDOM走査をどこまでも複雑にするより、観測品質と中断理由を表示し、実用上信頼できる境界をテストする方を選んだ。

## Pressureは正確なcontext残量ではない

Full Scanでは、CJK、通常のASCII、code内ASCII、記号、message overheadを別々に数え、次の近似でtokenを推定している。

```text
CJK + 通常ASCII / 4 + code ASCII / 3.2 + 記号 × 0.5 + message数 × 4
```

そのtoken推定値、message数、Conversationの経過日数を、それぞれ段階的なanchor間で補間してPressureにする。defaultでは54以下がGREEN、55〜74がYELLOW、75以上がARCHIVE RECOMMENDEDになる。

ここで重要なのは、この値が正確なcontext window残量ではないことだ。system prompt、tool、添付、画像、モデル内部の状態は測っていない。scroll heightをtoken数へ直接変換しているわけでもない。

Indicatorが示しているのは、あくまでConversationを運用するうえでの圧力である。

## YELLOWは「まあ、たぶんちょうどいいんかな？」

実際に使ってみた感覚として、YELLOWになるタイミングは「まあ、たぶんちょうどいいんかな？」くらいだった。

少し曖昧な評価ではある。ただ、使ってみて重要だったのは、しきい値が完璧かどうかではなかった。Indicatorが見えることで、「このConversationはかなりコンテキストが増えてきたな」と意識するようになったことの方が大きい。

すでにコンテキストが十分に蓄積されていた古いChatについては、Indicatorをきっかけに、新しいConversationへ移す作業を一定のルーチンとして進められた。自分の判断だけでは先送りしがちだった移行に、始めるきっかけができたのはよかった。

## 会話本文を読むことと、保存することを分ける

通常のPassive計測はgeometryだけを見る。一方、Full Scanではtoken componentを作るために、表示されたConversation本文をcontent scriptの一時memoryで読む。

ただし、その本文をstorageやservice workerへ渡すことはしない。captureごとに文字数やtoken componentへ変換し、Accumulatorには数値だけを残す。diagnostic JSONにも、coverage、turn範囲、message数、推定token、文字数、走査時間などの集計値しか出さない。

保存対象は、設定、URLから得たConversation識別子、長さを制限したtitle、時刻、集計値、診断結果である。使われなくなったsummaryは90日で削除する。

「本文を読み取れる」と「本文を保存・送信してよい」は別の話なので、その境界は実装とtestの両方に置いた。

## CSS整形は独立したcontrollerにした

Context Health Indicatorに加えて、後からCSS整形機能も追加した。これは良いアイデアだったと思う。

Readability layerは、一つの`style`要素を追加・削除する小さなcontrollerに分けた。ONを繰り返してもstyleが増殖せず、OFFにすればChatGPT標準へ戻る。

scopeにはbuildごとに変わりやすい生成classではなく、assistant messageを示すsemantic attributeを使っている。paragraph、heading、strong、inline code、blockquote、list、table borderの読みやすさを調整する一方、tableの幅やoverflowはChatGPT側へ任せ、標準code blockへ余計な外枠やshadowを足さない。

最初はConversationの状態を見るための機能として始まったが、CSS整形も含めて考えると、個別の小さな機能を寄せ集めたというより、ChatGPTをVivaldi上で使いやすくするための統合的な拡張機能と捉えられる。

「VivaldiをChatGPT専用ブラウザにする」という目的にまとめると、何のための拡張なのかがシンプルになった。

## Handoffは明示操作の中に閉じ込める

YELLOWでは任意の準備として、ARCHIVE RECOMMENDEDではより強い案内として、Handoff準備のactionを表示する。

このactionも、拡張機能がConversation本文を自動exportするものではない。利用者がbuttonを押したときだけ現在のConversation titleを取得し、固定templateからHandoff準備用promptを作ってclipboardへコピーする。

titleは現在のConversationに対応するnavigation linkを優先し、見つからなければdocument title、最後は取得不能を示す固定値へfallbackする。clipboardへの書き込みが拒否された場合は、同じpromptをread-only textareaへ表示して手動copyできるようにした。

Open New Chatも、固定されたChatGPTのroot URLを`noopener,noreferrer`付きの新しいtabで開くだけである。composerへの自動paste、送信、現在のChatの切り替え、filesystem操作、外部agentの起動は行わない。

## コンテキストを意識したら、別の不便も見えてきた

Indicatorを使うようになってから、長いCodex向けpromptをそのままChat本文へ出す必要はないのでは、と考えるようになった。

Codexへ渡すpromptは、人間が毎回全文を精査するようなものではない。場合によっては、人間に読みやすい形式である必要すらない。そこで長いpromptをMarkdownファイルへ分離し、Chat本文そのものが必要以上に長くならないようにした。

ただし、ファイルへ分ければすべて解決するわけでもなかった。copy＆pasteがしにくくなり、Codexへ渡す作業に手間が生じた。

現在は、その不便をGitHubを介した共有コンテキストの設計へ変えることで、より柔軟にしようとしている。Indicatorが直接この問題を解決したわけではない。コンテキストの肥大を意識したことで別の運用を試し、そこで新しい不便が見つかり、次の設計変更につながったという流れである。

## Buildとtest

開発にはNode.js 22以上とpnpmを使う。依存関係の導入からpackage作成までの基本手順は次のとおり。

```powershell
pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm test:coverage
pnpm build
pnpm package
```

Viteはcontent script、service worker、popup、options pageを固定名でbuildする。Content scriptだけIIFE、その他はES moduleで、source mapはreleaseへ含めない。package scriptはbuild済みファイルとversion情報をZIPへまとめる。

v0.3.7では20 test files、97 testsが通過した。設定されたcritical moduleではstatement／line 99.39%、branch 93.48%、function 100%だった。

testには短い／長いConversation、PassiveとFull Scan、storage migration、SPA navigation、streaming、複数tab、selector fallback、Readability ON/OFF、table geometry、clipboard fallback、title取得などが含まれる。実Conversationはfixtureへ保存せず、合成HTMLだけを使っている。

### 最小の再現手順

1. lockfileどおりに依存関係を導入する
2. `pnpm build`でunpacked extensionを生成する
3. Vivaldiのextensions画面でDeveloper modeを有効にし、生成directoryを`Load unpacked`する
4. ChatGPTの既存tabを再読み込みする
5. 短いConversationでGREENを確認する
6. 長い非機密Conversationで明示的にFull Scanを実行する
7. storageとdiagnostic exportに集計値だけが入っていることを確認する

## 自動testで全部が分かるわけではない

自動testが通っていても、ChatGPTのDOMが将来変わらない保証にはならない。実際のsigned-in Vivaldiでのlong Conversation、light／dark theme、複数pane、UI scale、実virtualizationなどは手動確認項目として残っている。

合成ChatGPT pageを使うVivaldi起動testも試したが、browser launchでtimeoutし、成功扱いにはしていない。自動化できなかった確認を、通ったことにしないのも重要だと思う。

## 今はミニマルでいい

現時点の機能はミニマルだが、それでよいと感じている。Vivaldi自体にもカスタマイズの余地が多く、Vivaldiと自作拡張機能を組み合わせた現在の構成が、自分にとっては今のところベストだ。

今後追加する機能を、現時点で細かく決めているわけではない。実際に使い続けていれば、その中で新しいアイデアや必要性が出てくるだろう。そのときに、現在のシンプルな目的を崩さない範囲で少しずつ足していけばよいと思っている。

数か月前なら、自分でブラウザ拡張を作ろうとは思いもしなかった。その意味では、今回の経験にはちょっとしたパラダイムシフトを感じている。

完成形を先に決めて大きなツールを作るのではなく、自分の使い方を観察し、小さな違和感を機能にする。そして実際に使い、次の変更が必要になったらまた手を入れる。Vivaldi上のChatGPT専用環境は、そういう形で育てていくのが合っていそうだ。
