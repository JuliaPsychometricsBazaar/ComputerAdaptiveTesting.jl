#!/bin/bash

set -e

echo "🚀 Setting up ComputerAdaptiveTesting.jl development environment..."

# Set up Julia environment - workspace is mounted to /workspace in Claude reference pattern
cd /workspace

# Copy startup file to Julia config
cp .devcontainer/startup.jl /home/julia/.julia/config/startup.jl

echo "📦 Installing Julia packages (main project only)..."

# Remove Manifest.toml to avoid local path issues and let Pkg resolve from registry
rm -f Manifest.toml

# Instantiate the project - this will get packages from registry instead of local paths
julia --project=. -e "
using Pkg;
Pkg.instantiate();
"

echo "✅ Julia environment setup complete!"

# Set up git configuration if not already set
if ! git config --global user.name > /dev/null 2>&1; then
    echo "⚠️  Remember to set up your git configuration:"
    echo "   git config --global user.name \"Your Name\""
    echo "   git config --global user.email \"your.email@example.com\""
fi

# Skip firewall initialization during development to avoid network issues
echo "🔓 Skipping firewall initialization for package installation..."

# Install Claude Code CLI as user (post-create, after network is available)
echo "🤖 Installing Claude Code CLI..."
if sudo npm install -g @anthropic-ai/claude-code; then
    echo "✅ Claude Code CLI installed successfully!"
else
    echo "⚠️  Claude Code CLI installation failed - you can install it manually later"
    echo "    Manual installation: sudo npm install -g @anthropic-ai/claude-code"
fi

echo "🎉 Development environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Open the Julia REPL with 'julia --project=.'"
echo "  2. Run tests with 'julia --project=test test/runtests.jl'"
echo "  3. Build documentation with 'julia --project=docs docs/make.jl'"
echo "  4. Try Claude Code with 'claude --help'"
echo ""
echo "🔧 Available development tools:"
echo "  - Claude Code CLI for AI assistance"
echo "  - Revise.jl for automatic code reloading"
echo "  - BenchmarkTools.jl for performance testing"
echo "  - ProfileView.jl for profiling"
echo "  - OhMyREPL.jl for enhanced REPL experience"
echo "  - Zsh with git integration and history search"
echo "  - Git Delta for improved diffs"