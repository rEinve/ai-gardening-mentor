function slugify(value) {
  return value
    .toLocaleLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

export function initArticleToc(scope = document) {
  scope.querySelectorAll(".blog-article").forEach((article) => {
    const body = article.querySelector(".post-content");
    const nav = article.querySelector(".takeaways .blog-article__toc");
    if (!body || !nav || nav.childElementCount) return;

    const headings = [...body.querySelectorAll("h2")];
    if (!headings.length) return;

    const list = document.createElement("ul");
    list.className = "blog-article__toc-list stack";

    headings.forEach((heading) => {
      if (!heading.id) {
        const baseId = slugify(heading.textContent) || "section";
        let id = baseId;
        let suffix = 2;
        while (document.getElementById(id)) id = `${baseId}-${suffix++}`;
        heading.id = id;
      }

      const item = document.createElement("li");
      const link = document.createElement("a");
      link.href = `#${heading.id}`;
      link.textContent = heading.textContent.trim();
      item.append(link);
      list.append(item);
    });

    const eyebrow = document.createElement("p");
    eyebrow.className = "cluster items-middle blog-article__toc-eyebrow";
    eyebrow.textContent = "On this post";

    const title = document.createElement("p");
    title.className = "blog-article__toc-title";
    title.textContent = "Contents";

    nav.append(eyebrow, title, list);
  });
}
