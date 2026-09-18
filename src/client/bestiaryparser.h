#pragma once

#include "staticdata.h"
#include <framework/net/inputmessage.h>
#include <framework/stdext/exception.h>
#include <utility>

namespace bestiary {
// 15.25 added a byte before progress and, for revealed entries, one after
// occurrence. Read them even while the UI has no use for their values.
inline BestiaryOverviewMonsters readOverviewEntry(InputMessage& msg, bool animus, bool summer2026)
{
    BestiaryOverviewMonsters entry{};
    entry.id = msg.getU16();
    if (summer2026)
        msg.getU8();
    entry.currentLevel = msg.getU8();
    if (entry.id == 0 || entry.currentLevel > 4)
        throw stdext::exception("invalid bestiary overview entry (id={}, progress={})", entry.id, entry.currentLevel);
    if (entry.currentLevel > 0) {
        entry.occurrence = msg.getU8();
        if (summer2026)
            msg.getU8();
    }
    if (animus)
        entry.creatureAnimusMasteryBonus = msg.getU16();
    return entry;
}

inline std::pair<uint8_t, uint8_t> readLootHeader(InputMessage& msg, uint8_t progress, bool summer2026)
{
    if (summer2026 && progress == 0)
        return {0, 0};
    const auto occurrence = msg.getU8();
    if (summer2026)
        msg.getU8();
    return {occurrence, msg.getU8()};
}
}
