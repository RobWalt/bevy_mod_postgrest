#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct Todo {
    id: usize,
    done: bool,
    task: String,
    due: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(serde::Deserialize, bevy::prelude::Deref)]
pub struct Todos(Vec<Todo>);
