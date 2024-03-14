use crate::todo::Todos;

pub async fn basic_postgrest_get_works() {
    const ERR: &str = "basic postgrest test failed";
    let client = postgrest::Postgrest::new("http://localhost:3000");
    let resp_text = client
        .rpc("get_todos", "")
        .execute()
        .await
        .expect(ERR)
        .text()
        .await
        .expect(ERR);
    let _resp: Todos = serde_json::from_str(resp_text.as_str()).expect(ERR);
}
