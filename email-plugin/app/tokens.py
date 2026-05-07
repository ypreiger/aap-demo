"""Signed tokens for approve / deny URLs."""

from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer


def signer(secret: str) -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(secret, salt="email-plugin-workflow-approval-v1")


def sign_action(secret: str, approval_job_id: int, action: str, max_age_s: int) -> str:
    if action not in ("approve", "deny"):
        raise ValueError("action must be approve or deny")
    # max_age is enforced at loads(); include for clarity in serializer versioning
    _ = max_age_s
    return signer(secret).dumps({"a": approval_job_id, "t": action})


def verify(secret: str, token: str, max_age_s: int) -> tuple[int, str]:
    try:
        data = signer(secret).loads(token, max_age=max_age_s)
    except SignatureExpired as e:
        raise ValueError("Token expired") from e
    except BadSignature as e:
        raise ValueError("Bad signature") from e
    return int(data["a"]), str(data["t"])
