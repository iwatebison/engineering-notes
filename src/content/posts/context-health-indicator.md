---
title: "長期化するChatGPT Conversationを管理するContext Health Indicator"
description: "長く続くConversationの状態を、会話を止めずに観測し、必要なときだけhandoffへ導く設計。"
pubDate: 2026-08-15
tags:
  - AI-assisted engineering
  - tooling
  - operations
draft: false
---

## Problem

ChatGPTとのConversationは、最初は軽い相談でも、調査、実装、検証、意思決定を重ねるうちに長くなる。長さそのものが問題なのではない。問題は、いまのConversationが「まだ自然に続けられる」のか、「新しいスレッドへ設計を引き継ぐべき」なのかが見えにくいことだ。

状態が見えないまま会話を続けると、古い前提が残り、重要な決定が埋もれ、引き継ぎ時に同じ説明をやり直すことになる。

## Why long-lived Conversations become difficult

長期Conversationには、少なくとも三つの負荷が積み上がる。

1. **前提の負荷** — 既に決めたこと、保留中のこと、例外条件が増える。
2. **探索の負荷** — 過去のどこに根拠や成果物があるかを探す時間が増える。
3. **引き継ぎの負荷** — 新しいConversationへ移るとき、何を残すべきか判断しにくい。

Context Health Indicatorは、この負荷を「会話を止める警告」ではなく、次の行動を選ぶための小さな観測値にする。

## Design goals

- 会話中に目立ちすぎない
- 状態の根拠を説明できる
- 誤検知しても作業を壊さない
- 全文を外部へ送らず、ローカルで安全に評価できる
- `GREEN`、`YELLOW`、`ARCHIVE RECOMMENDED` の3段階で判断できる
- 必要なときにhandoff用の要約を作れる

最も重要なのは、Indicatorが会話の主役にならないことだ。健康度を表示するために会話を読むのではなく、会話を続ける判断を補助するために表示する。

## Passive Pressure

最初の層は、会話の内容を深く解釈しない **Passive Pressure** である。次のような軽いシグナルを積算する。

| シグナル | 例 | 意味 |
| --- | --- | --- |
| 長さ | メッセージ数、文字数、添付数 | 探索コストの増加 |
| 反復 | 同じ前提の再説明、同じ質問 | 文脈の発見性低下 |
| 分岐 | 話題や成果物の種類の増加 | 引き継ぎ単位の曖昧さ |
| 保留 | 未解決の質問、未検証の案 | 次の作業の不確実性 |

ここでは「危険」と断定しない。圧力が高まっていることだけを示し、利用者がFull Scanを選べるようにする。

## Full Scan

Full Scanでは、Conversationを次の観点で読み直す。

- 現在の目的は一文で言えるか
- 決定済みの事項と仮説が分かれているか
- 実装済みの成果物と未実装の約束が分かれているか
- 次の一手が具体的か
- 新しいConversationへ移すときに失う情報は何か

出力は長い要約ではなく、判断に必要な小さなレポートにする。

```text
Purpose: 何を達成しようとしているか
Decisions: 既に決めたこと
Open issues: 未解決のこと
Artifacts: 参照すべき成果物
Next action: 次に実行する一手
```

## GREEN / YELLOW / ARCHIVE RECOMMENDED

Indicatorの色は、モデルの自信ではなく、運用上の選択肢を表す。

| 状態 | 推奨する行動 |
| --- | --- |
| GREEN | そのまま続ける |
| YELLOW | 重要な決定を短く記録し、次の区切りで再評価する |
| ARCHIVE RECOMMENDED | handoffを作り、新しいConversationを開始する |

`ARCHIVE RECOMMENDED` は強制終了ではない。現在のConversationを保存し、利用者が都合のよいタイミングで切り替えられることが重要だ。

## Conversation Handoff

Handoffは、過去の全文をコピーする機能ではない。次のConversationが迷わず再開できる最小の作業文脈を作る機能である。

```markdown
# Handoff

## Goal
一文の目的

## Decisions
- 決定済みの事項

## Open issues
- 未解決の事項

## Artifacts
- 参照するファイルやURL

## Next action
最初に実行する具体的な作業
```

この形式なら、Handoff自体をMarkdownとして保存し、レビューし、後から修正できる。自動要約をそのまま真実として扱わず、人が確認してから使えることも大切だ。

## Why a Chromium/Vivaldi extension

Indicatorは、会話の横に常に存在する必要はない。ブラウザ拡張なら、現在のタブ、ページ内の会話領域、利用者の明示操作を組み合わせて、必要なときだけ小さなパネルを表示できる。

Chromium系ブラウザを選ぶ理由は、拡張API、開発者ツール、ローカル開発の情報が揃っているからだ。Vivaldiでも同じWebExtensionの基本構造を使える一方、ブラウザ固有の挙動は独立して検証する必要がある。

最初の実装では、会話の検出、圧力の表示、Full Scanの開始、Handoffのコピーに機能を絞る。バックグラウンドで常時収集する設計にはしない。

## Privacy / safety boundary

安全境界は機能より先に決める。

- 会話本文を既定で外部サーバーへ送らない
- 解析対象は利用者が明示的に選択したConversationだけにする
- APIキー、Cookie、認証情報、個人情報をHandoffへ自動記録しない
- ブラウザの全履歴や別サイトの内容を収集しない
- 解析結果は「提案」として表示し、削除や送信を自動実行しない

特に、Conversationの長さを測れることと、Conversationの中身を自由に収集してよいことは別である。この境界をUIとREADMEの両方で説明する。

## Testing

最初のテストは、モデルの精度競争ではなく、誤動作しても安全なことを確認する。

- 短い会話がGREENになる
- 長いだけの会話が即座にARCHIVE扱いされない
- 同じ前提の反復でYELLOWへ近づく
- Full Scanは明示操作なしに開始されない
- Handoffから秘密情報らしい文字列が除外される
- 拡張を無効化すると追加の収集が止まる
- DOM変更でパネルが壊れても会話の入力を妨げない

テスト用Conversationには、本物の認証情報や個人データを使わない。DOMに依存する箇所は、ブラウザの更新で壊れる前提で小さく隔離する。

## Operational lessons

健康度の数字を精密に見せるほど、利用者は数字を真実だと受け取りやすい。最初はしきい値の根拠を説明できる単純なルールから始め、実際の運用で誤検知の種類を集める方がよい。

また、Handoffを作ること自体が目的化すると、作業が止まる。Indicatorは「今すぐ整理しろ」と命令するのではなく、「次の区切りで整理すると楽になる」と知らせる道具であるべきだ。

## Future work

- ルールベース評価の実データ検証
- Handoffテンプレートの利用者編集体験
- Vivaldi固有のタブ・権限挙動の検証
- ローカルLLMを使う場合のオプトイン設計
- Conversation単位のエクスポートと削除
- Indicatorの判断根拠を確認できる診断画面
