<!-- @format -->

# Deployment Setup - Complete Guide

## API Deployment Setup

### GitHub Secrets

- `API_SSH_HOST`
- `API_SSH_USER`
- `API_SSH_KEY`
- `API_ENV_FILE_B64`
- `API_FIREBASE_ADMINSDK_JSON_B64`
- `SSL_CERT_B64`
- `SSL_KEY_B64`

### Generate Base64 Secrets on Windows

```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Users\Femi.Badmus\Desktop\Sales Note\backend\.env.production")) | Set-Clipboard
```

```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Users\Femi.Badmus\Desktop\Sales Note\backend\firebase-adminsdk.json")) | Set-Clipboard
```

### Generate Deploy SSH Key on Windows

```powershell
ssh-keygen -t ed25519 -C "github-actions-salesnote-api" -f $env:USERPROFILE\.ssh\salesnote_api_actions_nopass -N ""
Get-Content $env:USERPROFILE\.ssh\salesnote_api_actions_nopass.pub
Get-Content $env:USERPROFILE\.ssh\salesnote_api_actions_nopass -Raw | Set-Clipboard
```

### Server Paths

Everything for the API deploy is expected directly inside:

```text
/home/salesnote
```

Main files:

- `/home/salesnote/api`
- `/home/salesnote/.env`
- `/home/salesnote/firebase-adminsdk.json`
- `/home/salesnote/manage.sh`
- `/home/salesnote/nginx.conf`
- `/home/salesnote/nginx.conf.template`
- `/home/salesnote/salesnote@.service`
- `/home/salesnote/salesnote.service`

### Important Env Rules

Do not set a fixed bind port in production `.env`.

Remove this if present:

```env
SALESNOTE__BIND=0.0.0.0:80
```

The bind port must come from systemd instance units:

```text
Environment=SALESNOTE__BIND=0.0.0.0:%i
```

### PostgreSQL Connection Limit

Current deploy behavior through [manage.sh](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/manage.sh):

- local PostgreSQL bootstrap enforces:
    - `max_connections = 152`

Why:

- app pool is currently planned around:
    - `5` API instances
    - `SALESNOTE__POOL_MAX_SIZE=28`
- total possible DB connections:
    - `5 x 30 = 150`

Useful PostgreSQL commands:

```bash
sudo -u postgres psql -tAc "SHOW max_connections;"
sudo -u postgres psql -tAc "SELECT count(*) FROM pg_stat_activity;"
```

### Useful Server Commands

Check all API instances:

```bash
systemctl list-units --type=service | grep salesnote
sudo systemctl status salesnote@8081
sudo systemctl status salesnote@8082
sudo bash /home/salesnote/manage.sh status 2
```

Check logs:

```bash
journalctl -u salesnote@8081 -n 100 --no-pager
journalctl -u salesnote@8082 -n 100 --no-pager
```

Check port usage:

```bash
sudo ss -ltnp | grep -E '8081|8082|8083|8084|8085'
sudo ss -ltnp | grep ':80'
sudo ss -ltnp | grep ':443'
```

Kill a stray process on a port:

```bash
sudo fuser -k 8081/tcp
sudo fuser -k 8082/tcp
```

### Nginx Commands

Check generated config:

```bash
cat /home/salesnote/nginx.conf
```

Check live nginx config:

```bash
sudo nginx -t
sudo nginx -T | grep -A20 -B5 'listen 443'
sudo nginx -T | grep -A20 -B5 salesnote_api
```

### Health Checks

Use `GET`, not `HEAD`.

```bash
curl http://127.0.0.1:8081/health
curl http://127.0.0.1:8082/health
curl https://api.salesnote.online/health
```

`curl -I` returns `405` because `/health` allows `GET`.

### Firewall Commands

```bash
sudo apt-get update
sudo apt-get install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

### DNS Check

On Windows:

```powershell
Resolve-DnsName api.salesnote.online | Select-Object Name,Type,IPAddress
```

---

## k6 Load Testing Setup

### Workflow

Manual workflow:

- `SalesNote k6 Load Test`

File:

- [.github/workflows/test.yml](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/.github/workflows/test.yml)

Run it from:

1. GitHub `Actions`
2. Open `SalesNote k6 Load Test`
3. Click `Run workflow`

### Workflow Inputs

`script` choices:

- `login-only.js`
- `home-gets.js`
- `sales-list.js`
- `item-list.js`
- `sales-create.js`

`local_config_js`:

- paste the full contents of `backend/k6/local.config.js` directly into the workflow input

If `local_config_js` is empty, the workflow falls back to:

- `K6_LOCAL_CONFIG_B64`

### Optional Secret Fallback

GitHub secret:

- `K6_LOCAL_CONFIG_B64`

Copy local config to clipboard as base64 on Windows:

```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Users\Femi.Badmus\Desktop\Sales Note\backend\k6\local.config.js")) | Set-Clipboard
```

### Example `local_config_js`

```js
/** @format */

const localConfig = {
	baseUrl: "https://api.salesnote.online",
	loginId: "+0000",
	password: "0000",
	vus: 100,
	duration: "30s",
	executionMode: "duration",
	perVuIterations: 1,
	thinkTimeSecs: 1,
	includeItems: false,
	signatureName: "Amanda",
	signatureImageUrl: "https://aisignator.com/wp-content/uploads/2025/05/Amanda-signature.jpg",
};

export default localConfig;
```

### Meaning Of Main k6 Config Fields

- `vus`: concurrent virtual users
- `duration`: how long the test runs in `duration` mode
- `executionMode: "duration"`: run for a fixed time
- `executionMode: "iterations"`: each VU runs a fixed number of iterations
- `perVuIterations`: used when `executionMode` is `iterations`
- `thinkTimeSecs`: pause between iterations

For a real concurrency test, use:

```js
vus: 1000,
executionMode: "duration",
duration: "30s",
```

### Local Scripts

Main k6 scripts:

- [login-only.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/login-only.js)
- [home-gets.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/home-gets.js)
- [sales-list.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/sales-list.js)
- [item-list.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/item-list.js)
- [sales-create.js](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/k6/sales-create.js)

### Local Usage

```powershell
k6 run backend/k6/login-only.js
k6 run backend/k6/home-gets.js
k6 run backend/k6/sales-list.js
k6 run backend/k6/item-list.js
k6 run backend/k6/sales-create.js
```

### Important Behavior

In `sales-create.js`:

1. login happens once in `setup()`
2. signature fetch/create happens once in `setup()`
3. the actual loop is sale creation

So create-sale timing is not inflated by repeated login/signature setup per iteration.

### How To Read Results

Important metrics:

- `http_reqs`: total HTTP requests, not total sales
- `iterations`: total flow loops completed
- `http_req_failed`: request failure rate
- `http_req_duration p(95)`: tail latency

For `sales-create.js`:

- successful sale creates come from:
    - `create sale status is expected`
- not from `http_reqs`

Example:

- `http_reqs = 7115` does not mean `7115` sales created
- if `create sale status is expected` shows `✓ 6059 / ✗ 1054`, then:
    - successful sales created = `6059`
    - failed sale creates = `1054`

### Server Checks During k6

Track app logs:

```bash
tail -F /home/salesnote/logs/error-*.log
tail -F /home/salesnote/logs/*.log
```

Check non-201 sale creates in app logs:

```bash
grep 'POST /sales' /home/salesnote/logs/access-*.log | grep -v ' 201 ' | tail -n 200
```

Check nginx upstream failures:

```bash
sudo grep -iE "upstream|timed out|reset|refused|502|503|504|worker_connections" /var/log/nginx/error.log | tail -n 200
sudo grep 'POST /sales' /var/log/nginx/access.log | grep -v ' 201 ' | tail -n 200
```

### Known k6 Finding From Current Production Setup

If you see nginx errors like:

```text
worker_connections are not enough while connecting to upstream
```

that means failures are happening at nginx under load, before the request fully reaches Actix.

Current deploy now updates nginx worker tuning through [manage.sh](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/backend/manage.sh) during `scale`.

---

## Android Deployment Setup

### GitHub Secrets

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_GOOGLE_SERVICES_JSON`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

### Generate Base64 Secrets On Windows

Keystore:

```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\Users\Femi.Badmus\Desktop\Sales Note\mobile\android\app\salesnote-release.keystore")) | Set-Clipboard
```

### Workflow Notes

File:

- [.github/workflows/android-deploy.yml](/c:/Users/Femi.Badmus/Desktop/Sales%20Note/.github/workflows/android-deploy.yml)

What the workflow now does:

1. builds from the `mobile` app directory
2. restores `android/app/google-services.json` from GitHub Secrets
3. restores signing keystore and `key.properties`
4. builds the release `.aab`
5. uploads to Google Play internal testing

### Important Values

Current Android package name:

- `com.blackstackhub.salesnote`

Current bundle upload path:

- `mobile/build/app/outputs/bundle/release/app-release.aab`

### Manual Local Build

From repo root:

```powershell
cd mobile
flutter clean
flutter pub get
flutter build appbundle --release
```

---

## iOS Deployment Setup

> ✅ **Works 100% from Windows!** No Mac needed after initial setup.

This workflow automatically builds your iOS app and uploads it to TestFlight every time you push to GitHub.

---

## 📋 What You Need Before Starting

1. **Apple Developer Account** (paid $99/year)
2. **Windows PC with PowerShell** (no Mac needed!)
3. **OpenSSL installed** on Windows: `winget install -e --id ShiningLight.OpenSSL`
4. **GitHub repository** with your Flutter project

---

## 🔑 Step 1: Create App Store Connect API Key

This lets GitHub upload your app automatically.

1. Go to: https://appstoreconnect.apple.com
2. Click **Users and Access** → **Keys** tab (under Integrations)
3. Click the **"+"** button
4. Name it: `GitHub Actions`
5. Role: **App Manager**
6. Click **Generate**
7. **Download the `.p8` file** (you can ONLY download this once!)
8. **Save these 3 values:**
    - **Key ID** (e.g., `MPG2DHFTMF`) - shown in the filename `AuthKey_MPG2DHFTMF.p8`
    - **Issuer ID** (a UUID) - shown at the top of the Keys page
    - The `.p8` file itself

---

## 🎫 Step 2: Create Apple Distribution Certificate

This signs your app so Apple trusts it.

### 2a. Generate Certificate Request (Windows PowerShell)

```powershell
# Run this in your project folder
openssl req -nodes -newkey rsa:2048 -keyout salesnote.key -out salesnote.csr
```

Just press Enter for all the questions (name, organization, etc. don't matter).

### 2b. Upload to Apple Developer Portal

1. Go to: https://developer.apple.com/account/resources/certificates/list
2. Click **"+"** button
3. Select **"Apple Distribution"**
4. Click **Continue**
5. **Upload** the `salesnote.csr` file
6. Click **Continue** → **Download**
7. Save it as `distribution.cer` in your project folder

### 2c. Convert to P12 Format (Windows PowerShell)

```powershell
# Convert .cer to .pem
openssl x509 -in distribution.cer -inform DER -out salesnote.pem -outform PEM

# Create P12 file (YOU MUST SET A PASSWORD WHEN ASKED!)
openssl pkcs12 -export -out salesnote.p12 -inkey salesnote.key -in salesnote.pem
```

**IMPORTANT:** Remember the password you set! You'll need it for GitHub Secrets.

---

## 📦 Step 3: Create App ID

This identifies your app to Apple.

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Click **"+"** button
3. Select **App IDs** → **Continue**
4. Select **App** → **Continue**
5. Fill in:
    - **Description:** `Media Saver`
    - **Bundle ID:** Select **Explicit** and enter: `com.blackstackhub.salesnote`
6. Click **Continue** → **Register**

---

## 📱 Step 4: Create Provisioning Profile

This links your app, certificate, and Apple account together.

1. Go to: https://developer.apple.com/account/resources/profiles/list
2. Click **"+"** button
3. Select **App Store** (under Distribution) → **Continue**
4. Select your **App ID** (`com.blackstackhub.salesnote`) → **Continue**
5. Select the **certificate** you just created → **Continue**
6. Name it: `SalesNote AppStore Profile` → **Generate**
7. **Download** the `.mobileprovision` file to your project folder

---

## 🔐 Step 5: Convert Everything to Base64

GitHub needs these files encoded in Base64 format.

**Run these in PowerShell (in your project folder):**

```powershell
# 1. P12 Certificate
[Convert]::ToBase64String([IO.File]::ReadAllBytes("salesnote.p12")) | Set-Clipboard
# Now paste into a text file and label it "P12"

# 2. Provisioning Profile (replace with your actual filename)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("SalesNote_AppStore_Profile.mobileprovision")) | Set-Clipboard
# Paste into text file and label it "PROFILE"

# 3. API Key (replace with your actual filename)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_MPG2DHFTMF.p8")) | Set-Clipboard
# Paste into text file and label it "API_KEY"
```

Each command copies the Base64 string to your clipboard - paste it somewhere safe immediately!

---

## 🔒 Step 6: Add Secrets to GitHub

Go to: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions`

Click **"New repository secret"** and add these **7 secrets** one by one:

| Secret Name                        | Where to Get the Value                               |
| ---------------------------------- | ---------------------------------------------------- |
| `BUILD_CERTIFICATE_BASE64`         | Paste the P12 Base64 from your text file             |
| `P12_PASSWORD`                     | The password you set when creating the P12           |
| `BUILD_PROVISION_PROFILE_BASE64`   | Paste the PROFILE Base64 from your text file         |
| `KEYCHAIN_PASSWORD`                | Make up ANY strong password (e.g., `SecurePass123!`) |
| `APP_STORE_CONNECT_API_KEY_ID`     | Your Key ID (e.g., `MPG2DHFTMF`)                     |
| `APP_STORE_CONNECT_ISSUER_ID`      | The Issuer ID from App Store Connect (UUID format)   |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Paste the API_KEY Base64 from your text file         |

---

## 🎯 Step 7: Update Your Team ID

1. Get your Team ID from: https://developer.apple.com/account/#/membership/
2. Open `ios/ExportOptions.plist`
3. Replace `YOUR_TEAM_ID` with your actual Team ID

---

## 🚀 Step 8: Push to GitHub!

```powershell
git add .
git commit -m "Add iOS deployment workflow"
git push
```

**That's it!** The workflow will automatically:

- Build your iOS app on macOS runners (in the cloud)
- Sign it with your certificates
- Upload it to TestFlight

---

## 📊 Step 9: Watch the Build

Go to: `https://github.com/YOUR_USERNAME/YOUR_REPO/actions`

The build takes about 10-15 minutes. You'll see:

- ✅ Build completes
- ✅ App uploaded to TestFlight

---

## 🎉 Step 10: Test Your App

1. Go to: https://appstoreconnect.apple.com
2. Select your app
3. Go to **TestFlight** tab
4. Add internal testers
5. They'll get an email to download via TestFlight app

---

## 🔄 Future Deployments

Every time you push to `main` or `release` branch, the workflow automatically:

1. Builds the app
2. Uploads to TestFlight

**OR** manually trigger it:

1. Go to **Actions** tab on GitHub
2. Select "iOS Build and Deploy to App Store"
3. Click **"Run workflow"**

---

## 🛡️ Security Best Practices

All your certificate files are now in `.gitignore` and won't be committed.

**Backup these files safely** (NOT in the repo):

- `AuthKey_MPG2DHFTMF.p8` - Can NEVER be re-downloaded!
- `salesnote.p12` - Your certificate
- `salesnote.key` - Private key
- The P12 password you created

---

## 🆘 Troubleshooting

### ❌ "No matching provisioning profile"

- Check that your Bundle ID is exactly: `com.blackstackhub.salesnote`
- Make sure you selected the correct certificate when creating the provisioning profile

### ❌ "Unable to validate your application"

- Double-check your 3 API key values in GitHub Secrets
- Make sure you copied the full Base64 strings (no spaces or line breaks)

### ❌ Build fails immediately

- Check that all 7 GitHub Secrets are added correctly
- Make sure your Team ID is updated in `ExportOptions.plist`

### ❌ Certificate expired

- Certificates last 1 year
- Generate a new one following Step 2 again
- Update the `BUILD_CERTIFICATE_BASE64` secret in GitHub

---

## ✅ Success Checklist

- [x] Downloaded `.p8` API key from App Store Connect
- [x] Created Apple Distribution certificate
- [x] Created App ID: `com.blackstackhub.salesnote`
- [x] Created Provisioning Profile
- [x] Converted all files to Base64
- [x] Added all 7 secrets to GitHub
- [x] Updated Team ID in `ExportOptions.plist`
- [ ] Pushed to GitHub
- [ ] Workflow ran successfully
- [ ] App appeared in TestFlight

---

## 🎊 You're Done!

Your iOS app now deploys automatically to TestFlight every time you push to GitHub. No Mac required! 🎉
