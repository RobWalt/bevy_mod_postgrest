use bevy_eventlistener::{
    callbacks::Listener,
    event_listener::{EntityEvent, On},
    EventListenerPlugin,
};
use serde::de::DeserializeOwned;
use std::future::Future;

use bevy::{prelude::*, tasks::AsyncComputeTaskPool};
use bevy_eventlistener::EntityEvent;
use crossbeam::channel::{bounded, Receiver, Sender};
use postgrest::Postgrest;

// === plugin ===

pub struct BevyPostgrestRPCPlugin;

impl Plugin for BevyPostgrestRPCPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((
            EventListenerPlugin::<GoodResponse>::default(),
            EventListenerPlugin::<BadResponse>::default(),
        ))
        .add_systems(Update, (Self::handle_new_requests, Self::handle_responses));
    }
}

impl BevyPostgrestRPCPlugin {
    fn handle_new_requests(
        mut commands: Commands,
        added_requests: Query<(Entity, &RPCRequest), Added<RPCRequest>>,
    ) {
        let task_pool = AsyncComputeTaskPool::get();
        added_requests.iter().for_each(|(request, data)| {
            task_pool
                .spawn(create_request(&mut commands, request, data.clone()))
                .detach();
        })
    }

    fn handle_responses(
        existing_requests: Query<(Entity, &RequestDataRx)>,
        mut ev_good_response: EventWriter<GoodResponse>,
        mut ev_bad_response: EventWriter<BadResponse>,
    ) {
        existing_requests
            .iter()
            .filter(|(_, rx)| rx.is_full())
            .for_each(
                |(request, rx)| match rx.try_recv().map_err(anyhow::Error::from) {
                    Ok(Ok(content)) => {
                        ev_good_response.send(GoodResponse {
                            entity: request,
                            content,
                        });
                    }
                    Ok(Err(content)) | Err(content) => {
                        ev_bad_response.send(BadResponse {
                            entity: request,
                            content: content.to_string(),
                        });
                    }
                },
            )
    }
}

fn create_request(
    commands: &mut Commands,
    entity: Entity,
    data: RPCRequest,
) -> impl Future<Output = ()> {
    let (tx, rx) = RequestDataRx::new();
    commands.entity(entity).insert(rx);
    async move {
        let res = async_compat::Compat::new(async move {
            let client = Postgrest::new(data.base.as_str());
            let resp = client
                .rpc(data.function.as_str(), data.params.as_str())
                .execute()
                .await?;
            let text = resp.text().await?;
            Ok(text)
        })
        .await;

        if let Err(e) = tx.send(res) {
            error!("{e:?}");
        }
    }
}

#[derive(Clone, Event, EntityEvent)]
struct GoodResponse {
    #[target]
    entity: Entity,
    content: String,
}

#[derive(Clone, Event, EntityEvent)]
struct BadResponse {
    #[target]
    entity: Entity,
    content: String,
}

// === components ===

#[derive(Debug, Clone, Component, Deref, DerefMut)]
pub struct RequestDataRx(Receiver<anyhow::Result<String>>);

impl RequestDataRx {
    pub fn new() -> (Sender<anyhow::Result<String>>, Self) {
        let (tx, rx) = bounded(1);
        (tx, Self(rx))
    }
}

#[derive(Debug, Clone, Component, Default, Reflect)]
pub struct RPCRequest {
    base: String,
    function: String,
    params: String,
}

#[derive(Bundle)]
pub struct RPCRequestBundle {
    request: RPCRequest,
    on_good: On<GoodResponse>,
    on_bad: On<BadResponse>,
}

impl RPCRequestBundle {
    pub fn new<T: DeserializeOwned + Component>(url: &str, params: &str) -> Option<Self> {
        let (base, function) = url.rsplit_once("/")?;
        let request = RPCRequest {
            base: base.to_string(),
            function: function.to_string(),
            params: params.to_string(),
        };
        let on_good = On::<GoodResponse>::run(handle_good::<T>);
        let on_bad = On::<BadResponse>::run(handle_bad);
        Some(Self {
            request,
            on_good,
            on_bad,
        })
    }
}

fn handle_good<T: DeserializeOwned + Component>(
    mut commands: Commands,
    resp: Listener<GoodResponse>,
) {
    match serde_json::from_str::<T>(resp.content.as_str()) {
        Ok(val) => {
            commands.entity(resp.entity).insert(val);
        }
        Err(error) => {
            error!("{error:?}");
        }
    };
    commands.entity(resp.entity).remove::<RPCRequestBundle>();
}

fn handle_bad(mut commands: Commands, resp: Listener<BadResponse>) {
    error!("{error}", error = resp.content);
    commands.entity(resp.entity).remove::<RPCRequestBundle>();
}