"""MCP server: plug into Claude Desktop (or any MCP client) and Claude becomes the agent over the layers.
claude_desktop_config.json:
  "thessaly-layers": {"command": "python", "args": ["<path>/layers-agent/agent/mcp_server.py"]}"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from mcp.server.fastmcp import FastMCP
import tools
mcp = FastMCP("thessaly-layers", instructions=(
    "Spatial layers of Thessaly on an H3 res-8 grid. Call list_layers first. Always weight by area_km2, "
    "state source/date/caveats of the layers you used, and never answer a quantity without a tool result. "
    "'Not flooded' only counts where daniel_mapped_share > 0."))
for f in tools.TOOLS: mcp.tool()(f)
if __name__ == "__main__":
    mcp.run()
