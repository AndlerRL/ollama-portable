use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph, Wrap},
    Frame,
};

use crate::app::App;

pub fn draw(f: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // Header
            Constraint::Length(5),  // Container stats
            Constraint::Length(3),  // Active models
            Constraint::Length(5),  // Session
            Constraint::Min(5),     // Logs
            Constraint::Length(1),  // Footer
        ])
        .split(f.area());

    draw_header(f, chunks[0], app);
    draw_container(f, chunks[1], app);
    draw_models(f, chunks[2], app);
    draw_session(f, chunks[3], app);
    draw_logs(f, chunks[4], app);
    draw_footer(f, chunks[5], app);
}

fn draw_header(f: &mut Frame, area: Rect, app: &App) {
    let text = Text::from(vec![
        Line::from(vec![
            Span::styled(" OLLAMA MONITOR ", Style::default().add_modifier(Modifier::BOLD)),
            Span::styled(" | ", Style::default()),
            Span::styled("ollama_server", Style::default().fg(Color::Cyan)),
            Span::styled(" | ", Style::default()),
            Span::styled(app.last_update.as_str(), Style::default().add_modifier(Modifier::DIM)),
        ]),
    ]);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::White));
    f.render_widget(Paragraph::new(text).block(block), area);
}

fn draw_container(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .title(" Container ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::White));

    if let Some(stats) = &app.container_stats {
        let cpu_pct = stats.cpu_percent;
        let cpu_color = if cpu_pct < 50.0 {
            Color::Green
        } else if cpu_pct <= 80.0 {
            Color::Yellow
        } else {
            Color::Red
        };

        let inner = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(1), Constraint::Length(1), Constraint::Length(1)])
            .split(block.inner(area));

        // CPU bar
        let gauge = Gauge::default()
            .gauge_style(Style::default().fg(cpu_color))
            .percent(cpu_pct.min(100.0) as u16)
            .label(format!("CPU: {:.1}%", cpu_pct));
        f.render_widget(gauge, inner[0]);

        // RAM
        let ram_text = format!("RAM: {} / {}", stats.mem_used, stats.mem_total);
        f.render_widget(Paragraph::new(ram_text), inner[1]);

        // NET + Uptime
        let net_text = format!(
            "NET: RX {}  TX {}     UPTIME: {}",
            stats.net_rx, stats.net_tx, stats.uptime
        );
        f.render_widget(Paragraph::new(net_text), inner[2]);

        f.render_widget(block, area);
    } else {
        let text = Text::from("Container not running");
        f.render_widget(Paragraph::new(text).block(block), area);
    }
}

fn draw_models(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .title(" Active Models ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::White));

    if app.active_models.is_empty() {
        let text = Text::from(Span::styled(
            "(none loaded)",
            Style::default().add_modifier(Modifier::DIM),
        ));
        f.render_widget(Paragraph::new(text).block(block), area);
    } else {
        let items: Vec<ListItem> = app
            .active_models
            .iter()
            .map(|m| {
                ListItem::new(format!(
                    "{}  SIZE: {}  GPU: {}%  UNTIL: {}",
                    m.name, m.size, m.gpu_percent, m.until
                ))
            })
            .collect();
        f.render_widget(List::new(items).block(block), area);
    }
}

fn draw_session(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .title(" Live Session ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::White));

    if let Some(session) = &app.session {
        let inner = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(1), Constraint::Length(1), Constraint::Length(1)])
            .split(block.inner(area));

        let model_text = format!("Model: {}    Elapsed: {}", session.model, session.elapsed);
        f.render_widget(Paragraph::new(model_text), inner[0]);

        let cpu_text = format!(
            "CPU: {:.1}% (peak: {:.1}%)    MEM: {} (peak: {})",
            session.cpu, session.cpu_peak, session.mem, session.mem_peak
        );
        f.render_widget(Paragraph::new(cpu_text), inner[1]);

        let snap_text = format!("Snapshots: {}", session.snapshot_count);
        f.render_widget(Paragraph::new(snap_text), inner[2]);

        f.render_widget(block, area);
    } else {
        let text = Text::from(Span::styled(
            "No active session. Run 'task record' to start recording.",
            Style::default().add_modifier(Modifier::DIM),
        ));
        f.render_widget(Paragraph::new(text).block(block), area);
    }
}

fn draw_logs(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .title(" Recent Logs ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::White));

    if app.recent_logs.is_empty() {
        let text = Text::from(Span::styled(
            "(no logs)",
            Style::default().add_modifier(Modifier::DIM),
        ));
        f.render_widget(Paragraph::new(text).block(block), area);
    } else {
        let text = Text::from(
            app.recent_logs
                .iter()
                .map(|l| Line::from(Span::styled(l, Style::default().add_modifier(Modifier::DIM))))
                .collect::<Vec<_>>(),
        );
        f.render_widget(
            Paragraph::new(text).block(block).wrap(Wrap { trim: false }),
            area,
        );
    }
}

fn draw_footer(f: &mut Frame, area: Rect, app: &App) {
    let rec_status = if app.recording { "ON" } else { "OFF" };
    let follow_status = if app.follow_logs { "ON" } else { "OFF" };
    let text = Text::from(Line::from(vec![
        Span::styled(
            format!(" Q=Quit  R=Record [{}]  F=Follow [{}] ", rec_status, follow_status),
            Style::default().add_modifier(Modifier::DIM),
        ),
    ]));
    f.render_widget(Paragraph::new(text), area);
}
