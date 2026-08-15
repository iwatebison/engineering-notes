# Engineering Notes public repository instructions

## Site role

This is the public Astro site for personal notes about AI-assisted development, self-built tools, computing environments, and workflows the author has actually tried.

Do not frame the site as a workplace portfolio, researcher profile, institutional project record, or professional-project showcase.

## Editorial source of truth

The authoritative Editorial Policy, Publishing Workflow, candidate state, interviews, drafts, and reviews live in a separate private staging repository.

When working on an article:

1. Consult the private staging manifest and policy first.
2. Do not reconstruct missing private context from the public article or chat history.
3. Transfer only a sanitized article and explicitly approved public assets.
4. Never transfer raw reports, manifests, private paths, interview notes, redaction notes, or internal reviews.
5. After private Publication Review passes, local sanitized article transfer, validation, build, and rendered preview are allowed without a separate gate.
6. Do not stage, commit, push, or deploy the public bundle without the single final external-publication approval.

If the private staging context is unavailable, stop article work rather than bypassing the editorial gates.

## Public boundary

Do not expose credentials, secrets, usernames, email addresses, private filesystem paths, internal URLs or hostnames, private repository details, Conversation IDs, collaborator names, workplace architecture, or unpublished work.

The public-facing summary is in `docs/EDITORIAL_NOTE.md`.

## Development

When starting the Astro development server, use background mode:

```sh
astro dev --background
```

Manage it with `astro dev stop`, `astro dev status`, and `astro dev logs`.

Before requesting publication approval, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-public-content.ps1
npm run check
npm run build
```

Review the exact Git diff, generated routes, Project Pages base-path links, GitHub Actions result, and final public URLs.

Astro documentation: https://docs.astro.build
