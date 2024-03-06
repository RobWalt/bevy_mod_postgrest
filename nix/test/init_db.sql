create schema api;
create table api.todos (
  id serial primary key,
  done boolean not null default false,
  task text not null,
  due timestamptz
);

insert into api.todos (task) values 
  ('finish tutorial 0'), ('pat self on back');

create or replace function api.get_todos()
returns "jsonb" as $$ 
begin
  return (
    select json_agg(json_build_object(
      'id', id,
      'done', done,
      'task', task,
      'due', due
    ))
    from api.todos
  );
end;
$$ language plpgsql;

create role web_anon nologin;

grant usage on schema api to web_anon;
grant select on api.todos to web_anon;

create role authenticator noinherit login password 'mysecretpassword';
grant web_anon to authenticator;
