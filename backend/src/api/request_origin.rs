use actix_web::{dev::ServiceRequest, http::header::HeaderMap, HttpRequest};
use ipnet::IpNet;
use std::net::{IpAddr, SocketAddr};
use std::str::FromStr;

pub fn extract_client_ip(req: &HttpRequest, trusted_proxies: &[IpNet]) -> Option<String> {
    extract_client_ip_from_parts(
        req.headers(),
        req.connection_info().peer_addr(),
        trusted_proxies,
    )
}

pub fn extract_client_ip_for_service(
    req: &ServiceRequest,
    trusted_proxies: &[IpNet],
) -> Option<String> {
    extract_client_ip_from_parts(
        req.headers(),
        req.connection_info().peer_addr(),
        trusted_proxies,
    )
}

pub fn build_location_from_headers(req: &HttpRequest, trusted_proxies: &[IpNet]) -> Option<String> {
    build_location_from_parts(
        req.headers(),
        req.connection_info().peer_addr(),
        trusted_proxies,
    )
}

fn extract_client_ip_from_parts(
    headers: &HeaderMap,
    peer_addr: Option<&str>,
    trusted_proxies: &[IpNet],
) -> Option<String> {
    let peer_ip = parse_ip_or_socket(peer_addr)?;

    if is_trusted_proxy(peer_ip, trusted_proxies) {
        if let Some(ip) = forwarded_client_ip(headers) {
            return Some(ip);
        }
        if let Some(ip) = header_ip(headers, "X-Real-IP") {
            return Some(ip);
        }
    }

    Some(peer_ip.to_string())
}

fn build_location_from_parts(
    headers: &HeaderMap,
    peer_addr: Option<&str>,
    trusted_proxies: &[IpNet],
) -> Option<String> {
    let peer_ip = parse_ip_or_socket(peer_addr)?;
    if !is_trusted_proxy(peer_ip, trusted_proxies) {
        return None;
    }

    let city = header_text(headers, "X-Geo-City");
    let region = header_text(headers, "X-Geo-Region");
    let country =
        header_text(headers, "X-Geo-Country").or_else(|| header_text(headers, "CF-IPCountry"));

    let parts: Vec<String> = [city, region, country]
        .into_iter()
        .flatten()
        .filter(|part| !part.is_empty())
        .collect();

    if parts.is_empty() {
        None
    } else {
        Some(parts.join(", "))
    }
}

fn forwarded_client_ip(headers: &HeaderMap) -> Option<String> {
    headers
        .get("X-Forwarded-For")
        .and_then(|v| v.to_str().ok())
        .and_then(|value| {
            value
                .split(',')
                .map(str::trim)
                .find_map(|candidate| parse_ip_or_socket(Some(candidate)).map(|ip| ip.to_string()))
        })
}

fn header_ip(headers: &HeaderMap, name: &str) -> Option<String> {
    headers
        .get(name)
        .and_then(|v| v.to_str().ok())
        .and_then(|value| parse_ip_or_socket(Some(value.trim())).map(|ip| ip.to_string()))
}

fn header_text(headers: &HeaderMap, name: &str) -> Option<String> {
    headers
        .get(name)
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(ToString::to_string)
}

fn is_trusted_proxy(ip: IpAddr, trusted_proxies: &[IpNet]) -> bool {
    trusted_proxies.iter().any(|net| net.contains(&ip))
}

fn parse_ip_or_socket(value: Option<&str>) -> Option<IpAddr> {
    let value = value?.trim();
    if value.is_empty() {
        return None;
    }

    IpAddr::from_str(value)
        .ok()
        .or_else(|| SocketAddr::from_str(value).ok().map(|addr| addr.ip()))
}
