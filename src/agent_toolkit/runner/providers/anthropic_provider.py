"""
Anthropic provider for dev-companion.

Uses Anthropic API (Claude) as optional paid provider.
Requires: ANTHROPIC_API_KEY environment variable.
"""

import json
import os
import time
from pathlib import Path
from typing import Optional

from .base import LLMProvider, LLMResponse


class AnthropicProvider(LLMProvider):
    name = "anthropic"
    is_local = False
    is_free = False

    def __init__(self, model: str = "claude-3-5-haiku-20241022"):
        self.model = model

    def is_available(self) -> bool:
        return bool(os.environ.get("ANTHROPIC_API_KEY"))

    def supports_directory_context(self) -> bool:
        return False

    def get_model_name(self) -> str:
        return self.model

    def get_priority(self) -> int:
        return 10

    def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        repo_path: Optional[Path] = None,
        timeout_sec: int = 300,
    ) -> LLMResponse:
        import urllib.request
        import urllib.error

        start_time = time.time()

        headers = {
            "Content-Type": "application/json",
            "x-api-key": os.environ["ANTHROPIC_API_KEY"],
            "anthropic-version": "2023-06-01",
        }

        messages = [{"role": "user", "content": prompt}]
        if system_prompt:
            messages[0] = {
                "role": "user",
                "content": f"{system_prompt}\n\n---\n\n{prompt}",
            }

        data = {
            "model": self.model,
            "messages": messages,
            "max_tokens": 4096,
        }

        try:
            req = urllib.request.Request(
                "https://api.anthropic.com/v1/messages",
                data=json.dumps(data).encode(),
                headers=headers,
                method="POST",
            )

            with urllib.request.urlopen(req, timeout=timeout_sec) as response:
                result = json.loads(response.read().decode())

            duration = time.time() - start_time

            content = ""
            for block in result.get("content", []):
                if block.get("type") == "text":
                    content += block.get("text", "")

            usage = result.get("usage", {})

            return LLMResponse(
                content=content,
                model=self.model,
                provider=self.name,
                tokens_used=usage.get("output_tokens"),
                duration_sec=duration,
            )

        except urllib.error.HTTPError as e:
            return LLMResponse(
                content=f"HTTP Error: {e.code} - {e.reason}",
                model=self.model,
                provider=self.name,
                duration_sec=time.time() - start_time,
            )
        except Exception as e:
            return LLMResponse(
                content=f"Error: {str(e)}",
                model=self.model,
                provider=self.name,
                duration_sec=time.time() - start_time,
            )
