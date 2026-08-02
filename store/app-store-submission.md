# App Store submission pack — Sree Lakshmi Kalamkari (iOS)

Everything below is copy-paste ready for App Store Connect → your app → **App Store** tab
(the public listing, distinct from TestFlight). Fill anything marked ⚠️.

---

## 1. App Review Information  (App Store Connect → App Review Information)
This is the single most important thing to get the app past review. A reviewer must be able to
sign in and see it working, and understand it's a legitimate retail tool.

**Sign-in required:** Yes
**Demo account** (put in the "User name" / "Password" fields — the app uses staff + PIN):
- Staff: **Owner**
- PIN: **1111**
- Store to pick at login: **Retail Unit 1**

**Notes to reviewer** (paste into the Notes box):
```
Sree Lakshmi Kalamkari is a retail inventory & billing app for a saree/textile business.
Staff sign in with a name + 4-digit PIN (no email/password).

To review:
1. On the login screen, choose staff "Owner", pick store "Retail Unit 1", enter PIN 1111.
2. Home shows the modules. Try "Point of Sale": search a product, add to cart, Checkout,
   choose Cash, Complete sale — this generates a GST tax invoice you can view/print.
3. Other modules: Dashboard, Products, Stock, Transfers, Invoices, Daily report, Settings.

The camera permission is used only to scan product barcodes at the till (Point of Sale →
Scan). Barcode scanning is optional for reviewing; manual product search works too.

The app connects to our own secured server over HTTPS. No third-party accounts are needed.
```

**Contact information:** ⚠️ your first name, last name, phone, and email.

---

## 2. Listing copy  (App Store → App Information / Version)

**Name:** Sree Lakshmi Kalamkari

**Subtitle** (30 chars max): `Stock & GST billing for stores`

**Promotional text** (170 chars): 
`Run your saree & textile counter and stockroom from your phone — barcode POS, GST invoices, stock control, transfers, and daily reports.`

**Keywords** (100 chars, comma-separated, no spaces):
`inventory,billing,POS,GST,invoice,stock,retail,barcode,textile,saree,shop,pos billing`

**Description:**
```
Sree Lakshmi Kalamkari is a complete inventory and billing app for a saree and textile business.

Run your counter and your stockroom from one app:

• Point of Sale — Search or scan products, build a cart, capture customer details, and complete a GST tax invoice in seconds. Print or share the invoice as a PDF.
• Barcode scanning — Use the phone camera to add products at the till and find stock instantly.
• Stock control — Receive goods, adjust for damage or loss, and transfer stock between warehouse and shops. Every change is recorded in a full audit trail.
• Transfers — Dispatch stock from the warehouse and confirm what arrives at the shop, with shortages captured automatically.
• GST invoicing — Gapless, sequential invoice numbers per store, CGST/SGST split, and amount in words.
• Dashboard — Stock value, low-stock alerts, stock by location, and recent activity at a glance.
• Daily reconciliation — What sold, GST collected, and the cash / UPI / card split for any day and store.
• Settings — Manage your business profile, staff PINs, categories, locations and product attributes.

Staff sign in with a simple 4-digit PIN tied to their store.
```

**Support URL** (required): ⚠️ a page users can reach for help. Simplest: `https://tantu-fmp9.onrender.com/privacy` works, or make a `/support` page.
**Marketing URL** (optional): leave blank or your site.
**Privacy Policy URL** (required): `https://tantu-fmp9.onrender.com/privacy`  ← page added; deploy tantu first.

**Category:** Primary = **Business** (Secondary optional = Productivity).
**Age rating:** answer the questionnaire → this app = **4+** (no objectionable content).

---

## 3. App Privacy  (App Store Connect → App Privacy → Get Started)
Declare data collection. For this app:

- **Contact Info → Name, Phone Number, Physical Address, Other (GSTIN):**
  Collected (optional customer details on invoices). Linked to the user? These are the merchant's
  customers, used for **App Functionality** only. NOT used for tracking, NOT for advertising.
- **Do you use data for tracking?** **No.**
- **Third-party analytics/ads SDKs?** **None.**
- Everything is **App Functionality**; nothing is used to track users across apps/sites.

(Camera is a permission, not "data collection" — no need to declare unless you store images. We don't.)

---

## 4. Screenshots  (required: at least one 6.7" iPhone set)
Apple needs real iPhone screenshots at the right size. **Easiest & best: take them on your own
iPhone from the TestFlight build** (they'll be the exact required dimensions automatically).

Capture these 5–6 screens (log in as Owner / 1111 first):
1. **Point of Sale** — product list with the cart bar showing a total.
2. **Checkout** — cart + payment options + total.
3. **A tax invoice** — the completed GST invoice view.
4. **Dashboard** — KPIs + low-stock + stock by location.
5. **Stock** — per-location stock list.
6. **Daily report** — the reconciliation with the payment split.

On iPhone: press **Side button + Volume Up** to screenshot. Upload the PNGs to the 6.7" slot in
App Store Connect. (You can reuse the same set for other sizes — Apple scales them.)

---

## 5. Before you submit — do these first
1. ⚠️ **Upgrade the backend off Render's free tier** (it sleeps ~15 min → 40s cold start). A public
   app on a sleeping server will get a poor review and a bad first impression.
2. Replace placeholder business details (GSTIN/address) in the app's Settings → Business profile.
3. Deploy the tantu site so `/privacy` (and `/support`) URLs are live.
4. Fill the App Review demo account + notes above (prevents an automatic rejection).

## 6. Honest expectation
An internal, single-business tool can hit Guideline **4.2** ("for a specific business — consider
Apple Business Manager custom app distribution"). If Apple pushes back, reply explaining it's a
commercial retail product; if they insist, the fallback is **Custom App / Business Manager** or
staying on **TestFlight** — both perfectly good for staff use.
