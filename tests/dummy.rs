#[tokio::test]
async fn basic_postgrest_get_works() {
    #[derive(Debug, serde::Serialize, serde::Deserialize)]
    struct Todo {
        id: usize,
        done: bool,
        task: String,
        due: Option<chrono::DateTime<chrono::Utc>>,
    }

    let client = postgrest::Postgrest::new("http://localhost:3000");
    let resp_text = client
        .rpc("get_todos", "")
        .execute()
        .await
        .unwrap()
        .text()
        .await
        .unwrap();
    println!("{resp_text:?}");
    let _resp: Vec<Todo> = serde_json::from_str(resp_text.as_str()).unwrap();
    println!("{_resp:?}");
}
