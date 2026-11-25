# Releasing

GitHub Actions builds and uploads releases with [BigWigsMods/packager](https://github.com/BigWigsMods/packager). The workflow is `.github/workflows/release.yml`, and the packaging settings are in `.pkgmeta`.

- **Every push and pull request** runs the syntax checks and the test harness.
- **Pushing a tag** also packages the `PotionMixer` folder into a zip, versioned from the tag, with a changelog of the commits since the previous tag. That release step runs only after the tests pass.
- **Where it goes:** the zip is uploaded to GitHub Releases, CurseForge and Wago. WoWInterface has no WoW Forever category, so the packager can't upload there.
- **Game version:** the packager reads interface 16001 from the `.toc` and files each release under WoW Forever (game version 1.60.1).
- **What's in the zip:** the addon files, `LICENSE` and the generated `CHANGELOG.md`. `.pkgmeta` leaves out the README, `docs`, `tests` and `logos`.

## Setup

This is already done for Potion Mixer, and is listed here for reference:

1. The project IDs are in `PotionMixer/PotionMixer.toc`, as `## X-Curse-Project-ID: 1830713` and `## X-Wago-ID: kNMPl3Gz`. CurseForge shows the ID in the "About Project" box, and Wago on its developer dashboard.
2. Each site's API token is a repository secret, under Settings → Secrets and variables → Actions → Repository secrets: `CF_API_TOKEN` (CurseForge) and `WAGO_API_TOKEN` (Wago). GitHub's own token is provided automatically.

A site without its project ID or token is skipped without an error, and the run still finishes green. Check the start of the "Package and upload" log: each site that will get the upload ends in `[token set]`.

```
CurseForge ID: 1830713 [token set]
Wago ID: kNMPl3Gz [token set]
GitHub: zerfall/wow-potionmixer [token set]
```

## Releasing a version

Tag the commit and push the tag:

```sh
git tag -a 1.0.1 -m "Potion Mixer 1.0.1"
git push origin 1.0.1
```

A tag containing `beta` or `alpha`, such as `1.1.0-beta1`, is uploaded as a beta or alpha release.

If creating the GitHub release fails with "Resource not accessible by integration", allow read and write permissions for workflows under Settings → Actions → General.

The `.toc` says `## Version: @project-version@`, and the packager replaces that with the tag.
