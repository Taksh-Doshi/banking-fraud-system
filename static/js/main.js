(() => {
    const root = document.documentElement;
    const savedTheme = window.localStorage.getItem("securebank-theme");
    if (savedTheme === "light" || savedTheme === "dark") {
        root.dataset.theme = savedTheme;
    }

    const themeButton = document.getElementById("theme-toggle");
    themeButton?.addEventListener("click", () => {
        const theme = root.dataset.theme === "light" ? "dark" : "light";
        root.dataset.theme = theme;
        window.localStorage.setItem("securebank-theme", theme);
    });

    const menuButton = document.getElementById("menu-toggle");
    const sidebar = document.getElementById("sidebar");
    menuButton?.addEventListener("click", () => sidebar?.classList.toggle("is-open"));

    const role = document.getElementById("login-role");
    const label = document.getElementById("login-id-label");
    const identifier = document.querySelector('input[name="identifier"]');
    document.querySelectorAll("[data-role-choice]").forEach((button) => {
        button.addEventListener("click", () => {
            const selected = button.dataset.roleChoice;
            if (role) role.value = selected;
            if (label) label.textContent = selected === "staff" ? "Staff email" : "Customer ID";
            if (identifier) {
                identifier.placeholder = selected === "staff"
                    ? "name@fraudbank.test"
                    : "CUST001";
            }
            document.querySelectorAll("[data-role-choice]").forEach((item) => {
                item.classList.toggle("active", item === button);
            });
        });
    });

    const typeInput = document.getElementById("transaction-type");
    const recipientGroup = document.querySelector("[data-recipient-group]");
    const recipientInput = document.getElementById("recipient");
    document.querySelectorAll("[data-transaction-tab]").forEach((button) => {
        button.addEventListener("click", () => {
            const selected = button.dataset.transactionTab;
            if (typeInput) typeInput.value = selected;
            const isTransfer = selected === "TRANSFER";
            if (recipientGroup) recipientGroup.hidden = !isTransfer;
            if (recipientInput) recipientInput.required = isTransfer;
            document.querySelectorAll("[data-transaction-tab]").forEach((item) => {
                item.classList.toggle("active", item === button);
            });
        });
    });
    if (typeInput && recipientGroup) {
        const isTransfer = typeInput.value === "TRANSFER";
        recipientGroup.hidden = !isTransfer;
        if (recipientInput) recipientInput.required = isTransfer;
    }

    const modal = document.getElementById("transaction-modal");
    const reviewButton = document.getElementById("review-transaction");
    const cancelButton = document.getElementById("cancel-transaction");
    const formatAmount = (raw) => {
        const [rawWhole, rawFraction = ""] = raw.split(".");
        const negative = rawWhole.startsWith("-");
        const whole = (negative ? rawWhole.slice(1) : rawWhole)
            .replace(/^0+(?=\d)/, "");
        const grouped = whole.length > 3
            ? `${whole.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ",")},${whole.slice(-3)}`
            : whole;
        return `₹${negative ? "-" : ""}${grouped}.${(rawFraction + "00").slice(0, 2)}`;
    };
    reviewButton?.addEventListener("click", () => {
        const form = document.getElementById("transaction-form");
        if (!(form instanceof HTMLFormElement) || !form.reportValidity()) return;
        const type = typeInput?.value ?? "";
        const amount = document.getElementById("amount");
        const recipient = document.getElementById("recipient");
        const confirmType = document.getElementById("confirm-type");
        const confirmAmount = document.getElementById("confirm-amount");
        const confirmRecipient = document.getElementById("confirm-recipient");
        if (confirmType) confirmType.textContent = type.replaceAll("_", " ");
        if (confirmAmount && amount instanceof HTMLInputElement) {
            confirmAmount.textContent = formatAmount(amount.value);
        }
        if (confirmRecipient) {
            confirmRecipient.textContent = recipient instanceof HTMLInputElement
                ? recipient.value || "—"
                : "—";
        }
        if (modal) modal.hidden = false;
    });
    cancelButton?.addEventListener("click", () => {
        if (modal) modal.hidden = true;
    });
    modal?.addEventListener("click", (event) => {
        if (event.target === modal) modal.hidden = true;
    });
})();
