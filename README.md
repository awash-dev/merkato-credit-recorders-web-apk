# Merkato Credit Record (መርካቶ የብድርና ክምችት መዝገብ)

Lightweight multi-store merchant credit & stock management system for Merkato traders.

---

## 📱 Deliverables & APK Downloads

Directly available in the project root:
1. **Flutter Android APK**: [`merkato-credit-record-flutter.apk`](file:///d:/project/eyoba-project/New%20folder/merkato-credit-record-flutter.apk) (Native Flutter Material 3 build with PDF statement printing)
2. **Capacitor Android APK**: [`merkato-credit-record-debug.apk`](file:///d:/project/eyoba-project/New%20folder/merkato-credit-record-debug.apk) (Lightweight Web wrapper build)

---

## 🏢 Business Structure & Credentials

| Role | Email | Password | Assigned Store | Access Scope |
| :--- | :--- | :--- | :--- | :--- |
| **Admin** | `admin@click.et` | `Admin@123` | *All Stores (Central Store)* | Can view/switch Store 1, Store 2, or Combined view; manage storekeepers, reset passwords, activate/deactivate accounts. |
| **Storekeeper 1** | `store1@click.et` | `Store@123` | **Store 1 (Merkato)** | Strictly isolated to Store 1 customer credit, supplier credit, and stock records. |
| **Storekeeper 2** | `store2@click.et` | `Store@123` | **Store 2 (Bole)** | Strictly isolated to Store 2 customer credit, supplier credit, and stock records. |

---

## 🧮 Core Calculations & Rules (Strict ETB Currency)

- **Customer Credit**:
  $$\text{Customer Balance} = \text{Total Debit} - \text{Total Credit (Payments)}$$
  - *Debit*: Customer buys goods on credit.
  - *Credit*: Customer makes a payment (Cash or Bank: CBE, Awash, Dashen, etc.).

- **Supplier Credit**:
  $$\text{Supplier Balance} = \text{Total Credit} - \text{Total Debit (Payments)}$$
  - *Credit*: Goods received from supplier on credit.
  - *Debit*: Payment sent to supplier.

- **Stock (Inventory)**:
  - Simple tracking: Item Description, Quantity, Cartons × Pcs/Ctn calculator, Unit Cost, Total ETB Valuation.
  - Removed all USDT/forex converters; strict Ethiopian Birr (ETB) accounting.

- **Excel-Style Ledger**:
  - Interactive table: Date | Description / Product | Quantity | Unit Price | Debit | Credit | Running Balance.
  - Automatic column totals and 1-tap PDF statement generation.

---

## 📂 Project Organization

- [`web/`](file:///d:/project/eyoba-project/New%20folder/web/): React + Vite web dashboard and backend API server (`web/server/index.mjs`) on port `8787` connected to Neon PostgreSQL.
- [`apk/`](file:///d:/project/eyoba-project/New%20folder/apk/): Complete native Flutter application built with Flutter SDK 3.38.6 / Dart 3.10.6.

## ⚙️ CI/CD (GitHub Actions)

| Workflow | File | Trigger | What it does |
| :--- | :--- | :--- | :--- |
| **Web Deploy** | [`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml) | Push to `main` | Builds the Vite app and deploys to **Vercel** production (`vercel build --prebuilt`). |
| **APK Release** | [`.github/workflows/release_apk.yml`](.github/workflows/release_apk.yml) | Push to `main`, tag `v*`, or manual | Builds the Flutter Android APK and publishes it to **GitHub Releases** + a workflow artifact. |

### Required repository secrets (Web → Vercel)

Create them under *Settings → Secrets and variables → Actions*:

- `VERCEL_TOKEN` — from [vercel.com/account/tokens](https://vercel.com/account/tokens)
- `VERCEL_ORG_ID` — from the Vercel project's `.vercel/project.json` (or `vercel link`)
- `VERCEL_PROJECT_ID` — same file as above

Also set `DATABASE_URL` (and optionally `VITE_DATABASE_URL`, S3 keys) in the Vercel project's *Environment Variables*, since `/api/sql` is an Edge Function that reads them at runtime.

---

# merkato-credit-recorders-web-apk
