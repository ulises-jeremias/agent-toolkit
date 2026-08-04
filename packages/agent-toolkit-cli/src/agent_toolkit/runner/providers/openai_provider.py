"""
OpenAI provider for dev-companion.

Uses OpenAI API as optional paid provider.
Requires: OPENAI_API_KEY environment variable.
"""

import json
import os
import time
from pathlib import Path
from typing import Optional

from .base import LLMProvider, LLMResponse


class OpenAIProvider(LLMProvider):
    name = "openai"
    is_local = False
    is_free = False

    def __init__(self, model: str = "gpt-4o-mini"):
        self.model = model

    def is_available(self) -> bool:
        return bool(os.environ.get("OPENAI_API_KEY"))

    def supports_directory_context(self) -> bool:
        return False

    def get_model_name(self) -> str:
        return self.model

    def get_priority(self) -> int:
        return 20

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
            "Authorization": f"Bearer {os.environ['OPENAI_API_KEY']}",
        }

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        data = {
            "model": self.model,
            "messages": messages,
            "max_tokens": 4096,
        }

        try:
            req = urllib.request.Request(
                "https://api.openai.com/v1/chat/completions",
                data=json.dumps(data).encode(),
                headers=headers,
                method="POST",
            )

            with urllib.request.urlopen(req, timeout=timeout_sec) as response:
                result = json.loads(response.read().decode())

            duration = time.time() - start_time

            content = (
                result.get("choices", [{}])[0].get("message", {}).get("content", "")
            )
            usage = result.get("usage", {})

            return LLMResponse(
                content=content,
                model=self.model,
                provider=self.name,
                tokens_used=usage.get("total_tokens"),
                duration_sec=duration,
            )

        except urllib.error.HTTPError as e:
            body = e.read().decode() if e.fp else ""
            return LLMResponse(
                content=f"HTTP Error: {e.code} - {e.reason}\n{body}",
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
