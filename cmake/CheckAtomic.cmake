# atomic builtins are required for threading support.

INCLUDE(CheckCXXSourceCompiles)
INCLUDE(CheckLibraryExists)

# Sometimes linking against libatomic is required for atomic ops, if
# the platform doesn't support lock-free atomics.

function(check_working_cxx_atomics varname)
  set(OLD_CMAKE_REQUIRED_FLAGS ${CMAKE_REQUIRED_FLAGS})
  set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -std=c++11")
  CHECK_CXX_SOURCE_COMPILES("
#include <atomic>
std::atomic<int> x;
std::atomic<short> y;
std::atomic<char> z;
int main() {
  ++z;
  ++y;
  return ++x;
}
" ${varname})
  set(CMAKE_REQUIRED_FLAGS ${OLD_CMAKE_REQUIRED_FLAGS})
endfunction(check_working_cxx_atomics)

function(check_working_cxx_atomics64 varname)
  set(OLD_CMAKE_REQUIRED_FLAGS ${CMAKE_REQUIRED_FLAGS})
  set(CMAKE_REQUIRED_FLAGS "-std=c++11 ${CMAKE_REQUIRED_FLAGS}")
  CHECK_CXX_SOURCE_COMPILES("
#include <atomic>
#include <cstdint>
std::atomic<uint64_t> x (0);
int main() {
  uint64_t i = x.load(std::memory_order_relaxed);
  return 0;
}
" ${varname})
  set(CMAKE_REQUIRED_FLAGS ${OLD_CMAKE_REQUIRED_FLAGS})
endfunction(check_working_cxx_atomics64)


# This isn't necessary on MSVC, so avoid command-line switch annoyance
# by only running on GCC-like hosts.
if (LLVM_COMPILER_IS_GCC_COMPATIBLE)
  # First check if atomics work without the library.
  check_working_cxx_atomics(HAVE_CXX_ATOMICS_WITHOUT_LIB)
  # If not, check if the library exists, and atomics work with it.
  if(NOT HAVE_CXX_ATOMICS_WITHOUT_LIB)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "atomic")
    check_working_cxx_atomics(HAVE_CXX_ATOMICS_WITH_LIB)
    if (NOT HAVE_CXX_ATOMICS_WITH_LIB)
      message(FATAL_ERROR "Host compiler must support std::atomic!")
    endif()
  endif()
endif()

# Check for 64 bit atomic operations.
if(MSVC)
  set(HAVE_CXX_ATOMICS64_WITHOUT_LIB True)
else()
  check_working_cxx_atomics64(HAVE_CXX_ATOMICS64_WITHOUT_LIB)
endif()

# If not, check if the library exists, and atomics work with it.
if(NOT HAVE_CXX_ATOMICS64_WITHOUT_LIB)
  list(APPEND CMAKE_REQUIRED_LIBRARIES "atomic")
  check_working_cxx_atomics64(HAVE_CXX_ATOMICS64_WITH_LIB)
  if (NOT HAVE_CXX_ATOMICS64_WITH_LIB)
    message(FATAL_ERROR "Host compiler must support 64-bit std::atomic!")
  endif()
endif()

## TODO: This define is only used for the legacy atomic operations in
## llvm's Atomic.h, which should be replaced.  Other code simply
## assumes C++11 <atomic> works.
CHECK_CXX_SOURCE_COMPILES("
#ifdef _MSC_VER
#include <windows.h>
#endif
int main() {
#ifdef _MSC_VER
        volatile LONG val = 1;
        MemoryBarrier();
        InterlockedCompareExchange(&val, 0, 1);
        InterlockedIncrement(&val);
        InterlockedDecrement(&val);
#else
        volatile unsigned long val = 1;
        __sync_synchronize();
        __sync_val_compare_and_swap(&val, 1, 0);
        __sync_add_and_fetch(&val, 1);
        __sync_sub_and_fetch(&val, 1);
#endif
        return 0;
      }
" LLVM_HAS_ATOMICS)

if( NOT LLVM_HAS_ATOMICS )
  message(STATUS "Warning: LLVM will be built thread-unsafe because atomic builtins are missing")
endif()