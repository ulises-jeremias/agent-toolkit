module agent_toolkit_core

// ErrorClass is the ADR-010 domain error taxonomy.
pub enum ErrorClass {
	ok
	user
	config
	env
	external
	network
	internal
	usage_flags
}

// DomainError is a structured error returned by core (no printing).
pub struct DomainError {
pub:
	class   ErrorClass
	code    string
	message string
}

// msg returns the human-readable message.
pub fn (e DomainError) msg() string {
	return e.message
}

// exit_code maps a domain error class to a CLI process exit code (ADR-010).
pub fn (c ErrorClass) exit_code() int {
	return match c {
		.ok { 0 }
		.usage_flags { 2 }
		.user, .config, .env, .external, .network, .internal { 1 }
	}
}

// exit_code maps this domain error to a CLI exit code.
pub fn (e DomainError) exit_code() int {
	return e.class.exit_code()
}

// err_user constructs a USER-class domain error.
pub fn err_user(code string, message string) DomainError {
	return DomainError{
		class: .user
		code: code
		message: message
	}
}

// err_config constructs a CONFIG-class domain error.
pub fn err_config(code string, message string) DomainError {
	return DomainError{
		class: .config
		code: code
		message: message
	}
}

// err_env constructs an ENV-class domain error.
pub fn err_env(code string, message string) DomainError {
	return DomainError{
		class: .env
		code: code
		message: message
	}
}

// err_external constructs an EXTERNAL-class domain error.
pub fn err_external(code string, message string) DomainError {
	return DomainError{
		class: .external
		code: code
		message: message
	}
}

// err_network constructs a NETWORK-class domain error.
pub fn err_network(code string, message string) DomainError {
	return DomainError{
		class: .network
		code: code
		message: message
	}
}

// err_internal constructs an INTERNAL-class domain error.
pub fn err_internal(code string, message string) DomainError {
	return DomainError{
		class: .internal
		code: code
		message: message
	}
}

// err_usage_flags constructs a USAGE_FLAGS-class domain error (CLI parse).
pub fn err_usage_flags(code string, message string) DomainError {
	return DomainError{
		class: .usage_flags
		code: code
		message: message
	}
}
