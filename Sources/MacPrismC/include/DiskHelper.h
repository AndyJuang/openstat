#pragma once
#include <stdint.h>

typedef struct {
    uint64_t bytesRead;
    uint64_t bytesWritten;
} DiskIOStats;

// 全系統累計磁碟讀寫位元數（所有 IOBlockStorageDriver 加總）
DiskIOStats getDiskIOStats(void);

typedef struct {
    char   mountPoint[256];
    char   name[128];
    uint64_t totalBytes;
    uint64_t freeBytes;
} DiskVolumeInfo;

// 列舉本機（非網路、非唯讀系統）掛載點容量。最多 maxCount 筆，回傳實際筆數。
int getDiskVolumes(DiskVolumeInfo *out, int maxCount);
