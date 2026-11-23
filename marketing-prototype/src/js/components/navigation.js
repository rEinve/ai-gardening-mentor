function getNavigationRoots(scope = document) {
  return Array.from(scope.querySelectorAll('.nav-main'));
}

function getDropdown(trigger) {
  return trigger.parentElement?.querySelector('.nav-main__dropdown') ?? null;
}

function ensureId(element, prefix, index) {
  if (!element.id) {
    element.id = `${prefix}-${index}`;
  }

  return element.id;
}

function setDropdownState(trigger, open) {
  const dropdown = getDropdown(trigger);

  if (!dropdown) return;

  trigger.setAttribute('aria-expanded', String(open));
  dropdown.toggleAttribute('data-open', open);
  dropdown.hidden = !open;
}

function setDrawerState(toggle, drawer, open, { restoreFocus = true } = {}) {
  if (!drawer) return;

  toggle.setAttribute('aria-expanded', String(open));
  toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  drawer.toggleAttribute('data-open', open);
  drawer.hidden = !open;

  if (open) {
    requestAnimationFrame(() => {
      drawer.querySelector('a[href], button:not([disabled])')?.focus();
    });
  } else if (restoreFocus) {
    toggle.focus();
  }
}

/**
 * Adds the small amount of state management needed by the navigation
 * component. Links remain ordinary links; only disclosures receive JS.
 */
export function initMainNavigation(scope = document) {
  getNavigationRoots(scope).forEach((root, rootIndex) => {
    if (root.dataset.navigationReady === 'true') return;

    root.dataset.navigationReady = 'true';
    const dropdownTriggers = Array.from(root.querySelectorAll('.nav-main__link--dropdown'));
    const toggle = root.querySelector('.nav-main__toggle');
    const drawerId = toggle?.getAttribute('aria-controls');
    const drawer = drawerId ? document.getElementById(drawerId) : null;
    const usesMobileBottomNavigation = root.classList.contains('nav-main--bottom-mobile');
    let previousScrollY = window.scrollY;

    const hero = document.querySelector('#top');
    const setScrolledState = (isScrolled) => {
      root.classList.toggle('nav-main--scrolled', isScrolled);
    };

    if (hero && 'IntersectionObserver' in window) {
      const heroObserver = new IntersectionObserver(
        ([entry]) => setScrolledState(!entry.isIntersecting),
        { threshold: 0 },
      );

      heroObserver.observe(hero);
    } else {
      const updateScrollState = () => {
        setScrolledState(window.scrollY > 0);
      };

      updateScrollState();
      window.addEventListener('scroll', updateScrollState, { passive: true });
    }

    if (usesMobileBottomNavigation) {
      const updateMobileBottomNavigation = () => {
        const currentScrollY = window.scrollY;
        const drawerIsOpen = toggle?.getAttribute('aria-expanded') === 'true';
        const shouldHide = currentScrollY > 0 && currentScrollY > previousScrollY && !drawerIsOpen;

        root.classList.toggle('nav-main--scroll-hidden', shouldHide);
        previousScrollY = currentScrollY;
      };

      window.addEventListener('scroll', updateMobileBottomNavigation, { passive: true });
    }

    dropdownTriggers.forEach((trigger, triggerIndex) => {
      const dropdown = getDropdown(trigger);
      if (!dropdown) return;

      const triggerId = ensureId(trigger, `nav-trigger-${rootIndex}`, triggerIndex);
      trigger.setAttribute('aria-controls', ensureId(dropdown, `nav-dropdown-${rootIndex}`, triggerIndex));
      dropdown.setAttribute('aria-labelledby', triggerId);
      setDropdownState(trigger, false);

      trigger.addEventListener('click', () => {
        const shouldOpen = trigger.getAttribute('aria-expanded') !== 'true';
        dropdownTriggers.forEach((candidate) => setDropdownState(candidate, candidate === trigger && shouldOpen));
      });
    });

    if (toggle && drawer) {
      setDrawerState(toggle, drawer, false, { restoreFocus: false });
      toggle.addEventListener('click', () => {
        const willOpen = toggle.getAttribute('aria-expanded') !== 'true';
        setDrawerState(toggle, drawer, willOpen);
        root.classList.toggle('nav-main--scroll-hidden', false);
      });
    }

    root.addEventListener('keydown', (event) => {
      if (event.key !== 'Escape') return;

      const openTrigger = dropdownTriggers.find((trigger) => trigger.getAttribute('aria-expanded') === 'true');

      if (openTrigger) {
        setDropdownState(openTrigger, false);
        openTrigger.focus();
      } else if (toggle && drawer && !drawer.hidden) {
        setDrawerState(toggle, drawer, false);
      }
    });

    document.addEventListener('click', (event) => {
      if (root.contains(event.target)) return;
      dropdownTriggers.forEach((trigger) => setDropdownState(trigger, false));
    });
  });
}
