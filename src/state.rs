use dashmap::DashMap;
use serde::Serialize;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum NodeStatus {
    Healthy,
    Degraded,
    Down,
    Unknown,
}

#[derive(Debug, Clone)]
pub struct NodeHealth {
    pub status: NodeStatus,
    pub last_seen: Instant,
    pub error_rate: f32,
    pub call_count: u64,
}

impl Default for NodeHealth {
    fn default() -> Self {
        Self {
            status: NodeStatus::Healthy,
            last_seen: Instant::now(),
            error_rate: 0.0,
            call_count: 0,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct EdgeStats {
    pub call_count: u64,
    pub error_count: u64,
    pub total_duration_ms: u64,
}

impl EdgeStats {
    pub fn avg_ms(&self) -> f32 {
        if self.call_count == 0 {
            0.0
        } else {
            self.total_duration_ms as f32 / self.call_count as f32
        }
    }

    pub fn error_rate(&self) -> f32 {
        if self.call_count == 0 {
            0.0
        } else {
            self.error_count as f32 / self.call_count as f32
        }
    }
}

pub struct GraphState {
    pub nodes: DashMap<String, NodeHealth>,
    pub edges: DashMap<(String, String), EdgeStats>,
}

impl GraphState {
    pub fn new() -> Self {
        Self {
            nodes: DashMap::new(),
            edges: DashMap::new(),
        }
    }

    pub fn touch_node(&self, name: &str) {
        let mut entry = self.nodes.entry(name.to_string()).or_default();
        entry.last_seen = Instant::now();
        if entry.status == NodeStatus::Unknown {
            entry.status = NodeStatus::Healthy;
        }
    }

    pub fn record_call(&self, source: &str, target: &str, duration_ms: u32, ok: bool) {
        self.touch_node(target);

        let mut edge = self
            .edges
            .entry((source.to_string(), target.to_string()))
            .or_default();
        edge.call_count += 1;
        edge.total_duration_ms += duration_ms as u64;
        if !ok {
            edge.error_count += 1;
        }
        drop(edge);

        let mut node = self.nodes.entry(source.to_string()).or_default();
        node.last_seen = Instant::now();
        node.call_count += 1;

        // exponential moving average so one bad call doesn't immediately tank the node
        let alpha = 0.2;
        let sample = if ok { 0.0 } else { 1.0 };
        node.error_rate = node.error_rate * (1.0 - alpha) + sample * alpha;
        node.status = if node.error_rate > 0.2 {
            NodeStatus::Degraded
        } else {
            NodeStatus::Healthy
        };
    }

    /// Mark anything that hasn't sent a call or heartbeat recently as unknown.
    pub fn sweep_stale(&self, stale_after: Duration) {
        for mut entry in self.nodes.iter_mut() {
            if entry.last_seen.elapsed() > stale_after && entry.status != NodeStatus::Down {
                entry.status = NodeStatus::Unknown;
            }
        }
    }

    pub fn snapshot(&self) -> Snapshot {
        let nodes = self
            .nodes
            .iter()
            .map(|e| SnapshotNode {
                id: e.key().clone(),
                status: e.status,
                error_rate: e.error_rate,
                call_count: e.call_count,
            })
            .collect();

        let edges = self
            .edges
            .iter()
            .map(|e| {
                let (source, target) = e.key().clone();
                SnapshotEdge {
                    source,
                    target,
                    call_count: e.call_count,
                    error_rate: e.error_rate(),
                    avg_ms: e.avg_ms(),
                }
            })
            .collect();

        Snapshot { nodes, edges }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct SnapshotNode {
    pub id: String,
    pub status: NodeStatus,
    pub error_rate: f32,
    pub call_count: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct SnapshotEdge {
    pub source: String,
    pub target: String,
    pub call_count: u64,
    pub error_rate: f32,
    pub avg_ms: f32,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Snapshot {
    pub nodes: Vec<SnapshotNode>,
    pub edges: Vec<SnapshotEdge>,
}
