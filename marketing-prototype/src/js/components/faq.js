export function initFAQ() {
  document.querySelectorAll('.faq__item').forEach((item) => {
    const icon = item.querySelector('.faq__toggle-icon');

    if (!icon) return;

    const syncIcon = () => {
      icon.textContent = item.open ? 'remove' : 'add';
    };

    item.addEventListener('toggle', syncIcon);
    syncIcon();
  });
}
