# SlawBot

A native SwiftUI iPhone client for a self-hosted OpenHands server. SlawBot has no intermediary server: messages go directly from the phone to your OpenHands App Server. OpenHands may then send prompts to whichever model provider you configured on the VPS.

## Connect your server

1. Install and connect the Tailscale app on your iPhone to the same tailnet as your VPS.
2. Launch SlawBot and open **Settings**.
3. Enter the OpenHands URL, such as `http://<your-vps-tailscale-ip>:3000`, then tap **Test connection**. SlawBot accepts HTTP only for Tailscale CGNAT IPv4 addresses (`100.64.0.0/10`); HTTPS URLs are also supported.
4. Optionally set a default repository (`owner/repository`) and branch. An optional OpenHands access token is stored in the iOS Keychain, never in the repository.
5. Start a task, or open one of your recent conversations.

If the server is unreachable, first confirm Tailscale is connected on the phone and that the URL/port matches your OpenHands dashboard.

## Build an unsigned IPA

The public GitHub Actions workflow uses a standard macOS runner, runs XcodeGen from `project.yml`, builds for a generic iOS device with code signing disabled, packages the app as an IPA, and uploads it as the `SlawBot-unsigned-ipa` workflow artifact. It requires no Apple signing certificate, provisioning profile, or repository secret.

To build locally on macOS:

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project SlawBot.xcodeproj \
  -scheme SlawBot -configuration Release -sdk iphoneos \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO 'CODE_SIGN_IDENTITY='
mkdir -p dist/Payload
ditto build/Build/Products/Release-iphoneos/SlawBot.app dist/Payload/SlawBot.app
(cd dist && ditto -c -k --sequesterRsrc --keepParent Payload SlawBot-unsigned.ipa)
```

An unsigned IPA is not installable directly by iOS. Use your signing service to sign the downloaded artifact for your device, then install the signed result according to that service's instructions. This repository intentionally contains no signing credentials.

## Security notes

- Use the app only with a trusted OpenHands server reachable over your tailnet or HTTPS.
- Cleartext HTTP is enabled at the iOS transport layer to support direct Tailscale IP access, but SlawBot's URL validator restricts HTTP to the Tailscale `100.64.0.0/10` range.
- The client rejects redirects and sends an optional `X-Access-Token` only to OpenHands API routes.
- The app itself has no telemetry or server-side proxy. OpenHands may forward prompts to its configured model provider.
- Never commit an access token, signing certificate, provisioning profile, or private key.
