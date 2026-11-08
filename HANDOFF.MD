# HANDOFF

## Scoop 清单维护

- 本仓库测试要求文本文件使用 CRLF。新增或修改 manifest 后运行 `.\bin\test.ps1`；若出现 non-CRLF 报错，只转换当前修改文件，不要批量重写其他文件。
- 新增应用清单时，先核对 Release 资产的真实目录结构和可执行文件名，再运行 `.\bin\checkver.ps1 -App <name>` 与 `.\bin\checkhashes.ps1 -App <name>`。
- 上游只有预发布、导致 `/releases/latest` 返回 404 时，`checkver.github` 可指向 `https://api.github.com/repos/<owner>/<repo>/releases?per_page=1`，并用 JSONPath `$[0].tag_name` 读取版本。
