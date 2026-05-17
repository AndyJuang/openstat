#pragma once
#include <stdint.h>

typedef struct {
    int      pid;
    char     name[64];
    uint64_t cpuTimeNs;    // 累計 user+system 時間（奈秒）
    uint64_t residentBytes;
} ProcessSample;

// 取得行程清單。out 必須能容納 maxCount 筆。回傳實際筆數，-1 表示失敗。
int sampleProcesses(ProcessSample *out, int maxCount);
