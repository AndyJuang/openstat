#include "ProcessHelper.h"
#include <libproc.h>
#include <sys/sysctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int sampleProcesses(ProcessSample *out, int maxCount) {
    if (!out || maxCount <= 0) return 0;

    int bufSize = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (bufSize <= 0) return -1;

    int *pids = (int *)malloc((size_t)bufSize);
    if (!pids) return -1;

    int gotBytes = proc_listpids(PROC_ALL_PIDS, 0, pids, bufSize);
    if (gotBytes <= 0) { free(pids); return -1; }

    int pidCount = gotBytes / (int)sizeof(int);
    int written  = 0;

    for (int i = 0; i < pidCount && written < maxCount; i++) {
        int pid = pids[i];
        if (pid <= 0) continue;

        struct proc_taskinfo info;
        int r = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, sizeof(info));
        if (r != (int)sizeof(info)) continue;

        ProcessSample *p = &out[written];
        p->pid           = pid;
        p->cpuTimeNs     = info.pti_total_user + info.pti_total_system;
        p->residentBytes = info.pti_resident_size;

        char name[2 * MAXCOMLEN + 1] = {0};
        if (proc_name(pid, name, sizeof(name)) > 0) {
            strncpy(p->name, name, sizeof(p->name) - 1);
            p->name[sizeof(p->name) - 1] = '\0';
        } else {
            snprintf(p->name, sizeof(p->name), "pid %d", pid);
        }
        written++;
    }

    free(pids);
    return written;
}
