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

#include "uispellpreview.h"

#include "creature.h"
#include "effect.h"
#include "gameconfig.h"
#include "item.h"
#include "missile.h"
#include <framework/const.h>
#include <framework/graphics/drawpoolmanager.h>
#include <algorithm>
#include <cmath>

void UISpellPreview::clearAll()
{
    m_effects.clear();
    m_missiles.clear();
    m_objects.clear();
    m_dummy = nullptr;
    m_hasTarget = false;
}

void UISpellPreview::setGridBounds(const int minX, const int minY, const int maxX, const int maxY)
{
    m_minX = minX;
    m_minY = minY;
    m_maxX = maxX;
    m_maxY = maxY;
}

void UISpellPreview::setPlayerOutfit(const Outfit& outfit)
{
    if (!m_player)
        m_player = std::make_shared<Creature>();
    m_player->setDirection(static_cast<Otc::Direction>(m_dir));
    m_player->setOutfit(outfit);
}

void UISpellPreview::setPlayerDirection(const int dir)
{
    m_dir = dir;
    if (m_player)
        m_player->setDirection(static_cast<Otc::Direction>(dir));
}

void UISpellPreview::setTargetPosition(const int x, const int y)
{
    m_targetX = x;
    m_targetY = y;
    m_hasTarget = (x != 0 || y != 0);
    if (m_hasTarget && !m_dummy)
        m_dummy = Item::create(5787); // training-dummy sprite, marks the target tile
}

void UISpellPreview::addEffect(const int x, const int y, const int effectId)
{
    if (effectId <= 0)
        return;
    m_effects.push_back({ x, y, effectId, nullptr, {}, 0 });
}

void UISpellPreview::addMissile(const int missileId, const int fromX, const int fromY, const int toX, const int toY)
{
    if (missileId <= 0)
        return;
    m_missiles.push_back({ fromX, fromY, toX, toY, missileId, nullptr, {}, 0 });
}

void UISpellPreview::addObject(const int x, const int y, const int objectId)
{
    if (objectId <= 0)
        return;
    m_objects.push_back({ x, y, objectId, Item::create(objectId) });
}

void UISpellPreview::removeObject(const int x, const int y, const int objectId)
{
    m_objects.erase(std::remove_if(m_objects.begin(), m_objects.end(),
        [&](const GridObject& o) { return o.x == x && o.y == y && (objectId <= 0 || o.id == objectId); }), m_objects.end());
}

void UISpellPreview::drawSelf(const DrawPoolType drawPane)
{
    if (drawPane != DrawPoolType::FOREGROUND)
        return;

    UIWidget::drawSelf(drawPane); // background / border / image

    const int cols = m_maxX - m_minX + 1;
    const int rows = m_maxY - m_minY + 1;
    if (cols <= 0 || rows <= 0)
        return;

    const Rect pr = getPaddingRect();
    int cell = std::min(pr.width() / cols, pr.height() / rows);
    cell = std::max(cell, 12);
    const int gw = cell * cols, gh = cell * rows;
    const int ox = pr.left() + (pr.width() - gw) / 2;
    const int oy = pr.top() + (pr.height() - gh) / 2;

    const auto cellRect = [&](const float tx, const float ty) {
        return Rect(ox + static_cast<int>((tx - m_minX) * cell), oy + static_cast<int>((ty - m_minY) * cell), cell, cell);
    };

    // stone floor
    for (int gy = 0; gy < rows; ++gy)
        for (int gx = 0; gx < cols; ++gx)
            g_drawPool.addFilledRect(Rect(ox + gx * cell + 1, oy + gy * cell + 1, cell - 2, cell - 2), Color(134, 139, 143));

    const int sprite = g_gameConfig.getSpriteSize();
    const auto drawThingScaled = [&](const ThingPtr& thing, const Rect& dest) {
        if (!thing)
            return;
        const int es = std::max<int>(sprite, thing->getExactSize());
        g_drawPool.bindFrameBuffer(es);
        thing->draw(Point(es - sprite) + thing->getDisplacement());
        g_drawPool.releaseFrameBuffer(dest);
    };

    // field objects (fire/energy field items etc.)
    for (auto& o : m_objects)
        drawThingScaled(o.item, cellRect(o.x, o.y));

    // target dummy
    if (m_hasTarget && m_dummy)
        drawThingScaled(m_dummy, cellRect(m_targetX, m_targetY));

    // caster (bottom-anchored in its tile, ~one tile tall)
    if (m_player) {
        const Rect r = cellRect(0, 0);
        m_player->draw(Rect(r.x() - cell / 2, r.y() - cell, cell * 2, cell * 2), static_cast<uint8_t>(std::min(255, cell * 2)), true);
    }

    // magic effects: recreate the moment their animation finishes -> continuous loop
    const int effTicks = std::max<int>(1, g_gameConfig.getEffectTicksPerFrame());
    for (auto& e : m_effects) {
        if (!e.effect || e.timer.ticksElapsed() >= e.duration) {
            e.effect = std::make_shared<Effect>();
            e.effect->setId(e.id);
            e.duration = std::max(300, e.effect->getAnimationPhases() * effTicks);
            e.timer.restart();
        }
        drawThingScaled(e.effect, cellRect(e.x, e.y));
    }

    // missiles: fly from source to target across the grid, then loop
    for (auto& m : m_missiles) {
        const int dist = std::max(1, std::abs(m.toX - m.fromX) + std::abs(m.toY - m.fromY));
        if (!m.missile || m.timer.ticksElapsed() >= m.duration) {
            m.missile = std::make_shared<Missile>();
            m.missile->setId(m.id);
            const int dx = m.toX - m.fromX, dy = m.toY - m.fromY;
            Otc::Direction dir;
            if (std::abs(dx) >= std::abs(dy))
                dir = dx >= 0 ? Otc::East : Otc::West;
            else
                dir = dy >= 0 ? Otc::South : Otc::North;
            m.missile->setDirection(dir);
            m.duration = dist * 220 + 400; // flight + short pause before looping
            m.timer.restart();
        }
        const float flight = static_cast<float>(dist * 220);
        float frac = flight > 0 ? m.timer.ticksElapsed() / flight : 1.f;
        if (frac > 1.f)
            frac = 1.f;
        const float tx = m.fromX + (m.toX - m.fromX) * frac;
        const float ty = m.fromY + (m.toY - m.fromY) * frac;
        drawThingScaled(m.missile, cellRect(tx, ty));
    }
}
