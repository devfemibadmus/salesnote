import os
import smtplib
from email.message import EmailMessage
from pathlib import Path


def load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def env_required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required env: {name}")
    return value


def main() -> None:
    base = Path(__file__).resolve().parent
    load_env_file(base / ".env")

    smtp_from = env_required("SALESNOTE__SMTP_FROM")
    smtp_host = env_required("SALESNOTE__SMTP_HOST")
    smtp_port = int(env_required("SALESNOTE__SMTP_PORT"))
    smtp_user = env_required("SALESNOTE__SMTP_USERNAME")
    smtp_pass = env_required("SALESNOTE__SMTP_PASSWORD")
    smtp_to = env_required("SALESNOTE__SMTP_TEST_TO")
    smtp_timeout = int(os.getenv("SALESNOTE__SMTP_TIMEOUT_SECS", "40").strip() or "40")

    print("SMTP config:")
    print(f"  host={smtp_host}")
    print(f"  port={smtp_port}")
    print(f"  user={smtp_user}")
    print(f"  from={smtp_from}")
    print(f"  to={smtp_to}")
    print(f"  timeout={smtp_timeout}s")

    msg = EmailMessage()
    msg["Subject"] = "SMTP Check (x.py)"
    msg["From"] = smtp_from
    msg["To"] = smtp_to
    msg.set_content("SMTP check from backend/x.py")

    if smtp_port == 465:
        with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=smtp_timeout) as server:
            server.set_debuglevel(1)
            server.ehlo()
            server.login(smtp_user, smtp_pass)
            server.send_message(msg)
    else:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=smtp_timeout) as server:
            server.set_debuglevel(1)
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(smtp_user, smtp_pass)
            server.send_message(msg)

    print("SUCCESS: email sent")


if __name__ == "__main__":
    main()
