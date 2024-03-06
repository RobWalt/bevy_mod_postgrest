#[derive(Debug, serde::Serialize, serde::Deserialize)]
struct Todo {
    id: usize,
    done: bool,
    task: String,
    due: Option<chrono::DateTime<chrono::Utc>>,
}

#[tokio::test]
#[ignore = "only for verifying the test setup"]
async fn basic_postgrest_get_works() {
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

#[test]
fn real_test() {
    use bevy::prelude::*;
    use bevy::time::common_conditions::once_after_delay;
    use std::time::Duration;

    #[derive(Component, serde::Deserialize)]
    pub struct Todos(Vec<Todo>);

    fn spawn_task(mut commands: Commands) {
        let url = "http://localhost:3000/get_todos";
        let Some(request) = bevy_mod_postgrest::RPCRequestBundle::new::<Todos>(url, "") else {
            error!("invalid request to {url}. It won't be handled");
            return;
        };
        commands.spawn(request);
    }

    fn exit_success(todos: Query<&Todos>) {
        todos.iter().for_each(|todos| {
            todos.0.iter().for_each(|todo| {
                println!("{todo:?}");
            });
        });

        std::process::exit(0);
    }

    fn exit_error() {
        std::process::exit(1);
    }

    App::new()
        .add_plugins((MinimalPlugins, bevy_mod_postgrest::BevyPostgrestRPCPlugin))
        .add_systems(Startup, spawn_task)
        .add_systems(
            Update,
            (
                exit_success.run_if(any_with_component::<Todos>),
                exit_error.run_if(once_after_delay(Duration::from_secs(2))),
            ),
        )
        .run();
}
