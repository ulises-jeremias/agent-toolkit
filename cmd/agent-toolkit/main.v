module main

import agent_toolkit_cli
import os

fn main() {
	code := agent_toolkit_cli.run(os.args)
	exit(code)
}
