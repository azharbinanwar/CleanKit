# Code signing without a paid Apple account

How CleanKit releases are signed with a free self-signed certificate, and how to
set up the same thing for any other macOS app.

## Why

macOS remembers permissions such as Full Disk Access by the app's signature.

- **Ad-hoc signed** (`CODE_SIGN_IDENTITY = "-"`): the signature is a fingerprint
  of that exact build. Every update looks like a new app, so users must grant
  permissions again after each update.
- **Signed with your own certificate**: macOS sees the same signer every time,
  so permissions survive updates.

What it does not do: remove the "can't verify developer" warning on first
install. Only a paid Developer ID certificate with notarization does that.

One certificate can sign all your apps. Each app keeps its own permissions,
because macOS also checks the bundle ID. Give it a general name (for example
`KodeElite Self-Signed`) if you plan to share it.

## 1. Create the certificate (once)

```sh
NAME="KodeElite Self-Signed"
D=~/.kodeelite-signing
mkdir -m 700 "$D" && cd "$D"

openssl req -x509 -newkey rsa:2048 -nodes -days 10950 \
  -keyout key.pem -out cert.pem -subj "/CN=$NAME" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"

openssl rand -base64 24 | tr -d '\n' > password.txt
openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -name "$NAME" \
  -passout file:password.txt -out signing.p12
chmod 600 *
```

- `-legacy` matters: macOS `security import` can't read OpenSSL 3's default
  `.p12` encryption ("MAC verification failed").
- `10950` days is 30 years. If a certificate expires you need a new one, and
  users re-grant permissions once.
- Never put this folder inside a git repository.

## 2. Back it up

GitHub secrets are write-only: you can't download them again, so they are not
a backup.

Make an encrypted disk image. This shows the password while you type it, so
you can check it, and keeps it out of shell history:

```sh
read -r "p?Type backup password (visible): " && printf '%s' "$p" | \
  hdiutil create -encryption AES-256 -stdinpass -srcfolder ~/.kodeelite-signing \
  -volname Signing ~/Desktop/signing-backup.dmg; unset p
```

1. Double-click the `.dmg` and enter the password to confirm it opens.
2. Save that password in a password manager (e.g. Google Password Manager).
3. Upload the `.dmg` to cloud storage (e.g. Google Drive), then delete it from
   the Desktop.

Never upload the folder unencrypted, and avoid `zip -e` (weak encryption). A
zip from Keka or 7-Zip with AES-256 is fine.

To restore: open the `.dmg` with the password and copy the folder back to
`~/.kodeelite-signing`.

## 3. Add the GitHub secrets (per repository)

```sh
REPO=owner/app
base64 -i ~/.kodeelite-signing/signing.p12 | gh secret set SIGNING_P12_BASE64 -R "$REPO"
gh secret set SIGNING_P12_PASSWORD -R "$REPO" < ~/.kodeelite-signing/password.txt
gh secret list -R "$REPO"
```

Secrets are not passed to workflows triggered by pull requests from forks, so
contributors can't read the key.

## 4. Sign in the release workflow

Load the certificate into a temporary keychain before building
(see `.github/workflows/release.yml`):

```yaml
- name: Signing certificate
  env:
    P12: ${{ secrets.SIGNING_P12_BASE64 }}
    P12_PASSWORD: ${{ secrets.SIGNING_P12_PASSWORD }}
  run: |
    [ -n "$P12" ] || { echo "::error::SIGNING_P12_BASE64 secret is missing"; exit 1; }
    kc="$RUNNER_TEMP/signing.keychain-db"
    security create-keychain -p ci "$kc"
    security set-keychain-settings -lut 3600 "$kc"
    security unlock-keychain -p ci "$kc"
    echo "$P12" | base64 --decode > "$RUNNER_TEMP/signing.p12"
    security import "$RUNNER_TEMP/signing.p12" -k "$kc" -P "$P12_PASSWORD" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k ci "$kc"
    rm "$RUNNER_TEMP/signing.p12"
    echo "SIGN_KEYCHAIN=$kc" >> "$GITHUB_ENV"
    echo "SIGN_IDENTITY=KodeElite Self-Signed" >> "$GITHUB_ENV"
```

Then sign the built app before packaging it (see `scripts/build-dmg.sh`):

```sh
codesign --force --sign "$SIGN_IDENTITY" ${SIGN_KEYCHAIN:+--keychain "$SIGN_KEYCHAIN"} "$APP"
codesign --verify --strict "$APP"
```

`SIGN_IDENTITY` must match the certificate's name (`/CN=` in step 1).

## 5. Check a signed app

```sh
codesign -dr - MyApp.app
```

Signed correctly:

```
designated => identifier "com.example.app" and certificate leaf = H"…"
```

Still ad-hoc (permissions will reset):

```
designated => cdhash H"…"
```

## Good to know

- **First update after switching:** users re-grant permissions once, then it sticks.
- **Lost key:** make a new certificate. Users re-grant once more.
- **Leaked key:** anyone holding it can sign an app macOS treats as yours. Make a
  new certificate, replace the GitHub secrets, and release an update.
- **Local debug builds** stay ad-hoc and lose permissions on each rebuild. To fix
  that, import `signing.p12` into your login keychain and sign debug builds with
  it, from a local, uncommitted build setting so contributors aren't affected.
