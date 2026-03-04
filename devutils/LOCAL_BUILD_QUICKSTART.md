# 本地构建说明（Windows）

## 0. 最小推荐命令

```bat
devutils\start_local_build.bat --threads 6 --no-proxies --step 1
devutils\start_local_build.bat --threads 6 --debug-file --no-proxies --step 2
devutils\start_local_build.bat --threads 6 --debug --proxy http://127.0.0.1:1081 --step 1
```

---

## 1. 前置条件

- Python 3.10+（建议 3.11）
- Visual Studio 2022（含 C++ 工具链）
- Git for Windows（提供 `sh.exe`）
- 已在仓库根目录执行命令：`E:\projects\my_chromium_patched`

---

## 2. 一键构建脚本

脚本：`devutils\start_local_build.bat`

### 常用参数

- `--threads <N>`：并行线程数（默认 `6`）
- `--proxy <URL>`：设置代理（示例：`http://127.0.0.1:1081`）
- `--no-proxy` / `--no-proxies`：禁用代理
- `--debug`：详细日志输出到**控制台+文件**
- `--debug-file`：详细日志仅输出到**文件**
- `--step <1|2|3>`：从指定步骤开始（默认 `1`）
  - `1`：`sync -> build -> package`
  - `2`：`build -> package`（跳过 sync）
  - `3`：仅 `package`（跳过 sync/build）

### 示例

```bat
devutils\start_local_build.bat --threads 6 --no-proxies --step 1
devutils\start_local_build.bat --threads 6 --debug-file --no-proxies --step 2
devutils\start_local_build.bat --threads 6 --debug --proxy http://127.0.0.1:1081
```

---

## 3. 构建阶段说明

脚本按以下阶段执行：

1. Sync dependencies（`gclient sync`）
2. Build Chromium（`build.py --ci -j N`）
3. Package（`package.py`）

脚本会输出每个阶段和总耗时（秒）。

---

## 4. 日志位置

- 日志目录：`build\logs`
- 文件名格式：`start_local_build_YYYYMMDD_HHMMSS.log`

---

## 5. 常见问题

### Q1: `Missing cargo ... third_party\rust-toolchain\bin\cargo.exe`

说明本地 Rust 工具链未准备好（常见于 `--step 2` 跳过 sync 后）。

建议：

1. 先执行 `--step 1` 跑完整流程；或
2. 手动准备 rust 工具链后再 `--step 2`。

---

### Q2: `where.exe sh` 失败 / 找不到 `sh`

需要 Git for Windows 的 `sh.exe`。

脚本已自动尝试加入：

- `C:\Program Files\Git\usr\bin`
- `C:\Program Files\Git\bin`

---

### Q3: `No supported Visual Studio can be found`

如果 VS 不在默认路径（如安装在 `D:\tools\...`），需设置环境变量：

```powershell
$env:DEPOT_TOOLS_WIN_TOOLCHAIN="0"
$env:vs2022_install="D:\tools\Microsoft Visual Studio\2022\Professional"
```

再执行构建命令。

---

### Q4: `--step 3` 直接失败

`--step 3` 只打包，不会编译。若没有已有产物，`package.py` 失败是正常现象。

---

## 6. 关于是否“每次都重新拉源码”

- 不会每次完整重新 clone。
- 但 `--step 1` 会执行 `gclient sync`，会做增量同步与依赖校验。
