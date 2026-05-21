import Foundation
import Security

/// 單一 AI CLI 的配額快照（聚焦「目前 5 小時滾動視窗」）
struct CLIUsage {
    let name: String                     // "Claude Code" / "Codex"
    var available: Bool = false          // 是否成功取得資料
    var usedPercent: Double = 0          // 5 小時視窗已用百分比
    var resetAt: Date? = nil             // 5 小時視窗重置時間點
    var weekUsedPercent: Double? = nil   // 每週視窗已用百分比
    var status: String = "讀取中…"        // 顯示用狀態 / 錯誤訊息

    /// 5 小時視窗剩餘百分比
    var remainingPercent: Double { max(0, 100 - usedPercent) }

    /// 距離重置還有幾分鐘；nil = 未知，0 = 即將重置
    var minutesToReset: Int? {
        guard let r = resetAt else { return nil }
        let secs = r.timeIntervalSinceNow
        return secs > 0 ? Int((secs / 60).rounded()) : 0
    }
}

/// 讀取 Claude Code 與 Codex 的本機配額狀況。
/// - Codex：完全離線，讀最新 rollout 檔內建的 rate-limit 快照。
/// - Claude：本機無快照，呼叫 `api.anthropic.com/api/oauth/usage`（憑證取自 Keychain）。
final class TokenUsageMonitor: ObservableObject {
    @Published var claude = CLIUsage(name: "Claude Code")
    @Published var codex  = CLIUsage(name: "Codex")

    /// 任一 CLI 有資料
    var hasData: Bool { claude.available || codex.available }

    /// 兩者中「剩餘最少」的百分比 — 供 menu bar 一眼示警
    var lowestRemaining: Double? {
        [claude, codex].filter(\.available).map(\.remainingPercent).min()
    }

    private var lastClaudeFetch: Date = .distantPast
    private let claudeInterval: TimeInterval = 300   // Claude API 最多 5 分鐘一次

    /// 觸發刷新。Codex 永遠重讀本機檔；Claude API 有 5 分鐘節流，`force` 可略過。
    func refresh(force: Bool = false) {
        Task {
            let result = await Self.readCodexUsage()
            await MainActor.run { self.codex = result }
        }
        if force || Date().timeIntervalSince(lastClaudeFetch) >= claudeInterval {
            lastClaudeFetch = Date()
            Task {
                let result = await Self.fetchClaudeUsage()
                await MainActor.run { self.claude = result }
            }
        }
    }

    // MARK: - Claude（呼叫官方 /usage 私有 API）

    private static func fetchClaudeUsage() async -> CLIUsage {
        var u = CLIUsage(name: "Claude Code")
        guard let token = readClaudeToken() else {
            u.status = "找不到 Claude 憑證（請先在 Claude Code 登入）"
            return u
        }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("openstat", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                u.status = "回應異常"; return u
            }
            if http.statusCode == 401 {
                u.status = "憑證已過期，請重新登入 Claude Code"; return u
            }
            guard http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                u.status = "API 錯誤（\(http.statusCode)）"; return u
            }

            if let fiveHour = json["five_hour"] as? [String: Any] {
                u.usedPercent = num(fiveHour["utilization"]) ?? 0
                u.resetAt = parseISO(fiveHour["resets_at"] as? String)
            }
            if let sevenDay = json["seven_day"] as? [String: Any] {
                u.weekUsedPercent = num(sevenDay["utilization"])
            }
            u.available = true
            u.status = "已更新"
            return u
        } catch {
            u.status = "連線失敗"
            return u
        }
    }

    /// 從 macOS Keychain 取出 Claude Code 的 OAuth access token。
    /// 首次存取時系統會跳出鑰匙圈授權提示，按「允許」即可。
    private static func readClaudeToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        return token
    }

    // MARK: - Codex（讀本機 rollout 檔內建的 rate-limit 快照）

    private static func readCodexUsage() async -> CLIUsage {
        var u = CLIUsage(name: "Codex")
        let sessions = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions")

        guard let newest = newestRollout(in: sessions) else {
            u.status = "找不到 Codex session"
            return u
        }
        guard let content = try? String(contentsOf: newest, encoding: .utf8) else {
            u.status = "讀取 session 失敗"
            return u
        }

        // 由後往前找最後一筆帶 rate_limits 的事件
        for line in content.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard line.contains("rate_limits"),
                  let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = obj["payload"] as? [String: Any],
                  let rateLimits = payload["rate_limits"] as? [String: Any]
            else { continue }

            if let primary = rateLimits["primary"] as? [String: Any] {
                u.usedPercent = num(primary["used_percent"]) ?? 0
                if let ts = num(primary["resets_at"]) {
                    u.resetAt = Date(timeIntervalSince1970: ts)
                }
            }
            if let secondary = rateLimits["secondary"] as? [String: Any] {
                u.weekUsedPercent = num(secondary["used_percent"])
            }
            u.available = true
            u.status = "已更新"
            return u
        }

        u.status = "session 中無配額資料"
        return u
    }

    /// 遞迴找 `~/.codex/sessions` 下修改時間最新的 rollout 檔
    private static func newestRollout(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        var best: (url: URL, date: Date)?
        for case let url as URL in enumerator {
            guard url.lastPathComponent.hasPrefix("rollout-"),
                  url.pathExtension == "jsonl" || url.pathExtension == "json"
            else { continue }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if best == nil || mod > best!.date { best = (url, mod) }
        }
        return best?.url
    }

    // MARK: - 共用小工具

    /// JSON 數值統一轉 Double（涵蓋整數 / 浮點）
    private static func num(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        return nil
    }

    /// 解析 ISO8601 字串。先去掉小數秒（ISO8601DateFormatter 只吃 3 位、來源是 6 位）。
    private static func parseISO(_ string: String?) -> Date? {
        guard var s = string else { return nil }
        if let range = s.range(of: #"\.\d+"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)
    }
}
