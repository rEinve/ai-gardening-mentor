export function initPricingTable(root = document) {
  const pricingTable = root.querySelector(".pricing-table");

  if (!pricingTable) {
    return;
  }

  const billingControl = pricingTable.querySelector("[data-segmented-control]");
  const prices = [...pricingTable.querySelectorAll("[data-annual-price]")];

  billingControl?.addEventListener("segmented-change", (event) => {
    const billing = event.detail.value;

    prices.forEach((price) => {
      price.textContent = price.dataset[`${billing}Price`];
    });
  });
}
