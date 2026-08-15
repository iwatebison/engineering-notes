# GitHub Pages Tech Blog Implementation Report

Date: 2026-08-15

## Result

Astroを使った静的技術ブログ `Engineering Notes` を新規構築し、GitHub Pagesへ公開した。

- Repository: https://github.com/iwatebison/engineering-notes
- Pages: https://iwatebison.github.io/engineering-notes/
- Visibility: Public
- Default branch: `main`
- Local source of truth: `C:\work\engineering-notes`
- Verified implementation commit: `005c2c5a557d679024465cdb419179980a114914`
- Successful Actions run: https://github.com/iwatebison/engineering-notes/actions/runs/31868088686

既存の `iwatebison/iwatebison.github.io`、`iwatebison/iwablo`、`iwatebison/note` には変更を加えていない。

## Implemented scope

- Astro 7.2.2による静的サイト生成
- Project Pages向けの `base: /engineering-notes` 設定
- Home、Articles、Aboutの3セクション
- Markdown Content Collectionと動的記事ルート
- 初期記事「長期化するChatGPT Conversationを管理するContext Health Indicator」
- モバイル対応、ダークモード対応、横スクロール可能なコードブロックと表
- GitHub Actionsによるbuild・artifact upload・Pages deployment
- GitHub Pagesのbuild typeを `workflow` に設定
- HTTPS enforcementを有効化
- README、ローカル開発コマンド、記事追加手順

CMS、データベース、アクセス解析、コメント、広告、カスタムドメインは導入していない。

## Environment

- Node.js: 24.19.0
- npm: 11.17.0
- Astro: 7.2.2
- GitHub Pages URL base: `/engineering-notes/`

## Validation

### Local validation

- `npm run check`: 9 files、0 errors、0 warnings、0 hints
- `npm run build`: 成功
- Generated routes: 4 pages
  - `/`
  - `/about/`
  - `/articles/`
  - `/articles/context-health-indicator/`
- ローカル開発サーバーで全4ルートがHTTP 200
- 生成HTML内の内部リンクが `/engineering-notes/` を含むことを確認
- 秘密情報、Windowsユーザーパス、クラウド同期パス、秘密鍵らしい文字列の混入なし
- `git diff --check`: 問題なし

### GitHub validation

- Actions build job: success
- Actions deploy job: success
- Pages build type: `workflow`
- HTTPS enforcement: enabled
- Public home page: HTTP 200
- Public article page: HTTP 200
- Public article title: confirmed

## Deployment correction history

初回workflowはYAMLのインデントにタブが含まれていたため、ジョブ作成前に失敗した。インデントをスペースへ修正して再pushした。

次の実行ではAstro buildは成功したが、GitHub Pagesが未有効だったためdeployが404となった。GitHub Pages REST APIでPagesを作成し、build typeを `workflow` に設定した後、workflowを再実行してbuild・deployともに成功した。

## Publishing workflow

1. `src/content/posts/` にMarkdownまたはMDXを追加する。
2. frontmatterに `title`、`description`、`pubDate`、`tags` を設定する。
3. `npm run check` と `npm run build` を実行する。
4. `main` へcommit・pushする。
5. GitHub Actionsが自動的にGitHub Pagesへdeployする。

## Remaining manual work

公開に必要な作業は残っていない。

任意の改善として、通常のPowerShellでもGitを直接利用したい場合はWindows用Gitをシステムへインストールできる。現在のCodex作業ではCodex同梱Gitを利用しており、リポジトリ運用とPages公開に支障はない。
