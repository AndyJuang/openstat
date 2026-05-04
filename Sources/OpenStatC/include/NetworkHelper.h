#pragma once
#include <stdint.h>

typedef struct {
    uint64_t bytesIn;
    uint64_t bytesOut;
} NetworkStats;

NetworkStats getNetworkStats(void);
