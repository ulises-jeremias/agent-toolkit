"""
Base interface for LLM providers.

All providers must implement this interface to be used by the dev-companion runner.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass
class LLMResponse:
    content: str
    model: str
    provider: str
    tokens_used: Optional[int] = None
    duration_sec: Optional[float] = None


class LLMProvider(ABC):
    name: str
    is_local: bool = False
    is_free: bool = False

    @abstractmethod
    def is_available(self) -> bool:
        """Check if the provider is available (installed, configured, etc.)"""
        pass

    @abstractmethod
    def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        repo_path: Optional[Path] = None,
        timeout_sec: int = 300,
    ) -> LLMResponse:
        """Generate a response from the LLM"""
        pass

    def get_priority(self) -> int:
        """Lower = higher priority. Local free providers should have priority over cloud paid ones."""
        return 100

    def supports_directory_context(self) -> bool:
        """Whether the provider can operate in a specific directory context"""
        return False

    def get_model_name(self) -> str:
        """Return the model name used by this provider"""
        return "unknown"
