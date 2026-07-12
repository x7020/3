# 抖音极速版商品页面探针（Universal）

此前版本只编译了 `arm64`，A12 及更新设备运行的 `arm64e` App 可能在启动时被 dyld 直接终止。

本工程同时编译：

- arm64
- arm64e

并用 `lipo` 合并为 `ProductProbe.dylib`。

## 编译

1. 用本项目的 `Probe.m` 覆盖仓库根目录文件。
2. 用 `.github/workflows/build.yml` 覆盖原工作流。
3. Commit 后进入 Actions。
4. 运行 `Build ProductProbe Universal dylib`。
5. 下载 `ProductProbe-Universal` artifact。

## 注入前

先在 TrollFools 中移除旧插件并恢复目标 App，再注入新的 `ProductProbe.dylib`，不要直接在旧注入结果上反复追加。
