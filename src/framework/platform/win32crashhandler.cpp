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

#include "framework/core/application.h"
#if defined(WIN32) && defined(CRASH_HANDLER)

#include <windows.h>

#ifdef _MSC_VER

#pragma warning (push)
#pragma warning (disable:4091) // warning C4091: 'typedef ': ignored on left of '' when no variable is declared
#include <imagehlp.h>
#pragma warning (pop)

#else

#include <imagehlp.h>

#endif

#include <framework/core/graphicalapplication.h>

const char* getExceptionName(const DWORD exceptionCode)
{
    switch (exceptionCode) {
        case EXCEPTION_ACCESS_VIOLATION:         return "Access violation";
        case EXCEPTION_DATATYPE_MISALIGNMENT:    return "Datatype misalignment";
        case EXCEPTION_BREAKPOINT:               return "Breakpoint";
        case EXCEPTION_SINGLE_STEP:              return "Single step";
        case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:    return "Array bounds exceeded";
        case EXCEPTION_FLT_DENORMAL_OPERAND:     return "Float denormal operand";
        case EXCEPTION_FLT_DIVIDE_BY_ZERO:       return "Float divide by zero";
        case EXCEPTION_FLT_INEXACT_RESULT:       return "Float inexact result";
        case EXCEPTION_FLT_INVALID_OPERATION:    return "Float invalid operation";
        case EXCEPTION_FLT_OVERFLOW:             return "Float overflow";
        case EXCEPTION_FLT_STACK_CHECK:          return "Float stack check";
        case EXCEPTION_FLT_UNDERFLOW:            return "Float underflow";
        case EXCEPTION_INT_DIVIDE_BY_ZERO:       return "Integer divide by zero";
        case EXCEPTION_INT_OVERFLOW:             return "Integer overflow";
        case EXCEPTION_PRIV_INSTRUCTION:         return "Privileged instruction";
        case EXCEPTION_IN_PAGE_ERROR:            return "In page error";
        case EXCEPTION_ILLEGAL_INSTRUCTION:      return "Illegal instruction";
        case EXCEPTION_NONCONTINUABLE_EXCEPTION: return "Noncontinuable exception";
        case EXCEPTION_STACK_OVERFLOW:           return "Stack overflow";
        case EXCEPTION_INVALID_DISPOSITION:      return "Invalid disposition";
        case EXCEPTION_GUARD_PAGE:               return "Guard page";
        case EXCEPTION_INVALID_HANDLE:           return "Invalid handle";
    }
    return "Unknown exception";
}

void Stacktrace(LPEXCEPTION_POINTERS e, std::stringstream& ss)
{
    STACKFRAME64 sf;
    HANDLE process, thread;
    DWORD machineType;
    char modname[MAX_PATH];
    char symBuffer[sizeof(IMAGEHLP_SYMBOL64) + 255];
    auto* pSym = reinterpret_cast<PIMAGEHLP_SYMBOL64>(symBuffer);
    CONTEXT context = *e->ContextRecord;

    ZeroMemory(&sf, sizeof(sf));
#ifdef _WIN64
    sf.AddrPC.Offset = context.Rip;
    sf.AddrStack.Offset = context.Rsp;
    sf.AddrFrame.Offset = context.Rbp;
    machineType = IMAGE_FILE_MACHINE_AMD64;
#else
    sf.AddrPC.Offset = context.Eip;
    sf.AddrStack.Offset = context.Esp;
    sf.AddrFrame.Offset = context.Ebp;
    machineType = IMAGE_FILE_MACHINE_I386;
#endif

    sf.AddrPC.Mode = AddrModeFlat;
    sf.AddrStack.Mode = AddrModeFlat;
    sf.AddrFrame.Mode = AddrModeFlat;

    process = GetCurrentProcess();
    thread = GetCurrentThread();

    for (int count = 0; count < 64; ++count) {
        if (!StackWalk64(machineType, process, thread, &sf, &context, nullptr,
                         SymFunctionTableAccess64, SymGetModuleBase64, nullptr)
            || sf.AddrPC.Offset == 0)
            break;

        const DWORD64 moduleBase = SymGetModuleBase64(process, sf.AddrPC.Offset);
        if (moduleBase)
            GetModuleFileNameA(reinterpret_cast<HINSTANCE>(moduleBase), modname, MAX_PATH);
        else {
#ifdef _MSC_VER
            strcpy_s(modname, sizeof(modname), "Unknown");
#else
            strncpy(modname, "Unknown", sizeof(modname));
            modname[sizeof(modname) - 1] = '\0';
#endif
        }

        ZeroMemory(pSym, sizeof(symBuffer));
        pSym->SizeOfStruct = sizeof(IMAGEHLP_SYMBOL64);
        pSym->MaxNameLength = 254;

        DWORD64 displacement = 0;
        if (SymGetSymFromAddr64(process, sf.AddrPC.Offset, &displacement, pSym))
            ss << fmt::format("    {}: {}({}+0x{:X}) [0x{:016X}]\n",
                              count, modname, pSym->Name, displacement, sf.AddrPC.Offset);
        else
            ss << fmt::format("    {}: {}+0x{:X} [0x{:016X}]\n",
                              count, modname,
                              moduleBase ? sf.AddrPC.Offset - moduleBase : sf.AddrPC.Offset,
                              sf.AddrPC.Offset);

        IMAGEHLP_LINE64 line{};
        line.SizeOfStruct = sizeof(line);
        DWORD lineDisplacement = 0;
        if (SymGetLineFromAddr64(process, sf.AddrPC.Offset, &lineDisplacement, &line))
            ss << fmt::format("       at {}:{} (+0x{:X})\n",
                              line.FileName, line.LineNumber, lineDisplacement);
    }
    // pSym points to symBuffer, which is stack storage owned by this function.
    // It must not be passed to GlobalFree; doing so corrupts the process heap
    // while handling another exception and masks the original crash as
    // STATUS_HEAP_CORRUPTION (0xC0000374).
}

LONG CALLBACK ExceptionHandler(const LPEXCEPTION_POINTERS e)
{
    const HANDLE process = GetCurrentProcess();
    SymSetOptions(SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES | SYMOPT_UNDNAME);
    SymInitialize(process, nullptr, TRUE);

    const auto exceptionAddress = reinterpret_cast<std::uintptr_t>(e->ExceptionRecord->ExceptionAddress);
    const DWORD64 moduleBase = SymGetModuleBase64(process, exceptionAddress);
    char moduleName[MAX_PATH] = "Unknown";
    if (moduleBase)
        GetModuleFileNameA(reinterpret_cast<HINSTANCE>(moduleBase), moduleName, MAX_PATH);

    std::string crashReport = fmt::format(
        "== application crashed\n"
        "app name: {}\n"
        "app version: {}\n"
        "build compiler: {} - {}\n"
        "build date: {}\n"
        "build type: {}\n"
        "build revision: {} ({})\n"
        "crash date: {}\n"
        "exception: {} (0x{:08X})\n"
        "exception address: 0x{:016X}\n"
        "fault module: {}\n"
        "fault module base: 0x{:016X}\n"
        "fault rva: 0x{:X}\n",
        g_app.getName(),
        g_app.getVersion(),
        g_app.getBuildCompiler(), g_app.getBuildArch(),
        g_app.getBuildDate(),
        g_app.getBuildType(),
        g_app.getBuildRevision(), g_app.getBuildCommit(),
        stdext::date_time_string(),
        getExceptionName(e->ExceptionRecord->ExceptionCode), e->ExceptionRecord->ExceptionCode,
        exceptionAddress,
        moduleName,
        moduleBase,
        moduleBase ? exceptionAddress - moduleBase : exceptionAddress
    );

    if (e->ExceptionRecord->ExceptionCode == EXCEPTION_ACCESS_VIOLATION
        && e->ExceptionRecord->NumberParameters >= 2) {
        const ULONG_PTR operation = e->ExceptionRecord->ExceptionInformation[0];
        const char* operationName = operation == 0 ? "read"
                                  : operation == 1 ? "write"
                                  : operation == 8 ? "execute"
                                                   : "access";
        crashReport += fmt::format("access violation: {} at 0x{:016X}\n",
                                   operationName,
                                   e->ExceptionRecord->ExceptionInformation[1]);
    }
    crashReport += "  backtrace:\n";

    std::stringstream oss;
    oss << crashReport;
    Stacktrace(e, oss);
    oss << "\n";

    SymCleanup(process);

    g_logger.info(oss.str());

    char dir[MAX_PATH];
    DWORD len = GetCurrentDirectory(sizeof(dir), dir);
    if (len == 0 || len >= sizeof(dir)) {
        g_logger.error("Failed to get current directory for crash report");
        return EXCEPTION_CONTINUE_SEARCH;
    }

    std::string fileName = fmt::format("{}\\crashreport.log", dir);

    std::ofstream fout(fileName, std::ios::out | std::ios::app);
    if (fout.is_open()) {
        fout << oss.str();
        fout.close();
        g_logger.info("Crash report saved to file {}", fileName);
    } else {
        g_logger.error("Failed to save crash report to {}", fileName);
    }

    std::string msg = fmt::format(
        "The application has crashed.\n\n"
        "A crash report has been written to:\n{}",
        fileName
    );
    MessageBoxA(nullptr, msg.c_str(), "Application crashed", MB_OK | MB_ICONERROR);

    return EXCEPTION_CONTINUE_SEARCH;
}

void installCrashHandler()
{
    SetUnhandledExceptionFilter(ExceptionHandler);
}

#endif
