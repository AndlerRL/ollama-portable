use anyhow::Result;
use bollard::container::{ListContainersOptions, LogsOptions, StatsOptions};
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

    let container_id = containers[0].id.as_ref()
        .ok_or_else(|| anyhow::anyhow!("container has no id"))?;

    let mut stats_stream = docker.stats(
        container_id,
        Some(StatsOptions {
            stream: false,
            one_shot: true,
        }),
    );

    if let Some(Ok(stats)) = stats_stream.next().await {
        let cpu_delta = stats.cpu_stats.cpu_usage.total_usage as f64
            - stats.precpu_stats.cpu_usage.total_usage as f64;
        let system_delta = stats.cpu_stats.system_cpu_usage.unwrap_or(0) as f64
            - stats.precpu_stats.system_cpu_usage.unwrap_or(0) as f64;
        let num_cpus = stats.cpu_stats.online_cpus.unwrap_or(1) as f64;
        let cpu_percent = if system_delta > 0.0 && cpu_delta > 0.0 {
            (cpu_delta / system_delta) * num_cpus * 100.0
        } else {
            0.0
        };

        let mem_used = stats.memory_stats.usage.unwrap_or(0);
        let mem_limit = stats.memory_stats.limit.unwrap_or(0);
        let mem_used_str = if mem_used > 1_000_000_000 {
            format!("{:.1}GB", mem_used as f64 / 1_000_000_000.0)
        } else {
            format!("{}MB", mem_used / 1_000_000)
        };
        let mem_total_str = if mem_limit > 1_000_000_000 {
            format!("{:.1}GB", mem_limit as f64 / 1_000_000_000.0)
        } else {
            format!("{}MB", mem_limit / 1_000_000)
        };

        let net_rx = stats.networks.as_ref()
            .and_then(|n| n.values().next())
            .map(|v| v.rx_bytes)
            .unwrap_or(0);
        let net_tx = stats.networks.as_ref()
            .and_then(|n| n.values().next())
            .map(|v| v.tx_bytes)
            .unwrap_or(0);
        let net_rx_str = if net_rx > 1_000_000_000 {
            format!("{:.1}GB", net_rx as f64 / 1_000_000_000.0)
        } else if net_rx > 1_000_000 {
            format!("{:.1}MB", net_rx as f64 / 1_000_000.0)
        } else {
            format!("{}KB", net_rx / 1000)
        };
        let net_tx_str = if net_tx > 1_000_000_000 {
            format!("{:.1}GB", net_tx as f64 / 1_000_000_000.0)
        } else if net_tx > 1_000_000 {
            format!("{:.1}MB", net_tx as f64 / 1_000_000.0)
        } else {
            format!("{}KB", net_tx / 1000)
        };

        let uptime = containers[0].status.clone().unwrap_or_default();

        Ok(DockerStats {
            cpu_percent,
            mem_used: mem_used_str,
            mem_total: mem_total_str,
            net_rx: net_rx_str,
            net_tx: net_tx_str,
            uptime,
        })
    } else {
        Ok(DockerStats {
            cpu_percent: 0.0,
            mem_used: "N/A".to_string(),
            mem_total: "N/A".to_string(),
            net_rx: "N/A".to_string(),
            net_tx: "N/A".to_string(),
            uptime: containers[0].status.clone().unwrap_or_default(),
        })
    }
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
