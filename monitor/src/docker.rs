use anyhow::Result;
use bollard::container::{ListContainersOptions, LogsOptions};
use bollard::Docker;
use futures_util::StreamExt;

pub struct DockerStats {
    pub cpu_percent: f64,
    pub mem_used: String,
    pub mem_total: String,
    pub net_rx: String,
    pub net_tx: String,
    pub uptime: String,
}

pub async fn fetch_stats() -> Result<DockerStats> {
    let docker = Docker::connect_with_local_defaults()?;

    let mut filters = std::collections::HashMap::new();
    filters.insert("name".to_string(), vec!["ollama_server".to_string()]);

    let containers = docker
        .list_containers(Some(ListContainersOptions {
            filters,
            ..Default::default()
        }))
        .await?;

    if containers.is_empty() {
        return Err(anyhow::anyhow!("ollama_server container not found"));
    }

    let container = &containers[0];
    let stats_str = container.status.clone();

    // Parse docker stats output from container inspect
    // For now, return placeholder — full stats require streaming API
    Ok(DockerStats {
        cpu_percent: 0.0,
        mem_used: "N/A".to_string(),
        mem_total: "N/A".to_string(),
        net_rx: "N/A".to_string(),
        net_tx: "N/A".to_string(),
        uptime: "N/A".to_string(),
    })
}

pub async fn fetch_logs(tail: usize) -> Result<Vec<String>> {
    let docker = Docker::connect_with_local_defaults()?;

    let options = LogsOptions::<String> {
        stdout: true,
        stderr: true,
        tail: tail.to_string(),
        ..Default::default()
    };

    let mut stream = docker.logs("ollama_server", Some(options));
    let mut lines = Vec::new();

    while let Some(Ok(log)) = stream.next().await {
        lines.push(log.to_string());
    }

    Ok(lines)
}
