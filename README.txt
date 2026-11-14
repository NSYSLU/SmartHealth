# 舒心 SmartHealth

一款以“让健康建议更贴近日常”为目标的 iOS 健康管理原型。它把睡眠、活动和心率等信号整理成容易理解的小建议，鼓励用户持续关注自己，而不是追逐单一分数。

## 当前体验

- 首页：今日健康分、睡眠/步数/心率/活跃能量概览、每日建议和 Apple 健康连接状态。
- AI 洞察：展示结合近期趋势的建议，并提供重新分析反馈。
- 健康数据：查看一周趋势，支持添加饮水、心情和体重记录。
- 本地模型：在极速、平衡、深度三种设备档位间切换，展示预估响应时间。
- 模型库：三个内置离线模型包可安装、切换、删除和重新安装；也可以填入可信 HTTPS Core ML `.mlmodel` 地址进行升级。模型下载后会编译并检查文本输入/输出兼容性。
- Qwen：模型库内置 Qwen2.5-0.5B-Instruct GGUF Q4_K_M 中国镜像下载，下载后校验 SHA-256 并保存到本机。GGUF 文件需要集成 llama.cpp/MLX GGUF 推理引擎后才能运行。
- 隐私表达：产品按“本地优先”设计，健康数据属于敏感信息，不应默认上传云端。

## 技术结构

- SwiftUI + Observation，最低 iOS 17。
- `HealthStore` 作为界面状态和服务编排入口；数据模型、主题、页面分层，便于替换数据源和推理实现。
- `HealthMetric`、`Insight`、`ModelTier` 为可扩展的领域模型。后续可新增指标、建议类型和模型档位，而不需要重写导航结构。
- 当前内置模型包是可离线运行的轻量策略模型，真实 Core ML 神经网络模型可通过模型库替换。HealthKit 已接入授权和读取今日步数、平均心率、活跃能量；没有 HealthKit 数据时不会显示虚构健康指标，页面会引导用户同步或手动添加。

## 打开工程

本仓库提供 XcodeGen 工程描述 `project.yml`。安装 XcodeGen 后，在项目目录运行：

```sh
xcodegen generate
open SmartHealth.xcodeproj
```

在 Xcode 中选择 iPhone 模拟器运行。也可将 `SmartHealthApp.swift`、`Models.swift`、`Theme.swift`、`RootView.swift`、`SecondaryViews.swift` 加入一个 iOS 17+ SwiftUI App target。


## 健康建议边界

此原型用于健康管理和生活方式提示，不用于诊断、治疗或紧急情况判断。建议应展示数据来源与时间范围，遇到异常症状应引导用户咨询专业医疗人员。
