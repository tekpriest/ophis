mod ingest;
mod state;
mod ws;

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;
use tower_http::services::ServeDir;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let graph = Arc::new(state::GraphState::new());
    let (tx, _rx) = broadcast::channel::<()>(100);

    let app_state = ws::AppState {
        graph: graph.clone(),
        updates: tx.clone(),
    };

    // stale-node sweeper: marks nodes unknown if nothing's been heard from them
    {
        let graph = graph.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(10)).await;
                graph.sweep_stale(Duration::from_secs(30));
            }
        });
    }

    // udp ingest from connectors (elixir telemetry forwarder, etc)
    {
        let graph = graph.clone();
        let tx = tx.clone();
        tokio::spawn(async move {
            if let Err(err) = ingest::run("127.0.0.1:9999", graph, tx).await {
                tracing::error!("ingest task died: {err}");
            }
        });
    }

    let api = Router::new()
        .route("/ws", get(ws::ws_handler))
        .route("/ingest", post(ingest_handler))
        .with_state(app_state);

    let app = Router::new()
        .merge(api)
        .nest_service("/", ServeDir::new("static"));

    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    tracing::info!("dashboard on http://{addr}");
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

/// POST /ingest — same event schema as the UDP listener, for tools that
/// can't easily send raw UDP (Postman, browser fetch, serverless).
async fn ingest_handler(
    State(app): State<ws::AppState>,
    Json(event): Json<ingest::IngestEvent>,
) -> StatusCode {
    ingest::apply_event(&app.graph, event, &app.updates);
    StatusCode::ACCEPTED
}

