# 第四批验收记录

- 接收日期：2026-11-15。
- 批次：`STAGE4-AUTO-001`。
- 用户运行结果：stage4-run-001，**整体 passed**。
- 树结构回归：35 passed、0 failed、35 total，逐项 cases 均通过。
- 输入／事件：36 passed、0 failed、36 total，逐项 cases 均通过。
- 合计：**71 项检查全部通过**。
- 环境：Lua 5.3、OpenOS 1.8.9；实际 OC 版本仍未独立核验，GTNH 2.9.0 由客户端目录名指示。
- 依据：开发端直接回读用户给定 Windows 目录中的原始报告，复制后逐一核对 SHA-256，没有在开发端重新运行 Lua。

证据：report.json（原始记录保留在开发工作区）、tree-regression.log（原始记录保留在开发工作区）、events.log（原始记录保留在开发工作区）、summary.txt（原始记录保留在开发工作区）、SHA256.json（原始记录保留在开发工作区）。

本批验收的是合成信号与纯分发逻辑，不包含真实键盘／触摸、焦点管理、指针捕获、Application 或按钮。下一停点为 [第五批焦点与捕获测试](../STAGE5.md)，尚未执行。
