#include <windows.h>

int main() {
    MessageBoxA(0, "Hello", 0, 0);
    return 0;
}

int __main() {
    MessageBoxA(0, "Hello", 0, 0);
    return 0;
}

int wWinMainCRTStartup() {
    MessageBoxA(0, "Hello", 0, 0);
    return 0;
}