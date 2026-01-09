# gemini-bridge

这个仓库提供一个可直接安装到 Codex CLI 的本地 Skill：通过终端里的 `gemini` 命令，把“生成/评审/总结”等工作委托给 Gemini CLI，然后由 Codex 根据结果决定下一步行动。

## 目录结构

- `skills/gemini-cli-bridge/`：Skill 本体（`SKILL.md` + 脚本）
- `scripts/install-skill.sh`：把 Skill 安装到 `~/.codex/skills/`（默认 `CODEX_HOME`）

## 快速开始（本地安装）

1) 确保你本机能运行 `gemini --help`（登录由你自行完成）

2) 推荐：直接用“仓库本地 CODEX_HOME”启动 Codex（真正 clone-and-use，不写全局目录）

```bash
./scripts/codex-local.sh
```

3) 或者：安装 Skill 到默认 `CODEX_HOME`（通常是 `~/.codex`，用 symlink，不复制）

```bash
./scripts/install-skill.sh
```

安装后需要重启 Codex，让新 Skill 生效

之后在 Codex 对话里提到“用 gemini CLI 生成/评审/总结”，Skill 就会触发并指导 Codex 如何调用 `gemini`。

## 不安装也能用的脚本

如果你只是想先在终端里试跑一次（不依赖 Codex），可以直接用：

```bash
./skills/gemini-cli-bridge/scripts/gemini-run.sh --help
```
