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

#include "resourcemanager.h"

#include <physfs.h>

#include "filestream.h"
#include "graphicalapplication.h"
#include "framework/graphics/drawpoolmanager.h"
#include "framework/net/protocolhttp.h"
#include "framework/platform/platform.h"
#include "framework/util/crypt.h"

#include <openssl/evp.h>
#include <openssl/sha.h>
#include <openssl/rand.h>
#include <openssl/core_names.h>
#include <openssl/params.h>
#include <cstdint>

#if defined(WIN32)
#include <windows.h>
#include <cstdlib>
#include <cstring>
// Resource ID for the embedded assets.pak (kept in sync with resources.rc).
#define IDR_ASSETS_PAK 1
#endif

ResourceManager g_resources;

void ResourceManager::init(const char* argv0)
{
    PHYSFS_init(argv0);
    PHYSFS_permitSymbolicLinks(1);

#if defined(WIN32)
    char fileName[255];
    GetModuleFileNameA(nullptr, fileName, sizeof(fileName));
    m_binaryPath = std::filesystem::absolute(fileName);
#elif defined(ANDROID)
    // nothing
#else
    m_binaryPath = std::filesystem::absolute(argv0);
#endif

    // Mount the embedded assets.pak FIRST. discoverWorkDir / addSearchPath
    // calls that follow only matter for the user write dir and for assets that
    // weren't bundled (assets/things, assets/sounds delivered by the launcher).
    mountEmbeddedPak();
}

bool ResourceManager::mountEmbeddedPak()
{
#if defined(WIN32)
    HMODULE hModule = GetModuleHandleA(nullptr);
    HRSRC hRes = FindResourceA(hModule, MAKEINTRESOURCEA(IDR_ASSETS_PAK), (LPCSTR)RT_RCDATA);
    if (!hRes) {
        // Dev build without embedded pak — caller will fall back to disk dirs.
        return false;
    }

    HGLOBAL hMem = LoadResource(hModule, hRes);
    if (!hMem) return false;

    const DWORD size = SizeofResource(hModule, hRes);
    void* data = LockResource(hMem);
    if (!data || size == 0) return false;

    // The pak built by build_pak.py stores files under their natural prefixes:
    //   modules/<dir>/<dir>.otmod
    //   mods/<name>/<name>.otmod
    //   assets/<subdir>/...
    //
    // We mount the same pak FOUR times under different archive identifiers and
    // use PHYSFS_setRoot to re-root each instance into the right subtree. This
    // is needed because OTC code paths mix literal prefixes with search-path-
    // relative ones:
    //   * HtmlManager::load hardcodes "/modules/<name>/foo.html"
    //   * Module .otmod files use unprefixed paths discovered at root by
    //     ModuleManager::discoverModules
    //   * init.lua may use "/assets/styles/..."
    //   * OTUI image-source attributes use short "/images/...", "/styles/..."
    //
    // PHYSFS_setRoot with a nullptr/empty subdir leaves the pak's prefixes
    // intact; a non-empty subdir trims it so the contents appear at the
    // archive's new root.
    struct MountSpec {
        const char* archive;
        const char* subdir;      // PHYSFS_setRoot target — nullptr leaves prefixes intact
        const char* mountPoint;  // virtual path the (possibly re-rooted) archive content appears under
    };
    static const MountSpec mounts[] = {
        // 1. Full layout: keep "modules/", "mods/", "assets/" prefixes intact at root.
        { "embedded-full.pak",      nullptr,    "/"      },
        // 2. Modules content at root for ModuleManager::discoverModules() and unprefixed lookups.
        { "embedded-modules.pak",   "/modules", "/"      },
        // 3. Mods content at root, same reason.
        { "embedded-mods.pak",      "/mods",    "/"      },
        // 4. Assets contents at root so short "/images/...", "/styles/..." refs resolve.
        { "embedded-assets-root.pak", "/assets", "/"      },
    };

    bool any_ok = false;
    for (const auto& m : mounts) {
        // Each of these four mounts used to make its own copy of the ENTIRE pak on the heap
        // (malloc + memcpy), i.e. with a ~97 MB pak about 390 MB of memory just for duplicates.
        // PHYSFS_mountMemory takes the buffer as `const void*` and with del == nullptr frees
        // and modifies nothing, while RCDATA resource memory is mapped from the exe image and lives
        // for the entire lifetime of the process - so we can pass the same pointer without copying.
        if (!PHYSFS_mountMemory(data, size, nullptr,
                                m.archive, m.mountPoint, 1)) {
            g_logger.error("Failed to mount embedded {} at {}: {}", m.archive, m.mountPoint,
                           PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));
            continue;
        }

        if (m.subdir != nullptr) {
            if (!PHYSFS_setRoot(m.archive, m.subdir)) {
                g_logger.warning("setRoot {} -> {} failed: {}", m.archive, m.subdir,
                                 PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));
            }
        }
        any_ok = true;
    }

    if (any_ok) {
        g_logger.info("Mounted embedded assets.pak ({} MB) as modules/mods/assets views",
                      size / 1024 / 1024);
    }
    return any_ok;
#else
    return false;
#endif
}

void ResourceManager::terminate()
{
    PHYSFS_deinit();
}

bool ResourceManager::discoverWorkDir(const std::string& existentFile)
{
    // search for modules directory
    std::string possiblePaths[] = { g_platform.getCurrentDir(),
                                    g_resources.getBaseDir(),
                                    g_resources.getBaseDir() + "/game_data/",
                                    g_resources.getBaseDir() + "../",
                                    g_resources.getBaseDir() + "../share/" + g_app.getCompactName() + "/" };

    bool found = false;
    for (const auto& dir : possiblePaths) {
        if (!PHYSFS_mount(dir.c_str(), nullptr, 0))
            continue;

        if (PHYSFS_exists(existentFile.c_str())) {
            g_logger.debug("Found work dir at '{}'", dir);
            m_workDir = dir;
            found = true;
            break;
        }
        PHYSFS_unmount(dir.c_str());
    }

    return found;
}

bool ResourceManager::setupUserWriteDir(const std::string& appWriteDirName)
{
    const std::string userDir = getUserDir();
    std::string dirName;
#ifndef WIN32
    dirName = fmt::format(".{}", appWriteDirName);
#else
    dirName = appWriteDirName;
#endif
    const std::string writeDir = userDir + dirName;

    if (!PHYSFS_setWriteDir(writeDir.c_str())) {
        if (!PHYSFS_setWriteDir(userDir.c_str()) || !PHYSFS_mkdir(dirName.c_str())) {
            g_logger.error(
                "Unable to create write directory '{}': {}",
                writeDir,
                PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode())
            );
            return false;
        }
    }
    return setWriteDir(writeDir);
}

bool ResourceManager::setWriteDir(const std::string& writeDir, bool)
{
    if (!PHYSFS_setWriteDir(writeDir.c_str())) {
        g_logger.error(
            "Unable to set write directory '{}': {}",
            writeDir,
            PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode())
        );
        return false;
    }

    if (!m_writeDir.empty())
        removeSearchPath(m_writeDir);

    m_writeDir = writeDir;

    if (!addSearchPath(writeDir))
        g_logger.error("Unable to add write '{}' directory to search path", writeDir);

    return true;
}

bool ResourceManager::addSearchPath(const std::string& path, const bool pushFront)
{
    std::string savePath = path;
    if (!PHYSFS_mount(path.c_str(), nullptr, pushFront ? 0 : 1)) {
        bool found = false;
        for (const auto& searchPath : m_searchPaths) {
            std::string newPath = searchPath + path;
            if (PHYSFS_mount(newPath.c_str(), nullptr, pushFront ? 0 : 1)) {
                savePath = newPath;
                found = true;
                break;
            }
        }

        if (!found) {
            /*g_logger.error(
                "Could not add '{}' to directory search path. Reason {}",
                path,
                PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode())
            );
            */

            return false;
        }
    }
    if (pushFront)
        m_searchPaths.push_front(savePath);
    else
        m_searchPaths.push_back(savePath);
    return true;
}

bool ResourceManager::removeSearchPath(const std::string& path)
{
    if (!PHYSFS_unmount(path.c_str()))
        return false;
    const auto it = std::ranges::find(m_searchPaths, path);
    assert(it != m_searchPaths.end());
    m_searchPaths.erase(it);
    return true;
}

void ResourceManager::searchAndAddPackages(const std::string& packagesDir, const std::string& packageExt)
{
    auto files = listDirectoryFiles(packagesDir);
    for (auto& file : std::ranges::reverse_view(files)) {
        if (!file.ends_with(packageExt))
            continue;
        std::string package = getRealDir(packagesDir) + "/" + file;
        if (!addSearchPath(package, true))
            g_logger.error(
                "Unable to read package '{}': {}",
                package,
                PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode())
            );
    }
}

bool ResourceManager::fileExists(const std::string& fileName)
{
    if (fileName.find("/downloads") != std::string::npos)
        return g_http.getFile(fileName.substr(10)) != nullptr;

    return (PHYSFS_exists(resolvePath(fileName).c_str()) && !directoryExists(fileName));
}

bool ResourceManager::directoryExists(const std::string& directoryName)
{
    if (directoryName == "/downloads")
        return true;

    PHYSFS_Stat stat = {};
    if (!PHYSFS_stat(resolvePath(directoryName).c_str(), &stat)) {
        return false;
    }

    return stat.filetype == PHYSFS_FILETYPE_DIRECTORY;
}

void ResourceManager::readFileStream(const std::string& fileName, std::iostream& out)
{
    const std::string buffer = readFileContents(fileName);
    if (buffer.length() == 0) {
        out.clear(std::ios::eofbit);
        return;
    }
    out.clear(std::ios::goodbit);
    out.write(&buffer[0], buffer.length());
    out.seekg(0, std::ios::beg);
}

std::string ResourceManager::readFileContents(const std::string& fileName)
{
    const std::string fullPath = resolvePath(fileName);

    if (fullPath.find(AY_OBFUSCATE("/downloads")) != std::string::npos) {
        const auto dfile = g_http.getFile(fullPath.substr(10));
        if (dfile)
            return std::string(dfile->response.begin(), dfile->response.end());
    }

    PHYSFS_File* file = PHYSFS_openRead(fullPath.c_str());
    if (!file)
        throw Exception("unable to open file '{}': {}", fullPath, PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));

    const int fileSize = PHYSFS_fileLength(file);
    std::string buffer(fileSize, 0);
    PHYSFS_readBytes(file, &buffer[0], fileSize);
    PHYSFS_close(file);

#if ENABLE_ENCRYPTION == 1
    const std::string encHeader(ENCRYPTION_HEADER);
    if (buffer.size() >= encHeader.size() &&
        buffer.compare(0, encHeader.size(), encHeader) == 0) {
        buffer = buffer.substr(encHeader.size());
        buffer = decrypt(buffer);
    }
#endif

    return buffer;
}

bool ResourceManager::writeFileBuffer(const std::string& fileName, const uint8_t* data, const uint32_t size, const bool createDirectory)
{
    if (createDirectory) {
        const auto& path = std::filesystem::path(fileName);
        const auto& dirPath = path.parent_path().string();

        if (!PHYSFS_isDirectory(dirPath.c_str())) {
            if (!PHYSFS_mkdir(dirPath.c_str())) {
                g_logger.error(
                    "Unable to create write directory '{}': {}",
                    dirPath,
                    PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode())
                );
                return false;
            }
        }
    }

    PHYSFS_file* file = PHYSFS_openWrite(fileName.c_str());
    if (!file) {
        g_logger.error(PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));
        return false;
    }

    PHYSFS_writeBytes(file, data, size);
    PHYSFS_close(file);
    return true;
}

bool ResourceManager::writeFileStream(const std::string& fileName, std::iostream& in)
{
    const std::streampos oldPos = in.tellg();
    in.seekg(0, std::ios::end);
    const std::streampos size = in.tellg();
    in.seekg(0, std::ios::beg);
    std::vector<char> buffer(size);
    in.read(&buffer[0], size);
    const bool ret = writeFileBuffer(fileName, (const uint8_t*)&buffer[0], size);
    in.seekg(oldPos, std::ios::beg);
    return ret;
}

bool ResourceManager::writeFileContents(const std::string& fileName, const std::string& data)
{
    return writeFileBuffer(fileName, (const uint8_t*)data.c_str(), data.size());
}

bool ResourceManager::writeFileContentsToWorkDir(const std::string& fileName, const std::string& data)
{
    // The editor resolves virtual module paths before calling this function.
    // Restore the settings directory after the write, including on exceptions.
    const auto oldWriteDir = getWriteDir();
    if (getWorkDir().empty() || !setWriteDir(getWorkDir()))
        return false;

    bool ok;
    try {
        ok = writeFileBuffer(fileName, reinterpret_cast<const uint8_t*>(data.data()), data.size(), true);
    } catch (...) {
        setWriteDir(oldWriteDir);
        throw;
    }
    setWriteDir(oldWriteDir);
    return ok;
}

FileStreamPtr ResourceManager::openFile(const std::string& fileName)
{
    const std::string fullPath = resolvePath(fileName);

    PHYSFS_File* file = PHYSFS_openRead(fullPath.c_str());
    if (!file)
        throw Exception("unable to open file '{}': {}", fullPath, PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));
    return { std::make_shared<FileStream>(fullPath, file, false) };
}

FileStreamPtr ResourceManager::appendFile(const std::string& fileName) const
{
    PHYSFS_File* file = PHYSFS_openAppend(fileName.c_str());
    if (!file)
        throw Exception("failed to append file '{}': {}", fileName, PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));
    return { std::make_shared<FileStream>(fileName, file, true) };
}

FileStreamPtr ResourceManager::createFile(const std::string& fileName) const
{
    PHYSFS_File* file = PHYSFS_openWrite(fileName.c_str());
    if (!file)
        throw Exception("failed to create file '{}': {}", fileName, PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));
    return { std::make_shared<FileStream>(fileName, file, true) };
}

bool ResourceManager::deleteFile(const std::string& fileName)
{
    return PHYSFS_delete(resolvePath(fileName).c_str()) != 0;
}

bool ResourceManager::makeDir(const std::string& directory)
{
    return PHYSFS_mkdir(directory.c_str());
}

std::list<std::string> ResourceManager::listDirectoryFiles(const std::string& directoryPath, const bool fullPath /* = false */, const bool raw /*= false*/, const bool recursive)
{
    std::list<std::string> files;
    const auto path = raw ? directoryPath : resolvePath(directoryPath);
    const auto rc = PHYSFS_enumerateFiles(path.c_str());

    if (!rc)
        return files;

    for (int i = 0; rc[i] != nullptr; i++) {
        std::string fileOrDir = rc[i];
        if (fullPath) {
            if (path != "/")
                fileOrDir = path + "/" + fileOrDir;
            else
                fileOrDir = path + fileOrDir;
        }

        if (recursive && directoryExists("/" + fileOrDir)) {
            const auto& moreFiles = listDirectoryFiles(fileOrDir, fullPath, raw, recursive);
            files.insert(files.end(), moreFiles.begin(), moreFiles.end());
        } else {
            files.push_back(fileOrDir);
        }
    }

    PHYSFS_freeList(rc);
    files.sort();
    return files;
}

std::vector<std::string> ResourceManager::getDirectoryFiles(const std::string& path, const bool filenameOnly, const bool recursive)
{
    if (!std::filesystem::exists(path))
        return {};

    const std::filesystem::path p(path);
    return discoverPath(p, filenameOnly, recursive);
}

std::vector<std::string> ResourceManager::discoverPath(const std::filesystem::path& path, const bool filenameOnly, const bool recursive)
{
    std::vector<std::string> files;

    /* Before doing anything, we have to add this directory to search path,
     * this is needed so it works correctly when one wants to open a file.  */
    addSearchPath(path.generic_string(), true);
    for (std::filesystem::directory_iterator it(path), end; it != end; ++it) {
        if (std::filesystem::is_directory(it->path().generic_string()) && recursive) {
            std::vector<std::string> subfiles = discoverPath(it->path(), filenameOnly, recursive);
            files.insert(files.end(), subfiles.begin(), subfiles.end());
        } else {
            if (filenameOnly)
                files.push_back(it->path().filename().string());
            else
                files.push_back(it->path().generic_string() + "/" + it->path().filename().string());
        }
    }

    return files;
}

std::string ResourceManager::resolvePath(const std::string& path)
{
    std::string fullPath;
    if (path.starts_with("/"))
        fullPath = path;
    else if (g_drawPool.isPreDrawing())
        fullPath = "/" + path;
    else {
        if (const std::string scriptPath = "/" + g_lua.getCurrentSourcePath(); !scriptPath.empty())
            fullPath += scriptPath + "/";
        fullPath += path;
    }

    if (!(fullPath.starts_with("/")))
        g_logger.traceWarning(fmt::format("the following file path is not fully resolved: {}", path));

    stdext::replace_all(fullPath, "//", "/");
    return fullPath;
}

std::string ResourceManager::getRealDir(const std::string& path)
{
    std::string dir;
    if (const char* cdir = PHYSFS_getRealDir(resolvePath(path).c_str()))
        dir = cdir;
    return dir;
}

std::string ResourceManager::getRealPath(const std::string& path)
{
    return getRealDir(path) + "/" + path;
}

std::string ResourceManager::getBaseDir()
{
#ifdef ANDROID
    return g_androidManager.getAppBaseDir();
#else
    return PHYSFS_getBaseDir();
#endif
}

std::string ResourceManager::getUserDir()
{
#ifdef ANDROID
    return getBaseDir() + "/";
#elif defined(__EMSCRIPTEN__)
    return "/user/";
#else
    static const char* orgName = g_app.getOrganizationName().data();
    static const char* appName = g_app.getCompactName().data();

    return PHYSFS_getPrefDir(orgName, appName);
#endif
}

std::string ResourceManager::guessFilePath(const std::string& filename, const std::string& type)
{
    if (isFileType(filename, type))
        return filename;
    return filename + "." + type;
}

bool ResourceManager::isFileType(const std::string& filename, const std::string& type)
{
    if (filename.ends_with(std::string(".") + type))
        return true;
    return false;
}

std::string ResourceManager::getFileName(const std::string& filePath)
{
    return std::filesystem::path(filePath).filename().string();
}

ticks_t ResourceManager::getFileTime(const std::string& filename)
{
    return g_platform.getFileModificationTime(getRealPath(filename));
}

// XChaCha20-Poly1305 asset cipher (matches build_pak.py). Key = BLAKE2b-256(password).
// Encrypted file layout (the ENCRYPTION_HEADER magic is prepended by the caller/packer):
//   [24-byte nonce][ciphertext][16-byte Poly1305 tag]
// XChaCha20 = HChaCha20(key, nonce[0:16]) -> subkey, then ChaCha20-Poly1305 with
//             a 12-byte nonce = (00 00 00 00 || nonce[16:24]).

// key = BLAKE2b with 32-byte digest, matching Python hashlib.blake2b(digest_size=32).
static void deriveAssetKey(const std::string& password, unsigned char key[32])
{
    EVP_MD* md = EVP_MD_fetch(nullptr, "BLAKE2B-512", nullptr);
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    size_t outlen = 32;
    OSSL_PARAM params[] = {
        OSSL_PARAM_construct_size_t(OSSL_DIGEST_PARAM_SIZE, &outlen),
        OSSL_PARAM_construct_end()
    };
    unsigned char buf[64]; // BLAKE2b-512 max output; guards against the size param being ignored
    unsigned int len = 0;
    const bool ok = md && ctx &&
        EVP_DigestInit_ex2(ctx, md, params) == 1 &&
        EVP_DigestUpdate(ctx, password.data(), password.size()) == 1 &&
        EVP_DigestFinal_ex(ctx, buf, &len) == 1;
    if (ctx) EVP_MD_CTX_free(ctx);
    if (md) EVP_MD_free(md);
    if (!ok || len != 32)
        throw Exception("BLAKE2b-256 key derivation failed (got {} bytes, expected 32)", len);
    std::memcpy(key, buf, 32);
}

static inline uint32_t rotl32(uint32_t v, int n) { return (v << n) | (v >> (32 - n)); }

// HChaCha20: derive a 32-byte subkey from a 32-byte key and 16 nonce bytes (RFC draft xchacha).
static void hchacha20(const unsigned char key[32], const unsigned char in16[16], unsigned char out[32])
{
    uint32_t x[16];
    x[0] = 0x61707865; x[1] = 0x3320646e; x[2] = 0x79622d32; x[3] = 0x6b206574;
    for (int i = 0; i < 8; ++i)
        x[4 + i] = static_cast<uint32_t>(key[4 * i]) | (static_cast<uint32_t>(key[4 * i + 1]) << 8) |
                   (static_cast<uint32_t>(key[4 * i + 2]) << 16) | (static_cast<uint32_t>(key[4 * i + 3]) << 24);
    for (int i = 0; i < 4; ++i)
        x[12 + i] = static_cast<uint32_t>(in16[4 * i]) | (static_cast<uint32_t>(in16[4 * i + 1]) << 8) |
                    (static_cast<uint32_t>(in16[4 * i + 2]) << 16) | (static_cast<uint32_t>(in16[4 * i + 3]) << 24);
    auto QR = [&](int a, int b, int c, int d) {
        x[a] += x[b]; x[d] ^= x[a]; x[d] = rotl32(x[d], 16);
        x[c] += x[d]; x[b] ^= x[c]; x[b] = rotl32(x[b], 12);
        x[a] += x[b]; x[d] ^= x[a]; x[d] = rotl32(x[d], 8);
        x[c] += x[d]; x[b] ^= x[c]; x[b] = rotl32(x[b], 7);
    };
    for (int i = 0; i < 10; ++i) {
        QR(0, 4, 8, 12); QR(1, 5, 9, 13); QR(2, 6, 10, 14); QR(3, 7, 11, 15);
        QR(0, 5, 10, 15); QR(1, 6, 11, 12); QR(2, 7, 8, 13); QR(3, 4, 9, 14);
    }
    const uint32_t o[8] = { x[0], x[1], x[2], x[3], x[12], x[13], x[14], x[15] };
    for (int i = 0; i < 8; ++i) {
        out[4 * i]     = static_cast<unsigned char>(o[i] & 0xff);
        out[4 * i + 1] = static_cast<unsigned char>((o[i] >> 8) & 0xff);
        out[4 * i + 2] = static_cast<unsigned char>((o[i] >> 16) & 0xff);
        out[4 * i + 3] = static_cast<unsigned char>((o[i] >> 24) & 0xff);
    }
}

std::string ResourceManager::encrypt(const std::string& data, const std::string& password)
{
    unsigned char key[32];
    deriveAssetKey(password, key);

    unsigned char xnonce[24];
    RAND_bytes(xnonce, sizeof(xnonce));
    unsigned char subkey[32];
    hchacha20(key, xnonce, subkey);
    unsigned char cnonce[12] = { 0, 0, 0, 0 };
    std::memcpy(cnonce + 4, xnonce + 16, 8);

    std::string out(24 + data.size() + 16, '\0');
    std::memcpy(&out[0], xnonce, 24);

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    int outLen = 0, finLen = 0;
    unsigned char tag[16];
    const bool ok = ctx != nullptr &&
        EVP_EncryptInit_ex(ctx, EVP_chacha20_poly1305(), nullptr, nullptr, nullptr) == 1 &&
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, 12, nullptr) == 1 &&
        EVP_EncryptInit_ex(ctx, nullptr, nullptr, subkey, cnonce) == 1 &&
        EVP_EncryptUpdate(ctx, reinterpret_cast<unsigned char*>(&out[24]), &outLen,
                          reinterpret_cast<const unsigned char*>(data.data()), static_cast<int>(data.size())) == 1 &&
        EVP_EncryptFinal_ex(ctx, reinterpret_cast<unsigned char*>(&out[24]) + outLen, &finLen) == 1 &&
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, tag) == 1;
    if (ctx)
        EVP_CIPHER_CTX_free(ctx);
    if (!ok)
        throw Exception("asset encryption failed");

    std::memcpy(&out[24 + outLen + finLen], tag, 16);
    out.resize(24 + outLen + finLen + 16);
    return out;
}
std::string ResourceManager::decrypt(const std::string& data)
{
    // Input: [24-byte nonce][ciphertext][16-byte tag] (the ENCRYPTION_HEADER magic is
    // already stripped by the caller). XChaCha20-Poly1305. Throws on tag mismatch.
    static const std::string password(ENCRYPTION_PASSWORD);
    if (data.size() < 24 + 16)
        return data;

    unsigned char key[32];
    deriveAssetKey(password, key);

    const auto* xnonce = reinterpret_cast<const unsigned char*>(data.data());
    unsigned char subkey[32];
    hchacha20(key, xnonce, subkey);
    unsigned char cnonce[12] = { 0, 0, 0, 0 };
    std::memcpy(cnonce + 4, xnonce + 16, 8);

    const auto* ct = xnonce + 24;
    const int ctLen = static_cast<int>(data.size()) - 24 - 16;
    auto* tag = reinterpret_cast<unsigned char*>(const_cast<char*>(data.data()) + data.size() - 16);

    std::string out(ctLen, '\0');
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    int outLen = 0, finLen = 0;
    const bool ok = ctx != nullptr &&
        EVP_DecryptInit_ex(ctx, EVP_chacha20_poly1305(), nullptr, nullptr, nullptr) == 1 &&
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, 12, nullptr) == 1 &&
        EVP_DecryptInit_ex(ctx, nullptr, nullptr, subkey, cnonce) == 1 &&
        EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char*>(&out[0]), &outLen, ct, ctLen) == 1 &&
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, 16, tag) == 1 &&
        EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char*>(&out[0]) + outLen, &finLen) == 1;
    if (ctx)
        EVP_CIPHER_CTX_free(ctx);
    if (!ok)
        throw Exception("asset decryption failed: authentication tag mismatch or wrong key");

    out.resize(outLen + finLen);
    return out;
}

void ResourceManager::runEncryption(const std::string& password)
{
    std::vector<std::string> excludedExtensions = { ".rar",".ogg",".xml",".dll",".exe", ".log",".otb" };
    for (const auto& entry : std::filesystem::recursive_directory_iterator("./")) {
        if (std::string ext = entry.path().extension().string();
            std::ranges::find(excludedExtensions, ext) != excludedExtensions.end())
            continue;

        std::ifstream ifs(entry.path().string(), std::ios_base::binary);
        std::string data((std::istreambuf_iterator(ifs)), std::istreambuf_iterator<char>());
        ifs.close();
        data = encrypt(data, password);
        std::string finalData = std::string(ENCRYPTION_HEADER) + data;
        save_string_into_file(finalData, entry.path().string());
    }
}

void ResourceManager::save_string_into_file(const std::string& contents, const std::string& name)
{
    std::ofstream datFile;
    datFile.open(name, std::ofstream::binary | std::ofstream::trunc | std::ofstream::out);
    datFile.write(contents.c_str(), contents.size());
    datFile.close();
}

std::string ResourceManager::fileChecksum(const std::string& path) {
    static stdext::map<std::string, std::string> cache;

    const auto it = cache.find(path);
    if (it != cache.end())
        return it->second;

    PHYSFS_File* file = PHYSFS_openRead(path.c_str());
    if (!file)
        return "";

    const int fileSize = PHYSFS_fileLength(file);
    std::string buffer(fileSize, 0);
    PHYSFS_readBytes(file, &buffer[0], fileSize);
    PHYSFS_close(file);

    auto checksum = g_crypt.crc32(buffer, false);
    cache[path] = checksum;

    return checksum;
}

std::unordered_map<std::string, std::string> ResourceManager::filesChecksums()
{
    return filesChecksumsForPaths({ "/" });
}

std::unordered_map<std::string, std::string> ResourceManager::filesChecksumsForPaths(const std::vector<std::string>& paths)
{
    std::unordered_map<std::string, std::string> ret;
    for (const auto& requestedPath : paths) {
        if (requestedPath.empty())
            continue;

        const std::string root = requestedPath.front() == '/' ? requestedPath : "/" + requestedPath;
        if (!PHYSFS_exists(root.c_str()))
            continue;

        std::list<std::string> files;
        if (directoryExists(root))
            files = listDirectoryFiles(root, true, false, true);
        else
            files.push_back(root);

        for (auto& filePath : std::ranges::reverse_view(files)) {
            if (ret.contains(filePath))
                continue;

            PHYSFS_File* file = PHYSFS_openRead(filePath.c_str());
            if (!file)
                continue;

            const int64_t fileSize = PHYSFS_fileLength(file);
            if (fileSize < 0 || static_cast<uint64_t>(fileSize) > std::string{}.max_size()) {
                PHYSFS_close(file);
                continue;
            }

            std::string buffer(static_cast<size_t>(fileSize), '\0');
            if (fileSize > 0 && PHYSFS_readBytes(file, buffer.data(), fileSize) != fileSize) {
                PHYSFS_close(file);
                continue;
            }
            PHYSFS_close(file);

            ret[filePath] = g_crypt.crc32(buffer, false);
        }
    }

    return ret;
}

std::string ResourceManager::selfChecksum() {
#ifdef ANDROID
    return "";
#else
    static std::string checksum;
    if (!checksum.empty())
        return checksum;

    std::ifstream file(m_binaryPath.string(), std::ios::binary);
    if (!file.is_open())
        return "";

    std::string buffer(std::istreambuf_iterator<char>(file), {});
    file.close();

    checksum = g_crypt.crc32(buffer, false);
    return checksum;
#endif
}

void ResourceManager::updateFiles(const std::set<std::string>& files) {
    g_logger.info("Updating client, {} files", files.size());

    const auto& oldWriteDir = getWriteDir();
    setWriteDir(getWorkDir());
    for (auto fileName : files) {
        if (fileName.empty())
            continue;

        if (fileName.size() > 1 && fileName[0] == '/')
            fileName = fileName.substr(1);

        auto dFile = g_http.getFile(fileName);

        if (dFile) {
            if (!writeFileBuffer(fileName, (const uint8_t*)dFile->response.data(), dFile->response.size(), true)) {
                g_logger.error("Cannot write file: {}", fileName);
            } else {
                //g_logger.info("Updated file: {}", fileName);
            }
        } else {
            g_logger.error("Cannot find file: {} in downloads", fileName);
        }
    }
    setWriteDir(oldWriteDir);
    addSearchPath(getWorkDir(), true);
}

void ResourceManager::updateExecutable(std::string fileName)
{
#if defined(ANDROID) || defined(FREE_VERSION)
    g_logger.fatal("Executable cannot be updated on android or in free version");
#else
    if (fileName.size() <= 2) {
        g_logger.fatal("Invalid executable name");
    }

    if (fileName[0] == '/')
        fileName = fileName.substr(1);

    const auto dFile = g_http.getFile(fileName);
    if (!dFile)
        g_logger.fatal("Cannot find executable: {} in downloads", fileName);

    const auto& oldWriteDir = getWriteDir();
    setWriteDir(getWorkDir());
    const std::filesystem::path path(m_binaryPath);
    const auto newBinary = path.stem().string() + "-" + std::to_string(time(nullptr)) + path.extension().string();
    g_logger.info("Updating binary file: {}", newBinary);
    PHYSFS_file* file = PHYSFS_openWrite(newBinary.c_str());
    if (!file) {
        return g_logger.fatal(
            "can't open {} for writing: {}",
            newBinary,
            PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode())
        );
    }

    PHYSFS_writeBytes(file, dFile->response.data(), dFile->response.size());
    PHYSFS_close(file);
    setWriteDir(oldWriteDir);

    std::filesystem::path newBinaryPath(std::filesystem::u8path(PHYSFS_getWriteDir()));
#endif
}

bool ResourceManager::launchCorrect(const std::vector<std::string>& args) { // curently works only on windows
#if (defined(ANDROID) || defined(FREE_VERSION))
    return false;
#else
    auto fileName2 = m_binaryPath.stem().string();
    fileName2 = stdext::split(fileName2, "-")[0];
    stdext::tolower(fileName2);

    const std::filesystem::path path(m_binaryPath.parent_path());
    std::error_code ec;
    auto lastWrite = last_write_time(m_binaryPath, ec);
    std::filesystem::path binary = m_binaryPath;
    for (auto& entry : std::filesystem::directory_iterator(path)) {
        if (is_directory(entry.path()))
            continue;

        auto fileName1 = entry.path().stem().string();
        fileName1 = stdext::split(fileName1, "-")[0];
        stdext::tolower(fileName1);
        if (fileName1 != fileName2)
            continue;

        if (entry.path().extension() == m_binaryPath.extension()) {
            std::error_code _ec;
            auto writeTime = last_write_time(entry.path(), _ec);
            if (!_ec && writeTime > lastWrite) {
                lastWrite = writeTime;
                binary = entry.path();
            }
        }
    }

    for (auto& entry : std::filesystem::directory_iterator(path)) { // remove old
        if (is_directory(entry.path()))
            continue;

        auto fileName1 = entry.path().stem().string();
        fileName1 = stdext::split(fileName1, "-")[0];
        stdext::tolower(fileName1);
        if (fileName1 != fileName2)
            continue;

        if (entry.path().extension() == m_binaryPath.extension()) {
            if (binary == entry.path())
                continue;
            std::error_code _ec;
            std::filesystem::remove(entry.path(), _ec);
        }
    }

    if (binary == m_binaryPath)
        return false;

    g_platform.spawnProcess(binary.string(), args);
    return true;
#endif
}

std::string ResourceManager::createArchive(const std::unordered_map<std::string, std::string>& /*files*/) { return ""; }

std::unordered_map<std::string, std::string> ResourceManager::decompressArchive(std::string /*dataOrPath*/)
{
    std::unordered_map<std::string, std::string> ret;
    return ret;
}
