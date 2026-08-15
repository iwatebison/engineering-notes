# Engineering Notes

Technical notes on resilient systems, AI-assisted engineering, and practical experiments. The site is a static Astro project deployed to GitHub Pages as Project Pages.

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

Create a Markdown or MDX file under `src/content/posts/`, add the required frontmatter, preview locally, and commit the change. The Articles index and article route are generated from the content collection.

## Deployment

Pushes to `main` run `.github/workflows/deploy.yml`. The workflow uses Astro's official GitHub Pages action and deploys to:

`https://iwatebison.github.io/engineering-notes/`

The repository's Pages source must be set to **GitHub Actions** once in GitHub Settings if it is not already enabled.
