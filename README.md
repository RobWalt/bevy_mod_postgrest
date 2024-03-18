# `bevy_mod_postgrest`

> PostgREST is a standalone web server that turns your PostgreSQL database directly into a RESTful API. The structural constraints and permissions in the database determine the API endpoints and operations.

This crate is the glue to integrate [`PostgREST`](https://postgrest.org/en/v12/) RESTful APIs into the bevy ECS, helping you to prevent custom `async` code while providing a simple and flexible interface.

The library was inspired by [`bevy_mod_reqwest`](https://github.com/TotalKrill/bevy_mod_reqwest) (Thanks!) and offers handling of the special case problem of a PostgREST API.

# Example

```rust
/// This system "spawns a single API reqwest" to get the todos from the database. Once the response was received, it will be available as an entity in the ECS holding a `RPCResponse<Todos>` component which holds a list of todos
fn get_todos(mut commands: Commands) {
    // some rpc endpoint to get todo objects
    let url = "http://localhost:3000/get_todos";
    // The plugin supports rpc endpoints which take arguments, here we just don't need any
    let no_args = "";
    // currently the bundle creation fails on relative urls like "/get_todos" without the url base prefix "http://localhost:3000"
    let Some(request) = RPCRequestBundle::new_as_component::<Todos>(url, no_args) else {
        error!("invalid request to {url}. It won't be handled");
        return;
    };
    // dispatch the request
    commands.spawn(request);
}

/// This system prints todos
fn handle_todo_response(todos: Query<&RPCResponse<Todos>>) {
        todos.iter().for_each(|RPCResponse(todos)| {
            todos.iter().for_each(|todo| {
                info!("New todo: {todo:?}");
            });
        });
    }
```

# License

This bevy plugin is dual-licensed under `MIT` + `Apache-2.0` (as usual in the bevy ecosystem).
