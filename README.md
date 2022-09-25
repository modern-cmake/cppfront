# cppfront cmake wrapper

This is a wrapper around Herb Sutter's [cppfront](https://github.com/hsutter/cppfront)
compiler. Go there to learn more about that project.

This repository is a wrapper around that one, offering a CMake build with some
"magic" helpers to make it easier to use cpp2.

Requires CMake 3.23+.

## Getting started

See the [example](/example) for a full example project.

### Find package

This is the workflow I will personally support.

Build this repository:

```
$ git clone --recursive https://github.com/modern-cmake/cppfront
$ cmake -S cppfront -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/wherever
$ cmake --build build --target install
```

Now just write your project like normal:

```cmake
cmake_minimum_required(VERSION 3.23)
project(example)

find_package(cppfront REQUIRED)

add_executable(main main.cpp2)
```

And that's literally it. Any targets with a `.cpp2` source will automatically
get custom commands added to them.

### FetchContent

FetchContent is also supported, though as always with FetchContent, there's a
chance it will be wonky.

Here's the code.

```cmake
cmake_minimum_required(VERSION 3.23)
project(example)

FetchContent_Declare(
  cppfront
  GIT_REPOSITORY https://github.com/modern-cmake/cppfront.git
  GIT_TAG        main  # or an actual git SHA if you don't like to live dangerously
)

FetchContent_MakeAvailable(cppfront)

add_executable(main main.cpp2)
```

The same automatic configuration will happen here, too. Though since
`FetchContent_MakeAvailable` will only run our `CMakeLists.txt` once, the magic
can only happen in the first directory to include it. Thus, you should probably
explicitly run `cppfront_enable(TARGETS main)` and add `set(CPPFRONT_NO_MAGIC 1)`
if you want your project to be consumable via FetchContent. Blech.

You can, of course, use this repo as a submodule and call `add_subdirectory`
rather than using `FetchContent`. It's basically the same except FC has some
overriding mechanism now, as of 3.24.

I won't personally address issues for FetchContent users. PRs are welcome, but
please know CMake well.

## Known issues

At the moment, cppfront's header is broken and needs to be patched. Here's the
patch if you're motivated:

```patch
diff --git a/include/cpp2util.h b/include/cpp2util.h
index e90c55f..b648dc2 100644
--- a/include/cpp2util.h
+++ b/include/cpp2util.h
@@ -192,6 +192,13 @@
     #include <cstddef>
     #include <utility>
 
+    // PATCH: missing headers
+    #include <algorithm>
+    #include <iomanip>
+    #include <span>
+    #include <vector>
+    #include <ranges>
+
     #if defined(CPP2_USE_SOURCE_LOCATION)
         #include <source_location>
     #endif
@@ -593,7 +600,7 @@ constexpr auto operator_as( std::variant<Ts...> const& x ) -> auto&& {
 
 //  A helper for is...
 template <class T, class... Ts>
-inline constexpr auto is_any = std::disjunction_v<std::is_same<T, Ts>...> {};
+inline constexpr auto is_any = std::disjunction_v<std::is_same<T, Ts>...>;
 
 template<typename T, typename... Ts>
 auto is( std::variant<Ts...> const& x ) {
```
