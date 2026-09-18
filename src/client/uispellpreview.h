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

#pragma once

#include "declarations.h"
#include "outfit.h"
#include <framework/core/timer.h>
#include <framework/ui/uiwidget.h>
#include <vector>

// Cyclopedia Magical Archive spell preview: a small self-contained scene (tile grid + caster
// creature + looping magic effects + flying missiles + field objects), animated continuously.
// Mirrors RubinOT's UISpellPreview interface so the Lua side drives it the same way.
class UISpellPreview final : public UIWidget
{
public:
    void drawSelf(DrawPoolType drawPane) override;

    void clearAll();
    void setGridBounds(int minX, int minY, int maxX, int maxY);
    void setPlayerOutfit(const Outfit& outfit);
    void setPlayerDirection(int dir);
    void setTargetPosition(int x, int y);
    void addEffect(int x, int y, int effectId);
    void addMissile(int missileId, int fromX, int fromY, int toX, int toY);
    void addObject(int x, int y, int objectId);
    void removeObject(int x, int y, int objectId);

private:
    struct GridEffect { int x, y, id; EffectPtr effect; Timer timer; int duration; };
    struct GridMissile { int fromX, fromY, toX, toY, id; MissilePtr missile; Timer timer; int duration; };
    struct GridObject { int x, y, id; ItemPtr item; };

    int m_minX{ 0 }, m_minY{ 0 }, m_maxX{ 0 }, m_maxY{ 0 };
    int m_dir{ 1 };
    bool m_hasTarget{ false };
    int m_targetX{ 0 }, m_targetY{ 0 };
    CreaturePtr m_player;
    ItemPtr m_dummy;
    std::vector<GridEffect> m_effects;
    std::vector<GridMissile> m_missiles;
    std::vector<GridObject> m_objects;
};
