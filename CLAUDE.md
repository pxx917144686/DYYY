# DYYY++ 项目记忆

抖音（TikTok 中国版）越狱插件，Theos 项目，目标进程 `com.ss.iphone.ugc.Aweme`。
构建：`export THEOS=$PWD/.theos && export PATH="$THEOS/bin:$PATH" && export CLANG_MODULE_CACHE_PATH="$PWD/.module-cache" && make`，产物 `.theos/obj/DYYY++.dylib`（arm64，iOS 15.0）。

## 已完成的性能优化（9 个 commit）

- `751a048` perf(decrypt-crypto)：逆向助手加密捕获 hook 关闭时短路（`anyCaptureActiveForBundle` 缓存门）
- `dc110de` perf(decrypt-network)：网络抓包 hook 关闭时短路
- `32d976c` perf(core)：全局 UIView 基类 hook 快速失败 + 配置内存缓存（`DYYYCachedBool/DYYYCachedString/DYYYConfigCacheInvalidate`）
- `d78a975` perf(feed)：feed/播放页热路径（NSDateFormatter 单例、图片 NSCache、VC 树遍历频控、手势幂等、contentFilter 配置缓存）
- `d05fe76` perf(core)：setBackgroundColor 去重派发 + findViewControllerFromView 单元素缓存（weak VC 防悬空）
- `7c286a8` perf(feed)：dataSource 去广告过滤标记（count 校验）+ TabBar 布局脏标记
- `d138eac` perf(feed)：毛玻璃合并遍历 + 过滤词预编译（`DYYYCachedKeywordList`）
- `000b021` refactor(decrypt)：URLIntercept 未注册死代码标注
- `27ffd32` feat(selftest)：一键自检单元（DYYYSelfTest，7 项自检）
- `90edcd3` docs(social)：NSDictionary hook cluster 绕过风险标注

## 分版构建（发布版 / 调试版）

- **调试版（默认）**：`make` —— 主功能 + FLEX + Capstone 反汇编 + 逆向助手 + 一键自检，dylib ≈ 14.6MB
- **发布版**：`make DYYY_RELEASE=1` —— 主功能 + 一键自检（唯一保留的调试功能），dylib ≈ 1.65MB
  - 排除 FLEX 全部 / Capstone / 逆向助手 Decrypt / flex_fishhook；`-DDYYY_RELEASE_BUILD=1` 宏
  - 长按面板"FLEX调试"菜单项与面板项隐藏（`#ifndef` 包住调用块）
  - `DYYYSelfTest` 数据库测试项发布版跳过；Hook 生效性不检查 `DYYYIZXURLCaptureProtocol`
  - 产物另存 `DYYY++-release.dylib`；切换版本需 `make clean`（文件列表不同）
  - 注意：Logos 的 `%new` 方法定义**不能**用 `#ifndef` 排除（`%init` 引用会链接失败），只能条件编译调用点
- 构建环境：`export THEOS=$PWD/.theos && export PATH="$THEOS/bin:$PATH" && export CLANG_MODULE_CACHE_PATH="$PWD/.module-cache"`

## 待真机验证事项

- **一键自检**：设置页"清理&备份"分区 →"一键自检"；弹出**实时自检页面**（逐项实时刷新、进度 x/y、完成汇总、可复制报告），覆盖 16 项：环境/配置缓存/播放页 hook/feed/倍速清屏/长按面板评论/下载保存/城市属地/社交统计/时间格式/画中画/截图/ABTest/文件系统/逆向助手数据库(仅调试版)/网络
- **已按真机反馈修复**：属地检测改单参数方法；网络改 douyin.com 5s 超时；iOS 版本改读 `operatingSystemVersionString`（`DYYYSystemVersionSpoof` 默认开启会把 `systemVersion` 伪装成 26.0，自检已同时显示伪装状态）
- **NSDictionary hook 已移除**（commit 19ab301）：真机确认被 cluster 绕过从未生效；社交统计由 AWEUserModel/AWEProfileSocialStatisticView 精准 hook 承担
- **去广告过滤标记**：抖音若绕过 setter 直改数据源数组内容（count 变）标记会失效重滤，语义安全；建议真机验证广告过滤与 TabBar 布局正常
- 毛玻璃合并遍历保留了 tag 999 幂等，真机验证评论区毛玻璃/弹幕容器显示正常

## 崩溃日志抓取

- `DYYYCrashCatcher`（constructor 自动安装）：捕获未捕获 ObjC 异常 + 6 类信号（ABRT/SEGV/BUS/ILL/FPE/TRAP）
- 日志存 `Documents/DYYY/CrashLogs/Crash_<时间戳>.txt`（时间/异常名/原因/调用栈），保留最近 20 份，启动清理
- 链式保存旧处理器（`NSGetUncaughtExceptionHandler` + `signal()` 旧值），写完交还抖音原有崩溃上报
- 已移除 `DYYYFloatClearButton.xm` 的 `signal(SIGSEGV, SIG_IGN)`（吞掉段错误且覆盖本模块 handler）
- signal handler 内仅 C 级操作（open/write/backtrace_symbols_fd），目录 C 路径在 constructor 预缓存
- 自检第 17 项"崩溃日志抓取"显示目录与已有日志数

## 备注

- 构建产物 `.theos/`、`.module-cache/`、`DYYY++.dylib`、`.DS_Store` 为 untracked，建议补 `.gitignore`
- 逆向助手数据库 `iosnixiangzhushoutest.sqlite` 在沙盒 Documents，已加每表 500 条/日志 200 条上限 + 启动裁剪

