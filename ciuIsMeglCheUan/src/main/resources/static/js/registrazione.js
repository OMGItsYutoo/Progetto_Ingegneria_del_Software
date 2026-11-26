document.addEventListener("DOMContentLoaded", function () {
    const form = document.getElementById("registration-form");
    const errorBox = document.getElementById("client-error");
    if (!form) {
        return;
    }

    form.addEventListener("submit", function (event) {
        errorBox.textContent = "";
        const password = document.getElementById("password").value;
        const hasUpper = /[A-Z]/.test(password);
        const hasLower = /[a-z]/.test(password);
        const hasDigit = /[0-9]/.test(password);
        const hasSpecial = /[^A-Za-z0-9]/.test(password);

        if (password.length < 8 || !hasUpper || !hasLower || !hasDigit || !hasSpecial) {
            event.preventDefault();
            errorBox.textContent = "La password deve contenere almeno 8 caratteri, una maiuscola, una minuscola, un numero e un carattere speciale.";
        }
    });
});
