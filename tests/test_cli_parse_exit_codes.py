"""CLI parse failures must exit 2; --help stays 0."""
from __future__ import annotations

from agent_toolkit.cli import doctor as doctor_mod
from agent_toolkit.cli import install as install_mod
from agent_toolkit.cli import memory as memory_mod
from agent_toolkit.cli import project as project_mod
from agent_toolkit.cli import workspace as workspace_mod


def test_install_help_exits_0() -> None:
    assert install_mod.cmd_install(["--help"]) == 0


def test_install_unknown_option_exits_2() -> None:
    assert install_mod.cmd_install(["--not-a-real-flag"]) == 2


def test_install_tools_missing_arg_exits_2() -> None:
    assert install_mod.cmd_install(["--tools"]) == 2


def test_doctor_help_exits_0() -> None:
    assert doctor_mod.cmd_doctor(["--help"]) == 0


def test_doctor_unknown_option_exits_2() -> None:
    assert doctor_mod.cmd_doctor(["--nope"]) == 2


def test_workspace_help_exits_0() -> None:
    assert workspace_mod.cmd_workspace(["--help"]) == 0


def test_workspace_unknown_top_level_option_exits_2() -> None:
    assert workspace_mod.cmd_workspace(["--nope"]) == 2


def test_workspace_context_unknown_option_exits_2() -> None:
    assert workspace_mod.cmd_workspace(["context", "--nope"]) == 2


def test_memory_help_exits_0() -> None:
    assert memory_mod.cmd_memory(["--help"]) == 0


def test_project_help_exits_0() -> None:
    assert project_mod.cmd_project(["--help"]) == 0


def test_project_unknown_option_exits_2() -> None:
    assert project_mod.cmd_project(["list", "--nope"]) == 2
