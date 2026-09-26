#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <libgen.h>
#include <spawn.h>
#include <sys/wait.h>

// Largest message accepted from Chrome. A wa.me link is a few KB at most; the
// cap only stops a bogus length prefix from allocating gigabytes.
#define MAX_MESSAGE (1024 * 1024)

// Growable string. Every URL piece goes through this, so no phone number or
// message text is ever copied into a fixed-size buffer.
typedef struct {
    char *buf;
    size_t len, cap;
} sbuf;

void sb_putn(sbuf *s, const char *p, size_t n) {
    if (s->len + n + 1 > s->cap) {
        size_t cap = s->cap ? s->cap : 256;
        while (s->len + n + 1 > cap) cap *= 2;
        char *grown = realloc(s->buf, cap);
        if (!grown) abort();
        s->buf = grown;
        s->cap = cap;
    }
    memcpy(s->buf + s->len, p, n);
    s->len += n;
    s->buf[s->len] = '\0';
}

void sb_puts(sbuf *s, const char *p) { sb_putn(s, p, strlen(p)); }
void sb_putc(sbuf *s, char c) { sb_putn(s, &c, 1); }

// Appends one Unicode code point as UTF-8.
void sb_put_utf8(sbuf *s, unsigned long cp) {
    char b[4];
    if (cp < 0x80) {
        b[0] = (char)cp;
        sb_putn(s, b, 1);
    } else if (cp < 0x800) {
        b[0] = (char)(0xC0 | (cp >> 6));
        b[1] = (char)(0x80 | (cp & 0x3F));
        sb_putn(s, b, 2);
    } else if (cp < 0x10000) {
        b[0] = (char)(0xE0 | (cp >> 12));
        b[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
        b[2] = (char)(0x80 | (cp & 0x3F));
        sb_putn(s, b, 3);
    } else {
        b[0] = (char)(0xF0 | (cp >> 18));
        b[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
        b[2] = (char)(0x80 | ((cp >> 6) & 0x3F));
        b[3] = (char)(0x80 | (cp & 0x3F));
        sb_putn(s, b, 4);
    }
}

// Reads 4 hex digits; stops at the first non-hex character (including the end
// of the string), so it never reads past a truncated escape.
int hex4(const char *p, unsigned long *out) {
    unsigned long v = 0;
    for (int i = 0; i < 4; i++) {
        char c = p[i];
        v <<= 4;
        if (c >= '0' && c <= '9') v |= (unsigned long)(c - '0');
        else if (c >= 'a' && c <= 'f') v |= (unsigned long)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') v |= (unsigned long)(c - 'A' + 10);
        else return 0;
    }
    *out = v;
    return 1;
}

// Simple JSON string value extractor for flat objects.
// Finds "key":"value" and returns a malloc'd copy of value with the JSON escapes
// decoded (\" \\ \/ \b \f \n \r \t and \uXXXX, surrogate pairs included), so a
// quote in the message no longer cuts the text short. Empty when missing.
char* json_get(const char *json, const char *key) {
    sbuf out = {0};
    sb_puts(&out, "");

    char pattern[256];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *pos = strstr(json, pattern);
    if (!pos) return out.buf;

    pos += strlen(pattern);
    while (*pos == ' ' || *pos == '\t' || *pos == '\n' || *pos == '\r' || *pos == ':') pos++;
    if (*pos != '"') return out.buf;
    pos++;

    while (*pos && *pos != '"') {
        if (*pos != '\\') {
            sb_putc(&out, *pos++);
            continue;
        }
        pos++;
        switch (*pos) {
        case '"': case '\\': case '/': sb_putc(&out, *pos++); break;
        case 'b': sb_putc(&out, '\b'); pos++; break;
        case 'f': sb_putc(&out, '\f'); pos++; break;
        case 'n': sb_putc(&out, '\n'); pos++; break;
        case 'r': sb_putc(&out, '\r'); pos++; break;
        case 't': sb_putc(&out, '\t'); pos++; break;
        case 'u': {
            unsigned long cp, low;
            if (!hex4(pos + 1, &cp)) return out.buf;
            pos += 5;
            if (cp >= 0xD800 && cp <= 0xDBFF && pos[0] == '\\' && pos[1] == 'u'
                && hex4(pos + 2, &low) && low >= 0xDC00 && low <= 0xDFFF) {
                cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
                pos += 6;
            } else if (cp >= 0xD800 && cp <= 0xDFFF) {
                cp = 0xFFFD;   // lone surrogate: replacement character
            }
            // A NUL would end the C string and silently cut the rest; drop it.
            if (cp != 0) sb_put_utf8(&out, cp);
            break;
        }
        default:
            return out.buf;    // malformed escape: keep what came before it
        }
    }
    return out.buf;
}

// Percent-encodes everything except RFC 3986 unreserved characters. The phone
// and text can then never add, split or cut URL parameters ("&" in the text
// stays text) and nothing is handed to `open` raw.
void sb_put_encoded(sbuf *s, const char *p) {
    static const char hex[] = "0123456789ABCDEF";
    for (; *p; p++) {
        unsigned char c = (unsigned char)*p;
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')
            || c == '-' || c == '.' || c == '_' || c == '~') {
            sb_putc(s, (char)c);
        } else {
            char e[3] = { '%', hex[c >> 4], hex[c & 15] };
            sb_putn(s, e, 3);
        }
    }
}

// WhatsApp wants the international number as digits only. What people type
// around it (+, spaces, dashes, dots, brackets) is dropped, and a leading 00
// counts like +. Anything else, e.g. the code of a wa.me/message/ short link,
// is not a phone number: better no chat than the wrong one. Numbers have at
// most 15 digits (E.164). Returns a malloc'd string, empty when invalid.
char* normalize_phone(const char *p) {
    sbuf out = {0};
    sb_puts(&out, "");
    for (; *p; p++) {
        if (*p >= '0' && *p <= '9') {
            sb_putc(&out, *p);
        } else if (!strchr("+ -.()", *p)) {
            out.buf[0] = '\0';
            return out.buf;
        }
    }
    char *d = out.buf;
    if (d[0] == '0' && d[1] == '0') memmove(d, d + 2, strlen(d + 2) + 1);
    if (strlen(d) > 15) d[0] = '\0';
    return d;
}

// The URL handed to the app: the button's URL base (default whatsapp://send)
// plus the phone and text as query parameters. A base that already has a query,
// e.g. "sup://send?account=business", gets them appended with "&".
char* build_url(const char *base, const char *phone, const char *text) {
    sbuf url = {0};
    sb_puts(&url, base);
    char sep = strchr(base, '?') ? '&' : '?';
    if (*phone) {
        sb_putc(&url, sep);
        sb_puts(&url, "phone=");
        sb_put_encoded(&url, phone);
        sep = '&';
    }
    if (*text) {
        sb_putc(&url, sep);
        sb_puts(&url, "text=");
        sb_put_encoded(&url, text);
    }
    return url.buf;
}

// What each button opens: the app (name or path, for `open -a`) and the URL
// base handed to it. The URL bases are optional in config.json; they let a
// button target an app with its own URL scheme, e.g. two accounts in one app:
//   "business_app": "Sup", "business_url": "sup://send?account=business"
typedef struct {
    char *whatsapp_app, *business_app;
    char *whatsapp_url, *business_url;
} config;

// Replaces *field with the config value for `key`, when present and non-empty.
void set_from(const char *json, const char *key, char **field) {
    char *val = json_get(json, key);
    if (strlen(val) > 0) {
        free(*field);
        *field = val;
    } else {
        free(val);
    }
}

// Parse a config.json at `path` into cfg.
// Returns 1 if the file was read, 0 if it couldn't be opened.
int parse_config_file(const char *path, config *cfg) {
    FILE *f = fopen(path, "r");
    if (!f) return 0;

    // Whole file: keys past the first 4 KB used to be silently ignored.
    static char buf[65536];
    size_t n = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[n] = '\0';

    set_from(buf, "whatsapp_app", &cfg->whatsapp_app);
    set_from(buf, "business_app", &cfg->business_app);
    set_from(buf, "whatsapp_url", &cfg->whatsapp_url);
    set_from(buf, "business_url", &cfg->business_url);
    return 1;
}

// Load the config, preferring the stable user config dir, then falling back to a
// config.json next to the binary (legacy manual installs). Homebrew wipes the
// Cellar on upgrade, so the binary's directory is not a safe place for config.
// Returns 1 if a config file was found, 0 if defaults were used.
int load_config(const char *argv0, config *cfg) {
    // Default values
    cfg->whatsapp_app = strdup("WhatsApp");
    cfg->business_app = strdup("WhatsApp Business");
    cfg->whatsapp_url = strdup("whatsapp://send");
    cfg->business_url = strdup("whatsapp://send");

    char config_path[2048];

    // 1. ~/.config/whatsapp-chooser/config.json (Homebrew, upgrade-safe)
    const char *home = getenv("HOME");
    if (home && *home) {
        snprintf(config_path, sizeof(config_path), "%s/.config/whatsapp-chooser/config.json", home);
        if (parse_config_file(config_path, cfg)) return 1;
    }

    // 2. config.json next to the binary (legacy manual install)
    char exe_dir[2048];
    strncpy(exe_dir, argv0, sizeof(exe_dir) - 1);
    exe_dir[sizeof(exe_dir) - 1] = '\0';
    char *dir = dirname(exe_dir);
    snprintf(config_path, sizeof(config_path), "%s/config.json", dir);
    return parse_config_file(config_path, cfg);
}

void send_response(const char *json) {
    uint32_t len = (uint32_t)strlen(json);
    fwrite(&len, 4, 1, stdout);
    fwrite(json, len, 1, stdout);
    fflush(stdout);
}

int main(int argc, char *argv[]) {
    // Load app names and URL bases from config
    config cfg;
    load_config(argv[0], &cfg);

    // Read 4-byte message length
    uint32_t msg_len;
    if (fread(&msg_len, 4, 1, stdin) != 1) {
        send_response("{\"success\":false,\"error\":\"No input\"}");
        return 1;
    }
    if (msg_len > MAX_MESSAGE) {
        send_response("{\"success\":false,\"error\":\"Message too large\"}");
        return 1;
    }

    // Read JSON message
    char *msg = malloc((size_t)msg_len + 1);
    if (!msg || fread(msg, msg_len, 1, stdin) != 1) {
        send_response("{\"success\":false,\"error\":\"Read error\"}");
        free(msg);
        return 1;
    }
    msg[msg_len] = '\0';

    // Parse fields
    char *app = json_get(msg, "app");
    char *raw_phone = json_get(msg, "phone");
    char *phone = normalize_phone(raw_phone);
    char *text = json_get(msg, "text");
    free(raw_phone);
    free(msg);

    // Map the button to an app and URL base from config
    const char *app_name = NULL;
    const char *base = NULL;
    if (strcmp(app, "WhatsApp") == 0) {
        app_name = cfg.whatsapp_app;
        base = cfg.whatsapp_url;
    } else if (strcmp(app, "WhatsApp Business") == 0) {
        app_name = cfg.business_app;
        base = cfg.business_url;
    }

    if (!app_name) {
        send_response("{\"success\":false,\"error\":\"Unknown app\"}");
        free(app); free(phone); free(text);
        return 0;
    }

    char *wa_url = build_url(base, phone, text);

    // Launch the app with an explicit argument vector via posix_spawn so the
    // untrusted URL (it embeds attacker-controllable message text) is passed as a
    // single literal argument and never parsed by a shell. Building a string for
    // system() here let a single quote in the text break out of the quoting and
    // run arbitrary commands; posix_spawn removes the shell from the path entirely.
    // "--" ends open's options, so a URL starting with "-" can never be read as
    // flags (open -R, -g and friends would still exit 0 without opening it).
    extern char **environ;
    char *const open_argv[] = { "open", "-a", (char *)app_name, "--", wa_url, NULL };
    pid_t pid;
    int result = -1;
    if (posix_spawn(&pid, "/usr/bin/open", NULL, NULL, open_argv, environ) == 0) {
        int status;
        if (waitpid(pid, &status, 0) == pid && WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            result = 0;
        }
    }

    if (result == 0) {
        send_response("{\"success\":true}");
    } else {
        send_response("{\"success\":false,\"error\":\"Failed to open app\"}");
    }

    free(wa_url);
    free(app); free(phone); free(text);
    return 0;
}
