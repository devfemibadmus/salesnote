use serde::Deserialize;
use sqlx::PgPool;

use crate::config::Settings;
use crate::models::DeviceSession;

#[derive(Debug, Deserialize)]
struct GeoResponse {
    city: Option<String>,
    region: Option<String>,
    country: Option<String>,
}

pub async fn process_geoip_once(settings: &Settings, pool: &PgPool) -> Result<(), String> {
    let url_template = match settings.geoip_url.as_deref() {
        Some(v) if !v.trim().is_empty() => v,
        _ => {
            tracing::debug!("geoip skipped: SALESNOTE__GEOIP_URL not set");
            return Ok(());
        }
    };

    let pending = DeviceSession::list_missing_location(pool, 50)
        .await
        .map_err(|e| e.to_string())?;

    for device in pending {
        let ip = match device.ip_address.as_deref() {
            Some(v) if !v.trim().is_empty() => v,
            _ => continue,
        };

        let url = url_template.replace("{ip}", ip);
        let client = reqwest::Client::new();
        let mut request = client.get(url);
        if let Some(token) = settings.geoip_token.as_deref() {
            if !token.trim().is_empty() {
                request = request.bearer_auth(token.trim());
            }
        }

        let resp = request.send().await.map_err(|e| e.to_string())?;
        if !resp.status().is_success() {
            tracing::warn!("geoip lookup failed for {}: {}", ip, resp.status());
            continue;
        }

        let geo: GeoResponse = resp.json().await.map_err(|e| e.to_string())?;
        let location = build_location(geo.city, geo.region, geo.country);
        if location.is_empty() {
            continue;
        }

        if let Err(e) = DeviceSession::update_location(pool, device.id, &location).await {
            tracing::warn!("geoip update failed for device {}: {}", device.id, e);
        }
    }

    Ok(())
}

fn build_location(city: Option<String>, region: Option<String>, country: Option<String>) -> String {
    let parts: Vec<String> = [city, region, country]
        .into_iter()
        .flatten()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .collect();
    parts.join(", ")
}
