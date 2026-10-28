# 在新机器上继续开发

仓库：https://github.com/benjaken/sketch
本机已验证环境：Windows 11 / SketchUp 26.1.189 / Ruby 3.2.2 / Python 3.11 / mcp 1.30.0。

仓库里**已经包含**的东西：

- `outputs/`：全部 `.skp` 模型（木纹贴图已嵌入文件）、导出的视图 PNG、`validation.json`、各版本说明。
- `work/conference-table/`：生成模型的 Ruby 脚本（`build_table_v04.rb`、`build_table_v06.rb`、`build_table_v07b.rb`、`finalize_v07.rb` 等），可直接复现几何。
- `mcp-bridge/`：本项目修订过的 SketchUp MCP 桥接源码（Python MCP 服务 + Ruby 插件），已含非阻塞收发、原生 Windows 截图路径、错误语义等修改。
- `review/`：验证记录、依赖锁、Harness MCP 配置样例。

**不包含**（需要在新机器重建）：`.venv`（95 MB，按下面步骤重装）、`vendor/`（上游 git 检出，用 `mcp-bridge/` 代替即可）、`*.skb` 备份。

## 1. 装 SketchUp 与插件

1. 装 SketchUp 2026（其它大版本 Ruby 版本可能不同）。
2. 装桥接插件，二选一：
   - 双击 `outputs/su_mcp_bridge-fds.rbz` 用 SketchUp 安装；或
   - 把 `mcp-bridge/sketchup_plugin/` 下的 `su_mcp_bridge.rb`、`su_mcp_bridge/`、`extension.json` 复制到
     `%APPDATA%\SketchUp\SketchUp 2026\SketchUp\Plugins\`。
3. 打开 SketchUp，`扩展程序 → SketchUp MCP Bridge → Status` 应显示 `127.0.0.1:9876`。

## 2. 建 Python 环境

```powershell
cd <仓库路径>
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U pip
.\.venv\Scripts\python.exe -m pip install -e .\mcp-bridge
```

`pip install -e .\mcp-bridge` 装的就是仓库内的修订版，**不需要**再 clone 上游或跑 `work/patch_bridge.py`（那支脚本是当初给上游打补丁用的，仅作历史记录）。

## 3. 配置 DeepSeek Harness 的 MCP

把下面的块合并进 Harness 的 `cordis.patch.yml`（本机在 `C:\Users\<你>\.dsh\profiles\desktop\cordis.patch.yml`），把路径换成新机器的实际路径：

```yaml
- insert:
    - id: mcp-sketchup
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: sketchup
        transport: stdio
        command: '<仓库路径>\.venv\Scripts\python.exe'
        args:
          - '-m'
          - sketchup_mcp_bridge.server
          - '--host'
          - '127.0.0.1'
          - '--port'
          - '9876'
          - '--screenshot-dir'
          - '<仓库路径>\work\screenshots'
        cwd: '<仓库路径>\mcp-bridge'
        failOnStartupError: true
```

改完重启 Harness，工具列表里应出现 `mcp__sketchup__eval_ruby` 等四个工具。

## 4. 自检

```powershell
.\.venv\Scripts\python.exe work\verify_mcp.py
.\.venv\Scripts\python.exe -m pytest -q mcp-bridge\tests
```

再在 SketchUp 里打开 `outputs/conference-table-v06/conference-table-3200x1390x775-v06.skp`，让 Harness 调一次 `get_scene_info`，应返回该模型路径与 3200×1390×775 的包围盒（英寸单位）。

## 5. 注意

- 只能有一个 SketchUp 实例占用 9876 端口；多开时先关掉其它实例。
- `eval_ruby` 拥有 SketchUp 进程权限，桥接只监听 127.0.0.1，没有认证，不要暴露到局域网。
- 模型里的木纹贴图是相对/绝对混合引用；换机器后如显示缺图，重新指定 `work/conference-table/light-oak-v02.png` 即可。
- 提交 .skp/PNG 属于二进制文件，仓库已用 `.gitattributes` 标记，仓库体积会持续增长；后续建议对 `outputs/` 用 Git LFS 或只提交最终版本。
