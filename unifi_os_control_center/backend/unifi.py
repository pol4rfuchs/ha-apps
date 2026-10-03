from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from urllib.parse import urlsplit, urlunsplit

import httpx

from .settings import Settings


@dataclass(slots=True)
class UniFiAPIError(Exception):
    method: str
    url: str
    status_code: int
    reason: str
    response_body: Any
    response_headers: dict[str, str]

    def __str__(self) -> str:
        return f"UniFi API returned HTTP {self.status_code} {self.reason} for {self.method} {self.url}"

    def as_dict(self) -> dict[str, Any]:
        return {
            "method": self.method,
            "url": self.url,
            "status_code": self.status_code,
            "reason": self.reason,
            "response_body": self.response_body,
            "response_headers": self.response_headers,
        }


class UniFiClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def _headers(self) -> dict[str, str]:
        return {
            "X-API-KEY": self.settings.api_key,
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    @staticmethod
    def _safe_url(url: str) -> str:
        parts = urlsplit(url)
        return urlunsplit((parts.scheme, parts.netloc, parts.path, parts.query, ""))

    @staticmethod
    def _response_body(response: httpx.Response) -> Any:
        if not response.content:
            return None
        try:
            return response.json()
        except ValueError:
            text = response.text.strip()
            return text[:12000] if text else None

    async def request(
        self,
        method: str,
        path: str,
        *,
        payload: dict[str, Any] | None = None,
        params: dict[str, str | int] | None = None,
    ) -> Any:
        method = method.upper()
        if method not in {"GET", "HEAD", "OPTIONS"} and self.settings.read_only:
            raise PermissionError("Write operation blocked by read-only mode")
        if not self.settings.controller_url:
            raise RuntimeError("Controller URL is not configured")
        if not self.settings.api_key:
            raise RuntimeError("API key is not configured")

        timeout = httpx.Timeout(12.0, connect=6.0)
        async with httpx.AsyncClient(verify=self.settings.verify_tls, timeout=timeout) as client:
            response = await client.request(
                method,
                f"{self.settings.controller_url}{path}",
                headers=self._headers(),
                json=payload,
                params=params,
            )
            if response.is_error:
                selected_headers = {
                    key: value
                    for key, value in response.headers.items()
                    if key.lower() in {"content-type", "x-request-id", "x-csrf-token", "server"}
                }
                raise UniFiAPIError(
                    method=method,
                    url=self._safe_url(str(response.request.url)),
                    status_code=response.status_code,
                    reason=response.reason_phrase,
                    response_body=self._response_body(response),
                    response_headers=selected_headers,
                )
            if response.status_code == 204:
                return None
            return self._response_body(response)

    async def sites(self) -> Any:
        return await self.request("GET", "/proxy/network/integration/v1/sites")

    async def devices(self, site_id: str) -> Any:
        return await self.request("GET", f"/proxy/network/integration/v1/sites/{site_id}/devices")

    async def clients(self, site_id: str) -> Any:
        return await self.request("GET", f"/proxy/network/integration/v1/sites/{site_id}/clients")

    async def firewall_policies(self, site_id: str, *, paged: bool = True) -> Any:
        return await self.request(
            "GET",
            f"/proxy/network/integration/v1/sites/{site_id}/firewall/policies",
            params={"offset": 0, "limit": 200} if paged else None,
        )

    async def firewall_zones(self, site_id: str, *, paged: bool = True) -> Any:
        return await self.request(
            "GET",
            f"/proxy/network/integration/v1/sites/{site_id}/firewall/zones",
            params={"offset": 0, "limit": 200} if paged else None,
        )

    async def firewall_ordering(
        self,
        site_id: str,
        source_zone_id: str,
        destination_zone_id: str,
    ) -> Any:
        return await self.request(
            "GET",
            f"/proxy/network/integration/v1/sites/{site_id}/firewall/policies/ordering",
            params={
                "sourceFirewallZoneId": source_zone_id,
                "destinationFirewallZoneId": destination_zone_id,
            },
        )
