# S2S 开发者规范（Contributing）

本文定义协作流程与编码规范，保证改动可维护、可验证、可回滚。

## 流程
- 分支策略：
  - `main`：稳定分支，仅接受通过评审的变更。
  - `feature/*`：功能分支（小步提交）。
  - `release/*`：发版分支（冻结修复）。
- 提交规范：
  - 消息格式：`<type>: <summary>`（type: feat/fix/docs/refactor/build/chore）。
  - 提交小而清：同一提交只做一件事。
- 代码评审：
  - 自检通过（本地运行、重要路径覆盖）后提 PR；说明改动范围与回滚策略。

## 代码规范
- Python 3.10+；强制类型标注；PEP8。
- 禁止 `print`；统一 `logger`。
- 错误处理：捕获→日志→不吞异常；对用户可恢复路径给出提示。
- 异步与线程：
  - 音频回调中只做轻操作；耗时逻辑放到异步任务。
  - 与 UI 的通信使用线程安全手段；避免全局可变共享。
- 依赖：
  - 不引入大体积/不合规依赖；如需新增，先在 Issue 中论证。

## 测试与验证
- 变更范围内的功能必须可手动验证；推荐添加脚本（如 smoke test）。
- 关键路径：
  - 连接重试/看门狗/优雅关停。
  - 设备选择与切换（有/无 BlackHole）。
  - 日志脱敏与文件滚动。

## 打包与发版
- 官网分发：
  - `bash packaging/build_app.sh` → `dist/S2S.app`
  - `bash packaging/build_pkg.sh` → `dist/S2S-<ver>.pkg`
  - 公证签名（参考团队文档）。
- App Store 版（合规构建）：
  - 禁用自动安装/系统修改；开启沙盒。
  - 使用 Xcode 壳工程上传。

## 安全
- 禁止在代码/日志/注释中泄露任何密钥；密钥仅在 Keychain。
- 首启导入后清理 `app_secrets.json`（自动完成）。

## PR 检查清单
- [ ] 仅修改必要文件；未引入无关改动。
- [ ] 日志级别与信息适当；无敏感数据。
- [ ] 关键路径经手动验证；无阻塞音频回调。
- [ ] 打包脚本/站点下载链接不受破坏。

# S2S 开发者读本（工程指北）

本读本面向后续维护者，说明项目架构、关键约束、编码规范、打包分发与常见坑位，帮助你在不破坏稳定性的前提下安全扩展功能。

## 1. 架构与模块边界

- UI（菜单栏 App）
  - `app_menu.py`: 菜单与交互中枢；负责启动/停止后端、设备/语言切换、字幕窗与偏好持久化、BlackHole 检测与（官网版）自动安装。
  - `preferences.py`: 偏好存取（NSUserDefaults 优先，fallback 到 `~/.config/s2s/preferences.json`）。
- 引擎（实时同传）
  - `realtime_simple.py`: 采集（`sounddevice`）→ WebSocket（`websockets` + Protobuf）→ 播放（PCM 48k FIFO）。含心跳、重连、看门狗与优雅关停。
  - `config.py`: `.env` → Keychain → `app_secrets.json` 的配置/凭证加载；首启将明文密钥导入 Keychain 并重命名 `app_secrets.json`，避免明文残留。
  - `logger.py`: 统一日志（控制台+滚动文件），敏感信息脱敏；支持动态调整级别。
- 资源与站点
  - `resources/BlackHole2ch.pkg`: 官网分发用的虚拟声卡安装包（App Store 版禁用自动安装）。
  - `website/`: 官网静态站点（SEO、下载、反馈）。
- 打包与安装
  - `packaging/macos.spec`、`Info.plist`、`build_app.sh`: 生成 `dist/S2S.app`。
  - `packaging/build_pkg.sh`、`postinstall`: 生成 `dist/S2S-<ver>.pkg`，安装后尝试部署 BlackHole（官网分发）。

> 边界准则：UI 只做状态与参数管理；引擎只做实时音频/网络；配置与日志模块必须无副作用、可独立测试。

## 2. 运行时数据流

- 采集：InputStream（16k/mono/80ms）→ 队列（asyncio.Queue）→ WS TaskRequest（持续）。
- 服务端事件：TTSSentenceStart/Response/End（PCM 汇聚）与 Source/Translation Subtitle（分片→句尾合并）。
- 播放：PCM s16 → float32 归一 → FIFO 播放；仅在句尾做极短淡出防爆音。
- 稳定性：心跳（ping/pong），连接失败指数退避；看门狗在会话非活动时 1→2→4→8s 重试；UI 线程死亡一次性自恢复。

## 3. 编码规范

- Python 版本：3.10+（类型注解必写，`Optional[int]` 等）。
- 代码风格：PEP8；命名清晰；避免一字母变量；函数短小、单一职责。
- 日志：禁止 `print`；统一使用 `logger`（INFO 为默认；支持 UI 动态切换）。严禁输出密钥与隐私数据；必要时打 `DEBUG`，并确保脱敏过滤生效。
- 错误处理：尽量捕获并分等级日志（warning/error）；不可吞异常无痕；面向用户的异常需可恢复或有提示。
- 线程/异步：
  - 音频 callback 内不得做阻塞操作（网络/锁等待/磁盘），仅轻量数据搬运。
  - 与 UI 的跨线程交互通过线程安全方式（如 `asyncio.run_coroutine_threadsafe`）。
  - 看门狗是唯一的全局自恢复入口；不要在多处做“隐式重连”。
- 依赖：最小化。新增依赖前需评估打包体积、许可证、App Store 合规性。

## 4. 配置与凭证

- 加载顺序：Env → Keychain（`keyring`）→ `app_secrets.json`。
- 首启导入：若读取到 `app_secrets.json` 且 Keychain 可用，将密钥写入 Keychain 并将该文件重命名为 `app_secrets.imported`。
- 禁止：在日志/异常/界面上显示任何密钥；不要把密钥打进 Git。

## 5. 日志与诊断

- 位置：控制台 + `~/Library/Logs/S2S/s2s.log`（App Store 版应使用沙盒容器路径）。
- 滚动策略：5×5MB。
- 脱敏：`SecretRedactFilter` 会覆盖常见敏感键（API_*、X-Api-*）。
- 问题定位：
  - 连接失败：检查 WS URL、证书、代理；看门狗退避是否生效。
  - 爆音/电音：确认目标音频 PCM 直通；仅句尾微淡出；勿在回调里做重采样或重处理。
  - 卡顿：发送节拍（80ms）保持稳定；`_sender_task` 的时间基准与队列饥饿日志。

## 6. 设备与会议模式

- 默认：输入/输出使用系统默认；用户可在 UI 选择具体设备索引。
- 会议模式（官网版）：
  - 自动检测 BlackHole；如未安装，优先资源包安装，其次 Homebrew，失败引导文档。
- App Store 版：
  - 禁止自动安装/系统修改；仅检测并提示用户自行安装；引导“共享电脑声音”作为替代路径。

## 7. 打包与分发

- 官网分发：
  - `bash packaging/build_app.sh` → `dist/S2S.app`
  - `bash packaging/build_pkg.sh` → `dist/S2S-<ver>.pkg`
  - 公证签名（步骤 8，另文档）。
- App Store 版（建议单独分支/构建标记）：
  - 打开沙盒；移除自动安装逻辑；日志写容器内；Info.plist 添加用途文案。
  - 使用 Xcode 壳工程上传（Archive → Distribute）。

## 8. 常见坑位与规避

- 音频回调阻塞：严禁网络/磁盘/复杂计算；仅做数据复制与轻转换。
- 队列拥塞：发送/接收协程异常退出会导致积压；看门狗+队列清理必须生效。
- 设备索引飘移：热插拔设备可能导致索引变化；UI 显示名称+索引，必要时做存在性校验并回退到默认。
- 密钥明文遗留：确保首启导入后重命名 `app_secrets.json`；日志过滤器必须启用。
- App Store 合规：
  - 不安装驱动、不调用 brew/installer/osascript。
  - 不自更新可执行代码；保持沙盒；隐私用途清晰。

## 9. 扩展建议（为未来留口）

- 功能：多语言、热键控制、字幕透明度/字号、历史记录（本地）、使用统计（匿名、可关闭）。
- 商业化：解锁更多语言/时长的内购（App Store 版），官网版 License Key（离线验签）。
- 社区：内置反馈入口接私有表单/Issue Bot；官网收集吐槽的 API 网关。

---
维护时保持“小步可验证”的思路：优先添加高价值、低耦合的能力；对稳定路径（采集/播放/WS）以最小入侵改动为原则。