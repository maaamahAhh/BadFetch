module bad::stealth;

import std::core::dstring;

// ─── Mode ──────────────────────────────────────────────────────
// 0 = Chrome (default), 1 = Firefox, 2 = curl
int _mode = 0;

fn void stealth_set_mode(int v) { _mode = v; }

// ─── Chrome version (Chrome mode only) ─────────────────────────
String _chrome_version = "131";

fn void stealth_set_version(String v) { _chrome_version = v; }
fn String _chrome_ver() { return _chrome_version; }

// ─── User-Agent per mode ───────────────────────────────────────

fn String stealth_user_agent()
{
    if (_mode == 2) return "curl/8.11.0";
    if (_mode == 1) {
        return "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:135.0) Gecko/20100101 Firefox/135.0";
    }

    DString ua = dstring::temp_with_capacity(128);
    ua.append("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/");
    ua.append(_chrome_ver());
    ua.append(".0.0.0 Safari/537.36");
    return ua.str_view();
}

// ─── Stealth Headers per mode ──────────────────────────────────

fn String stealth_headers()
{
    if (_mode == 2) {
        return "Accept: */*\r\n";
    }

    DString h = dstring::temp_with_capacity(1024);
    h.append("Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8\r\n");
    h.append("Accept-Language: en-US,en;q=0.5\r\n");
    h.append("Accept-Encoding: gzip, deflate, br\r\n");
    h.append("Connection: keep-alive\r\n");
    h.append("Upgrade-Insecure-Requests: 1\r\n");
    h.append("Sec-Fetch-Dest: document\r\n");
    h.append("Sec-Fetch-Mode: navigate\r\n");
    h.append("Sec-Fetch-Site: none\r\n");
    h.append("Sec-Fetch-User: ?1\r\n");

    if (_mode == 0) {
        h.append("sec-ch-ua: \"Google Chrome\";v=\"");
        h.append(_chrome_ver());
        h.append("\", \"Chromium\";v=\"");
        h.append(_chrome_ver());
        h.append("\", \"Not/A)Brand\";v=\"99\"\r\n");
        h.append("sec-ch-ua-mobile: ?0\r\n");
        h.append("sec-ch-ua-platform: \"Windows\"\r\n");
    }

    return h.str_view();
}
