# Engineering Notes

Personal experiments in AI-assisted development, tools, and computing environments. This is an individual engineering notes and build-log site, generated with Astro and deployed to GitHub Pages as Project Pages.

## Local setup

Requires Node.js 22.12 or newer.

```sh
npm install
npm run dev
```

Preview a production build with:

```sh
npm run build
npm run preview
```

## Adding an article

The public editorial summary is in `docs/EDITORIAL_NOTE.md`. Authoritative candidate state, source reports, interview notes, drafts, and reviews remain in a separate private publishing repository and must not be copied here.

After the private article plan and Publication Review have passed, create a Markdown or MDX file under `src/content/posts/`, add the required frontmatter, and preview it locally. The Articles index and article route are generated from the content collection.

Run the public-content scan, rendered preview, and production checks before requesting the single external-publication approval:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-public-content.ps1
npm run check
npm run build
```

## Deployment

Pushes to `main` run `.github/workflows/deploy.yml`. The workflow uses Astro's official GitHub Pages action and deploys to:

`https://iwatebison.github.io/engineering-notes/`

The repository's Pages source must be set to **GitHub Actions** once in GitHub Settings if it is not already enabled.
