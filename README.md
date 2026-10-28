# FDS-AI-3D — SketchUp MCP

已验证：2026-10-28，Windows / SketchUp 26.1.189 / Ruby 3.2.2 / Python 3.11 / MCP SDK 1.30.0。

仓库：https://github.com/benjaken/sketch —— 换机器请按 [SETUP.md](SETUP.md) 重建环境；桥接源码在 `mcp-bridge/`（已含本项目修订）。

## 现在可以使用

DeepSeek Harness 已通过热加载启动项目 MCP，并完成 tools/list。工具名称：
- mcp__sketchup__get_scene_info：查看当前模型。
- mcp__sketchup__get_selection：查看选择内容。
- mcp__sketchup__eval_ruby：运行 SketchUp Ruby，修改作为一次操作提交；普通异常及语法异常返回 MCP 错误。
- mcp__sketchup__screenshot：取得当前模型视图截图。

在 Harness 中选择工作区 D:\Codex work\FDS-AI-3D，然后可以输入：
“先调用 SketchUp MCP 查询当前模型路径和尺寸；在当前示例柜旁新增一个宽600、深400、高800毫米的独立柜体组，不修改原柜。将结果另存到 D:/Codex work/FDS-AI-3D/outputs/new-cabinet.skp，并调用截图工具检查。”

尺寸需显式使用 Ruby 的 .mm，SketchUp 内部几何单位为英寸；scene_info 中 bounds 数值也是英寸。
当前验证成功的连接模型是 outputs/FDS-demo-cabinet.skp。

## 启动及连接

Ruby 插件已安装到本机 SketchUp 2026 用户 Plugins 目录。
本地修订版会在 SketchUp 加载后自动尝试启动 127.0.0.1:9876；扩展程序 → SketchUp MCP Bridge 提供 Start Server / Stop Server / Status。
建议只保留一个要控制的 SketchUp 实例。多个实例同时运行时，仅第一个占用9876端口的实例受控；先通过 get_scene_info 确认模型，再执行修改。
Harness desktop 用户补丁已追加 MCP 配置，不需要修改程序安装目录。原补丁备份：review/cordis.patch.before-sketchup.yml。
Python 独立环境：.venv；桥接代码：vendor/sketchup-mcp-bridge；不要删除或移动这些目录。
截图临时文件：work/screenshots/su_mcp_view.png；示例最终文件：outputs/。

## 验证结果与证据

- Python 16项测试通过，包括Windows截图路径、响应ID及错误传播。
- 实机 Ruby 普通异常回滚、语法异常隔离、异常后恢复通过：work/ruby-live-check.json。
- 半条TCP请求不会阻塞另一个客户端，实测读取 SketchUp 版本成功。
- MCP初始化、工具发现、错误标志、生成、保存、图片内容返回通过：review/mcp-live-result.json。
- 15个板件均为实体；XYZ尺寸1200×600×2100mm：review/model-validation.json。
- Harness实际工具发现记录：work/harness-mcp-discovery.jsonl（仅记录时间、进程号、工具名，不记录模型或提示词）。
- 插件文件与源码及RBZ一致、安装版Ruby语法验证：review/installation-validation.json。
- 完整依赖版本：review/requirements-verified.txt。

注意：自然语言模型自行规划的生成质量取决于提示词；本轮生成验证通过真正MCP会话执行，未提交付费模型对话测试。
原生Ruby执行无法保证被超时强制中止；无限循环或长时间原生API调用仍可能阻塞SketchUp。事务回滚不涵盖磁盘写入或所有应用设置。

## 已修复

原生Windows截图路径；Ruby非阻塞收发、10秒请求期限和消息大小限制；MCP错误语义；SyntaxError回滚；Python响应ID验证与响应大小限制。额外加入自动启动与状态菜单。
源码上游MIT：Shattenjagger/sketchup-mcp-bridge，基线提交c7ee20c1f01a691dfdd903df7aa46b49b827b830，当前为项目内修订版本。
