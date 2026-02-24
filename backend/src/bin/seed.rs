use rand::Rng;
use reqwest::Client;
use salesnote_backend::config;
use serde_json::{json, Value};
use chrono::{Datelike, NaiveDate, TimeZone, Utc};
use std::time::Instant;

fn env_or_empty(key: &str) -> String {
    std::env::var(key).unwrap_or_default()
}

fn env_or_default(key: &str, default_value: &str) -> String {
    let value = env_or_empty(key);
    if value.trim().is_empty() {
        default_value.to_string()
    } else {
        value.trim().to_string()
    }
}

fn to_base_url(bind: &str) -> String {
    let host_port = if bind.starts_with("0.0.0.0:") {
        bind.replacen("0.0.0.0", "127.0.0.1", 1)
    } else {
        bind.to_string()
    };
    format!("http://{}", host_port)
}

fn pick_customer_name(index: usize) -> String {
    const CUSTOMERS: [&str; 24] = [
        "Amina Yusuf",
        "John Okeke",
        "Mary Bello",
        "Femi Ade",
        "Jane Doe",
        "Alex Rivera",
        "Mike Smith",
        "Grace David",
        "Ibrahim Musa",
        "Ada Nnadi",
        "Sophia Lee",
        "Kwame Asante",
        "Linda Brown",
        "Daniel Osei",
        "Fatima Hassan",
        "Yemi Akin",
        "Samuel Obi",
        "Deborah Cole",
        "Ugo Chukwu",
        "Blessing Tobi",
        "Rita Adams",
        "Victor James",
        "Noah Green",
        "Zara Khan",
    ];
    CUSTOMERS[index % CUSTOMERS.len()].to_string()
}

fn build_items(rng: &mut impl Rng) -> Vec<Value> {
    const CATALOG: [(&str, f64, f64); 18] = [
        ("Oversized Tee XL", 15.0, 45.0),
        ("Denim Jacket S", 35.0, 95.0),
        ("Classic Polo", 18.0, 55.0),
        ("Canvas Sneaker", 22.0, 70.0),
        ("Slim Fit Chinos", 25.0, 80.0),
        ("Leather Belt", 10.0, 35.0),
        ("Baseball Cap", 8.0, 25.0),
        ("Crew Socks (3pk)", 5.0, 18.0),
        ("Linen Shirt", 24.0, 75.0),
        ("Cargo Shorts", 20.0, 60.0),
        ("Hoodie Premium", 30.0, 110.0),
        ("Sports Jogger", 20.0, 65.0),
        ("Flannel Shirt", 22.0, 68.0),
        ("Formal Trousers", 28.0, 90.0),
        ("Ankle Boots", 45.0, 130.0),
        ("Card Wallet", 12.0, 40.0),
        ("Ray Sunglasses", 16.0, 85.0),
        ("Cotton Singlet", 6.0, 20.0),
    ];

    let item_count = rng.gen_range(1..=4);
    let mut items = Vec::with_capacity(item_count);

    for _ in 0..item_count {
        let (name, min_price, max_price) = CATALOG[rng.gen_range(0..CATALOG.len())];
        let quantity = rng.gen_range(1..=5) as f64;
        let unit_price = rng.gen_range(min_price..max_price);
        let rounded_price = (unit_price * 100.0).round() / 100.0;
        items.push(json!({
            "product_name": name,
            "quantity": quantity,
            "unit_price": rounded_price
        }));
    }

    items
}

fn build_items_for_day(rng: &mut impl Rng, day_seed: i64) -> Vec<Value> {
    // Repeatable pattern for some days, random for others.
    if day_seed % 5 == 0 {
        return vec![
            json!({"product_name":"Cargo Shorts","quantity":2.0,"unit_price":60.00}),
            json!({"product_name":"Linen Shirt","quantity":1.0,"unit_price":75.00}),
        ];
    }
    if day_seed % 7 == 0 {
        return vec![
            json!({"product_name":"Oversized Tee XL","quantity":3.0,"unit_price":39.00}),
            json!({"product_name":"Card Wallet","quantity":1.0,"unit_price":40.00}),
        ];
    }
    build_items(rng)
}

async fn post_json(
    client: &Client,
    url: &str,
    body: Value,
    bearer: Option<&str>,
) -> Result<Value, String> {
    let started = Instant::now();
    let mut req = client.post(url).json(&body);
    if let Some(token) = bearer {
        req = req.bearer_auth(token);
    }

    let resp = req.send().await.map_err(|e| {
        let elapsed_ms = started.elapsed().as_millis();
        tracing::error!("seed api POST {} failed in {}ms: {}", url, elapsed_ms, e);
        e.to_string()
    })?;
    let status = resp.status().as_u16();
    let raw = resp.text().await.map_err(|e| {
        let elapsed_ms = started.elapsed().as_millis();
        tracing::error!(
            "seed api POST {} body read failed in {}ms: {}",
            url,
            elapsed_ms,
            e
        );
        e.to_string()
    })?;
    let parsed: Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    let elapsed_ms = started.elapsed().as_millis();
    tracing::info!("seed api POST {} -> {} ({}ms)", url, status, elapsed_ms);

    let success = parsed
        .get("success")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if !success {
        let msg = parsed
            .get("error")
            .and_then(|v| v.get("message"))
            .and_then(Value::as_str)
            .unwrap_or("request failed");
        return Err(format!("{} {} -> {}", url, status, msg));
    }

    Ok(parsed.get("data").cloned().unwrap_or(Value::Null))
}

async fn get_json(client: &Client, url: &str, bearer: &str) -> Result<Value, String> {
    let started = Instant::now();
    let resp = client
        .get(url)
        .bearer_auth(bearer)
        .send()
        .await
        .map_err(|e| {
            let elapsed_ms = started.elapsed().as_millis();
            tracing::error!("seed api GET {} failed in {}ms: {}", url, elapsed_ms, e);
            e.to_string()
        })?;

    let status = resp.status().as_u16();
    let raw = resp.text().await.map_err(|e| {
        let elapsed_ms = started.elapsed().as_millis();
        tracing::error!(
            "seed api GET {} body read failed in {}ms: {}",
            url,
            elapsed_ms,
            e
        );
        e.to_string()
    })?;
    let parsed: Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    let elapsed_ms = started.elapsed().as_millis();
    tracing::info!("seed api GET {} -> {} ({}ms)", url, status, elapsed_ms);

    let success = parsed
        .get("success")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if !success {
        let msg = parsed
            .get("error")
            .and_then(|v| v.get("message"))
            .and_then(Value::as_str)
            .unwrap_or("request failed");
        return Err(format!("{} {} -> {}", url, status, msg));
    }

    Ok(parsed.get("data").cloned().unwrap_or(Value::Null))
}

async fn delete_auth(client: &Client, url: &str, bearer: &str) -> Result<(), String> {
    let started = Instant::now();
    let resp = client
        .delete(url)
        .bearer_auth(bearer)
        .send()
        .await
        .map_err(|e| {
            let elapsed_ms = started.elapsed().as_millis();
            tracing::error!("seed api DELETE {} failed in {}ms: {}", url, elapsed_ms, e);
            e.to_string()
        })?;

    let status = resp.status().as_u16();
    let raw = resp.text().await.map_err(|e| {
        let elapsed_ms = started.elapsed().as_millis();
        tracing::error!(
            "seed api DELETE {} body read failed in {}ms: {}",
            url,
            elapsed_ms,
            e
        );
        e.to_string()
    })?;
    let parsed: Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    let elapsed_ms = started.elapsed().as_millis();
    tracing::info!("seed api DELETE {} -> {} ({}ms)", url, status, elapsed_ms);

    let success = parsed
        .get("success")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if !success {
        let msg = parsed
            .get("error")
            .and_then(|v| v.get("message"))
            .and_then(Value::as_str)
            .unwrap_or("request failed");
        return Err(format!("{} {} -> {}", url, status, msg));
    }

    Ok(())
}

async fn upload_signature_via_api(
    client: &Client,
    base_url: &str,
    bearer: &str,
    name: &str,
    image_url: &str,
) -> Result<Value, String> {
    let started = Instant::now();
    let image_resp = client
        .get(image_url)
        .send()
        .await
        .map_err(|e| format!("signature image download failed: {}", e))?;
    let image_bytes = image_resp
        .bytes()
        .await
        .map_err(|e| format!("signature image read failed: {}", e))?;

    let boundary = format!("----salesnote-seed-{}", rand::thread_rng().gen_range(100000..999999));
    let mut body: Vec<u8> = Vec::new();

    let name_part = format!(
        "--{}\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\n{}\r\n",
        boundary, name
    );
    body.extend_from_slice(name_part.as_bytes());

    let file_header = format!(
        "--{}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"seed-signature.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n",
        boundary
    );
    body.extend_from_slice(file_header.as_bytes());
    body.extend_from_slice(&image_bytes);
    body.extend_from_slice(b"\r\n");

    let close = format!("--{}--\r\n", boundary);
    body.extend_from_slice(close.as_bytes());

    let url = format!("{}/signatures", base_url);
    let resp = client
        .post(&url)
        .bearer_auth(bearer)
        .header(
            reqwest::header::CONTENT_TYPE,
            format!("multipart/form-data; boundary={}", boundary),
        )
        .body(body)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    let status = resp.status().as_u16();
    let raw = resp.text().await.map_err(|e| e.to_string())?;
    let parsed: Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    let elapsed_ms = started.elapsed().as_millis();
    tracing::info!(
        "seed api POST {} (signature upload) -> {} ({}ms)",
        url,
        status,
        elapsed_ms
    );
    let success = parsed
        .get("success")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if !success {
        let msg = parsed
            .get("error")
            .and_then(|v| v.get("message"))
            .and_then(Value::as_str)
            .unwrap_or("request failed");
        return Err(format!("{} {} -> {}", url, status, msg));
    }

    Ok(parsed.get("data").cloned().unwrap_or(Value::Null))
}

async fn login_and_get_token(
    client: &Client,
    base_url: &str,
    email: &str,
    password: &str,
) -> Result<String, String> {
    let login_url = format!("{}/auth/login", base_url);
    let login_data = post_json(
        client,
        &login_url,
        json!({
            "phone_or_email": email,
            "password": password,
            "device_name": "Seed Script",
            "device_platform": "Seed",
            "device_os": "Seed"
        }),
        None,
    )
    .await?;

    match login_data.get("access_token").and_then(Value::as_str) {
        Some(v) if !v.is_empty() => Ok(v.to_string()),
        _ => Err("login response missing access_token".to_string()),
    }
}

async fn cleanup_existing_shop_data_via_api(
    client: &Client,
    base_url: &str,
    bearer: &str,
) -> Result<(), String> {
    let sales_url = format!("{}/sales", base_url);
    let sales_data = get_json(client, &sales_url, bearer).await?;
    let sales = sales_data
        .as_array()
        .ok_or("/sales response is not an array")?;

    for sale in sales {
        let sale_id = sale
            .get("id")
            .and_then(Value::as_i64)
            .ok_or("sale id missing")?;
        let delete_url = format!("{}/sales/{}", base_url, sale_id);
        delete_auth(client, &delete_url, bearer).await.map_err(|e| {
            format!(
                "cannot reset via API (sale delete failed for id={}): {}",
                sale_id, e
            )
        })?;
    }

    let sigs_url = format!("{}/signatures", base_url);
    let sigs_data = get_json(client, &sigs_url, bearer).await?;
    let signatures = sigs_data
        .as_array()
        .ok_or("/signatures response is not an array")?;

    for sig in signatures {
        let sig_id = sig
            .get("id")
            .and_then(Value::as_i64)
            .ok_or("signature id missing")?;
        let delete_url = format!("{}/signatures/{}", base_url, sig_id);
        delete_auth(client, &delete_url, bearer).await?;
    }

    Ok(())
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    config::init_tracing();
    let settings = config::Settings::load();
    tracing::info!(
        "[seed] starting (profile={}, env_file={})",
        config::active_env_profile(),
        config::active_env_file()
    );

    let seed_name = env_or_empty("SALESNOTE__SEED_SHOP_NAME");
    let seed_phone = env_or_empty("SALESNOTE__SEED_SHOP_PHONE");
    let seed_email = env_or_empty("SALESNOTE__SEED_SHOP_EMAIL").to_lowercase();
    let seed_password = env_or_empty("SALESNOTE__SEED_SHOP_PASSWORD");
    let seed_address = env_or_empty("SALESNOTE__SEED_SHOP_ADDRESS");
    let seed_timezone = env_or_default("SALESNOTE__SEED_SHOP_TIMEZONE", "Africa/Lagos");
    let seed_signature_url = env_or_empty("SALESNOTE__SEED_SIGNATURE_URL");
    let seed_api_base_url = env_or_empty("SALESNOTE__SEED_API_BASE_URL");

    if seed_name.trim().is_empty()
        || seed_phone.trim().is_empty()
        || seed_email.trim().is_empty()
        || seed_password.trim().is_empty()
        || seed_address.trim().is_empty()
        || seed_signature_url.trim().is_empty()
    {
        tracing::error!(
            "seed failed: set SALESNOTE__SEED_SHOP_NAME, SALESNOTE__SEED_SHOP_PHONE, SALESNOTE__SEED_SHOP_EMAIL, SALESNOTE__SEED_SHOP_PASSWORD, SALESNOTE__SEED_SHOP_ADDRESS, SALESNOTE__SEED_SIGNATURE_URL"
        );
        return Ok(());
    }

    let base_url = if seed_api_base_url.trim().is_empty() {
        to_base_url(&settings.bind)
    } else {
        seed_api_base_url.trim().to_string()
    };

    let client = Client::new();

    let register_url = format!("{}/auth/register", base_url);
    let register_result = post_json(
        &client,
        &register_url,
        json!({
            "shop_name": seed_name.trim(),
            "phone": seed_phone.trim(),
            "email": seed_email.trim(),
            "password": seed_password.trim(),
            "address": seed_address.trim(),
            "logo_url": Value::Null,
            "timezone": seed_timezone
        }),
        None,
    )
    .await;

    if let Err(err) = &register_result {
        tracing::warn!("register skipped: {}", err);
    }

    let access_token = match login_and_get_token(&client, &base_url, seed_email.trim(), seed_password.trim()).await {
        Ok(token) => token,
        Err(e) => {
            tracing::error!("seed login failed: {}", e);
            return Ok(());
        }
    };

    if register_result.is_err() {
        if let Err(e) = cleanup_existing_shop_data_via_api(&client, &base_url, &access_token).await {
            tracing::error!("seed failed reset step: {}", e);
            return Ok(());
        }
    }

    let signatures_url = format!("{}/signatures", base_url);
    let signatures_data = match get_json(&client, &signatures_url, &access_token).await {
        Ok(v) => v,
        Err(e) => {
            tracing::error!("seed list signatures failed: {}", e);
            return Ok(());
        }
    };

    let signature_id = if let Some(first) = signatures_data.as_array().and_then(|arr| arr.first()) {
        match first.get("id").and_then(Value::as_i64) {
            Some(id) => id,
            None => {
                tracing::error!("seed signature id missing in list response");
                return Ok(());
            }
        }
    } else {
        let created = match upload_signature_via_api(
            &client,
            &base_url,
            &access_token,
            "Amanda",
            seed_signature_url.trim(),
        )
        .await
        {
            Ok(v) => v,
            Err(e) => {
                tracing::error!("seed create signature failed: {}", e);
                return Ok(());
            }
        };

        match created.get("id").and_then(Value::as_i64) {
            Some(id) => id,
            None => {
                tracing::error!("seed created signature missing id");
                return Ok(());
            }
        }
    };

    let sales_url = format!("{}/sales", base_url);

    let start = NaiveDate::from_ymd_opt(2026, 1, 1).expect("invalid fixed start date");
    let end = Utc::now().date_naive();

    let mut rng = rand::thread_rng();
    let mut created_sales = 0_i64;
    let mut day = start;
    let mut customer_index = 0_usize;

    while day <= end {
        let day_ordinal = day.ordinal() as i64;
        let sales_for_day = 2 + (day_ordinal % 4); // 2..5 per day

        for n in 0..sales_for_day {
            let n_i64 = n;
            let with_customer = rng.gen_bool(0.9);
            let customer_name = if with_customer {
                pick_customer_name(customer_index)
            } else {
                "Walk-in Customer".to_string()
            };
            customer_index += 1;

            let customer_contact = if rng.gen_bool(0.5) {
                format!("+234{}", rng.gen_range(700_000_0000_u64..999_999_9999_u64))
            } else {
                let local = customer_name
                    .to_lowercase()
                    .replace(' ', ".")
                    .replace('\'', "")
                    .replace(',', "");
                format!("{}{}@example.com", local, customer_index)
            };

            let hour = 9 + ((n_i64 + (day_ordinal % 8)) % 11); // 09:00..19:00
            let minute = ((day_ordinal * 7 + n_i64 * 11) % 60) as u32;
            let second = ((day_ordinal * 13 + n_i64 * 3) % 60) as u32;
            let dt = Utc
                .with_ymd_and_hms(day.year(), day.month(), day.day(), hour as u32, minute, second)
                .single()
                .expect("invalid generated datetime");

            match post_json(
                &client,
                &sales_url,
                json!({
                    "signature_id": signature_id,
                    "customer_name": customer_name,
                    "customer_contact": customer_contact,
                    "created_at": dt.to_rfc3339(),
                    "items": build_items_for_day(&mut rng, day_ordinal)
                }),
                Some(&access_token),
            )
            .await
            {
                Ok(_) => {
                    created_sales += 1;
                }
                Err(e) => {
                    tracing::error!("seed create sale api error for day {}: {}", day, e);
                }
            };
        }

        day = day.succ_opt().expect("cannot advance day");
    }

    tracing::info!(
        "seed completed via api only: sales={} signature_id={} date_range={}..={}",
        created_sales,
        signature_id,
        start,
        end
    );

    Ok(())
}
