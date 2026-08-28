-module(datagouv_boot).
-behaviour(application).
-behaviour(supervisor).
-export([start/2, stop/1, init/1]).

start(_Type, _Args) ->
    {ok, Pid} = supervisor:start_link({local, datagouv_boot_sup}, ?MODULE, []),
    _ = application:ensure_all_started(em_filter),
    _ = em_filter:start_agent(datagouv_filter, datagouv_filter_app,
          #{pop_port => 9556,
            query_port => 9557,
            capabilities => datagouv_filter_app:base_capabilities(),
            pop_peers => [{"localhost", 9100}],
            pop_role => leaf}),
    {ok, Pid}.

stop(_State) -> ok.

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 1, period => 5}, []}}.
