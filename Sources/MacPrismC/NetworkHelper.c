#include "NetworkHelper.h"
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_var.h>
#include <sys/socket.h>
#include <string.h>

NetworkStats getNetworkStats(void) {
    NetworkStats result = {0, 0};
    struct ifaddrs *ifaddr;

    if (getifaddrs(&ifaddr) != 0) return result;

    for (struct ifaddrs *ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL) continue;
        if (ifa->ifa_addr->sa_family != AF_LINK) continue;
        if (strncmp(ifa->ifa_name, "lo", 2) == 0) continue;
        if (ifa->ifa_data == NULL) continue;

        struct if_data *data = (struct if_data *)ifa->ifa_data;
        result.bytesIn  += (uint64_t)data->ifi_ibytes;
        result.bytesOut += (uint64_t)data->ifi_obytes;
    }

    freeifaddrs(ifaddr);
    return result;
}
