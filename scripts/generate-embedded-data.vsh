#!/usr/bin/env -S v run
import os

fn main() {
	py := os.join_path(os.dir(@FILE), 'generate-embedded-data.py')
	if os.is_file(py) {
		res := os.execute('python3 ${py}')
		print(res.output)
		if res.exit_code != 0 {
			eprintln('generate-embedded-data.py failed')
			exit(res.exit_code)
		}
		return
	}
	eprintln('generate-embedded-data.py not found')
	exit(1)
}
