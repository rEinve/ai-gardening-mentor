import "@material-design-icons/font/round.css";
import "themeui-lab/styles.css";
import { initTabs, initCarousels } from "themeui-lab";
import "./theme.scss";
import { initMainNavigation } from "./js/components/navigation.js";
import { initPricingTable } from "./js/components/pricing-table.js";
import { initSegmentedControls } from "./js/components/billing-toggle.js";
import { initFAQ } from "./js/components/faq.js";
import { initFooterReveal } from "./js/components/footer-reveal.js";
import { initContactForm } from "./js/components/contact-form.js";
import { initArticleToc } from "./js/components/article-toc.js";
import { initRelatedPostCarousel } from "./js/components/related-post-carousel.js";

initMainNavigation();
initTabs();
const blogCategoryPanelId = window.location.hash.slice(1);
if (blogCategoryPanelId.startsWith("blog-panel-")) {
  const blogCategoryPanel = document.getElementById(blogCategoryPanelId);
  const blogCategoryTabId = blogCategoryPanel?.getAttribute("aria-labelledby");
  const blogCategoryTab = blogCategoryTabId ? document.getElementById(blogCategoryTabId) : null;

  if (blogCategoryPanel && blogCategoryTab) {
    blogCategoryTab.click();
    blogCategoryPanel.scrollIntoView({ block: "start" });
  }
}
initSegmentedControls();
initPricingTable();
initFAQ();
initFooterReveal();
initContactForm();
initArticleToc();
initRelatedPostCarousel();
initCarousels();
