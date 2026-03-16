# Privacy Policy — WhatsApp Chooser

**Last updated:** March 16, 2026

## Data Collection

WhatsApp Chooser does **not** collect, store, transmit, or share any user data. Period.

## What the extension does

- Intercepts navigation to `wa.me`, `api.whatsapp.com`, and `web.whatsapp.com` URLs
- Extracts the phone number and message text from the URL to display them in the chooser popup
- Passes the phone number and message text to a local native messaging host to open the selected WhatsApp app

All processing happens **locally on your device**. No data is sent to any server, third party, or external service.

## Permissions used

| Permission | Why |
|---|---|
| `webNavigation` | To detect when you navigate to a WhatsApp link |
| `nativeMessaging` | To communicate with the local native host that opens the correct app |
| Host permissions (`wa.me`, etc.) | To intercept navigation to WhatsApp domains |

## Third-party services

None. This extension has no analytics, no tracking, no ads, and no network requests.

## Contact

If you have questions about this privacy policy, open an issue on [GitHub](https://github.com/onemanjoe/whatsapp-chooser/issues).
