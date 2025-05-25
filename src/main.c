#include <windows.h>

// Define _tls_index so that UB
// sanitization code can be generated.
// u32 _tls_index = 0;

int test() {
    MessageBoxA(0, "Test", 0, 0);
    return 0;
}
