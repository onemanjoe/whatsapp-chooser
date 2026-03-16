const WHATSAPP_HOSTS = ['wa.me', 'api.whatsapp.com', 'web.whatsapp.com'];

// Intercept WhatsApp link navigations
chrome.webNavigation.onBeforeNavigate.addListener((details) => {
  if (details.frameId !== 0) return;

  let url;
  try {
    url = new URL(details.url);
  } catch {
    return;
  }

  if (!WHATSAPP_HOSTS.includes(url.hostname)) return;

  let phone = '';
  let text = '';

  if (url.hostname === 'wa.me') {
    phone = url.pathname.replace(/^\/+/, '');
    text = url.searchParams.get('text') || '';
  } else {
    phone = url.searchParams.get('phone') || '';
    text = url.searchParams.get('text') || '';
  }

  const chooserUrl = chrome.runtime.getURL('chooser.html') +
    `?phone=${encodeURIComponent(phone)}&text=${encodeURIComponent(text)}&original=${encodeURIComponent(details.url)}`;

  chrome.tabs.update(details.tabId, { url: chooserUrl });
});

// Handle messages from the chooser page
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'openWhatsApp') {
    chrome.runtime.sendNativeMessage(
      'com.whatsapp.chooser',
      { app: message.app, phone: message.phone, text: message.text },
      (response) => {
        if (chrome.runtime.lastError) {
          sendResponse({ success: false, error: chrome.runtime.lastError.message });
        } else {
          sendResponse(response || { success: true });
        }
      }
    );
    return true;
  }
});
