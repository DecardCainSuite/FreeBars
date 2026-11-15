# Free Bars

Action bars: any number of buttons, rows, size, spacing, growth, mouseover fade, and arc-of-a-circle layouts. /fb

Part of the **Free** addon suite for WoW Forever, by DecardCain.

## Releasing

1. Bump `## Version` in `FreeBars.toc` and commit.
2. Push a tag with the same version: `git tag v<version> && git push --tags`.
3. GitHub Actions packages the addon with the BigWigs packager and uploads it to CurseForge (secret `CF_API_KEY`) and to the GitHub releases.
