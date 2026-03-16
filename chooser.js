const params = new URLSearchParams(window.location.search);
const phone = params.get('phone') || '';
const text = params.get('text') || '';

const phoneInfo = document.getElementById('phoneInfo');
if (phone) {
  phoneInfo.textContent = `Contatto: +${phone.replace(/^\+/, '')}`;
} else {
  phoneInfo.textContent = 'Apri conversazione WhatsApp';
}

function openWith(appName) {
  const errorMsg = document.getElementById('errorMsg');
  errorMsg.style.display = 'none';

  // Call native messaging host directly (no background script needed)
  chrome.runtime.sendNativeMessage(
    'com.whatsapp.chooser',
    { app: appName, phone, text },
    (response) => {
      if (chrome.runtime.lastError) {
        errorMsg.textContent = `Errore: ${chrome.runtime.lastError.message}`;
        errorMsg.style.display = 'block';
        return;
      }
      if (response && !response.success) {
        errorMsg.textContent = `Errore: ${response.error}`;
        errorMsg.style.display = 'block';
        return;
      }
      if (window.history.length > 1) {
        window.history.back();
      }
    }
  );
}

document.getElementById('btnWhatsApp').addEventListener('click', () => openWith('WhatsApp'));
document.getElementById('btnBusiness').addEventListener('click', () => openWith('WhatsApp Business'));
document.getElementById('btnCancel').addEventListener('click', () => {
  if (window.history.length > 1) window.history.back();
  else window.close();
});
