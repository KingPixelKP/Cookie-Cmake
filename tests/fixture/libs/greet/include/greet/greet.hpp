#pragma once

#include <string>
#include <string_view>

namespace greet {
auto hello(std::string_view name) -> std::string;
}
