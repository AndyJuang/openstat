#include "GPUHelper.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

static double cfNumberToDouble(CFDictionaryRef d, CFStringRef key) {
    if (!d) return 0;
    CFNumberRef n = (CFNumberRef)CFDictionaryGetValue(d, key);
    if (!n) return 0;
    double v = 0;
    CFNumberGetValue(n, kCFNumberDoubleType, &v);
    return v;
}

GPUStats getGPUStats(void) {
    GPUStats out = {false, 0, 0};

    io_iterator_t iter = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iter) != KERN_SUCCESS) {
        return out;
    }

    io_registry_entry_t entry;
    double bestUtil = 0;
    double bestMem  = 0;
    bool   found    = false;

    while ((entry = IOIteratorNext(iter))) {
        CFDictionaryRef perf = (CFDictionaryRef)IORegistryEntryCreateCFProperty(
            entry, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);

        if (perf) {
            double util = cfNumberToDouble(perf, CFSTR("Device Utilization %"));
            if (util == 0) util = cfNumberToDouble(perf, CFSTR("GPU Activity(%)"));

            double mem  = cfNumberToDouble(perf, CFSTR("Alloc system memory"));
            if (mem == 0) mem = cfNumberToDouble(perf, CFSTR("In use system memory"));

            if (util > bestUtil) bestUtil = util;
            if (mem  > bestMem)  bestMem  = mem;
            found = true;
            CFRelease(perf);
        }
        IOObjectRelease(entry);
    }
    IOObjectRelease(iter);

    if (found) {
        out.available   = true;
        out.utilization = bestUtil;
        out.deviceMemMB = bestMem / (1024.0 * 1024.0);
    }
    return out;
}
