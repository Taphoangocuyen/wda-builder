# 🐼 WebDriverAgent Builder (Self-Launch)

Build WebDriverAgent IPA có thể **mở bằng icon** — không cần tidevice.

## ✨ Tính năng

- ✅ Nhấn icon trên iPhone → WDA tự khởi động
- ✅ Build trên cloud (GitHub Actions) — không cần Mac
- ✅ Ký bằng cert $99 → chạy 1 năm
- ✅ Tuỳ chỉnh tên, icon, Bundle ID
- ✅ Đầy đủ quyền truy cập

## 🚀 Hướng dẫn

### Bước 1: Push repo lên GitHub

Tạo repo **Private** trên GitHub, rồi:

```bash
git init
git add -A
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/wda-builder.git
git push -u origin main
```

### Bước 2: Chạy Build

1. Repo → Tab **Actions** → **Build WebDriverAgent IPA (Self-Launch)**
2. **Run workflow** → tuỳ chỉnh → **Run**
3. Đợi ~15 phút

### Bước 3: Cài lên iPhone

1. Tải IPA từ **Artifacts**
2. **Sideloadly** → ký bằng cert $99
3. Trust profile → nhấn icon → WDA chạy!

## 📁 Cấu trúc

```
├── .github/workflows/build-wda.yml   ← Workflow
├── src/WDAAutoStart.m                 ← Auto-launcher (thay thế hhhhsd.dylib)
├── scripts/customize_wda.sh           ← Tuỳ chỉnh
├── resources/icon.png                 ← Icon
└── README.md
```
