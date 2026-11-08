#include <gtest/gtest.h>

#include "greet/greet.hpp"

TEST(Greet, Hello) { EXPECT_EQ(greet::hello("x"), "hello, x"); }
