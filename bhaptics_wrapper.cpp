/*
 * bhaptics_wrapper.cpp
 *
 * A thin Lua C extension (bhaptics_wrapper.dll) that exposes bhaptics_library.dll
 * functions to UE4SS Lua scripts.
 *
 * Build (MSVC, x64):
 *   cl /LD /MD /O2 /std:c++17
 *      bhaptics_wrapper.cpp
 *      /I"<path_to_lua_headers>"
 *      /link lua54.lib (or whatever Lua lib UE4SS ships — check the UE4SS source)
 *      /OUT:bhaptics_wrapper.dll
 *
 * Build (MinGW-w64, x64):
 *   g++ -shared -O2 -std=c++17
 *       -I<path_to_lua_headers>
 *       bhaptics_wrapper.cpp
 *       -L<path_to_lua_lib> -llua54
 *       -o bhaptics_wrapper.dll
 *
 * NOTE: UE4SS typically embeds Lua 5.4. Check the UE4SS release you are using
 * to confirm the Lua version and grab the matching headers + import library
 * from the UE4SS DEV zip or the Lua 5.4 Windows binaries.
 *
 * Both bhaptics_wrapper.dll and bhaptics_library.dll must sit in the same
 * /scripts/ folder as main.lua.
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

// ─── bhaptics_library.dll function signatures ────────────────────────────────
// These match the exported C API of bhaptics_library.dll (SDK2, Windows x64).
// Adjust if bhaptics releases a new DLL with different exports.

using fn_Initialize   = bool  (*)(const char* appId, const char* apiKey);
using fn_Destroy      = void  (*)();
using fn_Play         = int   (*)(const char* eventId);
using fn_PlayParam    = int   (*)(const char* eventId, float intensity,
                                  float duration, float angleX, float offsetY);
using fn_IsConnected  = bool  (*)();
using fn_IsPlaying    = bool  (*)(const char* eventId);
using fn_Stop         = void  (*)(const char* eventId);

// ─── Module state ─────────────────────────────────────────────────────────────
static HMODULE           g_hLib       = nullptr;
static fn_Initialize     g_Initialize = nullptr;
static fn_Destroy        g_Destroy    = nullptr;
static fn_Play           g_Play       = nullptr;
static fn_PlayParam      g_PlayParam  = nullptr;
static fn_IsConnected    g_IsConnected= nullptr;
static fn_IsPlaying      g_IsPlaying  = nullptr;
static fn_Stop           g_Stop       = nullptr;

// Helper: load a function pointer from the DLL, push error if missing
template<typename T>
static bool LoadProc(HMODULE h, T& out, const char* name, lua_State* L)
{
    out = reinterpret_cast<T>(GetProcAddress(h, name));
    if (!out) {
        if (L) luaL_error(L, "bhaptics_wrapper: symbol '%s' not found in bhaptics_library.dll", name);
        return false;
    }
    return true;
}

// ─── Lua-callable functions ───────────────────────────────────────────────────

// bhaptics.initialize(appId, apiKey) -> bool
static int l_initialize(lua_State* L)
{
    const char* appId  = luaL_checkstring(L, 1);
    const char* apiKey = luaL_checkstring(L, 2);

    // Load the DLL on first call (it must be next to this wrapper DLL)
    if (!g_hLib) {
        g_hLib = LoadLibraryA("bhaptics_library.dll");
        if (!g_hLib) {
            lua_pushboolean(L, 0);
            lua_pushstring(L, "Failed to load bhaptics_library.dll");
            return 2;
        }
        bool ok = true;
        ok &= LoadProc(g_hLib, g_Initialize,  "Initialize",   nullptr);
        ok &= LoadProc(g_hLib, g_Destroy,     "Destroy",      nullptr);
        ok &= LoadProc(g_hLib, g_Play,         "Play",         nullptr);
        ok &= LoadProc(g_hLib, g_PlayParam,   "PlayParam",    nullptr);
        ok &= LoadProc(g_hLib, g_IsConnected, "IsConnected",  nullptr);
        ok &= LoadProc(g_hLib, g_IsPlaying,   "IsPlaying",    nullptr);
        ok &= LoadProc(g_hLib, g_Stop,        "Stop",         nullptr);

        if (!ok) {
            // Try SDK2 mangled names as fallback (bhaptics sometimes ships
            // a C++ DLL with slightly different export names)
            // You can inspect the DLL with: dumpbin /EXPORTS bhaptics_library.dll
            FreeLibrary(g_hLib);
            g_hLib = nullptr;
            lua_pushboolean(L, 0);
            lua_pushstring(L, "bhaptics_library.dll loaded but required exports not found. "
                              "Run: dumpbin /EXPORTS bhaptics_library.dll to check names.");
            return 2;
        }
    }

    bool result = g_Initialize(appId, apiKey);
    lua_pushboolean(L, result ? 1 : 0);
    return 1;
}

// bhaptics.destroy()
static int l_destroy(lua_State* L)
{
    if (g_Destroy) g_Destroy();
    lua_pushboolean(L, 1);
    return 1;
}

// bhaptics.play(eventId) -> requestId (int, -1 on failure)
static int l_play(lua_State* L)
{
    if (!g_Play) { lua_pushinteger(L, -1); return 1; }
    const char* eventId = luaL_checkstring(L, 1);
    int reqId = g_Play(eventId);
    lua_pushinteger(L, reqId);
    return 1;
}

// bhaptics.play_param(eventId, intensity, duration, angleX, offsetY) -> requestId
static int l_play_param(lua_State* L)
{
    if (!g_PlayParam) { lua_pushinteger(L, -1); return 1; }
    const char* eventId  = luaL_checkstring(L, 1);
    float intensity      = (float)luaL_optnumber(L, 2, 1.0);
    float duration       = (float)luaL_optnumber(L, 3, 1.0);
    float angleX         = (float)luaL_optnumber(L, 4, 0.0);
    float offsetY        = (float)luaL_optnumber(L, 5, 0.0);
    int reqId = g_PlayParam(eventId, intensity, duration, angleX, offsetY);
    lua_pushinteger(L, reqId);
    return 1;
}

// bhaptics.is_connected() -> bool
static int l_is_connected(lua_State* L)
{
    bool v = g_IsConnected ? g_IsConnected() : false;
    lua_pushboolean(L, v ? 1 : 0);
    return 1;
}

// bhaptics.is_playing(eventId) -> bool
static int l_is_playing(lua_State* L)
{
    if (!g_IsPlaying) { lua_pushboolean(L, 0); return 1; }
    const char* eventId = luaL_checkstring(L, 1);
    lua_pushboolean(L, g_IsPlaying(eventId) ? 1 : 0);
    return 1;
}

// bhaptics.stop(eventId)
static int l_stop(lua_State* L)
{
    if (g_Stop) {
        const char* eventId = luaL_checkstring(L, 1);
        g_Stop(eventId);
    }
    return 0;
}

// ─── Module registration ──────────────────────────────────────────────────────
static const luaL_Reg bhaptics_funcs[] = {
    { "initialize",   l_initialize   },
    { "destroy",      l_destroy      },
    { "play",         l_play         },
    { "play_param",   l_play_param   },
    { "is_connected", l_is_connected },
    { "is_playing",   l_is_playing   },
    { "stop",         l_stop         },
    { nullptr, nullptr }
};

extern "C" __declspec(dllexport)
int luaopen_bhaptics_wrapper(lua_State* L)
{
    luaL_newlib(L, bhaptics_funcs);
    return 1;
}
