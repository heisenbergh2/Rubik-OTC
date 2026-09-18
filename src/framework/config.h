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
#include <obfuscate.h>

static constexpr float DEFAULT_DISPLAY_DENSITY = 1.f;

// APPEARANCES
#define BYTES_IN_SPRITE_SHEET 384 * 384 * 4
#define LZMA_UNCOMPRESSED_SIZE BYTES_IN_SPRITE_SHEET + 122
#define LZMA_HEADER_SIZE LZMA_PROPS_SIZE + 8
#define SPRITE_SHEET_WIDTH_BYTES 384 * 4

// ENCRYPTION SYSTEM
// Enable client encryption
// DISABLED: the repository will be public, so asset encryption makes no sense
// (the password would have to live in the code anyway). Assets sit loose on disk, unencrypted.
#define ENABLE_ENCRYPTION 0
// Enable client encryption maker/builder.
// You can compile it once and use this executable to only encrypt client files once with command --encrypt which will be using password below.
#define ENABLE_ENCRYPTION_BUILDER 0
// Passphrase for the ChaCha20-Poly1305 asset cipher. Key = SHA-256(this). 100+ chars.
// MUST match PASSPHRASE in assets_crypto.py / build_pak.py.
#define ENCRYPTION_PASSWORD AY_OBFUSCATE("BERDBDnkK7nefAPbQjZk8yI1ehCxS6TSVpeK9gsn93y19mYVgfn3TTo06D0pGf3kgjZ45vMy3oB4Fry0iWutdGc2BXbxe36O3w4Q")
// Plaintext magic prepended to every encrypted file (ONLY letters + digits). MUST match the packer.
#define ENCRYPTION_HEADER AY_OBFUSCATE("3tRe5ZMfXeIIW7G8Yr2D8QkG")

// DISCORD RPC (https://discord.com/developers/applications)
// Enable Discord Rich Presence
#ifndef ENABLE_DISCORD_RPC
#define ENABLE_DISCORD_RPC 0 // 1 to enable | 0 to disable
#endif
#define RPC_API_KEY "1060650448522051664" // Your API Key
// RPC Configs (https://youtu.be/zCHYtRlD58g) step by step to config your rich presence
#define SHOW_CHARACTER_NAME_RPC 1 // 1 to enable | 0 to disable
#define SHOW_CHARACTER_LEVEL_RPC 1 // 1 to enable | 0 to disable
#define SHOW_CHARACTER_WORLD_RPC 1 // 1 to enable | 0 to disable
#define OFFLINE_RPC_TEXT "Selecting Character..." // Message at client startup | offline character
#define STATE_RPC_TEXT "github.com/mehah/otclient" // State Text
#define RPC_LARGE_IMAGE "rpc-logo" // Large Image Name (Imported to API)
#define RPC_LARGE_TEXT "OTClient - Redemption" // Large Text (Text showed at tooltip large image)
