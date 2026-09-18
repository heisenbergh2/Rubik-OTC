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

#include "soundsource.h"

#include "soundbuffer.h"
#include "soundeffect.h"

SoundSource::SoundSource()
{
    alGenSources(1, &m_sourceId);
    const ALenum err = alGetError();
    if (err != AL_NO_ERROR) {
        g_logger.error("Failed to create OpenAL source: {}", alGetString(err));
        m_sourceId = 0;
        return;
    }
    SoundSource::setReferenceDistance(128);
}

SoundSource::~SoundSource()
{
    if (m_effectId != 0) {
        removeEffect();
    }
    if (m_sourceId != 0) {
        stop();
        alDeleteSources(1, &m_sourceId);
        alGetError(); // clear any error
    }
}

void SoundSource::play()
{
    if (m_sourceId == 0) return;
    alSourcePlay(m_sourceId);
    alGetError(); // clear any error
}

void SoundSource::stop()
{
    if (m_sourceId == 0) return;
    alSourceStop(m_sourceId);
    alGetError(); // clear any error
    if (m_buffer) {
        alSourcei(m_sourceId, AL_BUFFER, AL_NONE);
        alGetError(); // clear any error
        m_buffer = nullptr;
    }
}

bool SoundSource::isBuffering()
{
    if (m_sourceId == 0) return false;
    int state = AL_PLAYING;
    alGetSourcei(m_sourceId, AL_SOURCE_STATE, &state);
    return state != AL_STOPPED;
}

void SoundSource::setBuffer(const SoundBufferPtr& buffer)
{
    if (m_sourceId == 0) return;
    alSourcei(m_sourceId, AL_BUFFER, buffer->getBufferId());
    alGetError(); // clear any error
    m_buffer = buffer;
}

void SoundSource::setLooping(const bool looping)
{
    if (m_sourceId == 0) return;
    alSourcei(m_sourceId, AL_LOOPING, looping ? AL_TRUE : AL_FALSE);
}

void SoundSource::setRelative(const bool relative)
{
    if (m_sourceId == 0) return;
    alSourcei(m_sourceId, AL_SOURCE_RELATIVE, relative ? AL_TRUE : AL_FALSE);
}

void SoundSource::setReferenceDistance(const float distance)
{
    if (m_sourceId == 0) return;
    alSourcef(m_sourceId, AL_REFERENCE_DISTANCE, distance);
}

float SoundSource::getReferenceDistance()
{
    if (m_sourceId == 0) return 0.f;
    float distance;
    alGetSourcef(m_sourceId, AL_REFERENCE_DISTANCE, &distance);
    return distance;
}

void SoundSource::setGain(const float gain)
{
    if (m_sourceId == 0) return;
    alSourcef(m_sourceId, AL_GAIN, gain);
    m_gain = gain;
}

void SoundSource::setPitch(const float pitch)
{
    if (m_sourceId == 0) return;
    alSourcef(m_sourceId, AL_PITCH, pitch);
}

void SoundSource::setPosition(const Point& pos)
{
    if (m_sourceId == 0) return;
    alSource3f(m_sourceId, AL_POSITION, pos.x, pos.y, 0);
}

void SoundSource::setRolloff(const float rolloff)
{
    if (m_sourceId == 0) return;
    alSourcef(m_sourceId, AL_ROLLOFF_FACTOR, rolloff);
}

void SoundSource::setVelocity(const Point& velocity)
{
    if (m_sourceId == 0) return;
    alSource3f(m_sourceId, AL_VELOCITY, velocity.x, velocity.y, 0);
}

void SoundSource::setFading(const FadeState state, const float fadeTime)
{
    const float now = stdext::millis() / 1000.0f;
    if (m_fadeState != NoFading) {
        const float elapsed = now - m_fadeStartTime;
        float add;
        if (m_fadeState == FadingOn)
            add = -(1 - (elapsed / m_fadeTime)) * fadeTime;
        else
            add = -(elapsed / m_fadeTime) * fadeTime;
        m_fadeStartTime = now + add;
    } else
        m_fadeStartTime = now;

    m_fadeState = state;
    m_fadeTime = fadeTime;
    m_fadeGain = m_gain;

    if (m_fadeState == FadingOn)
        setGain(0.0);
}

void SoundSource::update()
{
    const float now = stdext::millis() / 1000.0f;
    if (m_fadeState == FadingOn) {
        const float elapsed = now - m_fadeStartTime;
        if (elapsed >= m_fadeTime) {
            m_fadeState = NoFading;
        } else {
            setGain((elapsed / m_fadeTime) * m_fadeGain);
        }
    } else if (m_fadeState == FadingOff) {
        const float elapsed = now - m_fadeStartTime;
        if (elapsed >= m_fadeTime) {
            setGain(m_fadeGain);
            stop();
            m_fadeState = NoFading;
        } else {
            setGain(((m_fadeTime - elapsed) / m_fadeTime) * m_fadeGain);
        }
    }
}

void SoundSource::setEffect(const SoundEffectPtr soundEffect)
{
    if (m_sourceId == 0) return;
    m_effectId = soundEffect->m_effectId;
    alSource3i(m_sourceId, AL_AUXILIARY_SEND_FILTER, static_cast<ALint>(soundEffect->m_effectId), 0, AL_FILTER_NULL);
    const ALenum err = alGetError();
    if (err != AL_NO_ERROR) {
        g_logger.error("Failed to set effect on source: {}", alGetString(err));
    }
}

void SoundSource::removeEffect()
{
    if (m_sourceId == 0 || m_effectId == 0) return;
    m_effectId = 0;
    alSource3i(m_sourceId, AL_AUXILIARY_SEND_FILTER, AL_EFFECTSLOT_NULL, 0, AL_FILTER_NULL);
    const ALenum err = alGetError();
    if (err != AL_NO_ERROR) {
        g_logger.error("Failed to remove effect on source: {}", alGetString(err));
    }
}