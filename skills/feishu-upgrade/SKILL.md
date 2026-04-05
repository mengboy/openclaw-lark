---
name: feishu-upgrade
description: |
  飞书插件升级指南。当官方仓库（origin）有新版本时，自动拉取最新代码，
  并将个人的流式卡片增强改动重新应用到最新版本上，避免手动合并冲突。
---

# 飞书插件升级流程

## 场景

官方仓库 `larksuite/openclaw-lark`（origin）发布了新版本，你希望：
1. 获取最新官方代码
2. 保留自己的流式卡片增强改动
3. 避免手动解决合并冲突

## 一键升级

```bash
pnpm upgrade:origin
```

该命令会自动完成：
1. **Fetch** 拉取 origin 和 mengboy 最新代码
2. **检测** 判断 mengboy 是否已包含 origin 最新变更
3. **创建分支** 基于 `origin/main` 创建带日期的升级分支
4. **导出补丁** 从 mengboy 导出流式卡片相关改动
5. **应用补丁** 将改动重新应用到最新的 origin 代码上
6. **重建安装** 自动 build、安装插件、恢复飞书配置
7. **提示推送** 完成后提示推送到远端

## 升级后的分支结构

```
upgrade-from-origin-2026-04-05   ← 新创建的升级分支（基于最新 origin + 你的改动）
origin/main                       ← 官方最新版本
mengboy/main                      ← 你的个人版本（尚未包含最新 origin 变更）
```

## 升级完成后

### 检查变更

```bash
git diff origin/main..HEAD
```

### 推送更新到远端

```bash
git push mengboy upgrade-from-origin-YYYY-MM-DD:main --force
```

### 重启 OpenClaw

```bash
openclaw gateway restart
```

## 如果升级脚本失败

### 补丁应用失败（有冲突）

脚本会显示冲突文件列表。手动解决冲突后：

```bash
git add -A
git commit -m "feat: reapply streaming card improvements"
pnpm reinstall
git push mengboy HEAD:main --force
```

### 无需升级

如果输出显示 `✅ Mengboy main already includes latest origin changes`，说明你已经是最新的，无需操作。

## 远端配置

确保已配置 origin 和 mengboy 远端：

```bash
git remote -v
# 应包含:
# origin   https://github.com/larksuite/openclaw-lark (fetch/push)
# mengboy  git@github.com:mengboy/openclaw-lark.git (fetch/push)
```

## 常见问题

### 升级后飞书配置丢失

运行 `pnpm config:restore` 恢复。升级脚本已自动包含此步骤。

### 升级后 build 失败

可能是 origin 引入了新的依赖或 API 变更。检查编译错误并相应调整代码。
