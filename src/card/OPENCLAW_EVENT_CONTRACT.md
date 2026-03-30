# Feishu Card Event Contract

这份说明只覆盖飞书流式卡片依赖的 OpenClaw 事件契约，目的是在升级 `/Users/wow/dev/openclaw` 后快速判断这里是否需要同步调整。

## 当前依赖

飞书卡片摘要模式当前依赖这些插件层回调：

- `onPartialReply`
- `onReasoningStream`
- `onReasoningEnd`
- `onAssistantMessageStart`
- `onToolStart`
- `onToolResult`
- `onCompactionStart`
- `onCompactionEnd`
- `onModelSelected`

还依赖 reply dispatcher 在 `deliver(payload, info)` 中传入 `info.kind`，并区分：

- `kind === "tool"`: 走工具摘要更新
- 其他 kind: 走正常正文投递

## 当前使用的最小字段

为了降低和 OpenClaw 主仓库的耦合，飞书卡片只消费少量稳定字段：

- `ReplyPayload.text`
- `ReplyPayload.mediaUrl`
- `ReplyPayload.mediaUrls`
- `ReplyPayload.isError`
- `onToolStart({ name, phase })`
- `onModelSelected({ provider, model, thinkLevel })`

不要在飞书卡片层继续依赖更多 tool `args/result` 结构，除非明确需要展示完整过程。

## 主仓库核对点

升级 OpenClaw 后，优先核对这些文件：

- `/Users/wow/dev/openclaw/src/auto-reply/types.ts`
- `/Users/wow/dev/openclaw/src/auto-reply/reply/reply-dispatcher.ts`
- `/Users/wow/dev/openclaw/src/auto-reply/reply/agent-runner-execution.ts`
- `/Users/wow/dev/openclaw/src/agents/pi-embedded-subscribe.handlers.messages.ts`
- `/Users/wow/dev/openclaw/src/agents/pi-embedded-subscribe.handlers.tools.ts`

## 需要同步更新的信号

出现下面任一变动时，这里的飞书卡片链路需要同步更新：

- 回调名变化
- 回调触发时机变化
- `ReplyPayload` 字段语义变化
- `deliver()` 不再传 `info.kind`
- tool 摘要不再通过 `onToolResult` 或 `deliver(kind="tool")` 下发
- `onModelSelected` 不再提供 `provider/model`

## 回归建议

升级后至少回归这几类场景：

- 仅 reasoning，无正文
- reasoning 后进入正文流
- 工具开始后显示 `running <tool>`
- 工具结果到达后更新摘要
- compaction 开始/结束状态切换
- 终态显示 `Agent / Model / Provider`

## 设计边界

当前飞书卡片只展示摘要，不做完整过程 timeline。

这么做的原因：

- 事件耦合更小
- 主仓库事件变动时更容易兼容
- 飞书卡片空间有限，摘要比完整过程更稳
