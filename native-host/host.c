#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <libgen.h>

// Simple JSON string value extractor
// Finds "key":"value" and returns a copy of value
char* json_get(const char *json, const char *key) {
    char pattern[256];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *pos = strstr(json, pattern);
    if (!pos) return strdup("");

    pos += strlen(pattern);
    while (*pos == ' ' || *pos == ':') pos++;
    if (*pos != '"') return strdup("");
    pos++;

    const char *end = strchr(pos, '"');
    if (!end) return strdup("");

    size_t len = end - pos;
    char *result = malloc(len + 1);
    memcpy(result, pos, len);
    result[len] = '\0';
    return result;
}

// Load config.json from same directory as the binary
// Returns 1 on success, 0 on failure
int load_config(const char *argv0, char *whatsapp_app, char *business_app, size_t bufsize) {
    // Default values
    strncpy(whatsapp_app, "WhatsApp", bufsize);
    strncpy(business_app, "WhatsApp Business", bufsize);

    // Build path to config.json next to the binary
    char config_path[2048];

    // Try /proc/self/exe first (Linux), then argv[0]
    char exe_dir[2048];
    strncpy(exe_dir, argv0, sizeof(exe_dir) - 1);
    exe_dir[sizeof(exe_dir) - 1] = '\0';
    char *dir = dirname(exe_dir);

    snprintf(config_path, sizeof(config_path), "%s/config.json", dir);

    FILE *f = fopen(config_path, "r");
    if (!f) return 0; // No config file, use defaults

    char buf[4096];
    size_t n = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[n] = '\0';

    char *val;

    val = json_get(buf, "whatsapp_app");
    if (strlen(val) > 0) strncpy(whatsapp_app, val, bufsize);
    free(val);

    val = json_get(buf, "business_app");
    if (strlen(val) > 0) strncpy(business_app, val, bufsize);
    free(val);

    return 1;
}

void send_response(const char *json) {
    uint32_t len = (uint32_t)strlen(json);
    fwrite(&len, 4, 1, stdout);
    fwrite(json, len, 1, stdout);
    fflush(stdout);
}

int main(int argc, char *argv[]) {
    // Load app names from config
    char whatsapp_app[512], business_app[512];
    load_config(argv[0], whatsapp_app, business_app, sizeof(whatsapp_app));

    // Read 4-byte message length
    uint32_t msg_len;
    if (fread(&msg_len, 4, 1, stdin) != 1) {
        send_response("{\"success\":false,\"error\":\"No input\"}");
        return 1;
    }

    // Read JSON message
    char *msg = malloc(msg_len + 1);
    if (fread(msg, msg_len, 1, stdin) != 1) {
        send_response("{\"success\":false,\"error\":\"Read error\"}");
        free(msg);
        return 1;
    }
    msg[msg_len] = '\0';

    // Parse fields
    char *app = json_get(msg, "app");
    char *phone = json_get(msg, "phone");
    char *text = json_get(msg, "text");
    free(msg);

    // Map app name from config
    const char *app_name = NULL;
    if (strcmp(app, "WhatsApp") == 0) {
        app_name = whatsapp_app;
    } else if (strcmp(app, "WhatsApp Business") == 0) {
        app_name = business_app;
    }

    if (!app_name) {
        send_response("{\"success\":false,\"error\":\"Unknown app\"}");
        free(app); free(phone); free(text);
        return 0;
    }

    // Build whatsapp:// URL
    char wa_url[2048];
    char params[1024] = "";

    if (strlen(phone) > 0) {
        snprintf(params, sizeof(params), "phone=%s", phone);
    }
    if (strlen(text) > 0) {
        if (strlen(params) > 0) strcat(params, "&");
        char tmp[512];
        snprintf(tmp, sizeof(tmp), "text=%s", text);
        strcat(params, tmp);
    }

    if (strlen(params) > 0) {
        snprintf(wa_url, sizeof(wa_url), "whatsapp://send?%s", params);
    } else {
        snprintf(wa_url, sizeof(wa_url), "whatsapp://send");
    }

    // Build and execute open command
    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "open -a '%s' '%s'", app_name, wa_url);
    int result = system(cmd);

    if (result == 0) {
        send_response("{\"success\":true}");
    } else {
        send_response("{\"success\":false,\"error\":\"Failed to open app\"}");
    }

    free(app); free(phone); free(text);
    return 0;
}
