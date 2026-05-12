// StocksView.swift — track tickers via Stooq's free CSV endpoint.
// User can add/remove tickers; refreshes on demand and every 60s.
//
// API: https://stooq.com/q/l/?s=AAPL.US,MSFT.US&f=sd2t2ohlcvn&h&e=csv
//   Returns CSV with header — no API key, no rate limit headaches,
//   no crumb-cookie nonsense. Stooq covers US, EU, UK, JP markets.
//
// Why not Yahoo: query1.finance.yahoo.com/v7/finance/quote started
// requiring a per-session crumb cookie in 2023, so naked GETs return
// HTTP 401 with an HTML error page → "Couldn't parse Yahoo response."

import SwiftUI

struct StockQuote: Identifiable, Equatable {
    let symbol: String      // user-facing (no exchange suffix)
    let price: Double
    let prevClose: Double
    var change: Double { price - prevClose }
    var changePct: Double {
        guard prevClose != 0 else { return 0 }
        return (price - prevClose) / prevClose * 100
    }
    var id: String { symbol }
}

@MainActor
final class StocksService: ObservableObject {
    @AppStorage("np.stocks.symbols") var symbolsCSV: String = "AAPL,MSFT,NVDA,TSLA"
    @Published var quotes: [StockQuote] = []
    @Published var status: String = "Loading…"
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let symbols = symbolsCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
        guard !symbols.isEmpty else { quotes = []; status = ""; return }

        // Stooq US tickers need ".us" suffix. Other markets (.de, .uk,
        // etc.) are passed through if the user types them already.
        let suffixed = symbols.map { sym -> String in
            sym.contains(".") ? sym.lowercased() : "\(sym.lowercased()).us"
        }
        let joined = suffixed.joined(separator: ",")
        // f=spd2t2c1ohl — symbol, price, date, time, change, open, high, low
        // Format choice: keep it minimal, request what we use.
        let urlString = "https://stooq.com/q/l/?s=\(joined)&f=sd2t2ohlcvn&h&e=csv"
        guard let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let error = error {
                    self.status = error.localizedDescription
                    return
                }
                guard let data = data,
                      let body = String(data: data, encoding: .utf8) else {
                    self.status = "No response from Stooq."
                    return
                }
                self.parse(csv: body, originalSymbols: symbols)
            }
        }.resume()
    }

    /// Parse the Stooq CSV. Header is: Symbol,Date,Time,Open,High,Low,Close,Volume,Name
    private func parse(csv: String, originalSymbols: [String]) {
        let lines = csv.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else {
            self.status = "Empty Stooq response."
            return
        }
        // Skip header (first line)
        var parsed: [StockQuote] = []
        for (i, line) in lines.dropFirst().enumerated() {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false)
                .map(String.init)
            // Stooq returns "N/D" for unknown symbols → skip those.
            guard cols.count >= 7,
                  let close = Double(cols[6]),
                  let open  = Double(cols[3]) else { continue }
            // Use "open" as our previous-close proxy when prevClose
            // isn't available in this format. (Stooq's intraday CSV
            // doesn't include yesterday's close; open is a reasonable
            // baseline for the day's % change.)
            let symbol = i < originalSymbols.count
                ? originalSymbols[i]
                : cols[0].uppercased().replacingOccurrences(of: ".US", with: "")
            parsed.append(StockQuote(symbol: symbol, price: close, prevClose: open))
        }
        self.quotes = parsed
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
        self.status = parsed.isEmpty
            ? "No data — markets closed or all tickers invalid."
            : "Updated \(f.string(from: Date())) · % since open"
    }
}

struct StocksView: View {
    @StateObject private var service = StocksService()
    @State private var newSymbol: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Add symbol (AAPL)", text: $newSymbol)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .frame(width: 130)
                Button("+") {
                    let s = newSymbol.uppercased().trimmingCharacters(in: .whitespaces)
                    guard !s.isEmpty else { return }
                    var arr = service.symbolsCSV.split(separator: ",").map(String.init)
                    if !arr.contains(s) { arr.append(s) }
                    service.symbolsCSV = arr.joined(separator: ",")
                    newSymbol = ""
                    service.refresh()
                }.buttonStyle(.borderedProminent)
                Spacer()
                Button { service.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.bordered)
            }
            if service.quotes.isEmpty {
                Text(service.status.isEmpty
                     ? "Add a ticker symbol above to get started."
                     : service.status)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 4) {
                    ForEach(service.quotes) { q in
                        row(q)
                    }
                }
            }
            if !service.status.isEmpty && !service.quotes.isEmpty {
                Text(service.status).font(.system(size: 9)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func row(_ q: StockQuote) -> some View {
        let up = q.change >= 0
        return HStack {
            Text(q.symbol)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .frame(width: 56, alignment: .leading)
            Text(String(format: "$%.2f", q.price))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%.2f%%", q.changePct))
            }
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(up ? .green : .red)
            .monospacedDigit()
            Button {
                var arr = service.symbolsCSV.split(separator: ",").map(String.init)
                arr.removeAll { $0 == q.symbol }
                service.symbolsCSV = arr.joined(separator: ",")
                service.refresh()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
    }
}
