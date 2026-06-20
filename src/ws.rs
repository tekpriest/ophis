use crate::state::GraphState;
use axum::extract::State;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::response::IntoResponse;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;

#[derive(Clone)]
pub struct AppState {
    pub graph: Arc<GraphState>,
    pub updates: broadcast::Sender<()>,
}

pub async fn ws_handler(ws: WebSocketUpgrade, State(app): State<AppState>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, app))
}

async fn handle_socket(mut socket: WebSocket, app: AppState) {
    let mut rx = app.updates.subscribe();

    if let Ok(snapshot) = serde_json::to_string(&app.graph.snapshot())
        && socket.send(Message::Text(snapshot)).await.is_err()
    {
        return;
    }

    loop {
        tokio::select! {
            changed = rx.recv() => {
                match changed {
                    Ok(_) => {}
                    Err(broadcast::error::RecvError::Lagged(skipped)) => {
                        tracing::debug!("websocket receiver lagged: skipped {skipped} messages");
                    }
                    Err(broadcast::error::RecvError::Closed) => {
                        break;
                    }
                }

                // Throttle updates: wait a brief period to batch rapid events
                tokio::time::sleep(Duration::from_millis(200)).await;

                // Clear any intermediate notifications that queued up during the sleep
                while rx.try_recv().is_ok() {}

                let snapshot = app.graph.snapshot();
                match serde_json::to_string(&snapshot) {
                    Ok(json) => {
                        if socket.send(Message::Text(json)).await.is_err() {
                            break;
                        }
                    }
                    Err(err) => tracing::warn!("failed to serialize snapshot: {err}"),
                }
            }
            _ = tokio::time::sleep(Duration::from_secs(15)) => {
                if socket.send(Message::Ping(vec![])).await.is_err() {
                    break;
                }
            }
        }
    }
}
