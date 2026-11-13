# HANDOFF

## Scoop 清单维护

- 本仓库测试要求文本文件使用 CRLF。新增或修改 manifest 后运行 `.\bin\test.ps1`；若出现 non-CRLF 报错，只转换当前修改文件，不要批量重写其他文件。
- 新增应用清单时，先核对 Release 资产的真实目录结构和可执行文件名，再运行 `.\bin\checkver.ps1 -App <name>` 与 `.\bin\checkhashes.ps1 -App <name>`。
- 上游只有预发布、导致 `/releases/latest` 返回 404 时，`checkver.github` 可指向 `https://api.github.com/repos/<owner>/<repo>/releases?per_page=1`，并用 JSONPath `$[0].tag_name` 读取版本。
- 匿名 GitHub API 可能返回 403 速率限制；此时使用已连接的 GitHub 工具或 Scoop 的 GitHub token 查询 Release，不能据此判断仓库或资产不存在。

## 合并 BucketTemplate 上游更新

- 保留本仓库 README 的安装命令、清单列表，以及 Excavator 每天一次的 cron（`20 4 * * *`），不要直接覆盖为模板占位符或每四小时运行。
- 本仓库曾使用 `pull_request_target`，但固定到 GithubActions v3.0.0 后，其 PR 处理入口只接受 `pull_request` 和 `issue_comment`。合并时需将触发器和 job `if` 条件一起对齐上游；Git 自动合并不会发现这种逻辑冲突。`/verify` 已整合进该工作流，无需保留独立的 `issue_comment.yml`。
- GithubActions v3.0.0 会跳过 fork PR 的首次清单检查，可在 PR 中评论 `/verify` 触发验证；普通 CI 测试仍会自动运行。
- 本机 Git 默认启用 GPG 签名，签名子密钥位于硬件卡。提交报 `Operation cancelled` 时，先用 `gpg --card-status` 检查；若提示 `Service is not running`，检查 Windows `SCardSvr`（Smart Card）服务。启动该服务可能需要管理员权限；受阻时保留暂存的合并结果，不要改动全局签名配置。
