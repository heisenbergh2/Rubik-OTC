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

#include <framework/ui/uiwidget.h>

// progress ring/arc (health/mana/harmony circle in the ported client OTC style)
// angles in degrees: 0 = top (north), increasing clockwise
class UIProgressArc final : public UIWidget
{
public:
    void drawSelf(DrawPoolType drawPane) override;

    void setPercent(float percent);
    float getPercent() { return m_percent; }

    void setFillColor(const Color& color) { m_fillColor = color; repaint(); }
    void setTrackColor(const Color& color) { m_trackColor = color; repaint(); }
    void setThickness(int thickness) { m_thickness = std::max<int>(thickness, 1); repaint(); }
    void setRadialInset(int inset) { m_radialInset = std::max<int>(inset, 0); repaint(); }
    void setStartAngle(float deg) { m_startAngle = deg; repaint(); }
    void setFullSpan(float deg) { m_fullSpan = std::clamp<float>(deg, 1.f, 360.f); repaint(); }
    void setFillFromEnd(bool v) { m_fillFromEnd = v; repaint(); }
    void setArcLayoutSide(std::string_view side) { m_layoutSide = side; repaint(); }
    void setArcSlotCount(int count) { m_slotCount = std::max<int>(count, 0); repaint(); }
    void setArcFilledSlots(int filled) { m_filledSlots = std::max<int>(filled, 0); repaint(); }
    void setEmptyTrack(bool v) { m_emptyTrack = v; repaint(); }
    void setArcBorder(bool v) { m_borderEnabled = v; repaint(); }
    void setArcBorderColor(const Color& color) { m_arcBorderColor = color; repaint(); }
    void setArcBorderWidth(int w) { m_arcBorderWidth = std::max<int>(w, 0); repaint(); }

protected:
    void onStyleApply(std::string_view styleName, const OTMLNodePtr& styleNode) override;

private:
    void drawRingSegment(float fromDeg, float toDeg, float rin, float rout, float cx, float cy, const Color& color);

    float m_percent{ 100.f };
    float m_startAngle{ 0.f };
    float m_fullSpan{ 360.f };
    int m_thickness{ 10 };
    int m_radialInset{ 0 };
    int m_slotCount{ 0 };
    int m_filledSlots{ 0 };
    int m_arcBorderWidth{ 1 };
    bool m_fillFromEnd{ false };
    bool m_emptyTrack{ false };
    bool m_borderEnabled{ false };
    Color m_fillColor{ Color::white };
    Color m_trackColor{ Color(0, 0, 0, 60) };
    Color m_arcBorderColor{ Color::black };
    std::string m_layoutSide{ "left" };
};
