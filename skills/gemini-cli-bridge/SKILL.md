---
name: gemini-cli-bridge
description: Use when you want Codex to invoke the local Gemini CLI (`gemini`) to generate/rewrite/summarize/review content (code, diffs, docs). The workflow runs `gemini` in one-shot or prompt-interactive mode, captures output, then lets Codex decide the next concrete actions (edits, tests, follow-up prompts).
---

# Gemini CLI Bridge

目标：让 Codex **通过终端的 `gemini` 命令**把“生成/评审/总结”交给 Gemini CLI，然后把结果变成可执行的下一步（改哪些文件、跑哪些命令、需要哪些澄清）。

## 前置检查（每次开始都做）

1) 确认 CLI 可用

```bash
gemini --version
gemini --help
```

2) 认证/登录

本 Skill **不负责登录流程**。如果 `gemini` 提示未登录或缺权限，先让用户完成登录，然后再继续。

## 推荐工作流（Codex 执行顺序）

1) 明确“委托给 Gemini 的子任务”
- 生成：写一段内容/方案/测试用例草案/文档草案
- 评审：对某个文件、diff、或一段文本做 review，输出问题清单 + 建议改动
- 总结：把一段长输出压缩成可执行 TODO

2) 组装提示词（Prompt）并约束输出格式
- 强制 Gemini 输出：`结论 / 依据 / 建议改动 / 风险`（或你需要的结构）
- 如果是评审代码：要求逐条列出问题，并按严重程度排序

3) 调用 `gemini`（优先用 one-shot）
- 轻量 prompt：直接用 positional prompt
- 需要带长上下文：优先用 stdin 承载上下文，避免把超长 prompt 直接放在命令参数里；用短指令引导 Gemini 从 stdin 读取任务与上下文

4) 保存“输入/输出”以便可复现
- 至少保存：prompt、gemini 输出（最好加上时间戳文件名）

5) Codex 决策下一步
- 从 Gemini 输出中提取可执行动作：改文件、跑测试、补充信息
- 避免把 Gemini 输出当成最终真理：对关键结论进行二次验证（跑命令/查代码/查文档）

## 命令模板（可直接用）

### One-shot：prompt 很短

```bash
gemini --output-format text "在不改变行为的前提下，帮我把下面的内容改得更清晰：..."
```

### One-shot + JSON：便于后处理

```bash
gemini --output-format json "请输出结构化结果：{结论, 问题列表, 建议, 风险}"
```

### 带上下文：stdin + 短指令

```bash
cat CONTEXT.txt | gemini --output-format text -p "Use stdin context to output: 结论/问题/建议/风险"
```

## Bundled Scripts

- `scripts/gemini-run.sh`：把 prompt/context 组合成一次 `gemini` 调用，并可选写入输出文件

### `gemini-run.sh` 示例

从仓库根目录调用（未安装 skill 的情况下也能用）：

```bash
echo "请把下面的段落改写得更专业（输出 Markdown）" > /tmp/prompt.txt
./skills/gemini-cli-bridge/scripts/gemini-run.sh --prompt-file /tmp/prompt.txt --output-format text
```

用 diff 做 review（把 diff 走 stdin）：

```bash
echo "请对下面的 diff 做 review，输出：结论/问题清单(按严重程度)/建议改动/风险" > /tmp/prompt.txt
git diff | ./skills/gemini-cli-bridge/scripts/gemini-run.sh --prompt-file /tmp/prompt.txt --context-file - --output-format text
```

## 约束与故障排查

1) stdin 占用约束
- `--prompt-file -` 与 `--context-file -` 不能同时使用（两者都要读 stdin，脚本会拒绝并退出）。

2) 受限环境（沙箱/CI）
- 若出现 `listen EPERM: operation not permitted 0.0.0.0`：通常是 OAuth 回调监听端口受限。
- 处理方式：在非受限终端先完成 `gemini` 登录，或在允许网络与本地监听的环境执行。

3) 网络/DNS
- 若出现 `oauth2.googleapis.com ... ENOTFOUND`：检查网络、DNS 或代理配置后重试。

4) 版本兼容
- `--prompt` 已在 CLI help 中标记 deprecated，未来可能移除；建议优先使用 positional prompt 的 one-shot 调用。
