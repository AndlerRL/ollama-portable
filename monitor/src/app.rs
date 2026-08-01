use anyhow::Result;
use chrono::Local;

use crate::docker::DockerStats;
use crate::ollama::OllamaModels;
use crate::session::SessionState;

pub struct App {
    pub container_stats: Option<DockerStats>,
    pub active_models: Vec<OllamaModels>,
    pub recent_logs: Vec<String>,
    pub session: Option<SessionState>,
    pub recording: bool,
    pub follow_logs: bool,
    pub last_update: String,
}

impl App {
    pub async fn new() -> Result<Self> {
        let mut app = Self {
            container_stats: None,
            active_models: Vec::new(),
            recent_logs: Vec::new(),
            session: None,
            recording: false,
            follow_logs: true,
            last_update: Local::now().format("%Y-%m-%d %H:%M:%S").to_string(),
        };
        app.tick().await;
        Ok(app)
    }

    pub async fn tick(&mut self) {
        // Fetch container stats
        if let Ok(stats) = crate::docker::fetch_stats().await {
            self.container_stats = Some(stats);
        }

        // Fetch active models
        if let Ok(models) = crate::ollama::fetch_models().await {
            self.active_models = models;
        }

        // Fetch recent logs
        if let Ok(logs) = crate::docker::fetch_logs(5).await {
            self.recent_logs = logs;
        }

        // Fetch session state
        self.session = crate::session::read_live_session();

        self.last_update = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    }

    pub fn toggle_recording(&mut self) {
        self.recording = !self.recording;
        // TODO: spawn/kill record.sh process
    }

    pub fn toggle_follow(&mut self) {
        self.follow_logs = !self.follow_logs;
    }
}
