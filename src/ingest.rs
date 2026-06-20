use crate::state::GraphState;
use serde::Deserialize;
use std::sync::Arc;
use tokio::net::UdpSocket;
use tokio::sync::broadcast;

/// Wire format pushed by connectors (Elixir telemetry forwarder, future Go/Node connectors, etc).
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum IngestEvent {
    RpcCall {
        source: String,
        target: String,
        duration_ms: u32,
        status: String,
        #[serde(default)]
        #[allow(dead_code)]
        trace_id: String,
    },
    Heartbeat {
        service: String,
        #[serde(default)]
        #[allow(dead_code)]
        status: String,
    },
}

/// Applies a single ingest event to graph state and notifies websocket
/// subscribers. Shared by both the UDP listener and the HTTP /ingest route
/// so connectors that can't easily send UDP (Postman, browser, serverless)
/// have a path in too.
pub fn apply_event(state: &GraphState, event: IngestEvent, updates: &broadcast::Sender<()>) {
    match event {
        IngestEvent::RpcCall {
            source,
            target,
            duration_ms,
            status,
            ..
        } => {
            state.record_call(&source, &target, duration_ms, status == "ok");
        }
        IngestEvent::Heartbeat { service, .. } => {
            state.touch_node(&service);
        }
    }
    let _ = updates.send(());
}

pub async fn run(
    addr: &str,
    state: Arc<GraphState>,
    updates: broadcast::Sender<()>,
) -> anyhow::Result<()> {
    let socket = UdpSocket::bind(addr).await?;
    tracing::info!("ingest listening on {addr}");
    let mut buf = [0u8; 4096];

    loop {
        let (len, _peer) = socket.recv_from(&mut buf).await?;
        let payload = &buf[..len];

        match serde_json::from_slice::<IngestEvent>(payload) {
            Ok(event) => apply_event(&state, event, &updates),
            Err(err) => {
                tracing::warn!("dropped malformed event ({len} bytes): {err}");
            }
        }
    }
}

