"""CLI parse failures must exit non-zero; --help stays 0."""

from __future__ import annotations

from agent_toolkit.cli import doctor as doctor_mod
from agent_toolkit.cli import install as install_mod


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
