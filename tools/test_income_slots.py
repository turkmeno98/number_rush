#!/usr/bin/env python3
"""Run the actual standard-Lua-compatible service using system liblua5.4.
Roblox persistence is mocked; no real profiles are accessed.
"""
import ctypes
import ctypes.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
library=ctypes.util.find_library('lua5.4')
if not library:
    raise SystemExit('liblua5.4 is required for this optional native test runner.')
lua=ctypes.CDLL(library)
Lptr=ctypes.c_void_p
lua.luaL_newstate.restype=Lptr
lua.luaL_openlibs.argtypes=[Lptr]
lua.luaL_loadbufferx.argtypes=[Lptr,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p,ctypes.c_char_p]
lua.luaL_loadbufferx.restype=ctypes.c_int
lua.lua_pcallk.argtypes=[Lptr,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ssize_t,ctypes.c_void_p]
lua.lua_pcallk.restype=ctypes.c_int
lua.lua_tolstring.argtypes=[Lptr,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype=ctypes.c_void_p
lua.lua_close.argtypes=[Lptr]
source='SLOT_SERVICE_PATH='+json.dumps(str(ROOT/'src/ServerScriptService/IncomeSlotService.lua'),ensure_ascii=False)+'\n'
source+=(ROOT/'tests/income_slots.lua').read_text()
encoded=source.encode('utf-8')
state=lua.luaL_newstate()
if not state:raise SystemExit('Could not allocate Lua state.')
try:
    lua.luaL_openlibs(state)
    result=lua.luaL_loadbufferx(state,encoded,len(encoded),b'income_slot_tests',None)
    if result==0:result=lua.lua_pcallk(state,0,-1,0,0,None)
    if result:
        size=ctypes.c_size_t()
        ptr=lua.lua_tolstring(state,-1,ctypes.byref(size))
        message=ctypes.string_at(ptr,size.value).decode('utf-8','replace') if ptr else 'Unknown Lua error'
        raise SystemExit(message)
finally:
    lua.lua_close(state)
