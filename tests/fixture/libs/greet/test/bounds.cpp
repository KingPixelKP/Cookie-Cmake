#include <gtest/gtest.h>

#include <vector>

// configure_target() defines _GLIBCXX_ASSERTIONS in Debug builds, so an
// out-of-bounds operator[] must abort instead of reading past the end.
TEST(Hardening, OutOfBoundsAbortsInDebug) {
#ifdef NDEBUG
  GTEST_SKIP() << "bounds checks are only enabled in Debug builds";
#else
  std::vector<int> values{1};
  EXPECT_DEATH(static_cast<void>(values[3]), "");
#endif
}
