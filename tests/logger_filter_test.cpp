#include <gtest/gtest.h>
#include <framework/core/logger.h>

struct TraceFormatProbe { int* calls; };
template<> struct fmt::formatter<TraceFormatProbe> : fmt::formatter<std::string_view> {
    template<typename Context>
    auto format(const TraceFormatProbe& probe, Context& context) const {
        ++*probe.calls;
        return fmt::formatter<std::string_view>::format("probe", context);
    }
};

TEST(LoggerFilter, DisabledTraceDoesNotFormatOrCaptureStack)
{
    Logger logger;
    logger.setLevel(Fw::LogWarning);
    int calls = 0;
    logger.traceDebug("{}", TraceFormatProbe{ &calls });
    EXPECT_EQ(calls, 0);
    EXPECT_FALSE(logger.isLevelEnabled(Fw::LogInfo));
    EXPECT_TRUE(logger.isLevelEnabled(Fw::LogError));
}

TEST(LoggerFilter, ReleaseDebugTraceIsDisabledEvenAtDebugLevel)
{
    Logger logger;
#ifdef NDEBUG
    EXPECT_FALSE(logger.isLevelEnabled(Fw::LogDebug));
    int calls = 0;
    logger.traceDebug("{}", TraceFormatProbe{ &calls });
    EXPECT_EQ(calls, 0);
#else
    EXPECT_TRUE(logger.isLevelEnabled(Fw::LogDebug));
#endif
}
