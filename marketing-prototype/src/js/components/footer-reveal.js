export function initFooterReveal(scope = document) {
  const footer = scope.querySelector('.site-footer');

  if (!footer) return;

  const syncFooterHeight = () => {
    const footerHeight = footer.getBoundingClientRect().height;
    const footerMargin = parseFloat(getComputedStyle(footer).marginBlockStart) || 0;
    const revealSpace = Math.ceil(footerHeight + footerMargin);

    document.documentElement.style.setProperty('--site-footer-height', `${revealSpace}px`);
  };

  syncFooterHeight();

  if ('ResizeObserver' in window) {
    const observer = new ResizeObserver(syncFooterHeight);
    observer.observe(footer);
  } else {
    window.addEventListener('resize', syncFooterHeight, { passive: true });
  }
}
