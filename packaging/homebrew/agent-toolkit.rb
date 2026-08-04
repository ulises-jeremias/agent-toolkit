class AgentToolkit < Formula
  include Language::Python::Virtualenv

  desc "Composable AI agent toolkit — loops, skills, profiles, and MCP for AI coding tools"
  homepage "https://github.com/ulises-jeremias/agent-toolkit"
  url "https://files.pythonhosted.org/packages/.../agent_toolkit-1.0.0.tar.gz"
  sha256 "PLACEHOLDER"  # Update after first PyPI publish
  license "MIT"

  depends_on "python@3.11"

  def install
    virtualenv_install_with_resources
  end

  test do
    system "#{bin}/agent-toolkit", "version"
  end
end
