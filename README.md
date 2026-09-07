
# 🏗️ Thekaydaar.pk — AI Construction Marketplace

A Flutter-based multi-role construction marketplace that connects **Clients (Maaliks)** with **Thekaydaars (Contractors)** — featuring project posting & bidding, real-time chat, contract management, payments, ratings, and a built-in **AI House Planner** (2D blueprint, 3D view, and 360° panorama).

## ✨ Key Features

| Feature | Description |
|---|---|
| 🏠 AI House Planner | Generate complete house plans from plot details — 2D blueprint, procedural 3D projection, and first-person 360° panorama. Works **fully offline** via the built-in rule-based planner; Gemini AI is an optional enhancement. |
| 📋 Projects & Bidding | Clients post construction projects with location details; contractors browse open projects and submit bids. |
| 💬 Real-time Chat | Firestore-powered messaging with image sharing via Cloudinary. |
| 📄 Contract Management | PDF contract generation with printing and sharing support. |
| 💳 Billing & Payments | Payment tracking and payment history per project. |
| ⭐ Ratings & Reviews | Clients rate contractors after project completion. |
| 🗺️ Maps & Location | Google Maps location picker with automatic city/area detection. |
| 🔔 Messages & Notifications | In-app notification center for project and chat activity. |

## 👥 User Roles

| Role | Capabilities |
|---|---|
| **Client (Maalik)** | Post projects, generate AI house plans, chat, sign contracts, make payments, rate contractors |
| **Thekaydaar (Contractor)** | Browse projects, place bids, view blueprint dimensions, chat, manage jobs |
| **Super Admin** | Full platform control; reviews pending admin requests |
| **Regional Admin / Support Desk / Area Handler** | Tiered administrative access |

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart SDK `^3.10.4`) |
| Backend | Firebase — Auth, Cloud Firestore, Firebase Storage |
| AI (optional) | Google Gemini |
| Maps & Location | `google_maps_flutter`, `geolocator`, `geocoding` |
| Media | Cloudinary, `image_picker`, `cached_network_image` |
| Documents | `pdf`, `printing` |
| Animations | Lottie |
| Config | `flutter_dotenv` |
| Fonts | Poppins (English), Jameel Noori Nastaleeq (Urdu) |

## 📁 Project Structure

| Directory | Purpose |
|---|---|
| `lib/Client/` | Client screens — post project, AI planner wizard, project details |
| `lib/Theekaydaar/` | Contractor screens — browse projects, my bids |
| `lib/house_planner/` | AI House Planner — models, providers, painters, 3D & panorama viewers |
| `lib/MessageAndNotification/` | Real-time chat, notifications, Cloudinary config |
| `lib/contract/` | Contract generation & management |
| `lib/Payment&Requests/` | Billing & payment history |
| `lib/rating_system/` | Ratings & reviews |
| `lib/admin/` | Admin role screens & configuration |
| `lib/services/` | Core services (env config, Gemini, chat service, etc.) |
| `lib/model/` | Data models |
| `lib/Widgets/`, `lib/ui/`, `lib/utils/` | Shared widgets, theme & utilities |
| `lib/onboardingScreens/`, `lib/profile_sub_pages/` | Onboarding & profile screens |
| `assets/` | Images, Lottie animations, fonts |

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (Dart `^3.10.4`)
- A Firebase project with **Authentication**, **Cloud Firestore**, and **Storage** enabled
- *(Optional)* Gemini API key, Cloudinary account, Google Maps API key

### Setup

1. Clone the repository:

   ```powershell
   git clone https://github.com/KashifDev4you/ThekayDaar-AI.git
   cd ThekayDaar-AI
   ```

2. Install dependencies:

   ```powershell
   flutter pub get
   ```

3. Create your environment file from the template and fill in real values:

   ```powershell
   Copy-Item .env.example .env
   ```

4. Copy the Firebase templates and fill them in:
   - `android/app/google-services.json.example` → `android/app/google-services.json`
   - `firebase.json.example` → `firebase.json`

5. Add your Maps key to `android/local.properties` (injected at build time):

   ```properties
   GOOGLE_MAPS_API_KEY=your_google_maps_api_key
   ```

6. Run the app:

   ```powershell
   flutter run
   ```

## 🔑 Environment Variables

| Variable | Required | Purpose |
|---|---|---|
| `FIREBASE_*` (project ID, API keys, app IDs per platform) | ✅ | Firebase configuration for all platforms |
| `SUPER_ADMIN_EMAIL` | ✅ | The email that receives Super Admin privileges |
| `GOOGLE_MAPS_API_KEY` | ✅ | Google Maps integration (also needed in `android/local.properties`) |
| `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET` | ✅ | Image uploads for chat & project photos |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | ⭕ Optional | AI enhancements — the app works fully offline without them |

## 🔒 Security Notes

- All secrets are loaded at runtime from `.env` (git-ignored); `.example` templates contain placeholders only — never real values.
- `google-services.json`, `firebase.json`, and `android/local.properties` are git-ignored — never commit real credentials.
- Firestore security rules keep AI house plans client-private; contractors only see sanitized blueprint projections (dimensions only — no 3D/360° data).

## 📱 Supported Platforms

Android • iOS • Web • Windows • macOS • Linux
