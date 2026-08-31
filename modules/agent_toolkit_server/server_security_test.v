module agent_toolkit_server

fn test_secure_compare() {
	assert secure_compare('abc', 'abc') == true
	assert secure_compare('abc', 'abd') == false
	assert secure_compare('abc', 'ab') == false
	assert secure_compare('', '') == true
	// constant-time: same length different content
	assert secure_compare('Bearer token123', 'Bearer token124') == false
	// large token 10k
	large_a := 'a'.repeat(10000)
	large_b := 'a'.repeat(9999) + 'b'
	assert secure_compare(large_a, large_b) == false
	assert secure_compare(large_a, large_a) == true
}

fn test_host_header_is_loopback() {
	assert host_header_is_loopback('127.0.0.1') == true
	assert host_header_is_loopback('127.0.0.1:3847') == true
	assert host_header_is_loopback('localhost:3847') == true
	assert host_header_is_loopback('localhost') == true
	assert host_header_is_loopback('::1') == true
	assert host_header_is_loopback('[::1]:3847') == true
	assert host_header_is_loopback('::ffff:127.0.0.1') == true
	assert host_header_is_loopback('192.168.1.1') == false
	assert host_header_is_loopback('192.168.1.1:3847') == false
	assert host_header_is_loopback('evil.com') == false
	assert host_header_is_loopback('') == false
	assert host_header_is_loopback('LOCALHOST:3847') == true
}

fn test_origin_host() {
	assert origin_host('https://evil.com') == 'evil.com'
	assert origin_host('https://evil.com:443/path') == 'evil.com'
	assert origin_host('http://127.0.0.1:3847') == '127.0.0.1'
	assert origin_host('http://localhost:3000') == 'localhost'
	assert origin_host('http://[::1]:3847/') == '::1'
	assert origin_host('') == ''
	assert origin_host('https://192.168.1.1') == '192.168.1.1'
	assert origin_host('https://EXAMPLE.COM') == 'example.com'
}

fn test_is_loopback_extended() {
	assert is_loopback('127.0.0.1') == true
	assert is_loopback('localhost') == true
	assert is_loopback('::1') == true
	assert is_loopback('::ffff:127.0.0.1') == true
	assert is_loopback('0.0.0.0') == false
	assert is_loopback('192.168.1.1') == false
	assert is_loopback('evil.com') == false
}
