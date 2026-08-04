"""
OpenCode provider for dev-companion.

Uses opencode run command to generate responses.
Default model: big-pickle (free, local).
"""

import json
import subprocess
import time
from pathlib import Path
from typing import Optional

from .base import LLMProvider, LLMResponse


class OpenCodeProvider(LLMProvider):
    name = "opencode"
    is_local = True
    is_free = True

    def __init__(self, model: str = "opencode/big-pickle"):
        self.model = model

    def is_available(self) -> bool:
        try:
            result = subprocess.run(
                ["opencode", "--version"],
                capture_output=True,
                timeout=5,
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

    def supports_directory_context(self) -> bool:
        return True

    def get_model_name(self) -> str:
        return self.model

    def get_priority(self) -> int:
        return 1

    def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        repo_path: Optional[Path] = None,
        timeout_sec: int = 300,
    ) -> LLMResponse:
        start_time = time.time()

        cmd = [
            "opencode",
            "run",
            "--model",
            self.model,
            "--format",
            "json",
        ]

        if repo_path:
            cmd.extend(["--dir", str(repo_path)])

        full_prompt = prompt
        if system_prompt:
            full_prompt = f"{system_prompt}\n\n---\n\n{prompt}"

        cmd.append(full_prompt)

        try:
            result = subprocess.run(
                cmd,
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
                lines = result.stdout.strip().split("\n")
                text_parts = []
                for line in lines:
                    try:
                        data = json.loads(line)
                        if data.get("type") == "text":
                            part = data.get("part", {})
                            if isinstance(part, dict) and "text" in part:
                                text_parts.append(part.get("text", ""))
                            elif "text" in data:
                                text_parts.append(data.get("text", ""))
                    except json.JSONDecodeError:
                        continue
                if text_parts:
                    content = "\n".join(text_parts)
                else:
                    content = result.stdout
            except Exception:
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

    def _extract_content(self, response_data) -> str:
        return ""
