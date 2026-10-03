from __future__ import annotations

import time
from dataclasses import dataclass, field

import httpx

from .settings import Settings


@dataclass(slots=True)
class NotificationManager:
    settings: Settings
    sent: dict[str, float] = field(default_factory=dict)

    def _allowed(self, key: str) -> bool:
        now = time.monotonic()
        last = self.sent.get(key, 0.0)
        if now - last < self.settings.notification_cooldown:
            return False
        self.sent[key] = now
        if len(self.sent) > 256:
            oldest = sorted(self.sent.items(), key=lambda item: item[1])[:64]
            for old_key, _ in oldest:
                self.sent.pop(old_key, None)
        return True

    async def send(self, *, key: str, title: str, message: str, priority: str = "default", tags: str = "") -> bool:
        if not self.settings.ntfy_enabled or not self.settings.ntfy_url or not self.settings.ntfy_topic:
            return False
        if not self._allowed(key):
            return False
        headers = {"Title": title, "Priority": priority}
        if tags:
            headers["Tags"] = tags
        if self.settings.ntfy_token:
            headers["Authorization"] = f"Bearer {self.settings.ntfy_token}"
        url = f"{self.settings.ntfy_url}/{self.settings.ntfy_topic}"
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(url, content=message.encode("utf-8"), headers=headers)
            response.raise_for_status()
        return True
