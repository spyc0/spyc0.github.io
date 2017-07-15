function FindProxyForURL(url, host) {

if (shExpMatch(url, "*t.co.com/*|"))
        return "DIRECT";

if (shExpMatch(url, "*twitter.com/*|"))
        return "DIRECT";

if (shExpMatch(host, "*google.com*"))
        return "DIRECT";
 
// If the hostname matches, send direct.
    if (dnsDomainIs(host, "google.com") ||
        shExpMatch(host, "(*.google.com|*.twitter.com|*.t.co|*.gmail.com)"))
        return "DIRECT";
 
// If the protocol or URL matches, send direct.
    if (url.substring(0, 4)=="ftp:" ||
        shExpMatch(url, "http://abcdomain.com/folder/*"))
        return "DIRECT";
 
// If the requested website is hosted within the internal network, send direct.
    if (isPlainHostName(host) ||
        shExpMatch(host, "*.local") ||
        isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
        isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
        isInNet(dnsResolve(host), "10.0.0.0", "255.255.255.0") ||
        isInNet(dnsResolve(host), "10.0.0.0", "10.0.0.255") ||
        isInNet(dnsResolve(host), "10.0.0.20", "255.255.255.0") ||
        isInNet(dnsResolve(host), "10.0.0.20", "10.0.0.255") ||
        isInNet(dnsResolve(host), "172.16.0.0",  "255.240.0.0") ||
        isInNet(dnsResolve(host), "192.168.0.0",  "255.255.0.0") ||
        isInNet(dnsResolve(host), "127.0.0.1",  "255.0.0.0") ||
        isInNet(dnsResolve(host), "127.0.0.0", "255.255.255.0"))
        return "DIRECT";
 
// If the IP address of the local machine is within a defined
// subnet, send to a specific proxy.
    if (isInNet(myIpAddress(), "10.0.0.20", "255.255.255.0"))
        return "SOCKS5 127.0.0.1:9050";
 
// DEFAULT RULE: All other traffic, use below proxies, in fail-over order.
    return "SOCKS5 spyc0:9100; SOCKS5 spyc0:9050; DIRECT";
 
}
