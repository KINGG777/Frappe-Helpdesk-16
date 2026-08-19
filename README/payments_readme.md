# ERPNext + Payments + Razorpay

This README explains how to install the Frappe Payments app on ERPNext and configure Razorpay for online payments.

---

## 1. Install ERPNext

Create a fresh ERPNext/Frappe server and site.

Make sure ERPNext is running correctly before installing the Payments app.

---

# 2. Install Payments App

There are two ways to install the Payments app.

## Option A — New ERPNext Installation

If you are building a new Docker image, add Payments to `apps.json` using the `develop` branch.

Example:

```json
[
  {
    "url": "<PAYMENTS_APP_REPOSITORY_URL>",
    "branch": "develop"
  }
]
```

Build/deploy the ERPNext image with the Payments app.

Then install Payments on the ERPNext site:

```bash
docker compose exec backend bench --site <YOUR_SITE> install-app payments
```

Verify:

```bash
docker compose exec backend bench --site <YOUR_SITE> list-apps
```

Expected:

```text
frappe
erpnext
payments
```

---

## Option B — Existing Running ERPNext

If ERPNext is already running and you want to add Payments without rebuilding the image:

```bash
docker compose exec backend bench get-app --branch develop https://github.com/frappe/payments
```

Then install Payments on the site:

```bash
docker compose exec backend bench --site <YOUR_SITE> install-app payments
```

Verify:

```bash
docker compose exec backend bench --site <YOUR_SITE> list-apps
```

Expected:

```text
frappe
erpnext
payments
```

> **Note:** With Docker, installing an app using `bench get-app` into a running container may be lost if the container/image is recreated. For a permanent Docker deployment, adding the app to `apps.json` and rebuilding the image is recommended.

---

# 3. ERPNext Email Configuration

Go to:

**ERPNext → Email Account**

Configure your outgoing email account/SMTP.

This account is used to send Payment Request emails to customers.

---

# 4. Razorpay Configuration

Use **Razorpay Test Mode** for testing.

From the Razorpay Dashboard, get:

```text
Test API Key
Test API Secret
```

In ERPNext, open:

**Razorpay Settings**

Configure:

```text
API Key        = Razorpay Test Key
API Secret     = Razorpay Test Secret
Webhook Secret = <YOUR_WEBHOOK_SECRET>
```

Save the settings.

---

# 5. Razorpay Webhook

In the Razorpay Dashboard:

**Test Mode → Webhooks → Add Webhook**

Use the following webhook URL:

```text
https://helpdesk.pkdevops.online/api/method/payments.payment_gateways.doctype.razorpay_settings.webhook.razorpay_webhook
```

Set the webhook secret to the **same value** used in:

**ERPNext → Razorpay Settings → Webhook Secret**

Save the webhook.

---

# 6. ERPNext Payment Gateway

In ERPNext configure:

**Payment Gateway → Razorpay**

Configure the Razorpay payment account for the correct company.

Example:

```text
Company: Maa Industries Pvt Ltd
Account: Razorpay - MIPL
Currency: INR
```

---

# 7. Payment Request Email

Create a Sales Invoice.

Then:

**Sales Invoice → Create → Payment Request**

The Payment Request email should contain the payment URL.

Example:

```html
<p>Please click the link below to make your payment.</p>

<p>
<a href="{{ payment_url }}">Click Here to Pay</a>
</p>
```

The `payment_url` is generated dynamically for each Payment Request.

Do not hard-code a payment token or payment URL.

---

# 8. Testing

## Step 1 — Create Sales Invoice

Create and submit a Sales Invoice.

Example:

```text
Customer: XYZ Technologies
Item: Laptop
Amount: ₹200
```

---

## Step 2 — Create Payment Request

From the Sales Invoice:

**Create → Payment Request**

Configure:

```text
Payment Request Type: Inward
Party Type: Customer
Reference Doctype: Sales Invoice
Reference Name: <Sales Invoice>
Amount: ₹200
```

Submit the Payment Request.

---

## Step 3 — Send Payment Email

Send the Payment Request email.

The customer should receive an email containing:

```text
Click Here to Pay
```

ERPNext automatically processes the email through the Email Queue.

---

## Step 4 — Open Payment Link

Click:

```text
Click Here to Pay
```

Razorpay Checkout should open.

---

## Step 5 — Make Test Payment

Complete the payment using **Razorpay Test Mode**.

Do not use a real payment/card for testing.

---

## Step 6 — Verify Payment

After completing the test payment, check:

```text
Payment Request
Payment Entry
Sales Invoice
```

Verify that the payment/status has been updated correctly.

---

# 9. Complete Payment Flow

```text
ERPNext
   ↓
Sales Invoice
   ↓
Payment Request
   ↓
Email with payment_url
   ↓
Razorpay Checkout
   ↓
Test Payment
   ↓
Razorpay Webhook
   ↓
Payments App
   ↓
ERPNext
   ↓
Payment Status / Payment Entry
```

---

# 10. Required Configuration

```text
ERPNext
├── Email Account
├── Payment Gateway
├── Payment Account
└── Payment Request

Payments App
└── Installed on ERPNext site

Razorpay
├── Test API Key
├── Test API Secret
├── Webhook URL
└── Webhook Secret
```

## Razorpay Webhook URL

```text
https://helpdesk.pkdevops.online/api/method/payments.payment_gateways.doctype.razorpay_settings.webhook.razorpay_webhook
```

---

# 11. Production

After testing is completed successfully:

```text
Razorpay Test Mode
        ↓
Razorpay Live Mode
```

Replace the Test API credentials with the Live API credentials and configure the Live webhook separately.

Never commit API secrets or webhook secrets to GitHub.
