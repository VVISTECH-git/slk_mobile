# iOS code signing (Codemagic)

The `ios-workflow` in `codemagic.yaml` signs the IPA using the **VVIS Codemagic**
App Store Connect API key and **one persistent iOS Distribution certificate**
that is reused across builds.

## Why persistent (not per-build)

Apple caps you at **2 distribution certificates**. An earlier setup created a
fresh certificate on every build (`openssl genrsa` + `certificates create`),
which eventually failed with:

> 409: You already have a current iOS Distribution certificate or a pending
> certificate request.

The fix: store the certificate's **private key once**, and let
`app-store-connect fetch-signing-files --create` find the certificate made with
that key and reuse it (it only creates one the very first time).

## One-time setup

1. **Generate a private key** (once):

   ```bash
   openssl genrsa 2048
   ```

2. **Store it in Codemagic** → app → *Environment variables*:
   - Variable name: `CERTIFICATE_PRIVATE_KEY`
   - Value: the full PEM (including the `-----BEGIN/END PRIVATE KEY-----` lines)
   - Group: `signing`  (the workflow references `environment.groups: [signing]`)
   - ☑ **Secure**

3. **Free a certificate slot** in the Apple Developer portal
   (*Certificates, Identifiers & Profiles → Certificates*): revoke any stale
   Codemagic-created "Apple/iOS Distribution" certs. **Keep "Distribution
   Managed"** (used by other VVIS/LEAP apps).

The first build then creates a single distribution cert with this key and every
later build reuses it — no more 409, no more manual revoking.

## Notes

- Build number comes from `pubspec.yaml` (`version: x.y.z+<build>`); bump the
  `+<build>` for every App Store upload (must be unique & increasing).
- Bundle ID: `com.vvistech.slkMobile`.
- If the private key is ever lost, revoke the cert in the Apple portal and let a
  build recreate it (then re-store the new key).
