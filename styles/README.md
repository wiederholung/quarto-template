# 样式与版本

- `docx/`：中英文 Word 参考文档和必要的 Quarto 兼容代码。
- `csl/`：本地 IEEE CSL，保留原文件作者和 CC BY-SA 3.0 声明。
- `latex/`：保留旧 PDF 共享宏、作者标题块及素材，当前原生基线不加载这些覆盖。中文 ctexart、英文 scrartcl 在单篇文档中选择。
- `html/`：保留旧屏幕阅读样式，当前不加载；HTML 使用 Quarto 的 `cosmo` 主题。
- `manifest.json`：来源、基线 commit、开发版本和 SHA-256。标为工作树快照的文件包含未发布的本地修改，不能把基线 commit 当作修改后的发布版本。

Word 样式由相邻 `pandoc_docx_template` 仓库中的 `scripts/build_quarto_references.py` 生成，原始普通版模板保持不变。正文中英文分别使用首行缩进与段间距；其他样式以清晰的层级、紧凑题注和三线表为主。

Word 作者区采用本项目的独立规范：“姓名 → ORCID → 机构数字及 † 上标 → 通信信封”。作者 12 pt，机构与说明 10.5 pt，居中、1.15 倍行距。ORCID 直径 0.75 em，保留绿色；信封为黑色矢量轮廓，保持行内大小。机构每项一段，同等贡献使用 †，通信邮箱合并为一段、按作者顺序排列，不重复姓名。日期和摘要继续排在作者信息之后。完整尺寸、间距、换行和元数据规则见 [作者区设计规范](../docs/作者区设计规范.md)。

Word 的图标嵌入 SVG，并携带旧版阅读器所需的 PNG 备用图；图标、上标及间距的比例集中在扩展中。修改参考文档的作者或说明字号时，可用 `authors-block.docx.author-size` 和 `note-size` 同步行内几何尺寸。素材来源和转换命令见扩展的 `assets/README.md`，无需渲染时联网或安装 SVG 转换器。

PDF 现采用 Quarto 内置 LaTeX 模板与文档类默认排版，原生标题区只显示作者姓名。`latex/title.tex`、`latex/common.tex`、`latex/zh.tex` 及 ORCID 素材作为旧设计保留但不启用。后续从 PDF 基线评估必要调整，再规范 Word；详见 [PDF 基线记录](../docs/PDF基线.md)。HTML 使用 Quarto 原生作者区。

`docx/compat.lua` 在 Quarto 核心过滤器之后运行：移除覆盖题注样式的直接属性，区分数据表与布局表，将等宽分图整理为原生 Word 并列表格。分图与各自题注保持同段，分页由参考文档样式控制。该过滤器还合并 Word 摘要标签与首段，并在写出 DOCX 前修正 `docx-callout` 区块的列网格、宽度与段落属性。提示框宽度读取参考文档的页面与页边距。正常渲染没有 `post-render` 步骤。章节编号和引用保留 Quarto 默认输出。两个脚本中的原生多级编号及 REF 域实现保留但默认不启用，仅供维护者设置环境变量 `QUARTO_DOCX_NATIVE_NUMBERING=1` 并显式运行 `finalize-docx.lua` 开启实验；只设置环境变量不能完成原生编号。提示框字号、间距由参考文档的 Callout Title / Body / Icon 样式管理。当前示例覆盖单图、双图、三线表及表注；不承诺任意嵌套版式都能自动转换。

维护者在两个来源仓库检查修改后，运行 `python scripts/sync-styles.py` 更新快照，再重新渲染受影响的格式并运行检查。普通使用者无需运行这个脚本。发布时记录真实发布 commit/tag；已经创建的项目不会自动更新。

仅固定样式文件不能保证不同电脑上的分页完全相同。归档应保留最终 PDF、Quarto/Pandoc/TeX 版本与字体信息；需要更强复现性时固定工具链环境。
