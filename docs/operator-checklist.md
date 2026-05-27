# Mural release operator checklist

Everything you need to do **once** before pushing the first notarised release
tag. Subsequent releases are: bump `CFBundleShortVersionString`, push a `v*`
tag, watch CI.

## Apple Developer Program

1. Active Apple Developer Program membership ($99/year).
2. In Apple's portal, create a **Developer ID Application** certificate. Download
   the resulting `.cer` and let macOS install it into your login keychain. Verify
   the matching private key landed alongside it: open Keychain Access → My
   Certificates → look for `Developer ID Application: Your Name (TEAMID)`. Both
   the certificate AND a private key should be present.
3. Export the certificate + private key as a `.p12` (right-click → Export →
   choose Personal Information Exchange (.p12), set a strong password).
4. Base64-encode the `.p12` for CI:

   ```bash
   base64 -i path/to/DeveloperID.p12 | pbcopy
   ```

5. Create an **app-specific password** at appleid.apple.com → Security →
   App-Specific Passwords. Label it "Mural notarytool". This is what
   `notarytool` will authenticate with — NOT your iCloud password.

## GitHub secrets

In `Settings → Secrets and variables → Actions`, add these repository secrets:

| Secret | Value | Source |
|---|---|---|
| `DEVELOPER_ID_CERT_BASE64` | The base64-encoded `.p12` from step 4 above | local |
| `DEVELOPER_ID_CERT_PASSWORD` | The `.p12` export password from step 3 | local |
| `DEVELOPER_ID_NAME` | The certificate's identity string, e.g. `Developer ID Application: Your Name (TEAMID)` | Keychain Access |
| `APPLE_ID` | Your Apple ID email (developer account login) | local |
| `APPLE_TEAM_ID` | 10-character team ID (e.g. `A1B2C3D4E5`) | developer.apple.com → Membership |
| `APPLE_APP_PASSWORD` | App-specific password from step 5 | appleid.apple.com |
| `SPARKLE_ED_PRIVATE_KEY` | Base64 EdDSA private key (see "Sparkle keys" below) | local |

## Sparkle keys

Sparkle 2 signs every appcast entry with EdDSA. Generate the key pair **once**:

```bash
# After at least one `xcodebuild -scheme Mural ...` so SPM materialises Sparkle:
GEN_KEYS=$(find ~/Library/Developer/Xcode/DerivedData -name generate_keys -type f | head -1)
"$GEN_KEYS"
# Output:
#   public key: <base64-public>
#   private key: <base64-private>
```

- **Public key** → paste into `project.yml` under `Mural.info.properties.SUPublicEDKey`. Commit that.
- **Private key** → GitHub secret `SPARKLE_ED_PRIVATE_KEY`. NEVER commit. NEVER share. If leaked, attackers can ship arbitrary updates to every Mural user.

Treat the private key like an SSH key. If it leaks:
1. Generate a new pair.
2. Bump `SUPublicEDKey` in `project.yml`.
3. Ship a new release. Older versions can no longer accept new updates and must be re-installed manually.

## GitHub Pages (appcast hosting)

The Sparkle `SUFeedURL` in `project.yml` defaults to
`https://ayush-that.github.io/wallpaper-app/appcast.xml`. To make that live:

1. `Settings → Pages → Source → Deploy from a branch`.
2. Branch: `gh-pages` (will be auto-created by the release workflow on first
   tag push) / `/ (root)`.
3. Save. The first release push will populate the branch.

If you fork the repo or rename it, update `SUFeedURL` in `project.yml` to
match the new GH Pages URL.

## Sentry crash reporting (optional)

Defer until v1.1. If you want crash telemetry: create a Sentry project, copy
the DSN to a new `SENTRY_DSN` GitHub secret, and inject it into Info.plist via
an xcconfig substitution. (Not yet wired — leave alone for v1.0.)

## Cutting a release

Once all secrets are set + Pages is enabled:

```bash
# Bump version in project.yml (CFBundleShortVersionString)
# Commit + push to main, wait for CI to be green
git tag v1.0.0
git push origin v1.0.0
```

CI does everything: signs, notarises, builds the DMG, signs + staples the DMG,
generates the appcast, publishes to GitHub Releases, syncs the appcast to GH
Pages.

Watch the Actions tab. Notarisation alone takes 5–15 minutes; the full pipeline
takes 20–30 minutes end-to-end.

## Quick health checks

After a release lands:

```bash
# Download the DMG from the GitHub Release page, then:
xcrun stapler validate Mural-1.0.0.dmg
spctl --assess --type install --verbose=4 Mural-1.0.0.dmg
# Both should report "accepted" with "Notarized Developer ID".
```

```bash
# Fetch the live appcast:
curl -s https://ayush-that.github.io/wallpaper-app/appcast.xml | xmllint --format -
# Should print a valid RSS-style XML with one <item> per release + EdDSA sigs.
```

## Cdhash + TCC

With Developer ID signing, the binary's cdhash is **stable across rebuilds**
(it's a hash of the signed content, not the build hash). That kills the
TCC re-prompt loop we hit in Debug builds — users grant permission once and
it sticks across updates.

Until that day comes, Debug builds keep the audio/fullscreen-watcher opt-ins
dormant by default.
