"""
Ollama provider for dev-companion.

Uses ollama CLI to generate responses with locally running models.
Requires: ollama installed and running with models (e.g., llama3.2, mistral).
"""

import json
import subprocess
import time
from pathlib import Path
from typing import Optional

from .base import LLMProvider, LLMResponse


class OllamaProvider(LLMProvider):
    name = "ollama"
    is_local = True
    is_free = True

    def __init__(self, model: str = "llama3.2"):
        self.model = model

    def is_available(self) -> bool:
        try:
            result = subprocess.run(
                ["ollama", "list"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode != 0:
                return False
            return self.model in result.stdout
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

    def supports_directory_context(self) -> bool:
        return False

    def get_model_name(self) -> str:
        return self.model

    def get_priority(self) -> int:
        return 2

    def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        repo_path: Optional[Path] = None,
        timeout_sec: int = 300,
    ) -> LLMResponse:
        start_time = time.time()

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        input_data = {
            "model": self.model,
            "messages": messages,
            "stream": False,
        }

        try:
            result = subprocess.run(
                ["ollama", "api", "chat", "-"],
                input=json.dumps(input_data),
                capture_output=True,
                text=True,
                timeout=timeout_sec,
            )

            duration = time.time() - start_time

            if result.returncode != 0:
                return LLMResponse(
                    content=f"Error: {result.stderr}",
                    model=self.model,
                    provider=self.name,
                    duration_sec=duration,
                )

            try:
                response_data = json.loads(result.stdout)
                content = response_data.get("message", {}).get("content", "")
                if not content:
                    content = str(response_data)
            except json.JSONDecodeError:
                content = result.stdout

            return LLMResponse(
                content=content,
                model=self.model,
                provider=self.name,
                duration_sec=duration,
            )

        except subprocess.TimeoutExpired:
            return LLMResponse(
                content=f"Timeout after {timeout_sec} seconds",
                model=self.model,
                provider=self.name,
                duration_sec=timeout_sec,
            )
