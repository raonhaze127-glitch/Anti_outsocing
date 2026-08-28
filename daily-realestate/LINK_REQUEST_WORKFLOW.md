# Manual article-link carousel workflow

This workflow is for article links supplied directly by the user.

Important: links supplied by the user are treated as confirmed content, not collection candidates.

It is separate from the daily numbered news workflow:

- Daily collection workflow: collect news first, then publish selected article numbers.
- Link request workflow: start from one or more confirmed article URLs and assign publish numbers for the existing carousel builder.

## Files

- `daily-realestate/link-request.json`
- `daily-realestate/prepare-link-request.ps1`
- `.github/workflows/publish-link-request-instagram.yml`

## Safe default

`link-request.json` is committed with:

```json
{
  "enabled": false,
  "publish_to_instagram": false,
  "review_confirmed": false,
  "image_usage_confirmed": false
}
```

With this default, pushing the repository does not build or publish anything.

## Build-only request

Use this when the user wants a draft carousel from article links.

```json
{
  "enabled": true,
  "date": "2026-08-26",
  "articles": [
    {
      "url": "https://example.com/news/article",
      "title": "",
      "source": "",
      "summary": "",
      "category": "",
      "region": ""
    }
  ],
  "publish_to_instagram": false,
  "review_confirmed": false,
  "image_usage_confirmed": false,
  "requested_at": "2026-08-26T21:30:00+09:00",
  "note": "Build draft carousel from manual article link."
}
```

Expected result:

1. The workflow assigns publish numbers starting at `1`.
2. The existing carousel builder creates one carousel set per article.
3. GitHub Pages publishes public JPEG URLs for review.
4. Meta API publishing is skipped.

## Publish request

Use this only after context and image usage have been reviewed.

```json
{
  "enabled": true,
  "date": "2026-08-26",
  "articles": [
    {
      "url": "https://example.com/news/article"
    }
  ],
  "publish_to_instagram": true,
  "review_confirmed": true,
  "image_usage_confirmed": true,
  "requested_at": "2026-08-26T21:30:00+09:00",
  "note": "Publish reviewed manual article link."
}
```

Expected result:

1. The workflow assigns publish numbers to the confirmed links.
2. The carousel is built and validated.
3. Public JPEG URLs are verified.
4. Meta API publishes the carousel to Instagram.
5. Publish result logs are uploaded as a GitHub Actions artifact.

## Editorial rules

- One article equals one carousel set.
- Each carousel must contain 5 to 8 slides.
- Before writing slides, extract the current stage, change from before, affected audience, and next administrative checkpoint from article facts.
- Use the default six-slide order: conclusion cover, why it matters, current stage, numeric comparison, what is not yet confirmed, and next checkpoint.
- Use type-specific ordering: redevelopment/reconstruction = stage/scale/consent/next procedure; subscription = volume/price/schedule/eligibility; transport/SOC = route/time change/current stage/opening variables; supply policy = audience/effective date/numbers/actual supply conditions.
- Covers must lead with a concrete number, benefit, or confirmed stage in no more than two lines. Do not use generic hooks such as `주택공급 뉴스 핵심 체크` or `재건축 속도 붙나`.
- Do not include article source links in captions.
- Captions must place the project or region and core change in the first two lines, use article-specific emojis, and use about five region/project/stage hashtags. Do not use direct engagement prompts.
- Verify the final generated `caption.txt`, not merely the presence of caption code. The title and content sections must contain article-appropriate emojis; a generic bullet-only caption is not publishable.
- For multi-article requests, inspect every generated caption individually and record `number -> article title -> caption first line -> emoji applied` before publishing.
- Do not expose internal review notes in public-facing captions or slides.
- Preserve project/program names that affect meaning, such as `SH`, `LH`, `PF`, `A-2`, `SOC`, `GTX`, and official Korean project names.
- Do not simplify business terms in a misleading way. For example, keep terms such as `sin-tong-gihoeg`, `Moatown`, `public housing district`, or the exact Korean source wording when it affects meaning.
- Use article-contained building exteriors, architectural renderings, terrain maps, location maps, district maps, layout maps, and route maps first without pausing for a separate usage-condition check.
- Do not automatically use photographs containing people or text-dominant images such as notices, tables, posters, document screenshots, or promotional copy.
- Apply the selected article image to only one or two slides; build the remaining slides as original comparison tables, timelines, or process diagrams from article facts.
- After reviewing the draft, replace the article image with a generated image only when the user requests it.
- If article extraction is weak, fill `title`, `summary`, `category`, `region`, and `source` manually before publishing.

## Codex operating notes

When the user supplies an article link and asks for creation or publishing:

1. Read the article and inspect context.
2. Update `link-request.json`.
3. Run `prepare-link-request.ps1` locally.
4. Run the carousel builder locally when practical.
5. Push only after the request is ready.
6. Monitor the GitHub Actions run.
7. If the user asked for publishing, confirm the Instagram upload succeeded.
