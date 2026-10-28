# 状态更新

审查问题已修复，并完成本机MCP生成、保存和截图验证。以下为安装前历史记录，当前状态以项目README及验证JSON为准。

# SketchUp MCP 接入审查

日期：2026-10-28
上游：https://github.com/Shattenjagger/sketchup-mcp-bridge
审查提交：c7ee20c1f01a691dfdd903df7aa46b49b827b830
许可证：MIT；版本 0.1.0；Python >=3.10；直接依赖 mcp[cli]>=1.3.0。
本机可用 Python 3.11、uv、Node；未发现独立 Ruby 命令。

## 结论
可作为桥接基础，无需从零编写。但当前版本不宜直接用于原生 Windows 正式接入。

## 发现
1. server.py screenshot() 无条件将 Windows 路径转为 /mnt/<盘符>，原生 Windows Python 会读错路径。需按运行平台转换。
2. main.rb handle() 在 SketchUp UI 定时器内调用阻塞 client.gets 和 write；连接不发送换行或不读取响应可能冻结 UI。需非阻塞收发、跨 tick 缓冲、截止时间和消息大小限制。
3. server.py _safe_call() 将异常变成普通 ERROR 字符串，MCP 层可能将失败视为正常结果。应使用 SDK 工具错误语义。
4. main.rb run_eval 只 rescue StandardError；SyntaxError 等异常不在此范围内，不能保证文档宣称的所有错误均回滚。应确保失败路径关闭 operation，并验证定时器仍能响应。
5. Python 客户端没有验证响应 id，也没有响应大小上限；应补充协议校验。
6. 上游仅 4 个工具：eval_ruby、get_scene_info、get_selection、screenshot。参数化柜体、板件编号、材料清单需后续专用工具。
7. eval_ruby 拥有 SketchUp 进程的权限；当前 TCP 端点仅绑定 127.0.0.1，无认证。

## 配置草案
同目录 harness-sketchup.patch.yml 是待合并草案，不是已生效配置。
command 指向计划中的项目独立环境；当前尚未创建该环境。
计划链路：Harness --stdio--> 项目 Python MCP --TCP 127.0.0.1:9876--> SketchUp Ruby 插件。
使用原生 Windows Python，不需要 WSL 或系统网络改动。

## 实施顺序
1. 在项目中修复 Windows 截图和 Ruby 非阻塞收发，再修复工具错误及事务收尾。
2. 在项目独立环境安装固定依赖；补充针对上述问题的测试，运行上游测试和针对性检查。
3. 构建 RBZ 并检查归档结构，提供准确安装清单。
4. 用户同意安装阶段后，将 RBZ 安装到 SketchUp，通过 Harness 插件机制加入配置；不覆盖用户已有补丁。
5. 先验证 initialize、tools/list、get_scene_info、get_selection；截图会向项目目录写 PNG，另作验证。
6. 写模型测试使用临时模型，并检查撤销和异常回滚；当前阶段不执行。

## 验证边界
本轮仅静态审查、检查工具可用性并读取上游测试。未安装依赖、执行上游程序、运行测试或与 SketchUp 握手。上游源码保持不变。
