# 🆓 AppiMeal — 100% Free Production Deployment Guide
### Render Free (Laravel REST API) + Supabase Free (PostgreSQL Database) + Flutter Android App

This guide explains how to deploy **AppiMeal** with **ZERO paid infrastructure costs** using **Render Free** and **Supabase Free PostgreSQL**.

---

## 🏗️ 1. Architecture Overview (Zero-Cost Stack)

```
📱 Android Mobile App (Physical Phone / 5G / Wi-Fi)
        │
        │ HTTPS REST API Requests
        ▼
⚡ Render Free Web Service (Laravel 11 REST API / PHP 8.3 / Docker)
        │
        ▼ (PostgreSQL Connection over SSL)
🗄️ Supabase Free Cloud PostgreSQL Database
```

---

## 📋 2. Step-by-Step Non-Expert Deployment Checklist

### Step 1: Create Your Free Supabase PostgreSQL Database

1. Go to [https://supabase.com](https://supabase.com) and sign up for a **Free Account**.
2. Click **New Project**:
   - **Project Name:** `AppiMeal DB`
   - **Database Password:** Set a secure password (e.g., `AppiMealSecurePass2026!`) and **save it safely**.
   - **Region:** Choose the region closest to your users (e.g., `Singapore` or `US East`).
3. Click **Create New Project** and wait ~2 minutes for initialization.
4. Go to **Project Settings** ➔ **Database**:
   - Look under **Connection Parameters** or **Direct Connection**:
     - **Host:** `db.<your-project-ref>.supabase.co`
     - **Port:** `5432`
     - **Database:** `postgres`
     - **User:** `postgres` (or `postgres.<your-project-ref>`)
     - **Password:** *(The password you created in step 2)*

---

### Step 2: Deploy Laravel API to Render Free

1. Push your `backend/` project code to GitHub.
2. Sign up for a free account at [https://render.com](https://render.com).
3. On the Render Dashboard, click **New +** ➔ **Blueprint**.
4. Connect your GitHub repository:
   - Render automatically detects [`backend/render.yaml`](file:///Users/appiflybdltd/Documents/AppiMeal/backend/render.yaml).
5. On the Environment Variables configuration screen, enter your Supabase connection parameters:
   - `DB_HOST` = `db.<your-project-ref>.supabase.co`
   - `DB_USERNAME` = `postgres` (or `postgres.<your-project-ref>`)
   - `DB_PASSWORD` = `YourSupabasePassword`
   - `DB_DATABASE` = `postgres`
   - `DB_PORT` = `5432`
   - `DB_CONNECTION` = `pgsql`
   - `DB_SSLMODE` = `require`
6. Click **Apply**. Render will build the Docker container and deploy your live HTTPS API!

---

### Step 3: Initialize Database Migrations & Initial Seed Data

1. Once Render finishes building, open the **Shell** tab in your Render Web Service dashboard.
2. Execute the migration & seeder command:
   ```bash
   php artisan migrate:fresh --seed --force
   ```
3. Test your live Health Endpoint in any browser or phone:
   ```text
   https://appimeal-api.onrender.com/api/health
   ```
   **Expected Response:**
   ```json
   {
     "success": true,
     "message": "AppiMeal API is running",
     "status": "ok",
     "system": "AppiMeal REST API",
     "company": "Appifly BD Limited",
     "timezone": "Asia/Dhaka",
     "timestamp": "2026-09-07T00:00:00+06:00"
   }
   ```

---

### Step 4: Build & Install the Production Flutter Release APK

Once your Render URL is live (e.g. `https://appimeal-api.onrender.com/api`):

1. Run the release build command on your machine:
   ```bash
   cd frontend
   flutter build apk --release --dart-define=API_URL=https://appimeal-api.onrender.com/api
   ```
2. Your final production APK will be generated at:
   `frontend/build/app/outputs/flutter-apk/app-release.apk`
3. Install `AppiMeal-v1.0.0-release.apk` on your physical Android phone.
4. Log in using your official credentials:
   - **System Admin:** `info@appiflybd.com` / `appifly@meal`
   - **Employees:** `tusher@appiflybd.com` / `password`

---

## 🔑 Initial Production Logins

| Role | Email | Password | User Name |
| :--- | :--- | :--- | :--- |
| **System Admin** | `info@appiflybd.com` | `appifly@meal` | System Admin |
| **MD** | `tusher@appiflybd.com` | `password` | MD Tusher Akanda |
| **CEO** | `masum@appiflybd.com` | `password` | MD Masum Talukder |
| **Manager** | `ashfakul@appiflybd.com` | `password` | Ashfakul Alam |
| **Lead Engineer** | `iftekhar@appiflybd.com` | `password` | Iftekhar Mahmud |
| **Business Analyst** | `ridwan@appiflybd.com` | `password` | Md Ridwanur Rahman |

---

## ⚠️ Free-Tier Limitations & Simple Solutions

| Free Tier Limit | Impact | Recommended Free Solution |
| :--- | :--- | :--- |
| **Render Free Cold Start** | Render Free web services spin down (sleep) after 15 minutes of inactivity. The first request after a sleep period takes ~30-50s to wake up. | Create a free account at [UptimeRobot.com](https://uptimerobot.com) or [Cron-Job.org](https://cron-job.org) and set up a **5-minute HTTP ping** to `https://appimeal-api.onrender.com/api/health`. This keeps your Render API awake **24/7 with zero lag**! |
| **Supabase 7-Day Inactivity Pause** | Supabase pauses free projects if inactive for 7 consecutive days. | Daily app usage by employees keeps it active automatically. |
| **Supabase Storage Limit** | 500MB free database storage. | More than enough for ~50,000+ lunch records and attendance logs. |
