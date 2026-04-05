---
name: feishu-install
description: |
  飞书插件本地开发和安装指南。包含从源码构建、安装到本地 OpenClaw 的完整流程，
  以及安装后飞书 channel 配置恢复的自动化脚本。
---

# 飞书插件本地安装

## 前置条件

- Node.js >= 22
- pnpm
- openclaw CLI 已安装

## 安装

在项目根目录执行：

```bash
pnpm reinstall
```

该命令会自动完成：
1. `pnpm build` 编译 TypeScript
2. `npm pack` 打包 .tgz
3. `openclaw plugins uninstall` 移除旧版本
4. `openclaw plugins install` 安装新版本
5. 自动恢复飞书 channel 配置（appId/appSecret/groups 等）
6. 验证安装版本

## 配置恢复（单独使用）

如果飞书配置丢失，单独恢复：

```bash
pnpm config:restore
```

## 验证安装

```bash
# 检查已安装版本
node -p "require('$HOME/.openclaw/extensions/openclaw-lark/package.json').version"

# 检查飞书配置是否存在
openclaw config get channels.feishu
```

## 重启 OpenClaw

```bash
openclaw gateway restart
# 或者如果未运行：
openclaw gateway
```

## 开发工作流

修改源码后重新安装：

```bash
pnpm reinstall
```

## 常见问题

### 安装后飞书无响应

99% 是 `channels.feishu` 配置丢失。运行 `pnpm config:restore` 恢复。

### Node.js 报 simdjson 库缺失

```bash
brew reinstall simdjson
brew link --overwrite node@24
```

### 插件已存在无法安装

```bash
rm -rf ~/.openclaw/extensions/openclaw-lark
openclaw plugins uninstall openclaw-lark --force
pnpm reinstall
```
