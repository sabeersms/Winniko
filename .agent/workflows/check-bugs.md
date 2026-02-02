---
description: How to check for and debug bugs in the Winniko app
---

To ensure the application is running smoothly and to identify potential issues, follow these steps:

### 1. Static Analysis (Code Quality)
// turbo
Run the following command to find syntax errors, potential null-safety issues, and deprecated code:
```powershell
flutter analyze
```

### 2. Run Tests
Check if the core components and UI are working as expected by running the test suite:
```powershell
flutter test
```

### 3. Use Flutter DevTools
When running the app with `flutter run`, you can open **Flutter DevTools** to:
- **Inspect the Widget Tree:** see how UI elements are laid out.
- **Profile Performance:** identify lag or memory leaks.
- **Network Inspector:** monitor API calls to Firestore/Storage.
- **Logging View:** see all print statements and errors in one place.

### 4. Check the Debug Console
Always keep an eye on your terminal or IDE's **Debug Console** while the app is running. Look for:
- Red text (Unhandled exceptions).
- `W/` or `E/` tags (Warnings/Errors from the Android/iOS system).
- Custom logs we've added (e.g., `!!! ERROR: ...`).

### 5. Firebase Console
For database-related issues (like the index error we found earlier):
- Go to the [Firebase Console](https://console.firebase.google.com/).
- Check **Firestore > Indexes** for missing index warnings.
- Check **Crashlytics** (if enabled) to see logs of app crashes on actual devices.
