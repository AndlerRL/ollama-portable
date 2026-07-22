use serde::Deserialize;
use std::path::PathBuf;

#[derive(Debug, Deserialize)]
struct LiveSessionRaw {
    active: bool,
    model: Option<String>,
    started: Option<String>,
    elapsed_seconds: Option<u64>,
    current_cpu: Option<f64>,
    current_mem_mb: Option<f64>,
    peak_cpu: Option<f64>,
    peak_mem_mb: Option<f64>,
    snapshot_count: Option<u64>,
}

pub struct SessionState {
    pub model: String,
    pub elapsed: String,
    pub cpu: f64,
    pub cpu_peak: f64,
    pub mem: String,
    pub mem_peak: String,
    pub snapshot_count: u64,
}

pub fn read_live_session() -> Option<SessionState> {
    let home = dirs_next()?;
    let path: PathBuf = [home.to_str()?, ".ollama-portable", "sessions", "live.json"]
        .iter()
        .collect();

    let content = std::fs::read_to_string(path).ok()?;
    let raw: LiveSessionRaw = serde_json::from_str(&content).ok()?;

    if !raw.active {
        return None;
    }

    let elapsed_secs = raw.elapsed_seconds.unwrap_or(0);
    let elapsed = if elapsed_secs >= 3600 {
        format!(
            "{}h {}m",
            elapsed_secs / 3600,
            (elapsed_secs % 3600) / 60
        )
    } else if elapsed_secs >= 60 {
        format!("{}m {}s", elapsed_secs / 60, elapsed_secs % 60)
    } else {
        format!("{}s", elapsed_secs)
    };

    let mem = raw.current_mem_mb.unwrap_or(0.0);
    let mem_peak = raw.peak_mem_mb.unwrap_or(0.0);
    let mem_str = if mem >= 1000.0 {
        format!("{:.1}GB", mem / 1000.0)
    } else {
        format!("{:.0}MB", mem)
    };
    let mem_peak_str = if mem_peak >= 1000.0 {
        format!("{:.1}GB", mem_peak / 1000.0)
    } else {
        format!("{:.0}MB", mem_peak)
    };

    Some(SessionState {
        model: raw.model.unwrap_or_else(|| "unknown".to_string()),
        elapsed,
        cpu: raw.current_cpu.unwrap_or(0.0),
        cpu_peak: raw.peak_cpu.unwrap_or(0.0),
        mem: mem_str,
        mem_peak: mem_peak_str,
        snapshot_count: raw.snapshot_count.unwrap_or(0),
    })
}

fn dirs_next() -> Option<PathBuf> {
    std::env::var("HOME").ok().map(PathBuf::from)
}
