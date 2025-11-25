import os
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from dotenv import load_dotenv
from pathlib import Path

# Carregar .env
dotenv_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=dotenv_path)

SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
FROM_EMAIL = os.getenv("FROM_EMAIL", "no-reply@seusite.com")
REPLY_TO_EMAIL = os.getenv("REPLY_TO_EMAIL", FROM_EMAIL)

# DEBUG
print("SENDGRID_API_KEY carregada em email_utils.py:", SENDGRID_API_KEY)

def send_password_reset_email(to_email: str, reset_link: str):
    if not SENDGRID_API_KEY:
        raise RuntimeError("SENDGRID_API_KEY não configurado")

    message = Mail(
        from_email=FROM_EMAIL,
        to_emails=to_email,
        subject="Recuperação de senha",
        html_content=(
            f"<p>Você pediu para recuperar sua senha. Clique no link abaixo para resetar:</p>"
            f"<p><a href='{reset_link}'>Resetar senha</a></p>"
            f"<p>Se não pediu, ignore este e-mail.</p>"
        ),
    )

    message.reply_to = REPLY_TO_EMAIL

    sg = SendGridAPIClient(SENDGRID_API_KEY)
    response = sg.send(message)
    print("Status do envio de email:", response.status_code)
    return response.status_code
