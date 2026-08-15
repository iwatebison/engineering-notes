---
title: "CodexでWindows開発する話"
description: "Codexを使い始めてから、C:\\work、Git、build/test、Implementation Report、人間の最終確認をどう分けるようになったか。"
pubDate: 2026-08-16
tags:
  - AI-assisted engineering
  - Windows
  - workflow
draft: false
---

以前は、Windowsで開発しようという発想がほとんどなかった。Windowsは普段使う環境ではあっても、何かを作る場所という感覚があまりなかった。

それがCodexを使い始めてから変わった。やりたいことを伝えると、実装だけでなく、依存関係の導入、build、test、修正まで一続きで進められる。開発環境を一から理解して、全部自分で操作しなければ始められない、という心理的な障壁がかなり下がった。

ただ、始めやすくなったからこそ、作業場所の設計が必要になった。最初はiCloud folderの中をそのまま開発場所にしていたが、source以外にもdependency、build output、log、作業用Markdownなどが思った以上に増え、かなり散らかった。

そこで今は、Windowsでの開発作業を `C:\work\<project>` に寄せている。この記事では、単にdirectoryを一つ作ったという話ではなく、その中でGit、生成物、Implementation Report、自動test、人間による最終確認をどう分けているかをまとめる。

## `C:\work`を「作業してよい場所」にする

現在の基本形は、だいたい次のようになっている。

```text
C:\work\
  <project>\
    .git\
    source and configuration
    dependency metadata
    tests and validation scripts
    generated build/package output
    selected technical documentation
```

大事なのは、`C:\work`という文字列そのものではない。通常のlocal directoryを一つ、projectのcanonical worktreeとして決めることだ。dependencyの導入、実装、lint、typecheck、test、build、packageは、そのworktreeの中で行う。

自分にとっては、「この中だったら多少散らかされてもいい」という境界ができたことが大きかった。AI coding agentはsourceだけを編集するとは限らない。dependency directoryや一時的な生成物、検証用ファイルも増える。置き場所が曖昧だと、それらが普段使うfileと混ざってしまう。

実際、短いlocal pathには道具側の利点もあった。あるprojectでは、特殊なdirectory segmentを含むWindows pathでVitest/Viteのvirtual module解決がうまく動かず、同じrepositoryを短い `C:\work\<project>` へ置くことで検証できた。すべての同期folderに問題があるという話ではないが、少なくとも開発の基準点は、余計なpath条件の少ないlocal worktreeにした方が扱いやすかった。

## Gitの意味が変わった

以前は、Gitを個人で使うものだとはあまり考えておらず、使う習慣もまったくなかった。

Codexで開発するようになると、作業directory全体をまとめてversion管理する必要が出てきた。AIは短時間に複数fileを変更できる。変更が広いほど、「どこが変わったか」「直前の状態へ戻せるか」が重要になる。

今の自分にとってGitは、commandを覚えて操作する対象というより、次の目的を満たす基盤に近い。

- sourceの変更履歴を残す
- commit前にexact diffを確認する
- featureやfixを小さな単位で区切る
- 必要なら以前の状態へ戻す
- generated outputとsourceの変更を区別する

Git操作そのものはCodexがかなり進めてくれる。そのため、自分は細かなcommand手順よりも、「ここでbackupしたい」「この変更だけを残したい」「必要ならrollbackできるようにしたい」という本来のtaskへ集中できる。この変化はかなり助かっている。

もちろん、agentへ無制限に任せるわけではない。repositoryごとのinstructionに、読むべきpolicy、変更してよい範囲、実行するcheck、commitやpushのgateを書く。commit前にはstatusとdiffを確認し、関係のないfileを混ぜない。Gitを背景化できるのは、戻れる境界と確認点があるからだと思う。

## working treeと生成物とReportを分ける

開発中のfileを全部同じ意味で扱うと、何を残すべきか分かりにくくなる。今は大きく三つに分けて考えている。

一つ目は、Gitで履歴を持つsource、configuration、test、scriptである。二つ目は、buildによって作り直せるgenerated outputだ。たとえばbrowser extensionならunpacked extension directoryとrelease archive、static siteなら生成済みsiteとdeployment artifactがある。

三つ目が、後から作業を理解するためのImplementation Reportである。実際に残しているReportには、次のような項目が入る。

- 何を作ったか、どこまで実装したか
- 以前の状態と、設計を変えた理由
- environmentと重要なconfiguration
- 実行したtestとvalidation
- 途中で起きたfailureと修正内容
- 未解決事項とmanual action
- 次に何をすれば再開できるか

以前は、成果物や記録を「残すこと自体の負荷」が大きく、ほとんど残せていなかった。今はReport作成もAIとのworkflowへ組み込めるため、毎回強く意識しなくても記録が残る。

後からどれだけ役立つかは、まだ期待している段階である。ただ、単なる作業日誌より用途は広そうだ。blog記事の種にもできるし、別のAIや別の環境へ作業を引き継ぐcontextにもできる。

## AIにbuildとtestを任せる

project内で何を確認するかは、repositoryのscriptとして固定しておく。browser extension projectでは、たとえば次の一連のcommandを使っている。

```powershell
pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm test:coverage
pnpm build
pnpm package
```

static siteなら、公開前にcontent scan、Astro check、buildを行う。

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-public-content.ps1
npm run check
npm run build
```

こうしたcommandはCodexが実行し、失敗したら原因を調べて修正する。lint、typecheck、synthetic test、coverage、production build、package生成は自動化しやすい。Reportには、成功したcheckだけでなく、途中の失敗も残す。

たとえば、GitHub ActionsのYAMLにtabが混ざってjob作成前に失敗したことや、buildは成功したのにGitHub Pagesが未設定でdeployが404になったことがあった。build成功と公開成功は同じではない。どの段階まで確認できたかを分けて記録しておくと、次に同じ問題が起きたときに追いやすい。

## 最後は自分で触る

自動testで確認できることは多いが、全部ではない。

browser extensionでは、合成fixtureを使ってDOM処理やstorage、migration、clipboard fallbackなどをtestできる。一方、実際にsign-inしたbrowserでの画面遷移、streaming、light/dark theme、pane分割、UI scale、長いConversationのvirtualization、見た目のcollisionなどは、実環境で触らないと分からない部分が残る。

画面遷移が多く、確認すべきUI状態が増える規模なら、最終確認まで自動化した方がよい場面もあると思う。ただ、現在自分が作る程度の規模では、AIにbuildやtestを任せ、最後の動作確認は自分で行う分担がちょうどよい。

ここで見ているのは、単に正しく動くかだけではない。buttonを押したときの反応や、情報の見え方、実際に使ったときの手触りも確認している。最終確認を人間に残すことは、自動化しきれなかった穴埋めというより、使う人として設計を見直す工程になっている。

## 今の流れ

現在のworkflowを単純化すると、次のようになる。

```text
local project worktree
  -> Codexによる実装
  -> lint / typecheck / test / build / package
  -> Git statusとdiffの確認
  -> 必要なbrowser / UIのmanual verification
  -> commit可能なsource history
  -> Implementation Reportと次のaction
```

この形にしてから、Windows上でAI-assisted developmentを扱いやすくなった。`C:\work`が作業範囲を決め、Gitが戻る場所を作り、自動checkが機械的に確認できる部分を受け持ち、自分は最後の実使用感を見る。Reportは、その作業を次へ渡すために残る。

まだ完成したworkflowではない。次に改善したいのはMacとの連携である。WindowsとMacを一つの開発環境として扱い、成果物だけでなく、検討、判断、実装記録まで自然に蓄積できる形にしたい。

それがうまく積み重なれば、最終的には自分の開発活動に特化したsecond brainのようなものになるかもしれない。ただし、それはまだ将来像である。今のところ確実に言えるのは、CodexによってWindowsで作り始められるようになり、その作業を受け止める場所として `C:\work\<project>` が必要になった、というところまでだ。
