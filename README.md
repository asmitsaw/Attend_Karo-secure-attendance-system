# Attend Karo - Secure Attendance System

Production-grade Flutter app with **zero proxy tolerance** through device binding, geo-fencing, and dynamic QR validation.

## 🚀 Features

### 👨‍🏫 Faculty Module
- Create classes with subject, department, semester, section
- Upload student lists via CSV
- Start attendance sessions with dynamic QR codes
- Real-time student scan count
- Analytics dashboard with charts and proxy attempt logs

### 👨‍🎓 Student Module
- Dashboard with attendance statistics
- QR code scanner with camera
- Multi-layer validation pipeline
- Real-time attendance marking

### 🔐 Anti-Proxy Security
- **Device Binding**: One student ↔ one device (permanent lock)
- **Geo-Fencing**: 30-meter radius enforcement with GPS
- **Mock GPS Detection**: Rejects fake location apps
- **Emulator Detection**: Blocks virtual devices
- **Dynamic QR**: 10-second validity with timestamp verification
- **Backend Validation**: Signature verification + duplicate checks

## 📦 Installation

### Prerequisites
- Flutter SDK 3.10.8 or higher
- Android Studio / VS Code
- Android device or emulator (for testing only, real usage requires physical device)

### Setup
1. Clone the repository:
```bash
git clone https://github.com/asmitsaw/Attend_Karo-secure-attendance-system.git
cd Attend_Karo-secure-attendance-system
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure backend URL in `lib/core/constants/api_endpoints.dart`:
```dart
static const String baseUrl = 'YOUR_BACKEND_URL';
```

4. Run the app:
```bash
flutter run
```

## 🏗️ Architecture

Clean architecture with separation of concerns:
- **presentation/**: UI screens and Riverpod providers
- **data/**: Models, repositories, and data sources
- **core/**: Constants, theme, and utilities

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Flutter 3.10.8 |
| State Management | Riverpod 2.5.1 |
| HTTP Client | Dio 5.4.0 |
| Location | Geolocator 11.0.0 |
| QR Code | mobile_scanner 3.5.6, qr_flutter 4.1.0 |
| Device Info | device_info_plus 10.1.0 |
| Storage | flutter_secure_storage 9.0.0 |
| Charts | fl_chart 0.66.0 |
| Fonts | google_fonts 6.1.0 |

## 🌐 Backend Requirements

### Required Endpoints

**Authentication**
- `POST /auth/login` - Username/password login

**Faculty**
- `POST /faculty/class/create` - Create new class
- `POST /faculty/class/students` - Upload student CSV
- `POST /faculty/session/start` - Start attendance session
- `POST /faculty/session/end` - End session & mark absents
- `GET /faculty/analytics` - Get analytics data

**Student**
- `GET /student/classes` - Get enrolled classes
- `POST /student/attendance/mark` - Mark attendance (with validation)

### Critical Backend Validations
1. **QR Signature**: HMAC-SHA256 verification
2. **Geo-Fencing**: Haversine distance ≤ 30 meters
3. **Device Binding**: `UNIQUE(student_id, device_id)` constraint
4. **Duplicate Check**: `UNIQUE(student_id, session_id)` constraint
5. **Auto-Absence**: Mark remaining students as ABSENT on session end

## 📱 Screenshots

### Faculty Dashboard
- Quick actions for class creation, session management, and analytics

### Student Dashboard
- Attendance stats and QR scan button

### QR Scan Screen
- Camera view with validation pipeline
- Real-time error feedback

### Analytics Dashboard
- Line charts for attendance trends
- Proxy attempt logs

## 🔧 Configuration

### Android Permissions (already configured)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Constants
Edit `lib/core/constants/app_constants.dart` to change:
- Attendance radius (default: 30 meters)
- QR validity duration (default: 10 seconds)
- Location accuracy threshold

## 🧪 Testing

### Build APK
```bash
flutter build apk --release
```

### Analyze Code
```bash
flutter analyze
```

### Test Scenarios
1. ✅ Login as faculty → Create class → Start session
2. ✅ Login as student → Scan QR within 30m → Success
3. ❌ Scan QR outside 30m → Rejected
4. ❌ Scan with fake GPS → Rejected
5. ❌ Scan on different device → Rejected
6. ❌ Scan expired QR → Rejected

## 📚 Documentation

See [implementation_plan.md](./docs/implementation_plan.md) for detailed architecture design.

See [walkthrough.md](./docs/walkthrough.md) for complete feature walkthrough.

## 🔒 Security Notes

- All security validations happen **server-side**
- Client-side checks are for UX feedback only
- Device binding is permanent (admin override required)
- Location must be enabled with high accuracy
- Mock location apps must be disabled

## 👥 License

Private project - All rights reserved.

## 📧 Contact

For questions or support, contact the development team.

---

**Built with ❤️ using Flutter**
