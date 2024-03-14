mod todo;

mod basic;
mod load_component;
mod load_resource;

#[tokio::main]
async fn main() {
    load_resource::load_response_as_resource();
    load_component::load_response_as_component();
    basic::basic_postgrest_get_works().await;
}
