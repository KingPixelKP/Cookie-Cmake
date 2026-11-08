#include "greet/greet.hpp"

namespace greet {
auto hello(std::string_view name) -> std::string {
  return "hello, " + std::string(name);
}
}  // namespace greet
