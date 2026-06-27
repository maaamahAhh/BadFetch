module bad;
import net::http;
import bad::stealth;
import std::core::mem;
import libc;
import std::thread;

struct PageHandle
{
    char* current_url;
    bool is_active;
}

PageHandle[256] pages;
uint page_count = 0;

RecursiveMutex g_engine_mutex;
int g_mutex_state = 0;

fn void init_engine_mutex()
{
    int expected = 0;
    int old = mem::compare_exchange(&g_mutex_state, expected, 1);
    if (old == expected && old == 0) {
        g_engine_mutex.init();
    }
}

fn PageHandle* get_page(uint handle)
{
    init_engine_mutex();
    g_engine_mutex.lock();
    defer g_engine_mutex.unlock();
    if (handle >= page_count) return null;
    if (!pages[handle].is_active) return null;
    return &pages[handle];
}

fn String cstr_to_str(char* cstr)
{
    if (cstr == null) return "";
    ZString zs = (ZString)cstr;
    return zs.str_view();
}

fn char* str_to_cstr(String s)
{
    if (s.len == 0) return null;
    sz len = s.len;
    char* buf = (char*)malloc(len + 1);
    mem::copy(buf, s.ptr, len);
    buf[len] = 0;
    return buf;
}

fn void bad_set_chrome_version(char* version_cstr) @export("bad_set_chrome_version")
{
    String v = cstr_to_str(version_cstr);
    stealth::stealth_set_version(v);
}

fn void bad_set_mode(int mode) @export("bad_set_mode")
{
    stealth::stealth_set_mode(mode);
}

fn uint bad_page_new() @export("bad_page_new")
{
    init_engine_mutex();
    g_engine_mutex.lock();
    defer g_engine_mutex.unlock();
    if (page_count >= 256) return 0xFFFF_FFFF;
    uint handle = page_count;
    page_count++;
    pages[handle].current_url = null;
    pages[handle].is_active = true;
    return handle;
}

fn char* bad_page_fetch(uint handle, char* url_cstr) @export("bad_page_fetch")
{
    init_engine_mutex();
    g_engine_mutex.lock();
    PageHandle* page = get_page(handle);
    g_engine_mutex.unlock();
    if (page == null) return null;

    usz len = libc::strlen((ZString)url_cstr);
    String url = (String)(url_cstr[0:len]);

    String body = net::http::http_get(url);
    if (body.len == 0) return null;

    return str_to_cstr(body);
}

fn void bad_free(char* ptr) @export("bad_free")
{
    init_engine_mutex();
    g_engine_mutex.lock();
    defer g_engine_mutex.unlock();
    if (ptr != null) free(ptr);
}