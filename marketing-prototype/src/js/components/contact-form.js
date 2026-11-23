const fieldLabels = {
  interest: "What you need help with",
  business: "Business type",
  channel: "Main conversation channel",
  challenge: "What you want to improve",
  name: "Name",
  email: "Email",
  phone: "Phone",
};

function getFormValue(form, name) {
  const field = form.elements.namedItem(name);

  if (field instanceof RadioNodeList) {
    return field.value;
  }

  return field?.value.trim() ?? "";
}

function initContactForm() {
  const root = document.querySelector("[data-contact-flow]");

  if (!root) return;

  const form = root.querySelector("form");
  const steps = [...root.querySelectorAll("[data-step]")];
  const review = root.querySelector("[data-review]");
  const summary = root.querySelector("[data-summary]");
  const success = root.querySelector("[data-success]");
  const progress = root.querySelector("[data-progress]");
  const error = root.querySelector("[data-error]");
  const next = root.querySelector("[data-next]");
  const back = root.querySelector("[data-back]");
  const submit = root.querySelector("[data-submit]");
  let currentStep = 1;

  const showError = (message) => {
    error.textContent = message;
    error.hidden = false;
  };

  const clearError = () => {
    error.hidden = true;
  };

  const validateStep = () => {
    const step = steps[currentStep - 1];
    const fields = [...step.querySelectorAll("input, textarea")];

    for (const field of fields) {
      if (!field.checkValidity()) {
        field.reportValidity();
        showError("Please answer this question before continuing.");
        return false;
      }
    }

    clearError();
    return true;
  };

  const renderSummary = () => {
    const names = ["interest", "business", "channel", "challenge", "name", "email", "phone"];
    summary.replaceChildren();

    names.forEach((name) => {
      const value = getFormValue(form, name);
      if (!value) return;

      const row = document.createElement("div");
      const term = document.createElement("dt");
      const detail = document.createElement("dd");
      const edit = document.createElement("button");
      term.textContent = fieldLabels[name];
      detail.textContent = value;
      edit.type = "button";
      edit.textContent = "Edit";
      edit.addEventListener("click", () => {
        const field = form.elements.namedItem(name);
        const targetStep = field.closest("[data-step]");
        currentStep = Number(targetStep.dataset.step);
        render();
        field.focus();
      });
      row.append(term, detail, edit);
      summary.append(row);
    });
  };

  const render = () => {
    steps.forEach((step, index) => {
      step.hidden = index + 1 !== currentStep;
    });
    review.hidden = currentStep !== steps.length + 1;
    back.hidden = currentStep === 1;
    next.hidden = currentStep > steps.length;
    submit.hidden = currentStep !== steps.length + 1;
    progress.textContent = currentStep > steps.length ? "Ready to send" : `Question ${currentStep} of ${steps.length}`;
  };

  next.addEventListener("click", () => {
    if (!validateStep()) return;

    currentStep += 1;
    if (currentStep > steps.length) renderSummary();
    render();
  });

  back.addEventListener("click", () => {
    clearError();
    currentStep = Math.max(1, currentStep - 1);
    render();
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    if (currentStep !== steps.length + 1) return;
    form.hidden = true;
    root.querySelector(".contact-flow__header").hidden = true;
    success.hidden = false;
    success.focus();
  });

  render();
}

export { initContactForm };
