/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "luaobject.h"

#include "framework/core/graphicalapplication.h"

#include <shared_mutex>
#include <typeindex>
#include <unordered_map>

int16_t g_luaThreadId = -1;

LuaObject::LuaObject() :
    m_fieldsTableRef(-1)
{
}

LuaObject::~LuaObject()
{
#ifndef NDEBUG
    assert(!g_app.isTerminated());
#endif
    releaseLuaFieldsTable();
}

bool LuaObject::hasLuaField(const std::string_view field) const
{
    bool ret = false;
    if (m_fieldsTableRef != -1) {
        g_lua.getRef(m_fieldsTableRef);
        g_lua.getField(field); // push the field value
        ret = !g_lua.isNil();
        g_lua.pop(2);
    }
    return ret;
}

void LuaObject::releaseLuaFieldsTable()
{
    if (m_fieldsTableRef != -1) {
        g_lua.unref(m_fieldsTableRef);
        m_fieldsTableRef = -1;
    }
}

void LuaObject::clearLuaField(const std::string_view key)
{
    g_lua.pushNil();
    luaSetField(key);
}

void LuaObject::luaSetField(const std::string_view key)
{
    // create fields table on the fly
    if (m_fieldsTableRef == -1) {
        g_lua.newTable(); // create fields table
        m_fieldsTableRef = g_lua.ref(); // save a reference for it
    }

    g_lua.getRef(m_fieldsTableRef); // push the table
    g_lua.insert(-2); // move the value to the top
    g_lua.setField(key); // set the field
    g_lua.pop(); // pop the fields table
}

void LuaObject::luaGetField(const std::string_view key) const
{
    if (m_fieldsTableRef != -1) {
        g_lua.getRef(m_fieldsTableRef); // push the obj's fields table
        g_lua.getField(key); // push the field value
        g_lua.remove(-2); // remove the table
    } else {
        g_lua.pushNil();
    }
}

void LuaObject::luaGetMetatable()
{
    static stdext::map<const std::type_info*, int> metatableMap;
    const auto& tinfo = typeid(*this);
    const auto it = metatableMap.find(&tinfo);

    int metatableRef;
    if (it == metatableMap.end()) {
        g_lua.getGlobal(getClassName() + "_mt");
        metatableRef = g_lua.ref();
        metatableMap[&tinfo] = metatableRef;
    } else
        metatableRef = it->second;

    g_lua.getRef(metatableRef);
}

void LuaObject::luaGetFieldsTable() const
{
    if (m_fieldsTableRef != -1)
        g_lua.getRef(m_fieldsTableRef);
    else
        g_lua.pushNil();
}

std::string LuaObject::getClassName()
{
    // There was a TODO "could be cached" here: demangle + string building on every call.
    // The class name for a given type is immutable, so we compute it once per type. Reads go
    // under a shared lock, exclusivity only on the first hit of a new type.
    static std::shared_mutex cacheMutex;
    static std::unordered_map<std::type_index, std::string> cache;

    const std::type_index key(typeid(*this));

    {
        std::shared_lock<std::shared_mutex> lock(cacheMutex);
        const auto it = cache.find(key);
        if (it != cache.end())
            return it->second;
    }

#ifdef _MSC_VER
    std::string name = stdext::demangle_name(typeid(*this).name()) + 6;
#else
    std::string name = stdext::demangle_name(typeid(*this).name());
#endif

    std::unique_lock<std::shared_mutex> lock(cacheMutex);
    return cache.emplace(key, std::move(name)).first->second;
}

int LuaObject::getUseCount()
{
    try {
        const auto self = shared_from_this();
        return static_cast<int>(self.use_count()) - 1;
    } catch (...) {
        return 0;
    }
}
