function getControlledPanels(input, root) {
  return (input.getAttribute("aria-controls") || "")
    .split(/\s+/)
    .filter(Boolean)
    .map((id) => root.querySelector(`#${CSS.escape(id)}`))
    .filter(Boolean);
}

function applySegmentedState(group, input, inputs) {
  const value = input.value;
  group.dataset.segmentedValue = value;

  inputs.forEach((option) => {
    const isActive = option === input;
    option.checked = isActive;
    option.closest(".billing-toggle__option")?.classList.toggle("billing-toggle__option--active", isActive);

    getControlledPanels(option, group.closest("form") || document).forEach((panel) => {
      panel.hidden = !isActive;
    });
  });
}

function moveBillingFocus(group, input, inputs, direction) {
  const index = inputs.indexOf(input);
  if (index === -1) return;

  const nextIndex = direction === "first"
    ? 0
    : direction === "last"
      ? inputs.length - 1
      : (index + direction + inputs.length) % inputs.length;
  const nextInput = inputs[nextIndex];

  nextInput.checked = true;
  nextInput.dispatchEvent(new Event("change", { bubbles: true }));
  nextInput.focus();
}

export function initSegmentedControls(root = document) {
  const groups = root.querySelectorAll("[data-segmented-control]");

  groups.forEach((group) => {
    const inputs = [...group.querySelectorAll("input[type='radio']")];

    if (!inputs.length) {
      return;
    }

    const selected = inputs.find((input) => input.checked) || inputs[0];
    applySegmentedState(group, selected, inputs);

    inputs.forEach((input) => {
      input.addEventListener("keydown", (event) => {
        const direction = {
          ArrowRight: 1,
          ArrowDown: 1,
          ArrowLeft: -1,
          ArrowUp: -1,
          Home: "first",
          End: "last",
        }[event.key];

        if (direction === undefined) return;

        event.preventDefault();
        moveBillingFocus(group, input, inputs, direction);
      });

      input.addEventListener("change", () => {
        applySegmentedState(group, input, inputs);
        group.dispatchEvent(
          new CustomEvent("segmented-change", {
            bubbles: true,
            detail: { value: input.value, input },
          }),
        );
      });
    });
  });
}
