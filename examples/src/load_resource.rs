use bevy::app::AppExit;
use bevy::prelude::*;
use bevy::time::common_conditions::once_after_delay;
use bevy_mod_postgrest::*;
use std::time::Duration;

use crate::todo::Todos;

pub fn load_response_as_resource() {
    fn spawn_task(mut commands: Commands) {
        let url = "http://localhost:3000/get_todos";
        let Some(request) = RPCRequestBundle::new_as_resource::<Todos>(url, "") else {
            error!("invalid request to {url}. It won't be handled");
            return;
        };
        commands.spawn(request);
    }

    fn exit_success(todos: Res<RPCResource<Todos>>, mut exit: EventWriter<AppExit>) {
        todos.iter().for_each(|todo| {
            println!("{todo:?}");
        });

        exit.send(AppExit);
    }

    fn exit_error() {
        panic!("load_response_as_resource failed")
    }

    App::new()
        .add_plugins((MinimalPlugins, BevyPostgrestRPCPlugin))
        .add_systems(Startup, spawn_task)
        .add_systems(
            Update,
            (
                exit_success.run_if(resource_exists::<RPCResource<Todos>>),
                exit_error.run_if(once_after_delay(Duration::from_secs(2))),
            ),
        )
        .run();
}
