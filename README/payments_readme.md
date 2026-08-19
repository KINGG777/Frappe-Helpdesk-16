# ERPNext + Payments + Razorpay

## 1. Install ERPNext

Create a fresh ERPNext server and site.

Make sure ERPNext is working correctly before installing the Payments app.

---

## 2. Install Payments App

Add the Payments app to `apps.json` using the `develop` branch.

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

Then install the Payments app on the ERPNext site:

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

## 3. ERPNext Email Configuration

Go to:

**ERPNext → Email Account**

Configure the outgoing email account/SMTP.

This email account is used by ERPNext to send Payment Request emails.

---

## 4. Razorpay Configuration

Use **Razorpay Test Mode** for testing.

From the Razorpay Dashboard, get:

```text
Test API Key
Test API Secret
```

In ERPNext, go to:

**Razorpay Settings**

Set:

```text
API Key        = Razorpay Test Key
API Secret     = Razorpay Test Secret
Webhook Secret = <YOUR_WEBHOOK_SECRET>
```

Save the settings.

---

## 5. Razorpay Webhook

In the Razorpay Dashboard:

**Test Mode → Webhooks → Add Webhook**

Use this webhook URL:

```text
https://helpdesk.pkdevops.online/api/method/payments.payment_gateways.doctype.razorpay_settings.webhook.razorpay_webhook
```

Set the webhook secret to the **same secret** configured in:

**ERPNext → Razorpay Settings → Webhook Secret**

Save the webhook.

---

## 6. ERPNext Payment Gateway

Configure the Razorpay Payment Gateway in ERPNext:

**Payment Gateway → Razorpay**

Configure the Razorpay payment account for the correct company.

Example:

```text
Company: Maa Industries Pvt Ltd
Account: Razorpay - MIPL
Currency: INR
```

---

## 7. Payment Request Email

Create a Sales Invoice.

Then:

**Sales Invoice → Create → Payment Request**

The Payment Request email should contain the generated payment URL:

```html
<p>Please click the link below to make your payment.</p>

<p>
<a href="{{ payment_url }}">Click Here to Pay</a>
</p>
```

Do not hard-code a payment token or payment URL.

The `payment_url` is generated dynamically for each Payment Request.

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

## Step 2 — Create Payment Request

From the Sales Invoice:

**Create → Payment Request**

Use:

```text
Payment Request Type: Inward
Party Type: Customer
Reference Doctype: Sales Invoice
Reference Name: <Sales Invoice>
Amount: ₹200
```

## Step 3 — Send Payment Email

Send the Payment Request email.

The customer should receive an email containing:

```text
Click Here to Pay
```

The email is processed automatically by ERPNext's email queue.

## Step 4 — Open Payment Link

Click:

```text
Click Here to Pay
```

Razorpay Checkout should open.

## Step 5 — Make Test Payment

Complete the payment using **Razorpay Test Mode**.

## Step 6 — Verify Payment

After the test payment, check:

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
