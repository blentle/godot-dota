# 平台与对战协议草案 v0.1

这是后续实现契约，目前没有对应 API 服务。

M2 的本机单席位开发适配器已实现独立子集，见 [双进程验证](m2-network.md)。其简化字段、清单哈希及无认证连接仅用于本机测试，不能替代本文件的正式身份、内容校验与十人装载契约。

## HTTP / WebSocket

所有接口前缀 `/v1`，通过 HTTPS 使用平台会话；密码使用现代密码哈希，访问会话短期有效，刷新会话可撤销。状态变更包含幂等键，请求身份由会话确定，不信任 body 内的 user_id。

| 接口 | 用途 |
|---|---|
| POST /auth/register、/auth/login、/auth/refresh、/auth/logout | 账号与会话 |
| GET /versions | 已发布版本、客户端构建、内容哈希与下载清单 |
| GET /rooms；POST /rooms/{id}/join、/leave | 浏览和进入匹配大厅 |
| POST /queue/join、/queue/leave | 加入/取消指定版本、地区、模式队列 |
| POST /matches/{id}/accept | 接受 ready check |
| POST /matches/{id}/launch-ticket | 为本人的已分配席位签发票据 |
| POST /matches/{id}/reconnect-ticket | 重连窗口内重新签发 |
| GET /session/state | 断线恢复当前房间/队列/比赛状态 |
| WSS /events | queue.updated、match.ready_check、match.allocated、match.aborted、match.finished |

错误返回 code、message、request_id、retryable；至少区分 VERSION_MISMATCH、ALREADY_QUEUED、READY_TIMEOUT、SERVER_UNAVAILABLE、MATCH_EXPIRED。事件含递增 sequence 和 match_id，恢复连接必须先读取权威状态再续订事件。

## 状态机

用户：`idle → in_room → queued → ready_check → allocated → launching → loading → drafting → playing → finished → in_room`。

取消仅适用于 queued；ready_check 失败进入 in_room 或 queued（已确认且愿意继续的玩家）；allocated 后失败必须由比赛协调器处理，不能单方面再入队。比赛：`forming → confirming → allocating → loading → drafting → running → finished`，各等待阶段可转 aborted，running 崩溃可转 interrupted。

10 人分配、用户唯一活动席位和版本一致性必须在事务或原子脚本中成立；不能靠 UI 禁用按钮保证。装载屏障超时后 abort，释放服务器与席位。实际期限由配置控制。

## 启动票据与游戏连接

平台长期令牌只保存在启动器。短期票据至少绑定 account_id、match_id、slot、build_id、content_hash、expires_at、nonce。平台原子兑换 nonce，过期、重复、错版本、错席位均拒绝。重试启动须签发新 nonce 并撤销旧票据。

启动器以固定配置的可执行文件路径和参数数组创建子进程，不接受远程任意命令或任意路径。短期票据通过限制访问的本地 IPC 交给游戏，日志和进程参数不得包含令牌。游戏用 HTTPS 兑换后获得绑定对战进程的短期连接凭据。

对战首包验证协议版本、构建 ID、内容哈希与连接凭据，验证完成前不发完整世界信息。平台到对战服务器的管理接口使用独立服务身份，不对普通玩家开放。

## 游戏命令与快照

命令信封：protocol_version、match_id、sequence、client_tick、command_type、entity_ids、target。控制权从已验证连接取得，客户端不得指定任意玩家身份。限制消息体大小、单位数量、速率及序号窗口。

起始命令：move、attack_target、attack_move、stop、hold、cast、learn_ability、buy、sell、use_item、select_hero。界面选择操作可保持本地；购买/施法/升级必须经过服务器。

快照包含 server_tick、baseline_id、可见实体与确认命令序号。完整快照使用可靠交付，增量丢基线时请求重同步。装载完成上报内容哈希与场景就绪状态，权威端收齐 10 个席位后发阶段转换。

结果提交使用独立服务鉴权并绑定分配的 match_id、进程实例、获胜方及统计；数据库按 match_id 唯一写入，重复回调返回已有结果。客户端不得上传权威胜负。
