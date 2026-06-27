module net::http;

import std::io;
import std::net::url;
import std::core::string::conv;
import std::core::mem;
import std::core::dstring;
import bad::stealth;
// ─── WinHTTP Types ────────────────────────────────────────────────────────────
alias Win32_HINTERNET = void*;
alias Win32_BOOL = int;
alias Win32_DWORD = uint;
alias Win32_DWORD_PTR = uint;
alias Win32_LPCSTR = Char16*;
alias Win32_LPVOID = void*;

// ─── WinHTTP Constants ───────────────────────────────────────────────────────

const WINHTTP_ACCESS_TYPE_DEFAULT_PROXY = 0;
const WINHTTP_OPTION_ADD_HEADERS = 0x20000003;
const WINHTTP_FLAG_SECURE = 0x00800000;
// ─── WinHTTP Extern Declarations ─────────────────────────────────────────────

extern fn Win32_HINTERNET winHttpOpen(
    Win32_LPCSTR pwszUserAgent,
    Win32_DWORD dwAccessType,
    Win32_LPCSTR pwszProxyName,
    Win32_LPCSTR pwszProxyBypass,
    Win32_DWORD dwFlags
) @cname("WinHttpOpen");

extern fn Win32_BOOL winHttpCloseHandle(Win32_HINTERNET hInternet) @cname("WinHttpCloseHandle");

extern fn Win32_HINTERNET winHttpConnect(
    Win32_HINTERNET hSession,
    Win32_LPCSTR pwszServerName,
    Win32_DWORD nServerPort,
    Win32_DWORD dwReserved
) @cname("WinHttpConnect");

extern fn Win32_HINTERNET winHttpOpenRequest(
    Win32_HINTERNET hConnect,
    Win32_LPCSTR pwszVerb,
    Win32_LPCSTR pwszObjectName,
    Win32_LPCSTR pwszVersion,
    Win32_LPCSTR pwszReferrer,
    Win32_LPCSTR* ppszAcceptTypes,
    Win32_DWORD dwFlags
) @cname("WinHttpOpenRequest");

extern fn Win32_BOOL winHttpSetOption(
    Win32_HINTERNET hInternet,
    Win32_DWORD dwOption,
    Win32_LPVOID lpBuffer,
    Win32_DWORD dwBufferLength
) @cname("WinHttpSetOption");

extern fn Win32_BOOL winHttpSendRequest(
    Win32_HINTERNET hRequest,
    Win32_LPCSTR pwszHeaders,
    Win32_DWORD dwHeadersLength,
    Win32_LPVOID lpOptional,
    Win32_DWORD dwOptionalLength,
    Win32_DWORD dwTotalLength,
    Win32_DWORD_PTR dwContext
) @cname("WinHttpSendRequest");

extern fn Win32_BOOL winHttpReceiveResponse(Win32_HINTERNET hRequest, Win32_LPVOID lpReserved) @cname("WinHttpReceiveResponse");

extern fn Win32_BOOL winHttpQueryDataAvailable(Win32_HINTERNET hRequest, Win32_DWORD* lpdwSize) @cname("WinHttpQueryDataAvailable");

extern fn Win32_BOOL winHttpReadData(
    Win32_HINTERNET hRequest,
    Win32_LPVOID lpBuffer,
    Win32_DWORD dwBufferSize,
    Win32_DWORD* lpdwBytesRead
) @cname("WinHttpReadData");

// ─── Stealth Headers ─────────────────────────────────────────────────────────
// ─── Stealth Headers (dynamic from bad::stealth) ─────────────────────────

fn String stealth_headers_str() {
    String ua = stealth::stealth_user_agent();
    String hdrs = stealth::stealth_headers();
    DString h = dstring::temp_with_capacity(512);
    h.append("User-Agent: ");
    h.append(ua);
    h.append("\r\n");
    h.append(hdrs);
    return h.str_view();
}

// ─── HTTP Request ────────────────────────────────────────────────────────────

fn String http_get(String url) {
    return http_request("GET", url, "");
}

fn String http_post(String url, String body) {
    return http_request("POST", url, body);
}
fn String http_request(String method, String url, String body) {
    Url parsed = url::tparse(url)!!;
    int port = parsed.port;
    if (port == 0) {
        if (parsed.scheme == "https") {
            port = 443;
        } else {
            port = 80;
        }
    }
    
    // 构建路径（包含查询字符串）
    String path = parsed.path;
    if (parsed.query.len > 0) {
        path = path.tconcat("?").tconcat(parsed.query);
    }
    
    // Convert strings to UTF-16 for WinHTTP
    Char16[] user_agent = @char16("BadHeadlessBrowser/1.0");
    Char16[] host = parsed.host.to_temp_utf16()!!;
    Char16[] method_utf16 = method.to_temp_utf16()!!;
    Char16[] path_utf16 = path.to_temp_utf16()!!;
    String headers_str = stealth_headers_str();
    Char16[] headers_utf16 = headers_str.to_temp_utf16()!!;
    
    // WinHTTP 流程
    Win32_HINTERNET h_session = winHttpOpen(user_agent.ptr, WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, null, null, 0);
    if (h_session == null) {
        return "";
    }
    
    Win32_HINTERNET h_connect = winHttpConnect(h_session, host.ptr, (uint)port, 0);
    if (h_connect == null) {
        winHttpCloseHandle(h_session);
        return "";
    }
    
    int flags = parsed.scheme == "https" ? WINHTTP_FLAG_SECURE : 0;
    Win32_HINTERNET h_request = winHttpOpenRequest(h_connect, method_utf16.ptr, path_utf16.ptr, null, null, null, (Win32_DWORD)flags);
    if (h_request == null) {
        winHttpCloseHandle(h_connect);
        winHttpCloseHandle(h_session);
        return "";
    }
    
    // 设置 stealth headers
    Win32_DWORD headers_len = (Win32_DWORD)(headers_utf16.len * 2);
    winHttpSetOption(h_request, WINHTTP_OPTION_ADD_HEADERS, headers_utf16.ptr, headers_len);
    
    // 发送请求
    Win32_BOOL sent = winHttpSendRequest(h_request, null, 0, body.ptr, (uint)body.len, (uint)body.len, 0);
    if (!sent) {
        winHttpCloseHandle(h_request);
        winHttpCloseHandle(h_connect);
        winHttpCloseHandle(h_session);
        return "";
    }
    
    winHttpReceiveResponse(h_request, null);
    
    // 读取响应体
    String body_str = read_response_body(h_request);
    
    // 清理
    winHttpCloseHandle(h_request);
    winHttpCloseHandle(h_connect);
    winHttpCloseHandle(h_session);
    
    return body_str;
}

fn String read_response_body(Win32_HINTERNET h_request) {
    String body = "";
    
    while (true) {
        Win32_DWORD bytes_available = 0;
        if (!winHttpQueryDataAvailable(h_request, &bytes_available)) {
            break;
        }
        if (bytes_available == 0) {
            break;
        }
        
        char[] chunk = mem::new_array(char, bytes_available);
        Win32_DWORD bytes_read = 0;
        if (winHttpReadData(h_request, chunk, bytes_available, &bytes_read)) {
            body = body.tconcat((String)chunk[:bytes_read]);
        }
        mem::free(chunk);
        
        if (bytes_read == 0) {
            break;
        }
    }
    
    return body;
}
