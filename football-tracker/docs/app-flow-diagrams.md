# Football Tracker 业务流程图

> 将下方每个 mermaid 代码块粘贴到 [mermaid.live](https://mermaid.live) 即可导出 PNG/SVG 图片。

---

## 1. 整体应用架构图 (System Architecture)

```mermaid
graph TB
    subgraph WearOS["⌚ WearOS 手表"]
        W_GPS["GPS定位服务<br/>1Hz采集"]
        W_HR["心率传感器<br/>Health Services"]
        W_UI["手表界面<br/>开始/结束记录"]
        W_SYNC["DataLayer同步"]
    end

    subgraph Android["📱 Android 手机"]
        A_WEAR["WearDataSync<br/>监听手表数据"]
        A_ROOM["Room本地数据库<br/>sessions + track_points"]
        A_ANALYSIS["SessionAnalyzer<br/>数据分析引擎"]
        A_UI["Compose UI<br/>首页/统计/设置"]
        A_NET["Retrofit网络层<br/>API调用"]
        A_AUTH["AuthRepository<br/>登录管理"]
        A_TOKEN["TokenStore<br/>JWT存储"]
    end

    subgraph Server["☁️ 云端服务器 (Azure VM)"]
        S_NGINX["Nginx反向代理<br/>:80/:443"]
        S_KTOR["Ktor后端<br/>:8080"]
        S_PG["PostgreSQL<br/>用户+训练数据"]
    end

    subgraph External["🌐 外部服务"]
        EXT_SMS["腾讯云短信"]
        EXT_WX["微信开放平台"]
    end

    W_GPS --> W_SYNC
    W_HR --> W_SYNC
    W_UI --> W_GPS
    W_UI --> W_HR
    W_SYNC -->|"Wearable DataLayer"| A_WEAR
    A_WEAR --> A_ANALYSIS
    A_ANALYSIS --> A_ROOM
    A_WEAR -->|"自动上传"| A_NET
    A_UI --> A_ROOM
    A_UI --> A_NET
    A_AUTH --> A_NET
    A_TOKEN --> A_NET
    A_NET -->|"HTTPS"| S_NGINX
    S_NGINX --> S_KTOR
    S_KTOR --> S_PG
    S_KTOR --> EXT_SMS
    S_KTOR --> EXT_WX

    style WearOS fill:#E8F5E9,stroke:#4CAF50
    style Android fill:#E3F2FD,stroke:#2196F3
    style Server fill:#FFF3E0,stroke:#FF9800
    style External fill:#F3E5F5,stroke:#9C27B0
```

---

## 2. 用户登录与注册流程 (Auth Flow)

```mermaid
flowchart TD
    START((打开APP)) --> CHECK{已登录?}
    CHECK -->|是| HOME[🏠 首页]
    CHECK -->|否| LOGIN[📲 登录页]

    LOGIN --> PHONE_BTN["手机号登录"]
    LOGIN --> WX_BTN["微信登录"]

    %% 手机号登录流程
    PHONE_BTN --> INPUT_PHONE["输入手机号<br/>自动补+86前缀"]
    INPUT_PHONE --> SEND_SMS["POST /api/auth/sms/send<br/>发送验证码"]
    SEND_SMS --> TENCENT["腾讯云短信API<br/>发送6位验证码"]
    TENCENT --> INPUT_CODE["输入6位验证码<br/>60秒倒计时可重发"]
    INPUT_CODE --> VERIFY["POST /api/auth/sms/verify<br/>校验验证码"]
    VERIFY --> VERIFY_OK{验证通过?}
    VERIFY_OK -->|失败| INPUT_CODE
    VERIFY_OK -->|成功| JWT_PHONE["服务端签发JWT<br/>返回uid+token+isNewUser"]

    %% 微信登录流程
    WX_BTN --> WX_SDK["调起微信APP<br/>WeChat SDK SendAuth"]
    WX_SDK --> WX_CALLBACK["WXEntryActivity<br/>接收OAuth code"]
    WX_CALLBACK --> WX_AUTH["POST /api/auth/wechat<br/>发送code到服务器"]
    WX_AUTH --> WX_SERVER["服务器换取access_token<br/>获取openId+昵称"]
    WX_SERVER --> JWT_WX["签发JWT<br/>返回uid+token+isNewUser"]

    %% 新用户/老用户分流
    JWT_PHONE --> NEW_USER{新用户?}
    JWT_WX --> NEW_USER
    NEW_USER -->|是| ONBOARD["📝 引导页<br/>输入昵称/体重/年龄"]
    NEW_USER -->|否| HOME
    ONBOARD --> SAVE_PROFILE["PUT /api/user/profile<br/>保存用户资料"]
    SAVE_PROFILE --> HOME

    style START fill:#4CAF50,color:#fff
    style HOME fill:#2196F3,color:#fff
    style LOGIN fill:#FFC107
    style ONBOARD fill:#FF9800,color:#fff
    style TENCENT fill:#9C27B0,color:#fff
    style WX_SDK fill:#07C160,color:#fff
```

---

## 3. 核心业务流程：踢球记录全链路 (Session Recording Flow)

```mermaid
flowchart TD
    subgraph WATCH["⌚ 手表端"]
        W_START["点击 '开始记录'"] --> W_GPS_ON["启动GPS前台服务<br/>1Hz高精度定位"]
        W_START --> W_HR_ON["启动心率监测<br/>Wear Health Services"]
        W_GPS_ON --> W_TRACKING["实时显示<br/>时长 | 距离 | 心率 | 速度"]
        W_HR_ON --> W_TRACKING
        W_TRACKING --> W_STOP["点击 '结束记录'"]
        W_STOP --> W_CALC["快速计算摘要<br/>距离/卡路里/摸鱼指数"]
        W_CALC --> W_SUMMARY["显示总结<br/>'详情请看手机'"]
        W_CALC --> W_PUSH["DataLayer推送<br/>GPS轨迹 + 心率数据"]
    end

    subgraph PHONE["📱 手机端"]
        P_RECV["WearDataSync<br/>后台接收数据"] --> P_MERGE["合并GPS与心率<br/>按时间戳±5秒匹配"]
        P_MERGE --> P_ANALYZE["SessionAnalyzer 分析"]

        subgraph ANALYSIS["📊 分析引擎 (Shared KMP)"]
            A1["DistanceCalculator<br/>总距离(Haversine)"]
            A2["SpeedAnalyzer<br/>均速/极速/冲刺次数<br/>高强度距离"]
            A3["CalorieEstimator<br/>基于心率的卡路里<br/>(Keytel公式)"]
            A4["SlackDetector<br/>摸鱼指数0-100"]
            A5["FatigueAnalyzer<br/>每5分钟体能分段"]
            A6["HeatmapGenerator<br/>50×30覆盖热力图"]
        end

        P_ANALYZE --> A1 & A2 & A3 & A4 & A5 & A6
        A1 & A2 & A3 & A4 & A5 & A6 --> P_SAVE["保存到Room数据库"]
        P_SAVE --> P_UPLOAD["POST /api/sessions/sync<br/>上传到云端"]
    end

    W_PUSH -->|"蓝牙/WiFi"| P_RECV

    subgraph CLOUD["☁️ 云端"]
        C_STORE["PostgreSQL<br/>持久存储"]
    end

    P_UPLOAD --> C_STORE

    style WATCH fill:#E8F5E9,stroke:#4CAF50
    style PHONE fill:#E3F2FD,stroke:#2196F3
    style ANALYSIS fill:#FFF9C4,stroke:#FBC02D
    style CLOUD fill:#FFF3E0,stroke:#FF9800
```

---

## 4. 数据查看与交互流程 (Data Viewing Flow)

```mermaid
flowchart TD
    HOME["🏠 首页"] --> MONTHLY["月度汇总卡片<br/>总距离 | 场次 | 总卡路里"]
    HOME --> LIST["训练列表<br/>按月分组 倒序排列"]
    LIST --> TAP_SESSION["点击某次训练"]

    TAP_SESSION --> DETAIL["📋 训练详情页"]

    DETAIL --> D1["距离 + 时长"]
    DETAIL --> D2["2×4 数据卡片<br/>极速/均速/平均心率/最高心率<br/>卡路里/冲刺次数/高强度距离/覆盖率"]
    DETAIL --> D3["🐟 摸鱼指数仪表盘<br/>0-30 拼命三郎 🟢<br/>31-60 有点偷懒 🟡<br/>61-100 场上观光 🔴"]
    DETAIL --> D4["📈 速度曲线图"]
    DETAIL --> D5["❤️ 心率曲线图"]
    DETAIL --> D6["📊 疲劳分析柱状图<br/>每5分钟跑动距离"]
    DETAIL --> D7["🗺️ 热力图"]
    D7 --> HEATMAP["全屏热力图页"]

    HOME -.->|底部导航| STATS["📊 统计页"]
    HOME -.->|底部导航| SETTINGS["⚙️ 设置页"]

    STATS --> S1["累计总距离"]
    STATS --> S2["累计场次 + 总时长"]
    STATS --> S3["总卡路里 + 场均距离"]
    STATS --> S4["历史最高速度"]
    STATS --> S5["平均摸鱼指数"]

    SETTINGS --> SET1["👤 个人资料编辑<br/>昵称/体重/年龄"]
    SETTINGS --> SET2["☁️ 立即同步<br/>上传未同步数据"]
    SETTINGS --> SET3["📥 恢复数据<br/>从云端拉取"]
    SETTINGS --> SET4["🚪 退出登录"]

    style HOME fill:#2196F3,color:#fff
    style DETAIL fill:#FF9800,color:#fff
    style STATS fill:#4CAF50,color:#fff
    style SETTINGS fill:#607D8B,color:#fff
    style D3 fill:#FFF9C4,stroke:#FBC02D
```

---

## 5. 云端数据同步流程 (Cloud Sync Flow)

```mermaid
flowchart TD
    subgraph AUTO["自动同步 (手表数据到达时)"]
        A1["WearDataSync接收数据"] --> A2["保存到本地Room"]
        A2 --> A3{已登录?}
        A3 -->|是| A4["POST /api/sessions/sync<br/>上传训练记录"]
        A3 -->|否| A5["标记syncedToCloud=0<br/>等待登录后同步"]
        A4 --> A6["标记syncedToCloud=1"]
    end

    subgraph MANUAL_UP["手动同步 (设置页 - 立即同步)"]
        M1["点击'立即同步'"] --> M2["查询所有<br/>syncedToCloud=0的记录"]
        M2 --> M3{有未同步?}
        M3 -->|是| M4["POST /api/sessions/sync<br/>批量上传"]
        M3 -->|否| M5["提示'已全部同步'"]
        M4 --> M6["标记syncedToCloud=1"]
    end

    subgraph RESTORE["数据恢复 (设置页 - 恢复数据)"]
        R1["点击'恢复数据'"] --> R2["GET /api/sessions<br/>拉取云端所有记录"]
        R2 --> R3["对比本地数据库<br/>按session id去重"]
        R3 --> R4["插入缺失记录到Room"]
        R4 --> R5["数据恢复完成<br/>首页自动刷新"]
    end

    style AUTO fill:#E8F5E9,stroke:#4CAF50
    style MANUAL_UP fill:#E3F2FD,stroke:#2196F3
    style RESTORE fill:#FFF3E0,stroke:#FF9800
```

---

## 6. 页面导航地图 (Screen Navigation Map)

```mermaid
stateDiagram-v2
    [*] --> 判断登录状态

    判断登录状态 --> 登录页: 未登录
    判断登录状态 --> 首页: 已登录

    登录页 --> 手机验证码页: 手机号登录
    登录页 --> 微信授权: 微信登录

    手机验证码页 --> 引导页: 新用户
    手机验证码页 --> 首页: 老用户
    微信授权 --> 引导页: 新用户
    微信授权 --> 首页: 老用户

    引导页 --> 首页: 完成资料填写

    state 主界面 {
        首页 --> 训练详情: 点击训练记录
        训练详情 --> 热力图: 查看热力图
        热力图 --> 训练详情: 返回

        首页 --> 统计页: 底部导航
        统计页 --> 首页: 底部导航

        首页 --> 设置页: 底部导航
        设置页 --> 首页: 底部导航
        统计页 --> 设置页: 底部导航
    end

    设置页 --> 登录页: 退出登录
```

---

## 使用说明

1. 打开 [mermaid.live](https://mermaid.live)
2. 将上方任一 `mermaid` 代码块的内容粘贴到编辑器中
3. 右侧会自动渲染流程图
4. 点击右上角 **Actions → Download PNG/SVG** 导出图片
5. 将导出的图片提交即可

也可以使用 VS Code 的 **Markdown Preview Mermaid Support** 插件直接在 IDE 中预览。
