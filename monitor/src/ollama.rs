use anyhow::Result;

pub struct OllamaModels {
    pub name: String,
    pub size: String,
    pub gpu_percent: f64,
    pub until: String,
}

pub async fn fetch_models() -> Result<Vec<OllamaModels>> {
    let host = std::env::var("OLLAMA_HOST").unwrap_or_else(|_| "ollama_server:11434".to_string());
    let url = format!("http://{}/api/ps", host);

    let client = reqwest::Client::new();
    let resp = client.get(&url).send().await?;
    let data: serde_json::Value = resp.json().await?;

    let models = data["models"]
        .as_array()
        .unwrap_or(&Vec::new())
        .iter()
        .map(|m| {
            let name = m["name"].as_str().unwrap_or("unknown").to_string();
            let size_raw = m["size"].as_u64().unwrap_or(0);
            let size_vram = m["size_vram"].as_u64().unwrap_or(0);
            let total = size_raw + size_vram;
            let gpu_pct = if total > 0 {
                (size_vram as f64 / total as f64) * 100.0
            } else {
                0.0
            };

            let expires = m["expires_at"].as_str().unwrap_or("");
            let until = if expires.is_empty() {
                "forever".to_string()
            } else {
                expires.to_string()
            };

            let size_str = if size_raw > 1_000_000_000 {
                format!("{:.1}GB", size_raw as f64 / 1_000_000_000.0)
            } else {
                format!("{}MB", size_raw / 1_000_000)
            };

            OllamaModels {
                name,
                size: size_str,
                gpu_percent: gpu_pct,
                until,
            }
        })
        .collect();

    Ok(models)
}
