const POSTS = [
  ["clearer-pages", "Make complex pages clear", "A practical approach to making a web page's purpose, information, and next step easier to understand.", "/media/diagnosis-workshop.jpg"],
  ["useful-prototypes", "Prototype the useful path", "How a working page prototype can reveal the order, language, and actions a digital experience needs.", "/smart-sorting-card_image.webp"],
  ["ai-agents-multiple-support-channels", "How Can AI Agents Handle My Customer Support Across Multiple Channels?", "Connect support channels while preserving case context, access controls, and human handoffs.", "/media/blog/ai-agents-multiple-support-channels-flat-v3.svg"],
  ["chatbots-vs-agentic-ai", "What's the Difference Between Regular Chatbots and Agentic AI?", "Compare scripted chatbots with AI agents that use approved tools, and verify what an agent completes.", "/media/blog/chatbots-vs-agentic-ai-flat-v3.svg"],
  ["can-ai-understand-customers", "Can AI Really Understand My Customers Like My Team Does?", "What AI can infer from customer context, where it may miss the mark, and how to measure real resolution.", "/media/blog/can-ai-understand-customers-flat-v3.svg"],
  ["measure-ai-support-time-savings", "How Much Time Can Agentic AI Save My Customer Service Team?", "Measure net support time saved, including review, corrections, handoffs, and repeat contacts.", "/media/blog/measure-ai-support-time-savings-flat-v3.svg"],
  ["what-omnichannel-engagement-means", "What Does Omnichannel Customer Engagement Actually Mean?", "Learn how shared case context keeps customers from repeating their story across channels.", "/media/blog/what-omnichannel-engagement-means-flat-v3.svg"],
  ["start-ai-agents-business", "How Do I Get Started With AI Agents for My Business?", "Start with one bounded support task, test failure paths, and set a clear pilot decision.", "/media/blog/start-ai-agents-business-flat-v3.svg"],
  ["ai-agents-customer-service-jobs", "Will AI Agents Replace My Customer Service Jobs?", "Explore how AI agents may change service work, training, and the way teams measure outcomes.", "/media/blog/ai-agents-customer-service-jobs-flat-v3.svg"],
  ["customer-preferences-ai-or-human-support", "How Do Customers Feel About Talking to AI Instead of Humans?", "Customer preferences vary by task. Learn how to offer choice and measure the full experience.", "/media/blog/customer-preferences-ai-or-human-support-flat-v3.svg"],
  ["choose-omnichannel-ai-platform", "What Should I Look for in an Omnichannel AI Platform?", "Evaluate platform integrations, handoffs, permissions, data practices, and costs.", "/media/blog/choose-omnichannel-ai-platform-flat-v3.svg"],
  ["ai-contact-center-customer-satisfaction", "How Does AI-Powered Contact Center Automation Improve Customer Satisfaction?", "AI can improve satisfaction when it reduces effort, resolves requests, and transfers difficult cases well.", "/media/blog/ai-contact-center-customer-satisfaction-flat-v3.svg"],
  ["ai-agents-beyond-faqs", "Can AI Agents Actually Solve Problems or Just Answer FAQs?", "AI agents can complete bounded support tasks beyond FAQs. Learn how to verify an action.", "/media/blog/ai-agents-beyond-faqs-flat-v3.svg"],
  ["ai-engagement-customer-data-security", "How Secure Is Customer Data With AI Engagement Platforms?", "Review data flows, permissions, prompt injection, vendor evidence, and deletion practices.", "/media/blog/ai-engagement-customer-data-security-flat-v3.svg"],
].map(([slug, title, description, image]) => ({ slug, title, description, image }));

function createStoryCard(post) {
  const slide = document.createElement("div");
  slide.className = "carousel__slide";
  slide.setAttribute("data-carousel-slide", "");

  const card = document.createElement("a");
  card.className = "card card--interactive surface-container-low related-post-carousel__card";
  card.href = `/blog/${post.slug}.html`;
  card.setAttribute("aria-label", `Read ${post.title}`);

  const media = document.createElement("figure");
  media.className = "card__media surface-variant";
  const image = document.createElement("img");
  image.src = post.image;
  image.alt = "";
  image.width = 341;
  image.height = 222;
  image.loading = "lazy";
  media.append(image);

  const body = document.createElement("div");
  body.className = "card__body";
  const title = document.createElement("h3");
  title.className = "h4 card__title";
  title.textContent = post.title;
  const description = document.createElement("p");
  description.className = "card__text";
  description.textContent = post.description;
  body.append(title, description);

  card.append(media, body);
  slide.append(card);
  return slide;
}

function createRelatedPostCarousel(currentPost, recommendations) {
  const section = document.createElement("section");
  section.className = "related-post-carousel";
  section.setAttribute("data-carousel", "");
  section.setAttribute("aria-labelledby", `related-post-carousel-title-${currentPost.slug}`);

  const container = document.createElement("div");
  container.className = "container stack related-post-carousel__container";

  const heading = document.createElement("h2");
  heading.className = "related-post-carousel__title";
  heading.id = `related-post-carousel-title-${currentPost.slug}`;
  heading.textContent = "Related stories";

  const carousel = document.createElement("div");
  carousel.className = "carousel related-post-carousel__track-window";
  const viewport = document.createElement("div");
  viewport.className = "carousel__viewport";
  viewport.setAttribute("data-carousel-viewport", "");
  const track = document.createElement("div");
  track.className = "carousel__track";
  track.setAttribute("data-carousel-track", "");
  recommendations.forEach((post) => track.append(createStoryCard(post)));
  viewport.append(track);

  const controls = document.createElement("div");
  controls.className = "carousel__controls related-post-carousel__controls";
  const actions = document.createElement("div");
  actions.className = "carousel__actions";
  const previous = document.createElement("button");
  previous.className = "carousel__button carousel__button--icon";
  previous.type = "button";
  previous.setAttribute("data-carousel-prev", "");
  previous.setAttribute("aria-label", "Show previous stories");
  const previousIcon = document.createElement("span");
  previousIcon.className = "material-icons-round";
  previousIcon.setAttribute("aria-hidden", "true");
  previousIcon.textContent = "chevron_left";
  previous.append(previousIcon);
  const next = document.createElement("button");
  next.className = "carousel__button carousel__button--icon";
  next.type = "button";
  next.setAttribute("data-carousel-next", "");
  next.setAttribute("aria-label", "Show next stories");
  const nextIcon = document.createElement("span");
  nextIcon.className = "material-icons-round";
  nextIcon.setAttribute("aria-hidden", "true");
  nextIcon.textContent = "chevron_right";
  next.append(nextIcon);
  actions.append(previous, next);

  const progress = document.createElement("progress");
  progress.className = "related-post-carousel__progress";
  progress.max = 100;
  progress.value = 0;
  progress.setAttribute("aria-label", "Related stories carousel position");
  controls.append(actions, progress);

  carousel.append(viewport, controls);
  container.append(heading, carousel);
  section.append(container);
  return { section, progress };
}

export function initRelatedPostCarousel(scope = document) {
  scope.querySelectorAll(".blog-article").forEach((article) => {
    if (article.nextElementSibling?.classList.contains("related-post-carousel")) return;

    const slug = window.location.pathname.split("/").pop()?.replace(/\.html$/, "");
    const currentPost = POSTS.find((post) => post.slug === slug);
    if (!currentPost) return;

    const related = POSTS.filter((post) => post.slug !== slug);
    const startAt = POSTS.findIndex((post) => post.slug === slug);
    const recommendations = [...related.slice(startAt), ...related.slice(0, startAt)].slice(0, 4);
    const { section, progress } = createRelatedPostCarousel(currentPost, recommendations);
    article.after(section);

    const updateProgress = () => {
      const viewport = section.querySelector("[data-carousel-viewport]");
      const track = section.querySelector("[data-carousel-track]");
      const slides = [...section.querySelectorAll("[data-carousel-slide]")];
      if (!viewport || !track || !slides.length) return;

      const maxOffset = Math.max(0, track.scrollWidth - viewport.clientWidth);
      const offsets = slides.map((slide) => Math.min(slide.offsetLeft, maxOffset));
      const lastIndex = offsets.findIndex((offset) => offset >= maxOffset);
      const maxIndex = lastIndex === -1 ? slides.length - 1 : lastIndex;
      const index = Number(section.dataset.carouselIndex || 0);
      progress.value = maxIndex === 0 ? 100 : ((index + 1) / (maxIndex + 1)) * 100;
    };

    const observer = new MutationObserver(updateProgress);
    observer.observe(section, { attributes: true, attributeFilter: ["data-carousel-index"] });
    window.addEventListener("resize", updateProgress, { passive: true });
    progress.value = 0;
  });
}
