#include "DiskHelper.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/storage/IOBlockStorageDriver.h>
#include <sys/mount.h>
#include <sys/param.h>
#include <string.h>

static uint64_t cfNumberToUInt64(CFNumberRef num) {
    int64_t v = 0;
    if (num) CFNumberGetValue(num, kCFNumberSInt64Type, &v);
    return (uint64_t)(v < 0 ? 0 : v);
}

DiskIOStats getDiskIOStats(void) {
    DiskIOStats result = {0, 0};

    CFMutableDictionaryRef match = IOServiceMatching(kIOBlockStorageDriverClass);
    if (!match) return result;

    io_iterator_t iter = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter) != KERN_SUCCESS) {
        return result;
    }

    io_registry_entry_t entry;
    while ((entry = IOIteratorNext(iter))) {
        CFDictionaryRef stats = (CFDictionaryRef)IORegistryEntryCreateCFProperty(
            entry, CFSTR(kIOBlockStorageDriverStatisticsKey), kCFAllocatorDefault, 0);

        if (stats) {
            CFNumberRef r = (CFNumberRef)CFDictionaryGetValue(stats, CFSTR(kIOBlockStorageDriverStatisticsBytesReadKey));
            CFNumberRef w = (CFNumberRef)CFDictionaryGetValue(stats, CFSTR(kIOBlockStorageDriverStatisticsBytesWrittenKey));
            result.bytesRead    += cfNumberToUInt64(r);
            result.bytesWritten += cfNumberToUInt64(w);
            CFRelease(stats);
        }
        IOObjectRelease(entry);
    }
    IOObjectRelease(iter);
    return result;
}

int getDiskVolumes(DiskVolumeInfo *out, int maxCount) {
    if (!out || maxCount <= 0) return 0;

    struct statfs *mounts = NULL;
    int n = getmntinfo(&mounts, MNT_NOWAIT);
    if (n <= 0) return 0;

    int count = 0;
    for (int i = 0; i < n && count < maxCount; i++) {
        const struct statfs *m = &mounts[i];

        // 過濾網路/虛擬掛載：只看 local 實體磁碟
        if ((m->f_flags & MNT_LOCAL) == 0) continue;
        // 系統建立的隱藏 snapshot 掛載常以 /System/Volumes/ 開頭，保留根目錄與一般 /Volumes
        if (strncmp(m->f_mntonname, "/private/var/vm", 15) == 0) continue;
        if (strstr(m->f_fstypename, "devfs"))  continue;

        uint64_t bsize = (uint64_t)m->f_bsize;
        out[count].totalBytes = (uint64_t)m->f_blocks * bsize;
        out[count].freeBytes  = (uint64_t)m->f_bavail * bsize;
        if (out[count].totalBytes == 0) continue;

        strncpy(out[count].mountPoint, m->f_mntonname, sizeof(out[count].mountPoint) - 1);
        out[count].mountPoint[sizeof(out[count].mountPoint) - 1] = '\0';
        strncpy(out[count].name, m->f_mntfromname, sizeof(out[count].name) - 1);
        out[count].name[sizeof(out[count].name) - 1] = '\0';
        count++;
    }
    return count;
}
