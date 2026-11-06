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

Workflow files are authored **inside `apk/`** and mirrored to the repository root,
because GitHub only executes files in the root `.github/workflows/` directory:

| Workflow | Canonical file (source of truth) | Trigger | What it does |
| :--- | :--- | :--- | :--- |
| **APK CI/CD** | [`apk/.github/workflows/apk-ci.yml`](apk/.github/workflows/apk-ci.yml) | Every push to `main`, every PR, tag `v*`, manual | `flutter analyze` + `flutter test`, then builds the release APK; publishes it to **GitHub Releases** when a `v*` tag is pushed. |
| **Web → Vercel** | [`apk/.github/workflows/web-vercel-deploy.yml`](apk/.github/workflows/web-vercel-deploy.yml) | Push to `main` / PR touching web files | PRs get a Vite build check; pushes to `main` deploy to **Vercel production** (`vercel build --prebuilt`). |

Every run starts with a `workflow-sync` job that fails if the root copies drift
from the canonical ones. After editing a workflow, re-sync and commit both:

```bash
./apk/scripts/sync-workflows.sh          # copy apk/.github/workflows -> root
./apk/scripts/sync-workflows.sh --check  # verify (what CI runs)
```

**Release an APK:** bump `apk/pubspec.yaml`, then

```bash
git tag v1.0.19 && git push origin v1.0.19   # builds + attaches app-release.apk
```

### Required repository secrets

Create them under *Settings → Secrets and variables → Actions*:

- `NEON_CONNECTION_STRING` — used by the APK job to write `apk/.env` at build time (that file is gitignored, so CI cannot build without it)
- `VERCEL_TOKEN` — from [vercel.com/account/tokens](https://vercel.com/account/tokens)
- `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` — from the Vercel project's `.vercel/project.json` (or `vercel link`)

### Required Vercel environment variables

Set these in the Vercel project (*Settings → Environment Variables*); the deploy
job pulls them with `vercel pull`, so they are not duplicated in GitHub:

- `DATABASE_URL` — read at runtime by the `/api/sql` Edge Function
- `VITE_DATABASE_URL` — **inlined into the browser bundle at build time**; `src/lib/api.ts` and `src/lib/neonClient.ts` now throw instead of falling back to a hardcoded connection string
- `AWS_*` / `VITE_AWS_*`, `AUTH_URL`, `JWKS_URL`, `VITE_AUTH_URL`, `VITE_JWKS_URL`

For local development copy [.env.example](.env.example) → `.env` (both `.env`
files are gitignored) and [apk/.env.example](apk/.env.example) → `apk/.env`.

---

# merkato-credit-recorders-web-apk
