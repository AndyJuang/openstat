#pragma once
#include <stdbool.h>

typedef struct {
    bool   available;
    double utilization;   // 0-100 %
    double deviceMemMB;   // GPU 配置記憶體（MB）；無法取得為 0
} GPUStats;

// 透過 IORegistry 讀取 IOAccelerator 的 PerformanceStatistics
GPUStats getGPUStats(void);
