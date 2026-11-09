# rclone + Google Drive

讓 Claude 在 Google Drive 上有一塊自己的空間，用來放素材與開發工具的壓縮檔。
安裝由 `modules/rclone` 負責；remote 與授權是每台機器手動做一次的步驟，**不進版控**。

## 安全模型

| 層 | 做法 | 擋住什麼 |
|---|---|---|
| 權限範圍 | `scope = drive.file` | token 只看得到 rclone 自己建立的檔案（`claude/`），Drive 其他內容看不到也碰不到 |
| token 存放 | `~/.config/rclone/rclone.conf`，0600，不在 repo | 其他使用者讀不到；同帳號的程式仍讀得到，所以才需要上一層 |
| Claude 權限 | `configs/claude/settings.json` 的 allow / ask / deny | 列出與下載免問；sync / move / delete / purge 一律先問；不讀設定檔、不 `config show` |
| 安裝來源 | 官方 zip + `SHA256SUMS` 比對 | 下載途中被換掉的檔案不會被安裝 |
| 更新 | `sys_patch_status`（sps）每天比對官方版本 | 漏洞修正不會因為沒有套件管理員而被忘記 |

Drive 刪除的檔案進垃圾桶，30 天內可救回。

## Drive 結構

```
claude/
  inbox/            Roger 丟給 Claude 的東西
  assets/<專案>/    素材
  tools/            開發工具安裝檔、壓縮檔
  archive/          從本機移過去騰空間的舊東西
  tmp/              真正的暫存，隨時可清
```

`drive.file` 只看得到 rclone 建立的檔案：從 Drive 網頁直接上傳的檔案 rclone 看不到，
要放進 `claude/` 就用 rclone 上傳。

## 初次設定

### 1. Google Cloud OAuth client（瀏覽器，一次）

1. console.cloud.google.com → 新增專案。
2. 啟用 Google Drive API：
   `https://console.cloud.google.com/apis/library/drive.googleapis.com` → 啟用。
   （左側選單預設收起，從左上角 ☰ 進「API 和服務」→「程式庫」也可以；先確認上方選的是這個專案。）
3. ☰ → Google Auth Platform → 開始使用：名稱、支援信箱、使用者類型 **External**。
4. 「資料存取權」→ 新增或移除範圍 → 只勾 `.../auth/drive.file`（不是 `drive`、不是 `drive.readonly`）→ 更新 → 儲存。
5. 「目標對象」→ 測試使用者 → **加入自己的 Gmail**。漏了這步，授權時會出現
   「已封鎖存取權…尚未完成 Google 驗證程序」（403 access_denied）。
6. 「用戶端」→ 建立用戶端 → 類型 **電腦版應用程式** → 建立後立刻下載 JSON（之後可能看不到完整 secret）。

正式版（In production）需要首頁與隱私權政策網址，而且要在能向 Google 驗證擁有權的網域上；
沒做之前停在測試模式，**token 每 7 天過期**。

### 2. 安裝

```bash
dotfiles rclone            # = sudo bash install.sh rclone
```

### 3. 建立 remote（這台的終端機）

```bash
read -rp 'Client ID: ' RC_ID
read -rsp 'Client secret: ' RC_SECRET; echo
rclone config create gdrive drive \
  client_id="$RC_ID" client_secret="$RC_SECRET" \
  scope=drive.file config_is_local=false
unset RC_ID RC_SECRET
```

`read -s` 不回顯，歷史紀錄只留變數名。若這一步結束時設定檔裡沒有 `token`，接著做第 4 步。

### 4. 授權

```bash
rclone config reconnect gdrive:
```

| 問題 | 回答 |
|---|---|
| Use web browser to automatically authenticate…? | 見下方 |
| Configure this as a Shared Drive (Team Drive)? | **n**（答 y 而 token 還是空的，會報 `empty token found`） |

- **透過 VS Code Remote-SSH 連進來**：在 VS Code 內建終端機回答 **y**。VS Code 會把
  `127.0.0.1:53682` 轉到本機並開瀏覽器（或 Ctrl+點網址）。授權後若瀏覽器連不上，
  到「連接埠」分頁確認本機埠也是 53682。
- **其他無瀏覽器的情況**：回答 **n**，在有瀏覽器的電腦上執行它印出的
  `rclone authorize "drive" "…"`，把結果貼回來。

瀏覽器出現「Google 尚未驗證這個應用程式」：自己建的 app，按「進階」→「繼續」。

### 5. 驗證

```bash
stat -c '%A' ~/.config/rclone/rclone.conf     # -rw-------
grep '^scope ' ~/.config/rclone/rclone.conf   # scope = drive.file
rclone about gdrive:                          # 容量是對的帳號
rclone lsd gdrive:                            # 一開始是空的：drive.file 隔離有效
for d in inbox assets tools archive tmp; do rclone mkdir "gdrive:claude/$d"; done
```

## 日常

| 做什麼 | 指令 |
|---|---|
| 列出 | `rclone lsf gdrive:claude/assets/` |
| 下載 | `rclone copy gdrive:claude/tools/x.zip ./` |
| 上傳 | `rclone copy ./x.zip gdrive:claude/tools/` |
| token 過期（測試模式每 7 天） | `rclone config reconnect gdrive:` |
| 更新 rclone | `dotfiles rclone`（sps 會提示有新版；不用 `rclone selfupdate`） |

只用 `copy`；`sync` 會刪掉目的地多出來的檔案，真要用先加 `--dry-run`。
不開 `rclone serve` / `rclone rcd`。

## 緊急關閉

由輕到重：

1. **停掉正在跑的**：`pkill -x rclone`（卡住用 `pkill -9 -x rclone`）；Claude 在跑就按 Esc。
   中斷的上傳不會在 Drive 留下半個檔案；本機可能留下 `.partial`。
2. **這台暫時斷開**：`mv ~/.config/rclone/rclone.conf{,.off}`，改回原名即恢復。
3. **token 失效（懷疑外洩）**：
   - 可恢復：Cloud Console → Google Drive API → 停用 API。
   - 永久：myaccount.google.com/permissions → 移除這個 app。
4. **事後**：影響只限 `claude/`；Drive 垃圾桶 30 天；Drive 網頁的「活動」看最近變動。
