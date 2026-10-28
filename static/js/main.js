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
            const customerLinks = document.getElementById("customer-links");
            if (customerLinks) {
                customerLinks.hidden = selected === "staff";
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

    // Password visibility toggle
    const EYE_SVG = '<svg class="icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>';
    const EYE_OFF_SVG = '<svg class="icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9.88 9.88a3 3 0 1 0 4.24 4.24"/><path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.526 13.526 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/><line x1="2" y1="2" x2="22" y2="22"/></svg>';

    document.addEventListener("click", (e) => {
        const toggleBtn = e.target.closest("[data-password-toggle], .eye-toggle");
        if (!toggleBtn) return;
        e.preventDefault();
        const targetId = toggleBtn.dataset.target;
        let input = targetId ? document.getElementById(targetId) : null;
        if (!input) {
            input = toggleBtn.closest(".input-wrap")?.querySelector("input");
        }
        if (!input) return;

        const isPassword = input.type === "password";
        input.type = isPassword ? "text" : "password";
        if (isPassword) {
            input.dataset.originalPassword = "true";
        } else {
            delete input.dataset.originalPassword;
        }
        toggleBtn.setAttribute("aria-pressed", isPassword ? "true" : "false");
        toggleBtn.setAttribute("aria-label", isPassword ? "Hide password" : "Show password");
        toggleBtn.innerHTML = isPassword ? EYE_OFF_SVG : EYE_SVG;
        input.focus();
    });

    // Reset password inputs on back/forward cache navigation
    window.addEventListener("pageshow", () => {
        document.querySelectorAll('input[data-original-password="true"]').forEach((input) => {
            input.type = "password";
            delete input.dataset.originalPassword;
        });
        document.querySelectorAll("[data-password-toggle], .eye-toggle").forEach((btn) => {
            btn.setAttribute("aria-pressed", "false");
            btn.setAttribute("aria-label", "Show password");
            btn.innerHTML = EYE_SVG;
        });
    });

    // Copy to clipboard helper with execCommand fallback
    const copyTextToClipboard = (text) => {
        if (navigator.clipboard && window.isSecureContext) {
            return navigator.clipboard.writeText(text);
        }
        return new Promise((resolve, reject) => {
            const textArea = document.createElement("textarea");
            textArea.value = text;
            textArea.style.position = "fixed";
            textArea.style.left = "-999999px";
            textArea.style.top = "-999999px";
            textArea.setAttribute("readonly", "");
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            try {
                const successful = document.execCommand("copy");
                document.body.removeChild(textArea);
                if (successful) resolve();
                else reject(new Error("execCommand copy failed"));
            } catch (err) {
                document.body.removeChild(textArea);
                reject(err);
            }
        });
    };

    const CHECK_SVG = '<svg class="icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12 4 4L19 6"/></svg>';

    document.addEventListener("click", async (e) => {
        const copyBtn = e.target.closest(".copy-btn, [data-copy-target]");
        if (!copyBtn) return;
        e.preventDefault();
        const targetId = copyBtn.dataset.copyTarget;
        let textToCopy = "";
        if (targetId) {
            const targetEl = document.getElementById(targetId);
            if (targetEl) {
                textToCopy = targetEl.value || targetEl.textContent || "";
            }
        }
        if (!textToCopy && copyBtn.dataset.copyText) {
            textToCopy = copyBtn.dataset.copyText;
        }
        textToCopy = textToCopy.trim();
        if (!textToCopy) return;

        try {
            await copyTextToClipboard(textToCopy);
            const originalHtml = copyBtn.innerHTML;
            copyBtn.innerHTML = `${CHECK_SVG}<span>Copied!</span>`;
            copyBtn.classList.add("copied");

            let liveRegion = document.getElementById("copy-live-region");
            if (!liveRegion) {
                liveRegion = document.createElement("span");
                liveRegion.id = "copy-live-region";
                liveRegion.className = "visually-hidden";
                liveRegion.setAttribute("aria-live", "polite");
                document.body.appendChild(liveRegion);
            }
            if (liveRegion) {
                liveRegion.textContent = `${textToCopy} copied to clipboard`;
            }

            setTimeout(() => {
                copyBtn.innerHTML = originalHtml;
                copyBtn.classList.remove("copied");
            }, 2000);
        } catch (err) {
            console.error("Failed to copy:", err);
        }
    });

    // Disable register submit button on form submission
    const registerForm = document.querySelector('form[action*="register"]');
    registerForm?.addEventListener("submit", () => {
        if (registerForm.checkValidity()) {
            const submitBtn = registerForm.querySelector('button[type="submit"]');
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.textContent = "Creating account...";
            }
        }
    });

})();
