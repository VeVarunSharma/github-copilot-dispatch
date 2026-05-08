# Deploying Copilot Dispatch

## Deploy to Your Apple Watch (Fastest Path)

### What You Need

- **Apple Developer account** — free tier works, but the app expires after 7 days and needs re-deploy. Paid ($99/year) removes this limit. Sign up at [developer.apple.com](https://developer.apple.com).
- **Xcode 16+** — install from the Mac App Store
- **Apple Watch** running watchOS 11+ paired with an iPhone
- **iPhone** connected to your Mac (USB or same Wi-Fi for wireless debugging)

> **No iPhone app needed.** This is a standalone watchOS app — it installs directly on the Watch.

### Step 1: Deploy the Backend

The Watch app needs a backend server to connect to. In DEBUG builds, the app automatically points to the Azure staging backend (`https://copilot-dispatch-staging.azurewebsites.net/api`), so you just need to ensure it's deployed:

```bash
# Push to the staging branch to trigger CI deployment
git push origin develop/v1
```

Verify the backend is running:

```bash
curl https://copilot-dispatch-staging.azurewebsites.net/api/health
# Expected: {"status":"ok","service":"copilot-dispatch"}
```

If you haven't set up the backend's GitHub OAuth App yet, do that first — see the [README](README.md#1-create-a-github-oauth-app) for OAuth App setup.

### Step 2: Open the Project in Xcode

```bash
open CopilotDispatch/CopilotDispatch.xcodeproj
```

### Step 3: Set Up Code Signing

1. In Xcode, select **CopilotDispatch** in the project navigator (the blue project icon at the top)
2. Select the **CopilotDispatch** target
3. Go to the **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** from the dropdown (your Apple Developer account)
6. If the bundle identifier `com.copilotdispatch.watchapp` conflicts, change it to something unique like `com.yourname.copilotdispatch`

### Step 4: Select Your Apple Watch

1. Make sure your Apple Watch is **unlocked** and your **iPhone is connected** to your Mac
2. In Xcode's toolbar, click the device dropdown (next to the scheme name)
3. Under **watchOS Devices**, select your Apple Watch
   - If you don't see it: open the **Watch** app on your iPhone → **Developer** → enable **Debug Apple Watch Over Wi-Fi** (or connect iPhone via USB)
   - First-time pairing: your Watch may prompt you to **Trust This Computer** — accept it

### Step 5: Build and Run

Press **⌘R** (or click the ▶ Play button).

- Xcode will compile, sign, and install the app on your Watch
- First install takes 1–2 minutes — the Watch shows a loading spinner
- The app launches automatically when installation completes

### Step 6: Verify It Works

1. The app should show the **authentication screen**
2. Tap **Sign In** — you'll see a device code (e.g., `ABCD-1234`)
3. On your phone or computer, go to [github.com/login/device](https://github.com/login/device)
4. Enter the code and authorize
5. The Watch app should transition to the **home screen** within a few seconds

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Watch not showing in Xcode device list | Ensure iPhone is connected (USB or Wi-Fi). Open Watch app on iPhone → Developer → enable Wi-Fi debugging. Restart Xcode. |
| "Unable to install" error | Check that your Watch is unlocked and has enough storage. Try restarting the Watch. |
| Signing error | Make sure you selected a valid team in Signing & Capabilities. Change the bundle ID if there's a conflict. |
| App installs but can't connect to backend | Verify the staging backend is running with `curl`. Check that your Watch has internet access (connected to iPhone or Wi-Fi). |
| "Untrusted Developer" on Watch | On your Watch: Settings → General → Device Management → trust your developer profile. |
| App expires after 7 days (free account) | Re-deploy from Xcode with ⌘R. Upgrade to a paid developer account to avoid this. |

---

## App Store Distribution (Future)

### TestFlight (Beta Testing)

1. **Paid Apple Developer account required** ($99/year)

2. **Create an App Store Connect record:**
   - Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Click **My Apps → +** → **New App**
   - Platform: **watchOS**
   - Name: `Copilot Dispatch`
   - Bundle ID: select your registered bundle ID
   - SKU: `copilot-dispatch`

3. **Archive and upload from Xcode:**
   - Set the scheme to **Any watchOS Device (arm64)**
   - **Product → Archive**
   - In the Organizer window, click **Distribute App → TestFlight & App Store**
   - Follow the prompts to upload

4. **Set up TestFlight:**
   - In App Store Connect, go to your app → **TestFlight** tab
   - Create an internal or external testing group
   - Add testers by email
   - Testers install via the **TestFlight** app on their iPhone, which pushes the Watch app

### App Store Submission

Before submitting, you'll need:

- **App icon:** 1024×1024 watchOS app icon in the asset catalog
- **Screenshots:** Apple Watch screenshots for each supported size
- **Privacy policy URL:** required for all apps that access user data
- **App Review description:** explain the GitHub authentication flow and Copilot agent functionality
- **Backend URL:** switch `AppEnvironment.current` to return `.production` for release builds (this is already configured — release builds use the production backend automatically)

### Environment Configuration

The app automatically selects the right backend based on build type. No code changes needed:

| Build Type | Environment | Backend URL |
|-----------|-------------|-------------|
| DEBUG (⌘R from Xcode) | Staging | `copilot-dispatch-staging.azurewebsites.net` |
| Release (Archive) | Production | `copilot-dispatch-prod.azurewebsites.net` |

This is configured in `CopilotDispatch/Sources/Config/Environment.swift`.
